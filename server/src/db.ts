import pg from 'pg';

/// Postgres persistence — the memory that survives restarts. Entirely
/// fail-soft: no DATABASE_URL (or a dead database) means every call quietly
/// no-ops and the server keeps running from RAM exactly as before. The DB is a
/// ledger, never a gatekeeper: matchmaking must never block on it.
const URL = process.env.DATABASE_URL || '';

const sslFor = (url: string) =>
  url.includes('sslmode=require') ? { rejectUnauthorized: false } : undefined;

const pool = URL
  ? new pg.Pool({
      connectionString: URL,
      // hello runs ~6 queries in parallel and media GETs hold a connection
      // while buffering — 5 was a queueing choke point at any real load.
      max: 10,
      connectionTimeoutMillis: 5000, // fail fast into run()'s null path, never hang a verb
      idleTimeoutMillis: 30_000,
      keepAlive: true,
      // no verb query may camp on a connection — the pool is shared
      options: '-c statement_timeout=10000',
      // Railway Postgres requires TLS from outside the private network but
      // not within it; 'prefer' behavior via ssl config when the url asks.
      ssl: sslFor(URL),
    })
  : null;

// an idle client dying (backend restart, conn reset) emits 'error' on the
// pool — unhandled, that event would take the whole process down
pool?.on('error', (e) => console.error('[db] pool idle-client error:', e.message));

export const dbEnabled = !!pool;

export async function run(q: string, params: unknown[] = []): Promise<pg.QueryResult | null> {
  if (!pool) return null;
  try {
    return await pool.query(q, params);
  } catch (e) {
    console.error('[db]', (e as Error).message);
    return null;
  }
}

/// DDL runner: index creation over a large table can exceed the pool's 10s
/// statement timeout, so schema init gets its own untimed client, closed
/// when done. Init failures log-and-continue (fail-soft like everything).
export async function runInit(statements: string[]): Promise<boolean> {
  if (!URL) return false;
  const c = new pg.Client({
    connectionString: URL,
    options: '-c statement_timeout=0',
    ssl: sslFor(URL),
  });
  try {
    await c.connect();
    for (const s of statements) await c.query(s);
    return true;
  } catch (e) {
    console.error('[db] init:', (e as Error).message);
    return false;
  } finally {
    void c.end().catch(() => {});
  }
}

export async function initDb(): Promise<void> {
  if (!pool) {
    console.log('[db] DATABASE_URL not set — running memory-only');
    return;
  }
  await run(`CREATE TABLE IF NOT EXISTS users (
    uid TEXT PRIMARY KEY,
    name TEXT NOT NULL DEFAULT '',
    hue DOUBLE PRECISION NOT NULL DEFAULT 210,
    gender TEXT,
    meet TEXT,
    vibes JSONB NOT NULL DEFAULT '[]',
    push_token TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_seen TIMESTAMPTZ NOT NULL DEFAULT now()
  )`);
  await run('ALTER TABLE users ADD COLUMN IF NOT EXISTS push_token TEXT');
  await run(`CREATE TABLE IF NOT EXISTS saves (
    uid TEXT NOT NULL,
    target TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (uid, target)
  )`);
  await run(`CREATE TABLE IF NOT EXISTS blocks (
    uid TEXT NOT NULL,
    target TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (uid, target)
  )`);
  await run(`CREATE TABLE IF NOT EXISTS reports (
    id BIGSERIAL PRIMARY KEY,
    reporter TEXT NOT NULL DEFAULT '',
    target TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
  )`);
  // categories make triage possible — an untriaged report queue can't honour
  // the 24h promise, and child-safety/nudity must jump the line
  await run("ALTER TABLE reports ADD COLUMN IF NOT EXISTS reason TEXT NOT NULL DEFAULT 'other'");
  await run('ALTER TABLE reports ADD COLUMN IF NOT EXISTS severity SMALLINT NOT NULL DEFAULT 1');
  await run('ALTER TABLE reports ADD COLUMN IF NOT EXISTS context TEXT');
  await run('ALTER TABLE reports ADD COLUMN IF NOT EXISTS media_id BIGINT');
  await run('ALTER TABLE reports ADD COLUMN IF NOT EXISTS handled_at TIMESTAMPTZ');

  // Real sanctions. Keyed by uid OR device: a device ban survives the
  // delete-app-and-reinstall trick that made every previous ban a suggestion.
  await run(`CREATE TABLE IF NOT EXISTS bans (
    id BIGSERIAL PRIMARY KEY,
    subject_type TEXT NOT NULL CHECK (subject_type IN ('uid','device')),
    subject TEXT NOT NULL,
    reason TEXT NOT NULL DEFAULT '',
    until TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
  )`);
  // which hardware an account has used — lets an account ban also pin the
  // device, so the reinstall path is closed too
  await run(`CREATE TABLE IF NOT EXISTS user_devices (
    uid TEXT NOT NULL,
    device_id TEXT NOT NULL,
    last_seen TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (uid, device_id)
  )`);
  await run(`CREATE TABLE IF NOT EXISTS day_stats (
    day DATE PRIMARY KEY,
    matches BIGINT NOT NULL DEFAULT 0
  )`);
  // reverse lookups that run on EVERY hello (savedBy / blockedBy / report
  // count) — without these they seq-scan whole tables. Untimed init client:
  // building an index over a big table can take longer than the pool allows.
  await runInit([
    'CREATE INDEX IF NOT EXISTS saves_target ON saves(target)',
    'CREATE INDEX IF NOT EXISTS blocks_target ON blocks(target)',
    'CREATE INDEX IF NOT EXISTS reports_target ON reports(target)',
    'CREATE INDEX IF NOT EXISTS reports_open ON reports(handled_at, severity DESC, created_at DESC)',
    'CREATE UNIQUE INDEX IF NOT EXISTS bans_subject ON bans(subject_type, subject)',
  ]);
  console.log('[db] connected, schema ready');
}

