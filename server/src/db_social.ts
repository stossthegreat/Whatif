import { run, dbEnabled } from './db.js';

/// Social-layer persistence: friendships, encounters, ratings, trait votes,
/// messages, stats, badges, media, events. Same fail-soft contract as db.ts —
/// no DATABASE_URL means every call quietly no-ops (social verbs answer
/// {t:'err', code:'noDb'} at the protocol layer).
///
/// Pair convention EVERYWHERE: a < b lexicographically.
export function pair(u: string, v: string): [string, string] {
  return u < v ? [u, v] : [v, u];
}
export function pairKey(u: string, v: string): string {
  const [a, b] = pair(u, v);
  return `${a}|${b}`;
}

// ---- schema (all builds' tables created up front; features arrive in waves)
export async function initSocial(): Promise<void> {
  if (!dbEnabled) return;
  const alters = [
    "ALTER TABLE users ADD COLUMN IF NOT EXISTS age INT",
    "ALTER TABLE users ADD COLUMN IF NOT EXISTS bio TEXT NOT NULL DEFAULT ''",
    'ALTER TABLE users ADD COLUMN IF NOT EXISTS city TEXT',
    'ALTER TABLE users ADD COLUMN IF NOT EXISTS country TEXT',
    'ALTER TABLE users ADD COLUMN IF NOT EXISTS pronouns TEXT',
    "ALTER TABLE users ADD COLUMN IF NOT EXISTS languages JSONB NOT NULL DEFAULT '[]'",
    "ALTER TABLE users ADD COLUMN IF NOT EXISTS looking_for JSONB NOT NULL DEFAULT '[]'",
    "ALTER TABLE users ADD COLUMN IF NOT EXISTS interests JSONB NOT NULL DEFAULT '[]'",
    'ALTER TABLE users ADD COLUMN IF NOT EXISTS photo_media_id BIGINT',
    'ALTER TABLE users ADD COLUMN IF NOT EXISTS tz_offset_min INT',
    'ALTER TABLE users ADD COLUMN IF NOT EXISTS active_title TEXT',
    'ALTER TABLE users ADD COLUMN IF NOT EXISTS apple_id TEXT',
  ];
  for (const q of alters) await run(q);
  await run(`CREATE UNIQUE INDEX IF NOT EXISTS users_apple_idx
             ON users(apple_id) WHERE apple_id IS NOT NULL`);

  await run(`CREATE TABLE IF NOT EXISTS media (
    id BIGSERIAL PRIMARY KEY,
    owner TEXT NOT NULL,
    kind TEXT NOT NULL CHECK (kind IN ('photo','voice','avatar')),
    mime TEXT NOT NULL,
    bytes BYTEA NOT NULL,
    size INT NOT NULL,
    pair_key TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
  )`);
  await run('CREATE INDEX IF NOT EXISTS media_owner ON media(owner)');

  await run(`CREATE TABLE IF NOT EXISTS friendships (
    a TEXT NOT NULL, b TEXT NOT NULL,
    state TEXT NOT NULL CHECK (state IN ('pending','friends')),
    requested_by TEXT,
    origin TEXT NOT NULL DEFAULT 'match',
    a_tier SMALLINT NOT NULL DEFAULT 0,
    b_tier SMALLINT NOT NULL DEFAULT 0,
    a_pinned BOOLEAN NOT NULL DEFAULT false,
    b_pinned BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    matched_at TIMESTAMPTZ,
    PRIMARY KEY (a, b),
    CHECK (a < b)
  )`);
  await run('CREATE INDEX IF NOT EXISTS friendships_b ON friendships(b)');

  await run(`CREATE TABLE IF NOT EXISTS encounters (
    id BIGSERIAL PRIMARY KEY,
    a TEXT NOT NULL, b TEXT NOT NULL,
    cell_id TEXT NOT NULL,
    secs INT NOT NULL DEFAULT 0,
    a_country TEXT, b_country TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (a, b, cell_id)
  )`);
  await run('CREATE INDEX IF NOT EXISTS encounters_pair ON encounters(a, b, created_at DESC)');
  await run('CREATE INDEX IF NOT EXISTS encounters_bx ON encounters(b, created_at DESC)');
  await run('CREATE INDEX IF NOT EXISTS encounters_ax ON encounters(a, created_at DESC)');

  await run(`CREATE TABLE IF NOT EXISTS ratings (
    rater TEXT NOT NULL, target TEXT NOT NULL, cell_id TEXT NOT NULL,
    score SMALLINT NOT NULL CHECK (score BETWEEN 0 AND 3),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (rater, target, cell_id)
  )`);
  await run('CREATE INDEX IF NOT EXISTS ratings_pairx ON ratings(target, rater, created_at DESC)');

  await run(`CREATE TABLE IF NOT EXISTS personality_votes (
    voter TEXT NOT NULL, target TEXT NOT NULL,
    trait TEXT NOT NULL CHECK (trait IN
      ('funny','smart','chill','chaotic','flirty','confident','competitive','listener')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (voter, target)
  )`);
  await run('CREATE INDEX IF NOT EXISTS pvotes_target ON personality_votes(target)');

  await run(`CREATE TABLE IF NOT EXISTS messages (
    id BIGSERIAL PRIMARY KEY,
    a TEXT NOT NULL, b TEXT NOT NULL,
    sender TEXT NOT NULL,
    kind TEXT NOT NULL CHECK (kind IN ('text','voice','photo','gif','invite','call')),
    body TEXT NOT NULL DEFAULT '',
    media_id BIGINT,
    meta JSONB NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
  )`);
  await run('CREATE INDEX IF NOT EXISTS messages_pairx ON messages(a, b, id DESC)');

  await run(`CREATE TABLE IF NOT EXISTS message_reactions (
    message_id BIGINT NOT NULL, uid TEXT NOT NULL, emoji TEXT NOT NULL,
    PRIMARY KEY (message_id, uid)
  )`);

  await run(`CREATE TABLE IF NOT EXISTS chat_state (
    uid TEXT NOT NULL, peer TEXT NOT NULL,
    last_read_id BIGINT NOT NULL DEFAULT 0,
    PRIMARY KEY (uid, peer)
  )`);

  await run(`CREATE TABLE IF NOT EXISTS user_stats (
    uid TEXT PRIMARY KEY,
    rooms INT NOT NULL DEFAULT 0,
    rooms_won INT NOT NULL DEFAULT 0,
    point_wins INT NOT NULL DEFAULT 0,
    laughs INT NOT NULL DEFAULT 0,
    games INT NOT NULL DEFAULT 0,
    friends_made INT NOT NULL DEFAULT 0,
    requests_in INT NOT NULL DEFAULT 0,
    legend_ratings INT NOT NULL DEFAULT 0,
    chaos INT NOT NULL DEFAULT 0,
    streak INT NOT NULL DEFAULT 0,
    streak_best INT NOT NULL DEFAULT 0,
    streak_day DATE,
    night_rooms INT NOT NULL DEFAULT 0,
    rep NUMERIC NOT NULL DEFAULT 0
  )`);

  await run(`CREATE TABLE IF NOT EXISTS user_badges (
    uid TEXT NOT NULL, badge TEXT NOT NULL,
    earned_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (uid, badge)
  )`);

  await run(`CREATE TABLE IF NOT EXISTS events (
    key TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    kind TEXT NOT NULL DEFAULT 'season',
    starts_at TIMESTAMPTZ NOT NULL,
    ends_at TIMESTAMPTZ NOT NULL,
    meta JSONB NOT NULL DEFAULT '{}'
  )`);

  // legacy sparks -> friendships (idempotent; keeps running every boot so any
  // straggler mutual saves from old clients keep converting)
  await run(`INSERT INTO friendships (a, b, state, origin, matched_at)
    SELECT LEAST(s1.uid, s1.target), GREATEST(s1.uid, s1.target), 'friends', 'legacy', now()
    FROM saves s1 JOIN saves s2 ON s2.uid = s1.target AND s2.target = s1.uid
    WHERE s1.uid < s1.target
    ON CONFLICT DO NOTHING`);

  console.log('[db] social schema ready');
}

