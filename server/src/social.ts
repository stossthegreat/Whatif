import { store, type User, type Cell } from './store.js';
import { dbEnabled, run } from './db.js';
import * as dbs from './db_social.js';
import { sendPush, pushEnabled } from './push.js';
import { moderateText } from './moderation.js';

/// The social brain: rating → match → friendship, presence, trait votes,
/// hidden reputation. index.ts injects its send function at boot (avoids a
/// circular import); every WS case here is a one-line delegate from there.

type SendFn = (u: User, m: Record<string, unknown>) => void;
let send: SendFn = () => {};
export function init(s: SendFn) { send = s; }

/// Minimum shared seconds before a pair "counts" (encounter + rate prompt).
/// Env-tunable so tests don't wait a minute per room.
const MIN_SECS = Number(process.env.MIN_ENCOUNTER_SECS || 60);

// uid -> uids this user must never be matched with again (either direction).
// Hydrated on hello, extended live on rate(0).
const neverAgain = new Map<string, Set<string>>();

/// Same contract as matching.pruneHints — rehydrated on hello, safe to drop
/// for anyone offline.
export function pruneNeverAgain(online: (uid: string) => boolean): void {
  for (const uid of neverAgain.keys()) if (!online(uid)) neverAgain.delete(uid);
}

export function isNeverPair(a: string, b: string): boolean {
  return (neverAgain.get(a)?.has(b) ?? false) || (neverAgain.get(b)?.has(a) ?? false);
}

function err(user: User, code: string) {
  send(user, { t: 'err', code });
}

// ---- hello: hydrate + presence ---------------------------------------------
export async function hydrate(user: User): Promise<void> {
  if (!dbEnabled) return;
  const [never, edges] = await Promise.all([
    dbs.neverAgainOf(user.uid),
    dbs.edgesOf(user.uid),
  ]);
  if (store.userByUid(user.uid) !== user) return; // reconnected again meanwhile
  neverAgain.set(user.uid, new Set(never));
  user.friendUids = new Set(edges.filter((e) => e.state === 'friends').map((e) => e.uid));
  broadcastPresence(user, true);
  // the full friends graph lands on EVERY connect — requests that arrived
  // while offline surface without any screen having to ask for them
  void snapshot(user);
  void import('./chat.js').then((c) => c.sendUnread(user)); // Home badge, pre-ask
  void checkBadges(user.uid); // returning users pick up retroactive badges
}

/// Tell online friends this user came online / went offline.
export function broadcastPresence(user: User, on: boolean): void {
  for (const fu of user.friendUids ?? []) {
    const f = store.userByUid(fu);
    if (f && f !== user) send(f, { t: 'friendOnline', uid: user.uid, name: user.name, on });
  }
}

// ---- room end: encounters + rate prompts + room stats ----------------------
/// Called from leaveCell for the leaver AND for the last member when a cell
/// dies. cell.prompted/credited dedupe both paths.
export function onCellLeave(cell: Cell, u: User): void {
  if (!dbEnabled) return;
  if ((cell.mode as string) === 'call') return; // calls never rate (Build 4)
  const myJoin = cell.joinedAt.get(u.id);
  if (myJoin == null) return;
  const now = Date.now();

  const partners: { uid: string; name: string; hue: number; secs: number }[] = [];
  for (const [cid, meta] of cell.meta) {
    if (cid === u.id || meta.uid === u.uid) continue;
    const theirJoin = cell.joinedAt.get(cid);
    if (theirJoin == null) continue;
    const end = Math.min(now, cell.leftAt.get(cid) ?? now);
    const secs = Math.floor((end - Math.max(myJoin, theirJoin)) / 1000);
    if (secs < MIN_SECS) continue;
    partners.push({ uid: meta.uid, name: meta.name, hue: meta.hue, secs });
    dbs.recordEncounter(u.uid, meta.uid, cell.id, secs, null, null);
    // long enough to matter — tiny rep credit for a real conversation
    if (secs >= 300) dbs.bumpRep(u.uid, 1);
  }
  if (partners.length === 0) return;

  // room completed (met someone ≥60s): rooms + streak + night owl counter
  if (!cell.credited.has(u.id)) {
    cell.credited.add(u.id);
    const tz = u.tz ?? 0;
    const localHour = (((new Date().getUTCHours() + tz / 60) % 24) + 24) % 24;
    dbs.noteRoom(u.uid, tz, localHour < 5);
    void checkBadges(u.uid); // Icebreaker, Night Owl, streaks…
  }

  if (cell.prompted.has(u.id)) return;
  cell.prompted.add(u.id);
  // only prompt about people who aren't already friends
  void (async () => {
    const people = [] as { uid: string; name: string; hue: number; secs: number;
      photoId: number | null }[];
    for (const p of partners) {
      const st = await dbs.friendState(u.uid, p.uid);
      if (st !== 'friends') {
        // a face on the rating card converts far better than an orb
        const card = await dbs.userCard(p.uid);
        people.push({ ...p, photoId: card?.photoId ?? null });
      }
    }
    if (!people.length) return;
    if (store.users.get(u.id) !== u && store.userByUid(u.uid) !== u) return; // gone
    const target = store.userByUid(u.uid) ?? u;
    send(target, { t: 'ratePrompt', cell: cell.id, people });
  })();
}

