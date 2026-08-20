import { randomUUID } from 'crypto';
import { store, type User } from './store.js';
import { dbEnabled } from './db.js';
import * as dbs from './db_social.js';
import * as social from './social.js';
import { sendPush, pushEnabled } from './push.js';

/// Calls between friends — a call IS a private 2-person cell (the room engine
/// does the video); this module only does the ring/accept/decline dance.

type SendFn = (u: User, m: Record<string, unknown>) => void;
type FormCell = (memberIds: string[], modeOverride?: 'call') => Promise<void>;
let send: SendFn = () => {};
let formCell: FormCell = async () => {};
let isPlus: (u: User) => boolean = () => false;
export function init(s: SendFn, f: FormCell, p: (u: User) => boolean) { send = s; formCell = f; isPlus = p; }

interface Ring {
  meet?: boolean; // came from Explore -> forms a normal room
  from: string; // uid
  to: string;   // uid
  video: boolean;
  timer: NodeJS.Timeout;
}
const rings = new Map<string, Ring>();

/// Free users get a real daily allowance of Explore/Discover invites —
/// enough to genuinely use the feature every day, few enough that the people
/// who live in it convert. Plus is unlimited.
///
/// In memory, keyed by UTC day: a redeploy handing someone a fresh allowance
/// is a harmless generosity, and this needs no migration or write path. The
/// map is pruned rather than grown forever.
const FREE_MEET_INVITES_PER_DAY = 10;
const meetUsed = new Map<string, { day: string; n: number }>();
const MEET_MAP_CAP = 50_000;

const utcDay = (): string => new Date().toISOString().slice(0, 10);

export function meetInvitesLeft(uid: string): number {
  const cur = meetUsed.get(uid);
  if (!cur || cur.day !== utcDay()) return FREE_MEET_INVITES_PER_DAY;
  return Math.max(0, FREE_MEET_INVITES_PER_DAY - cur.n);
}

function noteMeetInvite(uid: string): void {
  const day = utcDay();
  const cur = meetUsed.get(uid);
  if (!cur || cur.day !== day) {
    // blunt but bounded — yesterday's rows are dead weight either way
    if (meetUsed.size > MEET_MAP_CAP) meetUsed.clear();
    meetUsed.set(uid, { day, n: 1 });
  } else {
    cur.n += 1;
  }
}

/// Which video-ness the cell got — read by index.ts when logging the call DM.
export const cellVideo = new Map<string, boolean>(); // cellId placeholder set at accept

function state(user: User, callId: string, s: string) {
  send(user, { t: 'callState', callId, state: s });
}

async function missedCallDm(fromUser: User, toUid: string, video: boolean): Promise<void> {
  await dbs.insertMessage(fromUser.uid, toUid, fromUser.uid, 'call', '',
      null, { missed: true, video });
  if (!pushEnabled) return;
  const token = await dbs.getPushToken(toUid);
  if (token) sendPush(token, fromUser.name, video ? '📹 missed video call' : '📞 missed call');
}

/// Ring someone. Two origins share this machine:
///   • a friend CALL (origin absent) — friends only, forms a private call cell,
///     always free — calling people you've already met is never paywalled
///   • an Explore/Discover MEET (origin 'explore') — a specific stranger,
///     forms a normal 'hang' room so games and P2P work exactly like a
///     matched room. Free, with a daily allowance: picking a specific person
///     is the premium motion, but locking it outright starves the room, and
///     an empty room is worth nothing to anyone.
/// Everything else — blocked check, busy/idle guard, 30s timeout, missed-call
/// DM — is identical, which is the whole reason to reuse it.
export async function invite(user: User, m: Record<string, unknown>): Promise<void> {
  if (!dbEnabled) return send(user, { t: 'err', code: 'noDb' });
  const to = typeof m.to === 'string' ? m.to : '';
  const meet = m.origin === 'explore';
  const video = meet ? true : m.video === true;
  if (!to || to === user.uid) return;
  if (store.isBlocked(user.uid, to)) return;
  if (social.isNeverPair(user.uid, to)) return;
  if (meet && !isPlus(user) && meetInvitesLeft(user.uid) <= 0) {
    return send(user, { t: 'err', code: 'meetLimit', per: FREE_MEET_INVITES_PER_DAY });
  }
  if (!meet && (await dbs.friendState(user.uid, to)) !== 'friends') {
    return send(user, { t: 'err', code: 'notFriends' });
  }
  const callId = randomUUID();
  const target = store.userByUid(to);
  if (!target) {
    await missedCallDm(user, to, video);
    return state(user, callId, 'timeout');
  }
  if (target.state !== 'idle' || user.state !== 'idle') {
    return state(user, callId, 'busy');
  }
  const timer = setTimeout(() => {
    if (!rings.delete(callId)) return;
    const caller = store.userByUid(user.uid);
    if (caller) state(caller, callId, 'timeout');
    const t2 = store.userByUid(to);
    if (t2) state(t2, callId, 'timeout');
    void missedCallDm(user, to, video);
  }, 30_000);
  rings.set(callId, { from: user.uid, to, video, timer, meet });
  // charged only once the ring actually goes out — a missed/busy/offline
  // target above returns before this, so a wasted tap never costs an invite
  if (meet && !isPlus(user)) {
    noteMeetInvite(user.uid);
    send(user, { t: 'meetQuota', left: meetInvitesLeft(user.uid), per: FREE_MEET_INVITES_PER_DAY });
  }
  state(user, callId, 'ringing');
  send(target, { t: 'call', callId, video, meet,
    from: { uid: user.uid, name: user.name, hue: user.hue } });
}

export async function accept(user: User, m: Record<string, unknown>): Promise<void> {
  const callId = typeof m.callId === 'string' ? m.callId : '';
  const ring = rings.get(callId);
  if (!ring || ring.to !== user.uid) return;
  clearTimeout(ring.timer);
  rings.delete(callId);
  const caller = store.userByUid(ring.from);
  if (!caller) return state(user, callId, 'cancelled');
  if (caller.state !== 'idle' || user.state !== 'idle') {
    state(user, callId, 'busy');
    state(caller, callId, 'busy');
    return;
  }
  state(caller, callId, 'accepted');
  state(user, callId, 'accepted');
  // remember video-ness for the cell about to form (index reads per members)
  pendingVideo = ring.video;
  // an Explore meet is a REAL room — games, chaos, P2P — not a private call
  await formCell([caller.id, user.id], ring.meet ? undefined : 'call');
  pendingVideo = false;
}

/// The video flag for the call cell currently being formed (single-threaded
/// event loop — set right before formCell, read inside it).
export let pendingVideo = false;

export function decline(user: User, m: Record<string, unknown>): void {
  const callId = typeof m.callId === 'string' ? m.callId : '';
  const ring = rings.get(callId);
  if (!ring || (ring.to !== user.uid && ring.from !== user.uid)) return;
  clearTimeout(ring.timer);
  rings.delete(callId);
  const other = store.userByUid(ring.from === user.uid ? ring.to : ring.from);
  const isCancel = ring.from === user.uid;
  if (other) state(other, callId, isCancel ? 'cancelled' : 'declined');
  const callerU = store.userByUid(ring.from);
  if (!isCancel && callerU) void missedCallDm(callerU, ring.to, ring.video);
}