// ---- friendships -----------------------------------------------------------
export interface FriendRow {
  uid: string; name: string; hue: number; photoId: number | null;
  title: string | null; tier: number; pinned: boolean; lastSeen: string | null;
  state: 'pending' | 'friends'; requestedBy: string | null; matchedAt: string | null;
}

/// Everything about [uid]'s edges in one query: friends + pending both ways.
export async function edgesOf(uid: string): Promise<FriendRow[]> {
  const r = await run(
    `SELECT f.a, f.b, f.state, f.requested_by, f.matched_at,
            CASE WHEN f.a = $1 THEN f.a_tier ELSE f.b_tier END AS tier,
            CASE WHEN f.a = $1 THEN f.a_pinned ELSE f.b_pinned END AS pinned,
            u.uid AS peer, u.name, u.hue, u.photo_media_id, u.active_title, u.last_seen
     FROM friendships f
     JOIN users u ON u.uid = CASE WHEN f.a = $1 THEN f.b ELSE f.a END
     WHERE f.a = $1 OR f.b = $1
     ORDER BY f.matched_at DESC NULLS LAST, f.created_at DESC`,
    [uid],
  );
  return (r?.rows ?? []).map((x) => ({
    uid: x.peer as string,
    name: (x.name as string) ?? 'someone',
    hue: Number(x.hue ?? 210),
    photoId: x.photo_media_id == null ? null : Number(x.photo_media_id),
    title: (x.active_title as string | null) ?? null,
    tier: Number(x.tier ?? 0),
    pinned: !!x.pinned,
    lastSeen: x.last_seen ? String(x.last_seen) : null,
    state: x.state as 'pending' | 'friends',
    requestedBy: (x.requested_by as string | null) ?? null,
    matchedAt: x.matched_at ? String(x.matched_at) : null,
  }));
}