// ---- the signature verb: rate ----------------------------------------------
export async function rate(user: User, m: Record<string, unknown>): Promise<void> {
  if (!dbEnabled) return err(user, 'noDb');
  const target = typeof m.target === 'string' ? m.target : '';
  const cellId = typeof m.cell === 'string' ? m.cell : '';
  const score = Number(m.score);
  if (!target || !cellId || target === user.uid) return;
  if (!(score >= 0 && score <= 3)) return;

  dbs.upsertRating(user.uid, target, cellId, score);

  if (score === 0) {
    // never again — hard matchmaking filter, both directions, immediately
    let mine = neverAgain.get(user.uid);
    if (!mine) { mine = new Set(); neverAgain.set(user.uid, mine); }
    mine.add(target);
    dbs.bumpRep(target, -2);
    return;
  }

  if (score === 3) {
    dbs.bumpStat(target, 'legend_ratings');
    dbs.bumpRep(target, 2);
  }

  // mutual? their most recent rating of us (any cell, last 30 days)
  const reverse = await dbs.latestReverseRating(user.uid, target);
  if (reverse != null && reverse >= 1) {
    const formed = await dbs.befriend(user.uid, target, 'match');
    if (formed) await announceBond(user.uid, target, 'matched');
    return;
  }
  // a Friend+ rating also accepts an open request from them
  const st = await dbs.friendState(user.uid, target);
  if (st === 'pendingIn') {
    if (await dbs.acceptFriend(user.uid, target)) {
      await announceBond(user.uid, target, 'matched');
    }
  }
}

/// A friendship just formed — celebrate on both sides (WS if online, push if
/// not), keep legacy sparkMutual flowing, update stats/rep/presence caches.
async function announceBond(u1: string, u2: string, kind: 'matched' | 'friendAccepted'): Promise<void> {
  dbs.bumpStat(u1, 'friends_made');
  dbs.bumpStat(u2, 'friends_made');
  dbs.bumpRep(u1, 3);
  dbs.bumpRep(u2, 3);
  for (const [me, other] of [[u1, u2], [u2, u1]] as const) {
    const conn = store.userByUid(me);
    const live = store.userByUid(other);
    // always hit the DB for the face — the online branch used to hardcode
    // photoId:null, which is why the match celebration showed blank orbs
    const dbCard = await dbs.userCard(other);
    const info = {
      uid: other,
      name: live?.name ?? dbCard?.name ?? 'someone',
      hue: live?.hue ?? dbCard?.hue ?? 210,
      photoId: dbCard?.photoId ?? null,
      title: dbCard?.title ?? null,
    };
    if (conn) {
      conn.friendUids ??= new Set();
      conn.friendUids.add(other);
      send(conn, { t: kind, ...info });
      send(conn, { t: 'sparkMutual', uid: other, name: info.name }); // legacy clients
      void snapshot(conn);
    } else if (pushEnabled) {
      const token = await dbs.getPushToken(me);
      if (token) {
        sendPush(token, `🎉 You matched with ${info.name}`,
            kind === 'matched' ? 'you both want to meet again — say hi' : 'you’re friends now');
      }
    }
  }
}