export function upsertUser(u: {
  uid: string; name: string; hue: number; gender?: string; meet?: string; vibes?: string[];
}): void {
  void run(
    `INSERT INTO users (uid, name, hue, gender, meet, vibes, last_seen)
     VALUES ($1,$2,$3,$4,$5,$6, now())
     ON CONFLICT (uid) DO UPDATE SET
       name = EXCLUDED.name, hue = EXCLUDED.hue,
       gender = COALESCE(EXCLUDED.gender, users.gender),
       meet = COALESCE(EXCLUDED.meet, users.meet),
       vibes = EXCLUDED.vibes, last_seen = now()`,
    [u.uid, u.name, u.hue, u.gender ?? null, u.meet ?? null, JSON.stringify(u.vibes ?? [])],
  );
}

/// Everything social about one uid, loaded on hello to hydrate the in-memory
/// maps: who they saved, who saved them, who they blocked, who blocked them,
/// and how many times they've been reported.
export async function loadSocial(uid: string): Promise<{
  saves: { target: string; name: string | null }[];
  savedBy: string[]; blocks: string[]; blockedBy: string[]; reports: number;
} | null> {
  if (!pool) return null;
  const [saves, savedBy, blocks, blockedBy, reports] = await Promise.all([
    run(`SELECT s.target, u.name FROM saves s
         LEFT JOIN users u ON u.uid = s.target WHERE s.uid = $1`, [uid]),
    run('SELECT uid FROM saves WHERE target = $1', [uid]),
    run('SELECT target FROM blocks WHERE uid = $1', [uid]),
    run('SELECT uid FROM blocks WHERE target = $1', [uid]),
    run('SELECT count(*)::int AS n FROM reports WHERE target = $1', [uid]),
  ]);
  return {
    saves: (saves?.rows ?? []).map((r) => ({ target: r.target as string, name: (r.name as string | null) })),
    savedBy: (savedBy?.rows ?? []).map((r) => r.uid as string),
    blocks: (blocks?.rows ?? []).map((r) => r.target as string),
    blockedBy: (blockedBy?.rows ?? []).map((r) => r.uid as string),
    reports: reports?.rows?.[0]?.n ?? 0,
  };
}

export function addSave(uid: string, target: string): void {
  void run('INSERT INTO saves (uid, target) VALUES ($1,$2) ON CONFLICT DO NOTHING', [uid, target]);
}
export function removeSave(uid: string, target: string): void {
  void run('DELETE FROM saves WHERE uid = $1 AND target = $2', [uid, target]);
}
export function addBlock(uid: string, target: string): void {
  void run('INSERT INTO blocks (uid, target) VALUES ($1,$2) ON CONFLICT DO NOTHING', [uid, target]);
}
export function removeBlock(uid: string, target: string): void {
  void run('DELETE FROM blocks WHERE uid = $1 AND target = $2', [uid, target]);
}
export function savePushToken(uid: string, token: string): void {
  void run('UPDATE users SET push_token = $2 WHERE uid = $1', [uid, token]);
}