export async function friendState(u: string, v: string):
    Promise<'none' | 'pendingOut' | 'pendingIn' | 'friends'> {
  const [a, b] = pair(u, v);
  const r = await run('SELECT state, requested_by FROM friendships WHERE a=$1 AND b=$2', [a, b]);
  const row = r?.rows?.[0];
  if (!row) return 'none';
  if (row.state === 'friends') return 'friends';
  return row.requested_by === u ? 'pendingOut' : 'pendingIn';
}

/// Create or upgrade the pair edge. Returns true if a NEW friendship formed.
export async function befriend(u: string, v: string, origin: string): Promise<boolean> {
  const [a, b] = pair(u, v);
  const r = await run(
    `INSERT INTO friendships (a, b, state, origin, matched_at)
     VALUES ($1, $2, 'friends', $3, now())
     ON CONFLICT (a, b) DO UPDATE SET
       state = 'friends',
       matched_at = COALESCE(friendships.matched_at, now())
     RETURNING (xmax = 0) AS inserted, friendships.state`,
    [a, b, origin],
  );
  // treat "was pending, now friends" as newly formed too
  const row = r?.rows?.[0];
  if (!row) return false;
  if (row.inserted) return true;
  const prev = await run(
    'SELECT 1 FROM friendships WHERE a=$1 AND b=$2 AND matched_at >= now() - interval \'5 seconds\'',
    [a, b]);
  return !!prev?.rows?.length;
}

export async function requestFriend(from: string, to: string): Promise<'created' | 'already' | 'accepted'> {
  const [a, b] = pair(from, to);
  const existing = await run('SELECT state, requested_by FROM friendships WHERE a=$1 AND b=$2', [a, b]);
  const row = existing?.rows?.[0];
  if (row?.state === 'friends') return 'already';
  if (row?.state === 'pending') {
    if (row.requested_by === from) return 'already';
    // they already asked us — a request back = acceptance
    await run('UPDATE friendships SET state=\'friends\', matched_at=now() WHERE a=$1 AND b=$2', [a, b]);
    return 'accepted';
  }
  await run(
    `INSERT INTO friendships (a, b, state, requested_by, origin)
     VALUES ($1, $2, 'pending', $3, 'request') ON CONFLICT DO NOTHING`,
    [a, b, from],
  );
  return 'created';
}

export async function acceptFriend(me: string, from: string): Promise<boolean> {
  const [a, b] = pair(me, from);
  const r = await run(
    `UPDATE friendships SET state='friends', matched_at=now()
     WHERE a=$1 AND b=$2 AND state='pending' AND requested_by=$3 RETURNING a`,
    [a, b, from],
  );
  return !!r?.rows?.length;
}