// ---- friends snapshot + graph verbs ----------------------------------------
export async function snapshot(user: User): Promise<void> {
  if (!dbEnabled) {
    return send(user, { t: 'friends', friends: [], reqsIn: [], reqsOut: [], recent: [] });
  }
  const [edges, recent] = await Promise.all([
    dbs.edgesOf(user.uid),
    dbs.recentlyMet(user.uid),
  ]);
  const shape = (e: dbs.FriendRow) => ({
    uid: e.uid, name: e.name, hue: e.hue, photoId: e.photoId, title: e.title,
    tier: e.tier, pinned: e.pinned, lastSeen: e.lastSeen,
    online: !!store.userByUid(e.uid),
  });
  const friends = edges.filter((e) => e.state === 'friends').map(shape);
  user.friendUids = new Set(friends.map((f) => f.uid));
  send(user, {
    t: 'friends',
    friends,
    reqsIn: edges.filter((e) => e.state === 'pending' && e.requestedBy !== user.uid).map(shape),
    reqsOut: edges.filter((e) => e.state === 'pending' && e.requestedBy === user.uid).map(shape),
    recent,
  });
}

function refreshBoth(user: User, targetUid: string): void {
  void snapshot(user);
  const other = store.userByUid(targetUid);
  if (other) void snapshot(other);
}

export async function friendRequest(user: User, targetUid: string): Promise<void> {
  if (!dbEnabled) return err(user, 'noDb');
  if (!targetUid || targetUid === user.uid || store.isBlocked(user.uid, targetUid)) return;
  const result = await dbs.requestFriend(user.uid, targetUid);
  if (result === 'accepted') {
    await announceBond(user.uid, targetUid, 'friendAccepted');
    return;
  }
  if (result === 'created') {
    dbs.bumpStat(targetUid, 'requests_in');
    const other = store.userByUid(targetUid);
    if (other) {
      send(other, { t: 'friendRequested', from: { uid: user.uid, name: user.name, hue: user.hue } });
    } else if (pushEnabled) {
      const token = await dbs.getPushToken(targetUid);
      if (token) sendPush(token, `${user.name} wants to be friends`, 'open Rivler to accept ⭐');
    }
  }
  refreshBoth(user, targetUid);
}

export async function friendAccept(user: User, targetUid: string): Promise<void> {
  if (!dbEnabled) return err(user, 'noDb');
  if (await dbs.acceptFriend(user.uid, targetUid)) {
    await announceBond(user.uid, targetUid, 'friendAccepted');
  }
  refreshBoth(user, targetUid);
}

export async function friendDecline(user: User, targetUid: string): Promise<void> {
  if (!dbEnabled) return err(user, 'noDb');
  const st = await dbs.friendState(user.uid, targetUid);
  if (st === 'pendingIn' || st === 'pendingOut') await dbs.removeEdge(user.uid, targetUid);
  refreshBoth(user, targetUid);
}

export async function unfriend(user: User, targetUid: string): Promise<void> {
  if (!dbEnabled) return err(user, 'noDb');
  await dbs.removeEdge(user.uid, targetUid);
  user.friendUids?.delete(targetUid);
  const other = store.userByUid(targetUid);
  if (other) {
    other.friendUids?.delete(user.uid);
    send(other, { t: 'friendRemoved', uid: user.uid });
  }
  refreshBoth(user, targetUid);
}

export async function setTier(user: User, m: Record<string, unknown>): Promise<void> {
  if (!dbEnabled) return err(user, 'noDb');
  const target = typeof m.target === 'string' ? m.target : '';
  if (!target) return;
  await dbs.setTier(user.uid, target, Number(m.tier ?? 0));
  void snapshot(user);
}