/// Push targets when [uid] goes live: people who saved them AND whom they
/// saved back (mutuals only — anything less is stalker fuel), with a token.
export async function mutualPushTargets(uid: string): Promise<{ uid: string; token: string }[]> {
  const r = await run(
    `SELECT u.uid, u.push_token AS token
     FROM saves s1
     JOIN saves s2 ON s2.uid = $1 AND s2.target = s1.uid
     JOIN users u ON u.uid = s1.uid
     WHERE s1.target = $1 AND u.push_token IS NOT NULL`,
    [uid],
  );
  return (r?.rows ?? []).map((x) => ({ uid: x.uid as string, token: x.token as string }));
}
export function addReport(
  reporter: string, target: string,
  opts: { reason?: string; severity?: number; context?: string; mediaId?: number } = {},
): void {
  void run(
    `INSERT INTO reports (reporter, target, reason, severity, context, media_id)
     VALUES ($1,$2,$3,$4,$5,$6)`,
    [reporter, target, opts.reason ?? 'other', opts.severity ?? 1,
     opts.context ?? null, opts.mediaId ?? null]);
}

// ---- bans -------------------------------------------------------------------
// A ban is a row, not a socket close: it must survive reconnects, restarts and
// reinstalls. `until` NULL means permanent.

export interface BanRow { subject: string; subjectType: string; reason: string; until: string | null; }

/// Is this uid OR device banned right now? Expired rows are ignored (and
/// swept lazily) so a 24h hold lifts itself with no cron.
export async function activeBan(uid: string, deviceId?: string | null): Promise<BanRow | null> {
  const r = await run(
    `SELECT subject, subject_type, reason, until FROM bans
      WHERE (until IS NULL OR until > now())
        AND ((subject_type='uid' AND subject=$1)
          OR (subject_type='device' AND $2::text IS NOT NULL AND subject=$2))
      ORDER BY until IS NULL DESC, until DESC LIMIT 1`,
    [uid, deviceId ?? null]);
  const row = r?.rows?.[0];
  if (!row) return null;
  return {
    subject: row.subject as string, subjectType: row.subject_type as string,
    reason: (row.reason as string) ?? '', until: row.until ? String(row.until) : null,
  };
}

/// Ban a uid or device. hours <= 0 (or omitted) means permanent.
export function addBan(subjectType: 'uid' | 'device', subject: string, reason: string, hours?: number): void {
  const until = hours && hours > 0 ? `now() + interval '${Math.floor(hours)} hours'` : 'NULL';
  void run(
    `INSERT INTO bans (subject_type, subject, reason, until)
     VALUES ($1,$2,$3, ${until})
     ON CONFLICT (subject_type, subject) DO UPDATE SET
       reason = EXCLUDED.reason, until = EXCLUDED.until, created_at = now()`,
    [subjectType, subject, reason.slice(0, 200)]);
}

export function clearBan(subjectType: 'uid' | 'device', subject: string): void {
  void run('DELETE FROM bans WHERE subject_type=$1 AND subject=$2', [subjectType, subject]);
}

/// The device(s) a uid has connected from — so banning the account can also
/// pin the hardware it used.
export function devicesFor(uid: string): Promise<pg.QueryResult | null> {
  return run('SELECT device_id FROM user_devices WHERE uid=$1 ORDER BY last_seen DESC LIMIT 5', [uid]);
}

export function noteDevice(uid: string, deviceId: string): void {
  void run(
    `INSERT INTO user_devices (uid, device_id, last_seen) VALUES ($1,$2, now())
     ON CONFLICT (uid, device_id) DO UPDATE SET last_seen = now()`,
    [uid, deviceId.slice(0, 64)]);
}

/// Account deletion — the privacy policy's §8 made real. Removes the user
/// row, saves in both directions, their blocks, and the push token. Report
/// ROWS naming them are kept (community-safety retention, policy §7).
export function deleteUser(uid: string): void {
  void run('DELETE FROM saves WHERE uid = $1 OR target = $1', [uid]);
  void run('DELETE FROM blocks WHERE uid = $1', [uid]);
  void run('DELETE FROM users WHERE uid = $1', [uid]);
}

export function bumpMatches(day: string): void {
  void run(
    `INSERT INTO day_stats (day, matches) VALUES ($1, 1)
     ON CONFLICT (day) DO UPDATE SET matches = day_stats.matches + 1`,
    [day],
  );
}

export async function loadMatches(day: string): Promise<number> {
  const r = await run('SELECT matches::int AS n FROM day_stats WHERE day = $1', [day]);
  return r?.rows?.[0]?.n ?? 0;
}