export async function removeEdge(u: string, v: string): Promise<void> {
  const [a, b] = pair(u, v);
  await run('DELETE FROM friendships WHERE a=$1 AND b=$2', [a, b]);
}

export async function setTier(me: string, target: string, tier: number): Promise<void> {
  const [a, b] = pair(me, target);
  const col = me === a ? 'a_tier' : 'b_tier';
  await run(`UPDATE friendships SET ${col}=$3 WHERE a=$1 AND b=$2 AND state='friends'`,
      [a, b, Math.max(0, Math.min(2, tier))]);
}

export async function setPinned(me: string, target: string, on: boolean): Promise<void> {
  const [a, b] = pair(me, target);
  const col = me === a ? 'a_pinned' : 'b_pinned';
  await run(`UPDATE friendships SET ${col}=$3 WHERE a=$1 AND b=$2`, [a, b, on]);
}

// ---- encounters ------------------------------------------------------------
export function recordEncounter(u: string, v: string, cellId: string, secs: number,
    uCountry: string | null, vCountry: string | null): void {
  const [a, b] = pair(u, v);
  const [ac, bc] = u < v ? [uCountry, vCountry] : [vCountry, uCountry];
  void run(
    `INSERT INTO encounters (a, b, cell_id, secs, a_country, b_country)
     VALUES ($1,$2,$3,$4,$5,$6) ON CONFLICT (a, b, cell_id) DO UPDATE SET
       secs = GREATEST(encounters.secs, EXCLUDED.secs)`,
    [a, b, cellId, secs, ac, bc],
  );
}

export async function hasMet(u: string, v: string): Promise<boolean> {
  const [a, b] = pair(u, v);
  const r = await run('SELECT 1 FROM encounters WHERE a=$1 AND b=$2 LIMIT 1', [a, b]);
  return !!r?.rows?.length;
}

/// Last 20 distinct non-friend people [uid] met, newest first.
export async function recentlyMet(uid: string): Promise<
    { uid: string; name: string; hue: number; photoId: number | null; title: string | null; metAt: string }[]> {
  const r = await run(
    `SELECT DISTINCT ON (peer) peer, name, hue, photo_media_id, active_title, met_at FROM (
       SELECT CASE WHEN e.a = $1 THEN e.b ELSE e.a END AS peer, e.created_at AS met_at
       FROM encounters e WHERE e.a = $1 OR e.b = $1
       ORDER BY e.created_at DESC LIMIT 200
     ) m
     JOIN users u ON u.uid = m.peer
     LEFT JOIN friendships f ON f.a = LEAST($1, m.peer) AND f.b = GREATEST($1, m.peer)
     WHERE f.a IS NULL
     ORDER BY peer, met_at DESC`,
    [uid],
  );
  const rows = (r?.rows ?? []).map((x) => ({
    uid: x.peer as string,
    name: (x.name as string) ?? 'someone',
    hue: Number(x.hue ?? 210),
    photoId: x.photo_media_id == null ? null : Number(x.photo_media_id),
    title: (x.active_title as string | null) ?? null,
    metAt: String(x.met_at),
  }));
  rows.sort((p, q) => (p.metAt < q.metAt ? 1 : -1));
  return rows.slice(0, 20);
}

// ---- ratings ---------------------------------------------------------------
export function upsertRating(rater: string, target: string, cellId: string, score: number): void {
  void run(
    `INSERT INTO ratings (rater, target, cell_id, score) VALUES ($1,$2,$3,$4)
     ON CONFLICT (rater, target, cell_id) DO UPDATE SET score = EXCLUDED.score`,
    [rater, target, cellId, score],
  );
}

/// The target's most recent rating OF the rater within [days].
export async function latestReverseRating(rater: string, target: string, days = 30): Promise<number | null> {
  const r = await run(
    `SELECT score FROM ratings WHERE rater=$1 AND target=$2
     AND created_at > now() - ($3 || ' days')::interval
     ORDER BY created_at DESC LIMIT 1`,
    [target, rater, String(days)],
  );
  const row = r?.rows?.[0];
  return row ? Number(row.score) : null;
}