export async function pinChat(user: User, m: Record<string, unknown>): Promise<void> {
  if (!dbEnabled) return err(user, 'noDb');
  const target = typeof m.target === 'string' ? m.target : '';
  if (!target) return;
  await dbs.setPinned(user.uid, target, m.on === true);
  void snapshot(user);
}

const TRAITS = new Set(['funny', 'smart', 'chill', 'chaotic', 'flirty', 'confident', 'competitive', 'listener']);

export async function traitVote(user: User, m: Record<string, unknown>): Promise<void> {
  if (!dbEnabled) return err(user, 'noDb');
  const target = typeof m.target === 'string' ? m.target : '';
  const trait = typeof m.trait === 'string' ? m.trait : '';
  if (!target || target === user.uid || !TRAITS.has(trait)) return;
  if (!(await dbs.hasMet(user.uid, target))) return; // must have actually met
  dbs.voteTrait(user.uid, target, trait);
  dbs.bumpRep(target, 1);
}

// ---- profiles --------------------------------------------------------------

/// A profile just changed (bio/age/title/interests/name) — nudge every
/// connected phone so friends lists, explore cards and open profiles
/// re-pull now instead of on their own next fetch. Same fan-out shape as
/// media.ts's faceFresh; profile edits are rare, the payload is tiny.
function broadcastProfileFresh(uid: string): void {
  const msg = JSON.stringify({ t: 'profileFresh', uid });
  for (const u of store.users.values()) {
    if (u.ws.readyState === 1 /* OPEN */) {
      try { u.ws.send(msg); } catch { /* socket died mid-iteration */ }
    }
  }
}

export async function setProfile(user: User, m: Record<string, unknown>): Promise<void> {
  if (!dbEnabled) return err(user, 'noDb');
  // one moderation call covers every free-text field in this save — the
  // fields themselves are validated/truncated inside dbs.setProfile, this
  // pass only decides whether the save is allowed to happen at all
  const free = ['bio', 'city', 'country', 'pronouns']
    .map((f) => (typeof m[f] === 'string' ? (m[f] as string) : ''))
    .filter(Boolean).join('\n');
  if (free) {
    const mod = await moderateText(free);
    if (mod?.flagged) { send(user, { t: 'err', code: 'flagged', where: 'profile' }); return; }
  }
  dbs.setProfile(user.uid, m);
  broadcastProfileFresh(user.uid);
}

export async function profile(user: User, m: Record<string, unknown>): Promise<void> {
  if (!dbEnabled) return err(user, 'noDb');
  const uid = typeof m.uid === 'string' ? m.uid : user.uid;
  const card = await dbs.profileCard(user.uid, uid);
  if (!card) return err(user, 'noUser');
  send(user, { t: 'profileCard', ...card });
}

// ---- badges + chaos titles --------------------------------------------------
/// Badge key -> [display label, granted title]. Titles are the memorable
/// layer: people remember "Rizz Merchant" long after they forget a number.
export const BADGE_META: Record<string, [string, string]> = {
  icebreaker: ['🧊 Icebreaker', 'Fresh Meat'],
  night_owl: ['🦉 Night Owl', 'Night Owl'],
  storyteller: ['🎤 Storyteller', 'Story King'],
  legend: ['👑 Legend', 'Certified Legend'],
  butterfly: ['🦋 Social Butterfly', 'Social Butterfly'],
  streak_keeper: ['🔥 Streak Keeper', 'The Consistent'],
  marathon: ['🗣️ Marathon Mouth', 'Professional Yapper'],
  globetrotter: ['🌎 Globetrotter', 'World Traveller'],
  rizz_king: ['😏 Rizz King', 'Rizz Merchant'],
  listener: ['👂 Elite Listener', 'Elite Listener'],
  chaos_agent: ['😈 Chaos Agent', 'Certified Menace'],
};

/// Chaos-score display tiers (migrated from the client's old rankTitle).
export function chaosTitle(chaos: number): string {
  if (chaos < 150) return 'Fresh Chaos';
  if (chaos < 350) return 'Certified Menace';
  if (chaos < 650) return 'Chaos Gremlin';
  if (chaos < 1100) return 'Room Wrecker';
  return 'Chaos Lord';
}

