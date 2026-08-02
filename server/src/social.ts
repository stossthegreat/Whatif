import { store, type User, type Cell } from './store.js';
import { dbEnabled } from './db.js';
import * as dbs from './db_social.js';
import { sendPush, pushEnabled } from './push.js';

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
  void import('./chat.js').then((c) => c.sendUnread(user)); // Home badge, pre-ask
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
  }

  if (cell.prompted.has(u.id)) return;
  cell.prompted.add(u.id);
  // only prompt about people who aren't already friends
  void (async () => {
    const people = [] as { uid: string; name: string; hue: number; secs: number }[];
    for (const p of partners) {
      const st = await dbs.friendState(u.uid, p.uid);
      if (st !== 'friends') people.push(p);
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
    const card = store.userByUid(other);
    const info = card
      ? { uid: other, name: card.name, hue: card.hue, photoId: null as number | null, title: null as string | null }
      : { uid: other, ...((await dbs.userCard(other)) ?? { name: 'someone', hue: 210, photoId: null, title: null }) };
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
      if (token) sendPush(token, `${user.name} wants to be friends`, 'open Rivlr to accept ⭐');
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

// ---- moderation reputation hooks -------------------------------------------
export function onReported(targetUid: string): void {
  if (dbEnabled) dbs.bumpRep(targetUid, -5);
}

export function onBlocked(user: User, targetUid: string): void {
  if (!dbEnabled) return;
  dbs.bumpRep(targetUid, -8);
  void dbs.removeEdge(user.uid, targetUid);
  user.friendUids?.delete(targetUid);
  store.userByUid(targetUid)?.friendUids?.delete(user.uid);
}