/// All uids this user marked "never again" (and who marked them) — hard filter.
export async function neverAgainOf(uid: string): Promise<string[]> {
  const r = await run(
    `SELECT target AS u FROM ratings WHERE rater=$1 AND score=0
     UNION SELECT rater AS u FROM ratings WHERE target=$1 AND score=0`,
    [uid],
  );
  return (r?.rows ?? []).map((x) => x.u as string);
}

// ---- trait votes -----------------------------------------------------------
export function voteTrait(voter: string, target: string, trait: string): void {
  void run(
    `INSERT INTO personality_votes (voter, target, trait) VALUES ($1,$2,$3)
     ON CONFLICT (voter, target) DO UPDATE SET trait = EXCLUDED.trait, created_at = now()`,
    [voter, target, trait],
  );
}

// ---- messaging -------------------------------------------------------------
export interface MsgRow {
  id: number; sender: string; kind: string; body: string;
  mediaId: number | null; meta: Record<string, unknown>; at: string;
}

export async function insertMessage(u: string, v: string, sender: string, kind: string,
    body: string, mediaId: number | null, meta: Record<string, unknown>):
    Promise<{ id: number; at: string } | null> {
  const [a, b] = pair(u, v);
  const r = await run(
    `INSERT INTO messages (a, b, sender, kind, body, media_id, meta)
     VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING id, created_at`,
    [a, b, sender, kind, body, mediaId, JSON.stringify(meta)],
  );
  const row = r?.rows?.[0];
  return row ? { id: Number(row.id), at: String(row.created_at) } : null;
}

export async function messagesPage(u: string, v: string, before: number | null, limit: number):
    Promise<{ msgs: MsgRow[]; reactions: [number, string, string][]; more: boolean }> {
  const [a, b] = pair(u, v);
  const r = await run(
    `SELECT id, sender, kind, body, media_id, meta, created_at FROM messages
     WHERE a=$1 AND b=$2 ${before != null ? 'AND id < $4' : ''}
     ORDER BY id DESC LIMIT $3`,
    before != null ? [a, b, limit + 1, before] : [a, b, limit + 1],
  );
  const rows = r?.rows ?? [];
  const more = rows.length > limit;
  const msgs = rows.slice(0, limit).map((x) => ({
    id: Number(x.id), sender: x.sender as string, kind: x.kind as string,
    body: x.body as string, mediaId: x.media_id == null ? null : Number(x.media_id),
    meta: (x.meta as Record<string, unknown>) ?? {}, at: String(x.created_at),
  })).reverse();
  let reactions: [number, string, string][] = [];
  if (msgs.length) {
    const ids = msgs.map((m) => m.id);
    const rr = await run(
      'SELECT message_id, uid, emoji FROM message_reactions WHERE message_id = ANY($1)', [ids]);
    reactions = (rr?.rows ?? []).map((x) => [Number(x.message_id), x.uid as string, x.emoji as string]);
  }
  return { msgs, reactions, more };
}

export async function messagePair(id: number): Promise<{ a: string; b: string } | null> {
  const r = await run('SELECT a, b FROM messages WHERE id=$1', [id]);
  const x = r?.rows?.[0];
  return x ? { a: x.a as string, b: x.b as string } : null;
}

export function setReaction(messageId: number, uid: string, emoji: string | null): void {
  if (emoji == null) {
    void run('DELETE FROM message_reactions WHERE message_id=$1 AND uid=$2', [messageId, uid]);
  } else {
    void run(
      `INSERT INTO message_reactions (message_id, uid, emoji) VALUES ($1,$2,$3)
       ON CONFLICT (message_id, uid) DO UPDATE SET emoji = EXCLUDED.emoji`,
      [messageId, uid, emoji]);
  }
}

export function setRead(uid: string, peer: string, upTo: number): void {
  void run(
    `INSERT INTO chat_state (uid, peer, last_read_id) VALUES ($1,$2,$3)
     ON CONFLICT (uid, peer) DO UPDATE SET
       last_read_id = GREATEST(chat_state.last_read_id, EXCLUDED.last_read_id)`,
    [uid, peer, upTo]);
}

