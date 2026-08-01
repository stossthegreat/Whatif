// WhatIf — matchmaking + live-video signaling server.
//
// One PLAY drops a user into the queue; the server composes an unpredictable
// "cell" (group size + game), mints a LiveKit room token per member (the live
// group video), and relays lightweight game events between members. Fail-soft:
// with no LiveKit keys it still matches people (video disabled); with ALLOW_SOLO
// a lone tester is dropped in solo after a short wait. WhatIf never fabricates
// fake humans in production.

import 'dotenv/config';
import express from 'express';
import { createServer } from 'http';
import { WebSocketServer, WebSocket } from 'ws';
import { AccessToken } from 'livekit-server-sdk';
import { randomUUID } from 'crypto';
import { rollGame, rollMemberCount, type GameKind } from './games.js';

const PORT = Number(process.env.PORT || 8080);
const LIVEKIT_URL = process.env.LIVEKIT_URL || '';
const LIVEKIT_API_KEY = process.env.LIVEKIT_API_KEY || '';
const LIVEKIT_API_SECRET = process.env.LIVEKIT_API_SECRET || '';
const ALLOW_SOLO = (process.env.ALLOW_SOLO || 'true') === 'true';
const SOLO_WAIT_MS = Number(process.env.SOLO_WAIT_MS || 6000);
const LIVE_BASELINE = Number(process.env.LIVE_BASELINE || 0);

// ---- display identities (strangers are anonymous handles, not real names) ----
const NAMES = ['kai', 'noor', 'remy', 'sasha', 'theo', 'luca', 'emi', 'dro', 'wren',
  'max', 'ira', 'jae', 'nova', 'sol', 'zed', 'fin', 'ash', 'juno'];
const HUES = [205, 212, 196, 220, 190, 208, 216, 200];
const pick = <T>(a: T[]): T => a[Math.floor(Math.random() * a.length)];

interface Client {
  id: string;
  ws: WebSocket;
  name: string;
  hue: number;
  state: 'idle' | 'queued' | 'incell';
  cellId: string | null;
  queuedAt: number;
}
interface CellRec {
  id: string;
  room: string;
  members: string[];
  kind: GameKind;
}

const clients = new Map<string, Client>();
const queue: string[] = [];
const cells = new Map<string, CellRec>();
let lastKind: GameKind | undefined;

const send = (c: Client, obj: unknown) => {
  if (c.ws.readyState === WebSocket.OPEN) c.ws.send(JSON.stringify(obj));
};
const broadcastCell = (cell: CellRec, obj: unknown, exceptId?: string) => {
  for (const id of cell.members) {
    if (id === exceptId) continue;
    const c = clients.get(id);
    if (c) send(c, obj);
  }
};

async function mintToken(room: string, identity: string, name: string): Promise<string> {
  if (!LIVEKIT_API_KEY || !LIVEKIT_API_SECRET) return '';
  const at = new AccessToken(LIVEKIT_API_KEY, LIVEKIT_API_SECRET, { identity, name, ttl: '2h' });
  at.addGrant({ roomJoin: true, room, canPublish: true, canSubscribe: true });
  return await at.toJwt();
}

async function formCell(ids: string[]) {
  const live = ids.filter((id) => clients.get(id)?.ws.readyState === WebSocket.OPEN);
  if (live.length === 0) return;

  const strangers = live.length - 1;
  const { game, prompt } = rollGame(strangers, lastKind);
  lastKind = game.kind;

  const cellId = randomUUID();
  const room = `cell_${cellId}`;
  cells.set(cellId, { id: cellId, room, members: [...live], kind: game.kind });

  for (const id of live) {
    const c = clients.get(id);
    if (!c) continue;
    c.state = 'incell';
    c.cellId = cellId;
    const others = live
      .filter((x) => x !== id)
      .map((x) => {
        const o = clients.get(x)!;
        return { id: x, name: o.name, hue: o.hue };
      });
    const token = await mintToken(room, id, c.name);
    send(c, {
      t: 'cell',
      room,
      url: LIVEKIT_URL,
      token,
      people: others,
      game: { kind: game.kind, name: game.name, hint: game.hint, prompt },
    });
  }
  console.log(`[cell] ${cellId} formed with ${live.length} (${game.kind})`);
}