/// Evaluate every badge condition for one uid; award what's newly true.
export async function checkBadges(uid: string): Promise<void> {
  if (!dbEnabled) return;
  const [st, votes, enc] = await Promise.all([
    run('SELECT * FROM user_stats WHERE uid=$1', [uid]),
    run('SELECT trait, COUNT(*)::int AS n FROM personality_votes WHERE target=$1 GROUP BY trait', [uid]),
    run(
      `SELECT COALESCE(SUM(secs),0)::int AS secs,
              COUNT(DISTINCT CASE WHEN a=$1 THEN b_country ELSE a_country END)
                FILTER (WHERE CASE WHEN a=$1 THEN b_country ELSE a_country END IS NOT NULL)::int AS countries
       FROM encounters WHERE a=$1 OR b=$1`, [uid]),
  ]);
  const s = st?.rows?.[0] ?? {};
  const v = Object.fromEntries((votes?.rows ?? []).map((x) => [x.trait, Number(x.n)]));
  const secs = Number(enc?.rows?.[0]?.secs ?? 0);
  const countries = Number(enc?.rows?.[0]?.countries ?? 0);

  const earned: string[] = [];
  if (Number(s.rooms ?? 0) >= 1) earned.push('icebreaker');
  if (Number(s.night_rooms ?? 0) >= 5) earned.push('night_owl');
  if (Number(s.point_wins ?? 0) >= 10) earned.push('storyteller');
  if (Number(s.legend_ratings ?? 0) >= 5) earned.push('legend');
  if (Number(s.friends_made ?? 0) >= 25) earned.push('butterfly');
  if (Number(s.streak ?? 0) >= 7 || Number(s.streak_best ?? 0) >= 7) earned.push('streak_keeper');
  if (secs >= 36_000) earned.push('marathon');
  if (countries >= 10) earned.push('globetrotter');
  if ((v.flirty ?? 0) >= 10) earned.push('rizz_king');
  if ((v.listener ?? 0) >= 10) earned.push('listener');
  if (Number(s.chaos ?? 0) >= 125) earned.push('chaos_agent');

  for (const key of earned) {
    const r = await run(
      'INSERT INTO user_badges (uid, badge) VALUES ($1,$2) ON CONFLICT DO NOTHING RETURNING badge',
      [uid, key]);
    if (!r?.rows?.length) continue; // already had it
    const conn = store.userByUid(uid);
    const [label] = BADGE_META[key] ?? [key, key];
    if (conn) {
      send(conn, { t: 'badge', key, label, title: BADGE_META[key]?.[1] ?? null });
      feedToFriends(conn, { t: 'feedEvent', kind: 'badge', uid, name: conn.name, x: label });
    }
    // first badge title becomes the default display title
    void run(
      "UPDATE users SET active_title = COALESCE(active_title, $2) WHERE uid = $1",
      [uid, BADGE_META[key]?.[1] ?? null]);
  }
}

/// Which titles this uid may equip: every earned badge's title + chaos tier.
export async function titlesFor(uid: string): Promise<string[]> {
  if (!dbEnabled) return [];
  const [b, st] = await Promise.all([
    run('SELECT badge FROM user_badges WHERE uid=$1', [uid]),
    run('SELECT chaos FROM user_stats WHERE uid=$1', [uid]),
  ]);
  const titles = (b?.rows ?? [])
      .map((x) => BADGE_META[x.badge as string]?.[1])
      .filter((t): t is string => !!t);
  titles.push(chaosTitle(Number(st?.rows?.[0]?.chaos ?? 0)));
  return [...new Set(titles)];
}

export async function setTitle(user: User, m: Record<string, unknown>): Promise<void> {
  if (!dbEnabled) return err(user, 'noDb');
  const title = typeof m.title === 'string' ? m.title.slice(0, 32) : '';
  if (!title) return;
  const allowed = await titlesFor(user.uid);
  if (!allowed.includes(title)) return err(user, 'notEarned');
  await run('UPDATE users SET active_title=$2 WHERE uid=$1', [user.uid, title]);
  feedToFriends(user, { t: 'feedEvent', kind: 'title', uid: user.uid, name: user.name, x: title });
  send(user, { t: 'titles', list: allowed, active: title });
  broadcastProfileFresh(user.uid);
}