export async function unreadTotal(uid: string): Promise<number> {
  const r = await run(
    `SELECT COUNT(*)::int AS n FROM messages m
     LEFT JOIN chat_state cs ON cs.uid=$1 AND cs.peer=m.sender
     WHERE (m.a=$1 OR m.b=$1) AND m.sender<>$1
       AND m.id > COALESCE(cs.last_read_id, 0)`,
    [uid]);
  return r?.rows?.[0]?.n ?? 0;
}

export async function chatList(uid: string): Promise<{
  peer: string; name: string; hue: number; photoId: number | null; title: string | null;
  pinned: boolean; unread: number;
  last: { id: number; sender: string; kind: string; body: string; at: string };
}[]> {
  const r = await run(
    `WITH mine AS (
       SELECT m.*, CASE WHEN m.a=$1 THEN m.b ELSE m.a END AS peer
       FROM messages m WHERE m.a=$1 OR m.b=$1
     ), lasts AS (
       SELECT DISTINCT ON (peer) * FROM mine ORDER BY peer, id DESC
     )
     SELECT l.peer, l.id, l.sender, l.kind, l.body, l.created_at,
       u.name, u.hue, u.photo_media_id, u.active_title,
       COALESCE(CASE WHEN f.a=$1 THEN f.a_pinned ELSE f.b_pinned END, false) AS pinned,
       (SELECT COUNT(*)::int FROM mine mm
          WHERE mm.peer = l.peer AND mm.sender = l.peer
            AND mm.id > COALESCE(cs.last_read_id, 0)) AS unread
     FROM lasts l
     JOIN users u ON u.uid = l.peer
     LEFT JOIN friendships f ON f.a = LEAST($1, l.peer) AND f.b = GREATEST($1, l.peer)
     LEFT JOIN chat_state cs ON cs.uid = $1 AND cs.peer = l.peer
     ORDER BY pinned DESC, l.id DESC`,
    [uid]);
  return (r?.rows ?? []).map((x) => ({
    peer: x.peer as string,
    name: (x.name as string) ?? 'someone',
    hue: Number(x.hue ?? 210),
    photoId: x.photo_media_id == null ? null : Number(x.photo_media_id),
    title: (x.active_title as string | null) ?? null,
    pinned: !!x.pinned,
    unread: Number(x.unread ?? 0),
    last: {
      id: Number(x.id), sender: x.sender as string, kind: x.kind as string,
      body: x.body as string, at: String(x.created_at),
    },
  }));
}

// ---- stats + reputation ----------------------------------------------------
export function bumpStat(uid: string, col: string, by = 1): void {
  // col is ALWAYS a code-side constant, never user input
  void run(
    `INSERT INTO user_stats (uid, ${col}) VALUES ($1, $2)
     ON CONFLICT (uid) DO UPDATE SET ${col} = user_stats.${col} + $2`,
    [uid, by],
  );
}

/// Hidden reputation — clamped, server-only, only the matcher ever reads it.
export function bumpRep(uid: string, delta: number): void {
  void run(
    `INSERT INTO user_stats (uid, rep) VALUES ($1, $2)
     ON CONFLICT (uid) DO UPDATE SET
       rep = GREATEST(-100, LEAST(100, user_stats.rep + $2))`,
    [uid, delta],
  );
}

/// Apple-as-recovery-key: the random uid stays the permanent identity;
/// apple_id maps back to it so a reinstall recovers the whole graph with
/// ZERO data migration.
export async function uidForApple(appleId: string): Promise<string | null> {
  const r = await run('SELECT uid FROM users WHERE apple_id = $1', [appleId]);
  return (r?.rows?.[0]?.uid as string | undefined) ?? null;
}

/// Link (first writer wins — an apple id can never point at two accounts;
/// the partial unique index rejects theft attempts). Upsert form so it works
/// even when it races the user row's own INSERT on a first-ever hello.
export function linkApple(uid: string, appleId: string): void {
  void run(
    `INSERT INTO users (uid, apple_id) VALUES ($1, $2)
     ON CONFLICT (uid) DO UPDATE SET
       apple_id = COALESCE(users.apple_id, EXCLUDED.apple_id)`,
    [uid, appleId]);
}