async function tryMatch() {
  while (queue.length >= 2) {
    const want = rollMemberCount();
    const take = Math.min(want, queue.length);
    if (take < 2) break;
    const ids = queue.splice(0, take);
    for (const id of ids) {
      const c = clients.get(id);
      if (c) c.cellId = null;
    }
    await formCell(ids);
  }
}

function enqueue(c: Client) {
  c.state = 'queued';
  c.queuedAt = Date.now();
  if (!queue.includes(c.id)) queue.push(c.id);
  send(c, { t: 'searching' });
  void tryMatch();
}

function leaveCell(c: Client, notify = true): string[] {
  if (!c.cellId) return [];
  const cell = cells.get(c.cellId);
  c.cellId = null;
  if (!cell) return [];
  cell.members = cell.members.filter((x) => x !== c.id);
  if (notify) broadcastCell(cell, { t: 'peerLeft', id: c.id });
  // dissolve a cell that's now too small — the fluid cell recomposes
  if (cell.members.length < 2) {
    const remaining = [...cell.members];
    cells.delete(cell.id);
    for (const id of remaining) {
      const other = clients.get(id);
      if (other) {
        send(other, { t: 'ended' });
        enqueue(other); // auto re-roll into a new cell
      }
    }
    return remaining;
  }
  return [];
}

function removeFromQueue(id: string) {
  const i = queue.indexOf(id);
  if (i >= 0) queue.splice(i, 1);
}

// ---- solo sweep + presence -------------------------------------------------
setInterval(() => {
  if (ALLOW_SOLO) {
    const now = Date.now();
    for (const id of [...queue]) {
      const c = clients.get(id);
      if (c && now - c.queuedAt > SOLO_WAIT_MS) {
        removeFromQueue(id);
        void formCell([id]); // solo cell so a single tester still sees the flow
      }
    }
  }
}, 1000);

setInterval(() => {
  const live = LIVE_BASELINE + clients.size;
  for (const c of clients.values()) send(c, { t: 'presence', live });
}, 3000);

// ---- http + ws -------------------------------------------------------------
const app = express();
app.get('/', (_req, res) => res.json({ ok: true, service: 'whatif', live: LIVE_BASELINE + clients.size }));
app.get('/health', (_req, res) => res.json({ ok: true }));

const server = createServer(app);
const wss = new WebSocketServer({ server, path: '/ws' });

wss.on('connection', (ws) => {
  const id = randomUUID();
  const client: Client = {
    id, ws,
    name: pick(NAMES),
    hue: pick(HUES),
    state: 'idle',
    cellId: null,
    queuedAt: 0,
  };
  clients.set(id, client);
  send(client, { t: 'welcome', id, name: client.name, hue: client.hue, live: LIVE_BASELINE + clients.size });

  ws.on('message', (raw) => {
    let msg: any;
    try { msg = JSON.parse(raw.toString()); } catch { return; }
    switch (msg.t) {
      case 'hello':
        if (typeof msg.name === 'string' && msg.name.trim()) client.name = msg.name.trim().slice(0, 16);
        break;
      case 'play':
        leaveCell(client);
        enqueue(client);
        break;
      case 'next':
        leaveCell(client);
        enqueue(client);
        break;
      case 'leave':
        removeFromQueue(id);
        leaveCell(client);
        client.state = 'idle';
        break;
      case 'answer':
      case 'react': {
        const cell = client.cellId ? cells.get(client.cellId) : null;
        if (cell) broadcastCell(cell, { t: msg.t, from: id, v: msg.v, e: msg.e }, id);
        break;
      }
      case 'report':
      case 'block':
        console.log(`[${msg.t}] ${id} -> ${msg.target}`);
        if (msg.t === 'block') { leaveCell(client); enqueue(client); }
        break;
    }
  });

  ws.on('close', () => {
    removeFromQueue(id);
    leaveCell(client);
    clients.delete(id);
  });
  ws.on('error', () => { /* ignore — close handler cleans up */ });
});

server.listen(PORT, () => {
  console.log(`WhatIf server on :${PORT}  (livekit ${LIVEKIT_URL ? 'ON' : 'OFF'}, solo ${ALLOW_SOLO})`);
});