export async function titles(user: User): Promise<void> {
  if (!dbEnabled) return err(user, 'noDb');
  const [allowed, cur] = await Promise.all([
    titlesFor(user.uid),
    run('SELECT active_title FROM users WHERE uid=$1', [user.uid]),
  ]);
  send(user, { t: 'titles', list: allowed, active: cur?.rows?.[0]?.active_title ?? null });
}

/// Push a lightweight activity line to this user's ONLINE friends.
export function feedToFriends(user: User, ev: Record<string, unknown>): void {
  for (const fu of user.friendUids ?? []) {
    const f = store.userByUid(fu);
    if (f && f !== user) send(f, ev);
  }
}

// ---- room-engine stat hooks (called from index.ts) --------------------------
export function onPointWin(winnerUid: string): void {
  if (!dbEnabled) return;
  dbs.bumpStat(winnerUid, 'point_wins');
  void checkBadges(winnerUid);
}

export function onAward(winnerUid: string, mvp: boolean): void {
  if (!dbEnabled) return;
  if (mvp) dbs.bumpStat(winnerUid, 'rooms_won');
  dbs.bumpStat(winnerUid, 'chaos', 25);
  void checkBadges(winnerUid);
}

export function onLaugh(targetUid: string): void {
  if (!dbEnabled) return;
  dbs.bumpStat(targetUid, 'laughs');
}

export function onGameComplete(uid: string): void {
  if (!dbEnabled) return;
  dbs.bumpStat(uid, 'games');
}

/// Weekly-ish decay pulls hidden reputation back toward zero.
export function startRepDecay(): void {
  const decay = () => {
    if (!dbEnabled) return;
    void run(
      `UPDATE user_stats SET rep = CASE
         WHEN rep > 0 THEN GREATEST(0, rep - 1)
         WHEN rep < 0 THEN LEAST(0, rep + 1)
         ELSE 0 END
       WHERE rep <> 0`);
  };
  decay();
  setInterval(decay, 7 * 24 * 3600_000);
}

// ---- seasonal events --------------------------------------------------------
let cachedEvent: { key: string; name: string; endsAt: string } | null = null;
let cachedEventAt = 0;

export async function activeEvent(): Promise<{ key: string; name: string; endsAt: string } | null> {
  if (!dbEnabled) return null;
  if (Date.now() - cachedEventAt < 60_000) return cachedEvent;
  cachedEventAt = Date.now();
  const r = await run(
    'SELECT key, name, ends_at FROM events WHERE now() BETWEEN starts_at AND ends_at ORDER BY starts_at DESC LIMIT 1');
  const row = r?.rows?.[0];
  cachedEvent = row ? { key: row.key as string, name: row.name as string, endsAt: String(row.ends_at) } : null;
  return cachedEvent;
}

export async function sendEvent(user: User): Promise<void> {
  const ev = await activeEvent();
  if (ev && store.userByUid(user.uid) === user) send(user, { t: 'event', ...ev });
}

// ---- moderation reputation hooks -------------------------------------------
export function onReported(targetUid: string): void {
  if (dbEnabled) dbs.bumpRep(targetUid, -5);
}

export function onBlocked(user: User, targetUid: string): void {
  if (!dbEnabled) return;
  dbs.bumpRep(targetUid, -8);
  void dbs.removeEdge(user.uid, targetUid);
  user.friendUids?.delete(targetUid);
  const other = store.userByUid(targetUid);
  other?.friendUids?.delete(user.uid);
  // the severed edge reaches BOTH UIs now, not on a coincidental refetch.
  // Deliberately shaped like an unfriend — a block must never announce
  // itself as a block to the blocked party.
  if (other) send(other, { t: 'friendRemoved', uid: user.uid });
  refreshBoth(user, targetUid);
}