export async function userCard(uid: string):
    Promise<{ name: string; hue: number; photoId: number | null; title: string | null } | null> {
  const r = await run('SELECT name, hue, photo_media_id, active_title FROM users WHERE uid=$1', [uid]);
  const x = r?.rows?.[0];
  if (!x) return null;
  return {
    name: (x.name as string) ?? 'someone',
    hue: Number(x.hue ?? 210),
    photoId: x.photo_media_id == null ? null : Number(x.photo_media_id),
    title: (x.active_title as string | null) ?? null,
  };
}

/// Room completed (≥60s with a real person). Bumps rooms + streak (local
/// day via tz offset) + night_rooms, all in one upsert.
export function noteRoom(uid: string, tzMin: number, night: boolean): void {
  const tz = String(Math.max(-840, Math.min(840, tzMin)));
  void run(
    `INSERT INTO user_stats (uid, rooms, streak, streak_best, streak_day, night_rooms)
     VALUES ($1, 1, 1, 1, (now() + ($2||' minutes')::interval)::date, $3)
     ON CONFLICT (uid) DO UPDATE SET
       rooms = user_stats.rooms + 1,
       night_rooms = user_stats.night_rooms + $3,
       streak_best = GREATEST(user_stats.streak_best, CASE
         WHEN user_stats.streak_day = (now() + ($2||' minutes')::interval)::date THEN user_stats.streak
         WHEN user_stats.streak_day = (now() + ($2||' minutes')::interval)::date - 1 THEN user_stats.streak + 1
         ELSE 1 END),
       streak = CASE
         WHEN user_stats.streak_day = (now() + ($2||' minutes')::interval)::date THEN user_stats.streak
         WHEN user_stats.streak_day = (now() + ($2||' minutes')::interval)::date - 1 THEN user_stats.streak + 1
         ELSE 1 END,
       streak_day = (now() + ($2||' minutes')::interval)::date`,
    [uid, tz, night ? 1 : 0],
  );
}

export async function getPushToken(uid: string): Promise<string | null> {
  const r = await run('SELECT push_token FROM users WHERE uid=$1', [uid]);
  return (r?.rows?.[0]?.push_token as string | null) ?? null;
}

// ---- profiles --------------------------------------------------------------
const PROFILE_FIELDS = ['bio', 'city', 'country', 'pronouns'] as const;
const PROFILE_JSON = ['languages', 'looking_for', 'interests'] as const;

export function setProfile(uid: string, m: Record<string, unknown>): void {
  const sets: string[] = [];
  const params: unknown[] = [uid];
  for (const f of PROFILE_FIELDS) {
    if (typeof m[f] === 'string') {
      params.push((m[f] as string).slice(0, f === 'bio' ? 240 : 48));
      sets.push(`${f} = $${params.length}`);
    }
  }
  for (const f of PROFILE_JSON) {
    const key = f === 'looking_for' ? 'lookingFor' : f;
    if (Array.isArray(m[key])) {
      const arr = (m[key] as unknown[]).filter((x): x is string => typeof x === 'string').slice(0, 12);
      params.push(JSON.stringify(arr));
      sets.push(`${f} = $${params.length}`);
    }
  }
  if (typeof m.age === 'number' && m.age >= 18 && m.age <= 99) {
    params.push(Math.trunc(m.age));
    sets.push(`age = $${params.length}`);
  }
  if (!sets.length) return;
  void run(`UPDATE users SET ${sets.join(', ')} WHERE uid = $1`, params);
}

