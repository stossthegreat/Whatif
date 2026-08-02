import pg from 'pg';

/// Postgres persistence — the memory that survives restarts. Entirely
/// fail-soft: no DATABASE_URL (or a dead database) means every call quietly
/// no-ops and the server keeps running from RAM exactly as before. The DB is a
/// ledger, never a gatekeeper: matchmaking must never block on it.
const URL = process.env.DATABASE_URL || '';

const pool = URL
  ? new pg.Pool({
      connectionString: URL,
      max: 5,
      // Railway Postgres requires TLS from outside the private network but
      // not within it; 'prefer' behavior via ssl config when the url asks.
      ssl: URL.includes('sslmode=require') ? { rejectUnauthorized: false } : undefined,
    })
  : null;

export const dbEnabled = !!pool;

async function run(q: string, params: unknown[] = []): Promise<pg.QueryResult | null> {
  if (!pool) return null;
  try {
    return await pool.query(q, params);
  } catch (e) {
    console.error('[db]', (e as Error).message);
    return null;
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
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_seen TIMESTAMPTZ NOT NULL DEFAULT now()
  )`);
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
  await run(`CREATE TABLE IF NOT EXISTS day_stats (
    day DATE PRIMARY KEY,
    matches BIGINT NOT NULL DEFAULT 0
  )`);
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
export function addReport(reporter: string, target: string): void {
  void run('INSERT INTO reports (reporter, target) VALUES ($1,$2)', [reporter, target]);
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
