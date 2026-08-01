// Rivlr — live social backend.
//
// One PLAY → an unpredictable, preference-aware, block-aware cell → LiveKit
// video tokens → relayed game events. Real Sparks (mutual + "they're live"),
// lightweight auto-moderation, and heartbeats. Fail-soft: no LiveKit keys →
// matchmaking still works (video disabled); ALLOW_SOLO lets a lone tester in.

import 'dotenv/config';
import express from 'express';
import { createServer } from 'http';
import { WebSocketServer, WebSocket } from 'ws';
import { randomUUID } from 'crypto';
import { rollGame, rollMemberCount } from './games.js';
import { store, type User, type Meet } from './store.js';
import { mintToken, LIVEKIT_URL } from './livekit.js';

const PORT = Number(process.env.PORT || 8080);
const ALLOW_SOLO = (process.env.ALLOW_SOLO || 'true') === 'true';
const SOLO_WAIT_MS = Number(process.env.SOLO_WAIT_MS || 6000);
const LIVE_BASELINE = Number(process.env.LIVE_BASELINE || 0);
const REPORT_KICK = Number(process.env.REPORT_KICK || 3);

const NAMES = ['kai', 'noor', 'remy', 'sasha', 'theo', 'luca', 'emi', 'dro', 'wren',
  'max', 'ira', 'jae', 'nova', 'sol', 'zed', 'fin', 'ash', 'juno'];
const HUES = [205, 212, 196, 220, 190, 208, 216, 200];
const pick = <T>(a: T[]): T => a[Math.floor(Math.random() * a.length)];

let lastKind: ReturnType<typeof rollGame>['game']['kind'] | undefined;
let lastName: string | undefined;

// ---- net helpers -----------------------------------------------------------
function send(u: User | undefined, obj: unknown) {
  if (u && u.ws.readyState === WebSocket.OPEN) u.ws.send(JSON.stringify(obj));
}
function sendById(id: string, obj: unknown) {
  send(store.users.get(id), obj);
}
function broadcastCell(cellId: string, obj: unknown, exceptId?: string) {
  const cell = store.cells.get(cellId);
  if (!cell) return;
  for (const id of cell.members) if (id !== exceptId) sendById(id, obj);
}

// ---- compatibility (the "who you want to meet" seed of the vision) ---------
function meetOk(meet: Meet, gender?: string): boolean {
  if (meet === 'Women') return gender === 'Woman';
  if (meet === 'Men') return gender === 'Man';
  return true; // Everyone (or unknown gender) — don't starve the queue
}
function compatible(a: User, b: User): boolean {
  return a.uid !== b.uid
    && !store.isBlocked(a.uid, b.uid)
    && meetOk(a.meet, b.gender)
    && meetOk(b.meet, a.gender);
}

// ---- matchmaking -----------------------------------------------------------
function enqueue(u: User) {
  u.state = 'queued';
  u.queuedAt = Date.now();
  if (!store.queue.includes(u.id)) store.queue.push(u.id);
  send(u, { t: 'searching' });
  tryMatch();
}
function dequeue(id: string) {
  const i = store.queue.indexOf(id);
  if (i >= 0) store.queue.splice(i, 1);
}

function tryMatch() {
  let guard = store.queue.length * 2 + 2;
  while (store.queue.length >= 2 && guard-- > 0) {
    const seed = store.users.get(store.queue[0]);
    if (!seed) { store.queue.shift(); continue; }

    const want = rollMemberCount();
    const members = [seed.id];
    for (let i = 1; i < store.queue.length && members.length < want; i++) {
      const cand = store.users.get(store.queue[i]);
      if (!cand) continue;
      if (members.every((mid) => compatible(store.users.get(mid)!, cand))) members.push(cand.id);
    }

    if (members.length >= 2) {
      for (const id of members) dequeue(id);
      void formCell(members);
    } else {
      // seed couldn't find a compatible partner right now — rotate and retry
      store.queue.push(store.queue.shift()!);
    }
  }
}

async function formCell(memberIds: string[]) {
  const live = memberIds.filter((id) => store.users.get(id)?.ws.readyState === WebSocket.OPEN);
  if (live.length === 0) return;

  const strangers = live.length - 1;
  const { game, prompt } = rollGame(strangers, lastKind, lastName);
  lastKind = game.kind;
  lastName = game.name;

  const cellId = randomUUID();
  const room = `cell_${cellId}`;
  store.cells.set(cellId, { id: cellId, room, members: [...live], kind: game.kind });

  for (const id of live) {
    const u = store.users.get(id);
    if (!u) continue;
    u.state = 'incell';
    u.cellId = cellId;
    const others = live.filter((x) => x !== id).map((x) => {
      const o = store.users.get(x)!;
      return { id: x, uid: o.uid, name: o.name, hue: o.hue };
    });
    const token = await mintToken(room, id, u.name);
    send(u, { t: 'cell', room, url: LIVEKIT_URL, token, people: others,
      game: { kind: game.kind, name: game.name, hint: game.hint, prompt } });
  }
  console.log(`[cell] ${cellId} · ${live.length} people · ${game.kind}`);
}

function leaveCell(u: User) {
  if (!u.cellId) return;
  const cell = store.cells.get(u.cellId);
  u.cellId = null;
  if (!cell) return;
  cell.members = cell.members.filter((x) => x !== u.id);
  broadcastCell(cell.id, { t: 'peerLeft', id: u.id });
  if (cell.members.length < 2) {
    const remaining = [...cell.members];
    store.cells.delete(cell.id);
    for (const id of remaining) {
      const other = store.users.get(id);
      if (other) { send(other, { t: 'ended' }); enqueue(other); } // fluid recompose
    }
  }
}