/// The full public profile card: identity + traits + record + badges +
/// mutuals + your relationship to them.
export async function profileCard(viewer: string, uid: string): Promise<Record<string, unknown> | null> {
  const u = await run(
    `SELECT name, hue, photo_media_id, active_title, age, bio, city, country,
            pronouns, languages, looking_for, interests, created_at, last_seen
     FROM users WHERE uid=$1`, [uid]);
  const row = u?.rows?.[0];
  if (!row) return null;

  const [traits, myVote, stats, badges, mutuals, met, enc] = await Promise.all([
    run('SELECT trait, COUNT(*)::int AS n FROM personality_votes WHERE target=$1 GROUP BY trait', [uid]),
    run('SELECT trait FROM personality_votes WHERE voter=$1 AND target=$2', [viewer, uid]),
    run('SELECT * FROM user_stats WHERE uid=$1', [uid]),
    run('SELECT badge FROM user_badges WHERE uid=$1 ORDER BY earned_at DESC', [uid]),
    run(
      `SELECT u.uid, u.name, u.hue, u.photo_media_id FROM friendships f1
       JOIN friendships f2 ON (f2.a = LEAST($2, CASE WHEN f1.a=$1 THEN f1.b ELSE f1.a END)
                           AND f2.b = GREATEST($2, CASE WHEN f1.a=$1 THEN f1.b ELSE f1.a END)
                           AND f2.state='friends')
       JOIN users u ON u.uid = CASE WHEN f1.a=$1 THEN f1.b ELSE f1.a END
       WHERE (f1.a=$1 OR f1.b=$1) AND f1.state='friends'
         AND CASE WHEN f1.a=$1 THEN f1.b ELSE f1.a END <> $2
       LIMIT 6`, [uid, viewer]),
    run('SELECT 1 FROM encounters WHERE a=LEAST($1,$2) AND b=GREATEST($1,$2) LIMIT 1', [viewer, uid]),
    run(
      `SELECT COALESCE(SUM(secs),0)::int AS secs,
              COUNT(DISTINCT CASE WHEN a=$1 THEN b_country ELSE a_country END)
                FILTER (WHERE CASE WHEN a=$1 THEN b_country ELSE a_country END IS NOT NULL)::int AS countries
       FROM encounters WHERE a=$1 OR b=$1`, [uid]),
  ]);

  const st = stats?.rows?.[0] ?? {};
  const fs = await friendState(viewer, uid);
  return {
    uid,
    name: row.name, hue: Number(row.hue ?? 210),
    photoId: row.photo_media_id == null ? null : Number(row.photo_media_id),
    title: row.active_title ?? null,
    age: row.age == null ? null : Number(row.age),
    bio: row.bio ?? '', city: row.city ?? null, country: row.country ?? null,
    pronouns: row.pronouns ?? null,
    languages: row.languages ?? [], lookingFor: row.looking_for ?? [],
    interests: row.interests ?? [],
    joined: String(row.created_at), lastSeen: row.last_seen ? String(row.last_seen) : null,
    traits: Object.fromEntries((traits?.rows ?? []).map((x) => [x.trait, Number(x.n)])),
    myTraitVote: myVote?.rows?.[0]?.trait ?? null,
    stats: {
      rooms: Number(st.rooms ?? 0), wins: Number(st.rooms_won ?? 0),
      laughs: Number(st.laughs ?? 0), games: Number(st.games ?? 0),
      friends: Number(st.friends_made ?? 0), streak: Number(st.streak ?? 0),
      chaos: Number(st.chaos ?? 0), legend: Number(st.legend_ratings ?? 0),
      hours: Math.round(Number(enc?.rows?.[0]?.secs ?? 0) / 360) / 10,
      countries: Number(enc?.rows?.[0]?.countries ?? 0),
    },
    badges: (badges?.rows ?? []).map((x) => x.badge as string),
    mutuals: (mutuals?.rows ?? []).map((x) => ({
      uid: x.uid, name: x.name, hue: Number(x.hue ?? 210),
      photoId: x.photo_media_id == null ? null : Number(x.photo_media_id),
    })),
    friendState: fs,
    canVote: !!met?.rows?.length && viewer !== uid,
  };
}

/// Extend account deletion across the social tables (called from db.deleteUser path).
export function deleteSocial(uid: string): void {
  void run('DELETE FROM friendships WHERE a=$1 OR b=$1', [uid]);
  void run('DELETE FROM encounters WHERE a=$1 OR b=$1', [uid]);
  void run('DELETE FROM ratings WHERE rater=$1', [uid]);
  void run('DELETE FROM personality_votes WHERE voter=$1 OR target=$1', [uid]);
  void run('DELETE FROM messages WHERE sender=$1', [uid]);
  void run('DELETE FROM chat_state WHERE uid=$1 OR peer=$1', [uid]);
  void run('DELETE FROM media WHERE owner=$1', [uid]);
  void run('DELETE FROM user_stats WHERE uid=$1', [uid]);
  void run('DELETE FROM user_badges WHERE uid=$1', [uid]);
}
