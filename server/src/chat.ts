import { store, type User } from './store.js';
import { dbEnabled } from './db.js';
import * as dbs from './db_social.js';
import { sendPush, pushEnabled } from './push.js';
import { claimForPair } from './media.js';
import { moderateText, isSevere } from './moderation.js';

/// Messaging between matched friends. WS carries the realtime layer; Postgres
/// is the source of truth; offline delivery rides push. Ordering = message id.

type SendFn = (u: User, m: Record<string, unknown>) => void;
let send: SendFn = () => {};
export function init(s: SendFn) { send = s; }

function err(user: User, code: string) { send(user, { t: 'err', code }); }

const KINDS = new Set(['text', 'voice', 'photo', 'gif', 'invite']);
const MAX_BODY = 4000;

// offline-push soft limit: at most one message push per pair per minute
const lastMsgPush = new Map<string, number>();

/// Prune by AGE, never by online-status: this map rate-limits pushes to
/// OFFLINE recipients — the cooldown is 60s, so anything older than 2min
/// is inert.
export function pruneMsgPush(): void {
  const cutoff = Date.now() - 120_000;
  for (const [k, t] of lastMsgPush) if (t < cutoff) lastMsgPush.delete(k);
}

export async function dm(user: User, m: Record<string, unknown>): Promise<void> {
  if (!dbEnabled) return err(user, 'noDb');
  const to = typeof m.to === 'string' ? m.to : '';
  const kind = typeof m.kind === 'string' ? m.kind : 'text';
  const tmp = typeof m.tmp === 'string' ? m.tmp : '';
  let body = typeof m.body === 'string' ? m.body : '';
  const mediaId = typeof m.mediaId === 'number' ? m.mediaId : null;
  const meta = (m.meta && typeof m.meta === 'object') ? m.meta as Record<string, unknown> : {};
  if (!to || to === user.uid || !KINDS.has(kind)) return;
  if (body.length > MAX_BODY) body = body.slice(0, MAX_BODY);
  if (kind === 'text' && !body.trim()) return;
  if ((kind === 'voice' || kind === 'photo') && mediaId == null) return;
  if (store.isBlocked(user.uid, to)) return err(user, 'blocked');
  if ((await dbs.friendState(user.uid, to)) !== 'friends') return err(user, 'notFriends');
  // proactive filter, text only — ordinary flirty/adult chat between two
  // people who matched each other is expected here and stays allowed; only
  // the genuinely dangerous categories (minors, self-harm coaching, graphic
  // violence, real threats) get hard-blocked at send time. Report+block
  // remain the backstop for everything this doesn't catch.
  if (kind === 'text') {
    const mod = await moderateText(body);
    if (mod?.flagged && isSevere(mod.categories)) {
      send(user, { t: 'err', code: 'flagged', where: 'chat' });
      return;
    }
  }
  if (mediaId != null) {
    // the media must be YOURS and unclaimed — then it belongs to this thread
    const ok = await claimForPair(mediaId, user.uid, dbs.pairKey(user.uid, to));
    if (!ok) return err(user, 'badMedia');
  }

  const row = await dbs.insertMessage(user.uid, to, user.uid, kind, body, mediaId, meta);
  if (!row) return err(user, 'noDb');
  send(user, { t: 'dmAck', tmp, id: row.id, at: row.at });

  const msg = {
    id: row.id, from: user.uid, kind, body, mediaId, meta, at: row.at,
  };
  const peer = store.userByUid(to);
  if (peer) {
    send(peer, { t: 'dm', msg });
    return;
  }
  // offline — push, softly rate-limited per pair
  if (!pushEnabled) return;
  const pk = dbs.pairKey(user.uid, to);
  const now = Date.now();
  if (now - (lastMsgPush.get(pk) ?? 0) < 60_000) return;
  lastMsgPush.set(pk, now);
  const token = await dbs.getPushToken(to);
  if (!token) return;
  const preview = kind === 'text' ? body.slice(0, 80)
      : kind === 'voice' ? '🎤 voice note'
      : kind === 'photo' ? '📷 photo'
      : kind === 'gif' ? 'GIF'
      : '🎮 room invite';
  sendPush(token, user.name, preview);
}

export async function history(user: User, m: Record<string, unknown>): Promise<void> {
  if (!dbEnabled) return err(user, 'noDb');
  const withUid = typeof m.with === 'string' ? m.with : '';
  if (!withUid) return;
  const before = typeof m.before === 'number' ? m.before : null;
  const limit = Math.min(100, Math.max(1, Number(m.limit ?? 50)));
  const page = await dbs.messagesPage(user.uid, withUid, before, limit);
  send(user, { t: 'dmHistory', with: withUid, msgs: page.msgs.map((x) => ({
    id: x.id, from: x.sender, kind: x.kind, body: x.body, mediaId: x.mediaId,
    meta: x.meta, at: x.at,
  })), reactions: page.reactions, more: page.more });
}

export async function read(user: User, m: Record<string, unknown>): Promise<void> {
  if (!dbEnabled) return;
  const withUid = typeof m.with === 'string' ? m.with : '';
  const upTo = Number(m.upTo);
  if (!withUid || !Number.isFinite(upTo)) return;
  dbs.setRead(user.uid, withUid, Math.trunc(upTo));
  const peer = store.userByUid(withUid);
  if (peer) send(peer, { t: 'dmRead', with: user.uid, upTo: Math.trunc(upTo) });
}

export function typing(user: User, m: Record<string, unknown>): void {
  const to = typeof m.to === 'string' ? m.to : '';
  if (!to) return;
  const peer = store.userByUid(to);
  if (peer) send(peer, { t: 'typing', from: user.uid, on: m.on === true });
}

export async function react(user: User, m: Record<string, unknown>): Promise<void> {
  if (!dbEnabled) return err(user, 'noDb');
  const id = Number(m.id);
  if (!Number.isFinite(id)) return;
  const e = typeof m.e === 'string' && m.e.length <= 8 ? m.e : null;
  const p = await dbs.messagePair(id);
  if (!p || (p.a !== user.uid && p.b !== user.uid)) return; // not your thread
  dbs.setReaction(id, user.uid, e);
  const otherUid = p.a === user.uid ? p.b : p.a;
  const payload = { t: 'msgReact', id, from: user.uid, e };
  send(user, payload);
  const peer = store.userByUid(otherUid);
  if (peer) send(peer, payload);
}

export async function chats(user: User): Promise<void> {
  if (!dbEnabled) return send(user, { t: 'chats', list: [] });
  const list = await dbs.chatList(user.uid);
  send(user, { t: 'chats', list: list.map((c) => ({
    peer: { uid: c.peer, name: c.name, hue: c.hue, photoId: c.photoId, title: c.title },
    last: c.last, unread: c.unread, pinned: c.pinned,
    online: !!store.userByUid(c.peer),
  })) });
}

/// Total unread — pushed after hydrate so Home can badge before any screen asks.
export async function sendUnread(user: User): Promise<void> {
  if (!dbEnabled) return;
  const n = await dbs.unreadTotal(user.uid);
  if (store.userByUid(user.uid) === user) send(user, { t: 'unread', n });
}