// ---- sparks (real connections) --------------------------------------------
function onSave(u: User, targetUid: string) {
  if (!targetUid) return;
  store.addSave(u.uid, targetUid);
  if (store.hasSaved(targetUid, u.uid)) {
    const other = store.userByUid(targetUid);
    send(u, { t: 'sparkMutual', uid: targetUid, name: other?.name ?? 'someone' });
    if (other) send(other, { t: 'sparkMutual', uid: u.uid, name: u.name });
  }
}
function notifyLive(u: User) {
  // tell everyone who saved me that I just came online
  for (const a of store.savedByOf(u.uid)) {
    const watcher = store.userByUid(a);
    if (watcher) send(watcher, { t: 'sparkLive', uid: u.uid, name: u.name });
  }
}

// ---- moderation ------------------------------------------------------------
function onReport(target: string) {
  const n = store.report(target);
  console.log(`[report] ${target} (${n})`);
  if (n >= REPORT_KICK) {
    const u = store.userByUid(target);
    if (u) {
      send(u, { t: 'removed', reason: 'community reports' });
      try { u.ws.close(); } catch { /* ignore */ }
    }
  }
}

// ---- background loops ------------------------------------------------------
setInterval(() => {
  if (ALLOW_SOLO) {
    const now = Date.now();
    for (const id of [...store.queue]) {
      const u = store.users.get(id);
      if (u && now - u.queuedAt > SOLO_WAIT_MS) { dequeue(id); void formCell([id]); }
    }
  }
}, 1000);

setInterval(() => {
  const live = LIVE_BASELINE + store.onlineCount;
  for (const u of store.users.values()) send(u, { t: 'presence', live });
}, 4000);

// heartbeat — drop dead sockets
setInterval(() => {
  const now = Date.now();
  for (const u of store.users.values()) {
    if (now - u.lastPong > 35000) { try { u.ws.terminate(); } catch { /* ignore */ } continue; }
    try { u.ws.ping(); } catch { /* ignore */ }
  }
}, 15000);

// ---- http + ws -------------------------------------------------------------
const app = express();
app.get('/', (_req, res) => res.json({ ok: true, service: 'rivlr', live: LIVE_BASELINE + store.onlineCount }));
app.get('/health', (_req, res) => res.json({ ok: true }));
app.get('/stats', (_req, res) => res.json({
  online: store.onlineCount, queued: store.queue.length, cells: store.cells.size, livekit: !!LIVEKIT_URL,
}));

const server = createServer(app);
const wss = new WebSocketServer({ server, path: '/ws' });

wss.on('connection', (ws) => {
  const id = randomUUID();
  const user: User = {
    id, ws, uid: id, name: pick(NAMES), hue: pick(HUES),
    meet: 'Everyone', state: 'idle', cellId: null, queuedAt: 0, lastPong: Date.now(),
  };
  store.users.set(id, user);
  store.byUid.set(user.uid, id);

  ws.on('pong', () => { user.lastPong = Date.now(); });

  ws.on('message', (raw) => {
    let m: any;
    try { m = JSON.parse(raw.toString()); } catch { return; }
    switch (m.t) {
      case 'hello': {
        if (typeof m.uid === 'string' && m.uid.length) {
          store.byUid.delete(user.uid);
          user.uid = m.uid.slice(0, 64);
          store.byUid.set(user.uid, id);
        }
        if (typeof m.name === 'string' && m.name.trim()) user.name = m.name.trim().slice(0, 16);
        if (typeof m.gender === 'string') user.gender = m.gender;
        if (m.meet === 'Women' || m.meet === 'Men' || m.meet === 'Everyone') user.meet = m.meet;
        send(user, { t: 'welcome', id, uid: user.uid, name: user.name, hue: user.hue, live: LIVE_BASELINE + store.onlineCount });
        notifyLive(user);
        break;
      }
      case 'play': leaveCell(user); enqueue(user); break;
      case 'next': leaveCell(user); enqueue(user); break;
      case 'leave': dequeue(id); leaveCell(user); user.state = 'idle'; break;
      case 'answer':
      case 'react':
        if (user.cellId) broadcastCell(user.cellId, { t: m.t, from: id, v: m.v, e: m.e }, id);
        break;
      case 'save': if (typeof m.target === 'string') onSave(user, m.target); break;
      case 'unsave': if (typeof m.target === 'string') store.removeSave(user.uid, m.target); break;
      case 'report': if (typeof m.target === 'string') onReport(m.target); break;
      case 'block':
        if (typeof m.target === 'string') { store.block(user.uid, m.target); onReport(m.target); }
        leaveCell(user); enqueue(user);
        break;
    }
  });

  ws.on('close', () => {
    dequeue(id);
    leaveCell(user);
    if (store.byUid.get(user.uid) === id) store.byUid.delete(user.uid);
    store.users.delete(id);
  });
  ws.on('error', () => { /* close handler cleans up */ });
});

server.listen(PORT, () => {
  console.log(`Rivlr server on :${PORT}  (livekit ${LIVEKIT_URL ? 'ON' : 'OFF'}, solo ${ALLOW_SOLO})`);
});
