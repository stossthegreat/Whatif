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
import { rollGame, rollMemberCount, SEQ_PACK, seqByName, type GameKind, type SeqDef } from './games.js';
import { store, type User, type Meet, type Cell, type RoundWire } from './store.js';
import { mintToken, LIVEKIT_URL } from './livekit.js';
import * as db from './db.js';

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
    && (a.mode ?? 'hang') === (b.mode ?? 'hang') // roulette matches roulette
    && meetOk(a.meet, b.gender)
    && meetOk(b.meet, a.gender);
}

// ---- matchmaking -----------------------------------------------------------
function enqueue(u: User) {
  u.state = 'queued';
  u.queuedAt = Date.now();
  if (!store.queue.includes(u.id)) store.queue.push(u.id);
  send(u, { t: 'searching' });
  // someone waiting alone in a room? walk straight in — their full-screen
  // solo view shrinks to a PiP the moment you arrive
  if (tryJoinLonelyCell(u)) return;
  tryMatch();
}

function tryJoinLonelyCell(u: User): boolean {
  for (const cell of store.cells.values()) {
    if (cell.members.length !== 1) continue;
    const lone = store.users.get(cell.members[0]);
    if (!lone || (cell.mode ?? 'hang') !== (u.mode ?? 'hang')) continue;
    if (!compatible(lone, u)) continue;
    void joinCell(cell, u);
    return true;
  }
  return false;
}

async function joinCell(cell: Cell, u: User) {
  dequeue(u.id);
  u.state = 'incell';
  u.cellId = cell.id;
  cell.members.push(u.id);
  // the room learns someone walked in
  broadcastCell(cell.id, { t: 'peerJoined', id: u.id, uid: u.uid, name: u.name, hue: u.hue }, u.id);
  // the newcomer gets the full room
  const others = cell.members.filter((x) => x !== u.id).map((x) => {
    const o = store.users.get(x)!;
    return { id: x, uid: o.uid, name: o.name, hue: o.hue };
  });
  const token = await mintToken(cell.room, u.id, u.name);
  send(u, { t: 'cell', room: cell.room, url: LIVEKIT_URL, token, people: others,
    game: cell.rounds[0], rounds: cell.rounds, golden: cell.golden,
    luckyId: cell.luckyId, mode: cell.mode });
  notifyLive(u);
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

// ---- friend rooms (party codes) --------------------------------------------
// The liquidity unlock: start a room with your mates via a 4-char code, then
// the same cell engine runs it. Fun with 3 users instead of 3,000.

interface Party { code: string; hostId: string; members: string[]; }
const parties = new Map<string, Party>();
const partyByUser = new Map<string, string>(); // conn-id -> code

const CODE_CHARS = 'ABCDEFGHJKMNPQRSTVWXYZ23456789'; // no 0/O/1/I/L confusion
function newPartyCode(): string {
  let c = '';
  do {
    c = Array.from({ length: 4 }, () => CODE_CHARS[Math.floor(Math.random() * CODE_CHARS.length)]).join('');
  } while (parties.has(c));
  return c;
}

function partyState(p: Party) {
  return {
    t: 'party', code: p.code, hostId: p.hostId,
    members: p.members.map((id) => {
      const u = store.users.get(id);
      return { id, name: u?.name ?? '?', hue: u?.hue ?? 205 };
    }),
  };
}
function broadcastParty(p: Party) {
  for (const id of p.members) sendById(id, partyState(p));
}
function leaveParty(userId: string) {
  const code = partyByUser.get(userId);
  if (!code) return;
  partyByUser.delete(userId);
  const p = parties.get(code);
  if (!p) return;
  p.members = p.members.filter((x) => x !== userId);
  if (!p.members.length) { parties.delete(code); return; }
  if (p.hostId === userId) p.hostId = p.members[0]; // promote — the room survives
  broadcastParty(p);
}

// ---- the session engine ----------------------------------------------------
// The server owns the room: it rolls the session, times the rounds, tallies
// real answers, schedules chaos, computes awards from real votes, and rolls
// the revive wheel. Clients keep local timers only as fail-soft fallback.

// Conversation-first pacing: talk games get real time; a round ends early when
// everyone has answered. This is a place to meet people, not a quiz show.
const ROUND_SECS: Record<string, number> = {
  point: 75,     // perform/talk games — storytime, debates, roasts
  spin: 45,      // bottle + the target performs
  freeze: 15,
  rapidFire: 20,
};
const secsFor = (kind: string) => ROUND_SECS[kind] ?? 30; // tap-answer kinds

const CHAOS_CARDS: [string, string][] = [
  ['🤫', 'Everyone WHISPER until the next game'],
  ['🤥', 'Next answer must be a LIE'],
  ['🙃', 'Flip your phone upside down. Now.'],
  ['😐', 'Last to smile wins the room'],
  ['👉', 'Everybody point at someone. NOW.'],
  ['😂', '10 seconds to make the room laugh'],
  ['🎭', 'Swap accents with the person on your left'],
  ['🌀', 'CHAOS — the rules just changed'],
];

const AWARD_POOL: [string, string][] = [
  ['😂', 'Funniest'], ['😈', 'Chaos Agent'], ['🧠', 'Smartest'],
  ['👀', 'Weirdest'], ['🔥', 'Main Character'],
];

function later(cellId: string, ms: number, fn: (cell: Cell) => void) {
  const cell = store.cells.get(cellId);
  if (!cell) return;
  const t = setTimeout(() => {
    const c = store.cells.get(cellId); // re-fetch: cell may be gone
    if (c) fn(c);
  }, ms);
  cell.timers.push(t);
}

function clearCellTimers(cell: Cell) {
  for (const t of cell.timers) clearTimeout(t);
  cell.timers = [];
  if (cell.roundTimer) { clearTimeout(cell.roundTimer); cell.roundTimer = undefined; }
}

function rollSession(strangers: number): RoundWire[] {
  const ROUNDS = 5;
  const rounds: RoundWire[] = [];
  let k = lastKind;
  let n = lastName;
  for (let i = 0; i < ROUNDS; i++) {
    const vibe = i === 0 ? 'warm' : i === ROUNDS - 1 ? 'spark' : undefined;
    const r = rollGame(strangers, k, n, vibe);
    k = r.game.kind;
    n = r.game.name;
    rounds.push({
      kind: r.game.kind, name: r.game.name, hint: r.game.hint, prompt: r.prompt,
      targetId: null, // filled per-cell (needs member ids)
      lieIdx: r.game.kind === 'twoTruths'
        ? Math.floor(Math.random() * Math.max(1, r.prompt.length - 1))
        : undefined,
    });
  }
  lastKind = k as typeof lastKind;
  lastName = n;
  return rounds;
}

function assignTargets(rounds: RoundWire[], members: string[]) {
  for (const r of rounds) r.targetId = pick(members);
}

/// Start one of THE TEN — a blended sequence of beats. The room chose it by
/// name, or the dice (or roulette mode) picked it. Beats auto-chain.
function startPickedGame(cell: Cell, name?: string) {
  if (cell.inRound) return; // one game at a time
  const seq: SeqDef = (name ? seqByName(name) : undefined) ?? pick(SEQ_PACK);

  // roll one prompt per beat now, so the whole chain is decided up front
  cell.seqBeats = seq.beats.map((b) => {
    const prompt = [...b.pool[Math.floor(Math.random() * b.pool.length)]];
    const head = prompt.shift()!;
    for (let i = prompt.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [prompt[i], prompt[j]] = [prompt[j], prompt[i]];
    }
    return {
      kind: b.kind, name: seq.name, hint: seq.hint, prompt: [head, ...prompt],
      targetId: pick(cell.members),
      lieIdx: b.kind === 'twoTruths'
        ? Math.floor(Math.random() * Math.max(1, prompt.length)) : undefined,
      secs: b.secs,
    } as RoundWire & { secs?: number };
  });
  cell.seqPos = 0;
  startBeat(cell);
}

function startBeat(cell: Cell) {
  const wire = cell.seqBeats?.[cell.seqPos] as (RoundWire & { secs?: number }) | undefined;
  if (!wire) return;
  const idx = cell.roundIdx + 1;
  cell.roundIdx = idx;
  if (idx < cell.rounds.length) cell.rounds[idx] = wire; else cell.rounds.push(wire);
  cell.answers = new Map();
  cell.inRound = true;

  const secs = wire.secs ?? secsFor(wire.kind);
  const endsAt = Date.now() + secs * 1000;
  broadcastCell(cell.id, { t: 'round', idx, endsAt, game: wire,
    beat: cell.seqPos + 1, beats: cell.seqBeats?.length ?? 1 });
  if (cell.roundTimer) clearTimeout(cell.roundTimer);
  cell.roundTimer = setTimeout(() => {
    const c = store.cells.get(cell.id);
    if (c && c.roundIdx === idx) endRound(c);
  }, secs * 1000);
}

function endRound(cell: Cell) {
  const idx = cell.roundIdx;
  const round = cell.rounds[idx];
  if (!round) return;
  const kind = round.kind;
  const vals = [...cell.answers.values()];
  const msg: Record<string, unknown> = { t: 'result', round: idx, kind };

  if (kind === 'point') {
    // real votes: mode of the tapped conn-ids
    const tally = new Map<string, number>();
    for (const v of vals) if (typeof v === 'string') tally.set(v, (tally.get(v) ?? 0) + 1);
    let winner: string | undefined;
    let best = -1;
    for (const [id, c] of tally) if (c > best && cell.members.includes(id)) { winner = id; best = c; }
    winner ??= pick(cell.members);
    cell.lastWinnerId = winner;
    msg.winnerId = winner;
    msg.tally = Object.fromEntries(tally); // per-face vote counts for the reveal
  } else if (kind === 'spin') {
    const winner = round.targetId && cell.members.includes(round.targetId) ? round.targetId : pick(cell.members);
    cell.lastWinnerId = winner;
    msg.winnerId = winner;
  } else if (kind === 'thumbs') {
    msg.guilty = vals.filter((v) => v === true).length;
  } else if (kind === 'freeze' || kind === 'rapidFire') {
    const winner = pick(cell.members);
    cell.lastWinnerId = winner;
    msg.winnerId = winner;
  } else {
    // option kinds: poll / wouldRather / same / twoTruths
    const nOpts = Math.max(2, round.prompt.length - 1);
    const counts = new Array<number>(nOpts).fill(0);
    for (const v of vals) if (typeof v === 'number' && v >= 0 && v < nOpts) counts[v]++;
    msg.counts = counts;
    if (round.lieIdx != null) msg.lieIdx = round.lieIdx;
  }

  cell.inRound = false;
  broadcastCell(cell.id, msg);

  // more beats in this game? quick flip, straight into the next beat
  if (cell.seqBeats && cell.seqPos < cell.seqBeats.length - 1) {
    cell.seqPos += 1;
    later(cell.id, 4000, (c) => startBeat(c));
    return;
  }

  // game complete — the reveal breathes, then back to the hang. Every 3rd
  // game earns a ceremony. Roulette rooms roll the next game automatically.
  cell.seqBeats = undefined;
  cell.gamesPlayed += 1;
  if (cell.gamesPlayed % 3 === 0) {
    later(cell.id, 7000, (c) => sendAwards(c));
    if (cell.mode === 'roulette') {
      later(cell.id, 22000, (c) => { if (!c.inRound) startPickedGame(c); });
    }
  } else {
    later(cell.id, 7000, (c) => broadcastCell(c.id, { t: 'talk' }));
    if (cell.mode === 'roulette') {
      later(cell.id, 14000, (c) => { if (!c.inRound) startPickedGame(c); });
    }
  }
}

function sendAwards(cell: Cell) {
  const members = cell.members.filter((id) => store.users.get(id));
  if (!members.length) return;
  const mvp = cell.lastWinnerId && members.includes(cell.lastWinnerId)
    ? cell.lastWinnerId : pick(members);

  // the room's real votes promote that award into the ceremony
  const voteTally = new Map<string, number>();
  for (const e of cell.votes.values()) voteTally.set(e, (voteTally.get(e) ?? 0) + 1);
  const pool = [...AWARD_POOL].sort(() => Math.random() - 0.5);
  pool.sort((a, b) => (voteTally.get(b[0]) ?? 0) - (voteTally.get(a[0]) ?? 0));

  const others = members.filter((id) => id !== mvp);
  const list: { emoji: string; label: string; winnerId: string }[] = [
    { emoji: '🏆', label: 'MVP', winnerId: mvp },
  ];
  for (let i = 0; i < Math.min(2, pool.length); i++) {
    list.push({
      emoji: pool[i][0], label: pool[i][1],
      winnerId: others.length ? others[i % others.length] : mvp,
    });
  }
  broadcastCell(cell.id, { t: 'awards', list });
}

// real "matches today" counter — resets at UTC midnight. Never fabricated:
// every increment is an actual cell that actually formed.
let matchesToday = 0;
let matchesDay = new Date().toISOString().slice(0, 10);
function noteMatch() {
  const day = new Date().toISOString().slice(0, 10);
  if (day !== matchesDay) { matchesDay = day; matchesToday = 0; }
  matchesToday += 1;
  db.bumpMatches(day);
}

async function formCell(memberIds: string[]) {
  const live = memberIds.filter((id) => store.users.get(id)?.ws.readyState === WebSocket.OPEN);
  if (live.length === 0) return;

  const strangers = live.length - 1;
  const rounds = rollSession(strangers);
  assignTargets(rounds, live);

  const cellId = randomUUID();
  const room = `cell_${cellId}`;
  const mode = (store.users.get(live[0])?.mode ?? 'hang');
  const cell: Cell = {
    id: cellId, room, members: [...live], kind: rounds[0].kind as GameKind,
    rounds, roundIdx: -1, answers: new Map(), votes: new Map(),
    golden: Math.random() < 0.04, luckyId: pick(live), timers: [],
    gamesPlayed: 0, inRound: false, mode, seqPos: 0,
  };
  store.cells.set(cellId, cell);
  noteMatch();

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
      game: rounds[0], rounds, golden: cell.golden, luckyId: cell.luckyId, mode });
  }

  // talk-first: the room opens as a hang. In HANG mode games start when the
  // room picks one; in ROULETTE they auto-chain — no choices, that's the deal.
  later(cellId, 1300, (c) => broadcastCell(c.id, { t: 'talk' }));
  if (mode === 'roulette') later(cellId, 6000, (c) => startPickedGame(c));
  const chaosCount = 1 + Math.floor(Math.random() * 2);
  for (let i = 0; i < chaosCount; i++) {
    const [e, x] = pick(CHAOS_CARDS);
    later(cellId, 15000 + Math.floor(Math.random() * 90000), (c) =>
      broadcastCell(c.id, { t: 'chaos', e, x }));
  }
  console.log(`[cell] ${cellId} · ${live.length} people · ${rounds.map((r) => r.name).join(' → ')}${cell.golden ? ' · GOLDEN' : ''}`);
}

function leaveCell(u: User) {
  if (!u.cellId) return;
  const cell = store.cells.get(u.cellId);
  u.cellId = null;
  if (!cell) return;
  // a resumed seat means this connection is no longer a member — its late
  // close event must not tear down the room it was reconnected into
  if (!cell.members.includes(u.id)) return;
  cell.members = cell.members.filter((x) => x !== u.id);
  broadcastCell(cell.id, { t: 'peerLeft', id: u.id });
  if (cell.members.length < 2) {
    const remaining = [...cell.members];
    clearCellTimers(cell); // never let a dead cell's timers fire into new rooms
    store.cells.delete(cell.id);
    for (const id of remaining) {
      const other = store.users.get(id);
      if (other) { send(other, { t: 'ended' }); enqueue(other); } // fluid recompose
    }
  }
}

/// A returning uid whose previous connection is still holding a seat in a live
/// cell (wifi blip — the dead socket hasn't been reaped yet) takes that seat
/// over: same room, fresh token. Others see a quick leave/rejoin.
function resumeCell(user: User) {
  for (const cell of store.cells.values()) {
    const oldId = cell.members.find((mid) => {
      if (mid === user.id) return false;
      const o = store.users.get(mid);
      return !!o && o.uid === user.uid;
    });
    if (!oldId) continue;
    const old = store.users.get(oldId)!;
    cell.members = cell.members.map((mid) => (mid === oldId ? user.id : mid));
    if (cell.luckyId === oldId) cell.luckyId = user.id;
    for (const r of cell.rounds) if (r.targetId === oldId) r.targetId = user.id;
    for (const r of cell.seqBeats ?? []) if (r.targetId === oldId) r.targetId = user.id;
    old.cellId = null;
    store.users.delete(oldId);
    try { old.ws.terminate(); } catch { /* already dead */ }
    user.state = 'incell';
    user.cellId = cell.id;
    broadcastCell(cell.id, { t: 'peerLeft', id: oldId }, user.id);
    void (async () => {
      const token = await mintToken(cell.room, user.id, user.name);
      if (user.cellId !== cell.id) return; // they left while the token minted
      const others = cell.members.filter((x) => x !== user.id).map((x) => {
        const o = store.users.get(x)!;
        return { id: x, uid: o.uid, name: o.name, hue: o.hue };
      });
      send(user, { t: 'cell', room: cell.room, url: LIVEKIT_URL, token, people: others,
        game: cell.rounds[0], rounds: cell.rounds, golden: cell.golden,
        luckyId: cell.luckyId, mode: cell.mode });
      broadcastCell(cell.id, { t: 'peerJoined', id: user.id, uid: user.uid, name: user.name, hue: user.hue }, user.id);
    })();
    return;
  }
}

// ---- sparks (real connections) --------------------------------------------
function onSave(u: User, targetUid: string) {
  if (!targetUid) return;
  store.addSave(u.uid, targetUid);
  db.addSave(u.uid, targetUid);
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
function onReport(target: string, reporter = '') {
  const n = store.report(target);
  db.addReport(reporter, target);
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
  // rooms + matches are real counts — the client hides anything too small to
  // impress, so low numbers never reach the screen.
  for (const u of store.users.values()) {
    send(u, { t: 'presence', live, rooms: store.cells.size, matches: matchesToday });
  }
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
        resumeCell(user); // wifi blip? re-seat them in the room they were in
        const vibes = Array.isArray(m.vibes)
          ? (m.vibes as unknown[]).filter((v): v is string => typeof v === 'string').slice(0, 12)
          : [];
        db.upsertUser({ uid: user.uid, name: user.name, hue: user.hue, gender: user.gender, meet: user.meet, vibes });
        void db.loadSocial(user.uid).then((d) => {
          if (!d) return;
          if (store.userByUid(user.uid) !== user) return; // reconnected again meanwhile
          store.hydrateSocial(user.uid, { ...d, saves: d.saves.map((s) => s.target) });
          // replay mutual sparks so a fresh install gets its people back
          for (const s of d.saves) {
            if (store.hasSaved(s.target, user.uid)) {
              send(user, { t: 'sparkMutual', uid: s.target, name: s.name ?? 'someone' });
            }
          }
        });
        break;
      }
      case 'play':
        if (m.mode === 'roulette' || m.mode === 'hang') user.mode = m.mode;
        leaveParty(id); leaveCell(user); enqueue(user);
        break;
      case 'next': leaveCell(user); enqueue(user); break;
      case 'leave': dequeue(id); leaveCell(user); user.state = 'idle'; break;
      case 'host': {
        leaveParty(id); dequeue(id); leaveCell(user);
        const p: Party = { code: newPartyCode(), hostId: id, members: [id] };
        parties.set(p.code, p);
        partyByUser.set(id, p.code);
        send(user, partyState(p));
        break;
      }
      case 'joinParty': {
        const code = String(m.code ?? '').toUpperCase().trim();
        // Joining the party you're already in (e.g. typing your own code) must
        // be a no-op success. The old flow left-then-rejoined — leaving a solo
        // party DELETES it from the map, so the host ended up holding a ghost
        // code and every friend after that got "code doesn't exist".
        if (partyByUser.get(id) === code) {
          const own = parties.get(code);
          if (own) { send(user, partyState(own)); break; }
        }
        const p = parties.get(code);
        if (!p || p.members.length >= 8) {
          send(user, { t: 'partyError', reason: !p ? 'That code doesn’t exist' : 'That room is full' });
          break;
        }
        leaveParty(id); dequeue(id); leaveCell(user);
        p.members.push(id);
        partyByUser.set(id, code);
        broadcastParty(p);
        break;
      }
      case 'leaveParty': leaveParty(id); break;
      case 'pickGame': {
        const cell = user.cellId ? store.cells.get(user.cellId) : undefined;
        // roulette rooms don't take requests — the wheel of fate runs them
        if (cell && cell.mode !== 'roulette') {
          startPickedGame(cell, typeof m.name === 'string' ? m.name : undefined);
        }
        break;
      }
      case 'startParty': {
        const code = partyByUser.get(id);
        const p = code ? parties.get(code) : undefined;
        if (!p || p.hostId !== id) break;
        const members = [...p.members];
        for (const mid of members) partyByUser.delete(mid);
        parties.delete(p.code);
        void formCell(members);
        break;
      }
      case 'answer': {
        if (!user.cellId) break;
        broadcastCell(user.cellId, { t: 'answer', from: id, v: m.v }, id);
        // record the real answer for this round's tally
        const cell = store.cells.get(user.cellId);
        if (cell && (m.round == null || m.round === cell.roundIdx)) {
          cell.answers.set(id, m.v);
          // everyone's in — give the room 4s to see it, then flip early
          if (cell.answers.size >= cell.members.length && cell.roundTimer) {
            clearTimeout(cell.roundTimer);
            const idx = cell.roundIdx;
            cell.roundTimer = setTimeout(() => {
              const c = store.cells.get(cell.id);
              if (c && c.roundIdx === idx) endRound(c);
            }, 4000);
          }
        }
        break;
      }
      case 'react':
        if (user.cellId) broadcastCell(user.cellId, { t: 'react', from: id, e: m.e }, id);
        break;
      case 'vote': {
        const cell = user.cellId ? store.cells.get(user.cellId) : undefined;
        if (cell && typeof m.e === 'string') cell.votes.set(id, m.e);
        break;
      }
      case 'spinWheel': {
        const cell = user.cellId ? store.cells.get(user.cellId) : undefined;
        if (!cell) { send(user, { t: 'wheel', revive: false }); break; }
        const revive = Math.random() < 0.35;
        if (revive) {
          // first reviver rerolls one shared session and restarts the room loop
          if (!cell.reviveRounds) {
            cell.reviveRounds = rollSession(Math.max(1, cell.members.length - 1));
            assignTargets(cell.reviveRounds, cell.members);
            clearCellTimers(cell);
            cell.rounds = cell.reviveRounds;
            cell.roundIdx = -1;
            cell.votes = new Map();
            cell.lastWinnerId = undefined;
            later(cell.id, 4200, (c) => {
              c.reviveRounds = undefined; // allow a fresh reroll next ceremony
              c.inRound = false;
              c.seqBeats = undefined;
              broadcastCell(c.id, { t: 'talk' }); // revived room = fresh hang
              if (c.mode === 'roulette') {
                later(c.id, 6000, (c2) => { if (!c2.inRound) startPickedGame(c2); });
              }
            });
            const [e, x] = pick(CHAOS_CARDS);
            later(cell.id, 12000 + Math.floor(Math.random() * 20000), (c) =>
              broadcastCell(c.id, { t: 'chaos', e, x }));
          }
          send(user, { t: 'wheel', revive: true, rounds: cell.reviveRounds });
        } else {
          send(user, { t: 'wheel', revive: false });
        }
        break;
      }
      case 'save': if (typeof m.target === 'string') onSave(user, m.target); break;
      case 'unsave':
        if (typeof m.target === 'string') {
          store.removeSave(user.uid, m.target);
          db.removeSave(user.uid, m.target);
        }
        break;
      case 'report': if (typeof m.target === 'string') onReport(m.target, user.uid); break;
      case 'block':
        if (typeof m.target === 'string') {
          store.block(user.uid, m.target);
          db.addBlock(user.uid, m.target);
          onReport(m.target, user.uid);
        }
        leaveCell(user); enqueue(user);
        break;
    }
  });

  ws.on('close', () => {
    dequeue(id);
    leaveParty(id);
    leaveCell(user);
    if (store.byUid.get(user.uid) === id) store.byUid.delete(user.uid);
    store.users.delete(id);
  });
  ws.on('error', () => { /* close handler cleans up */ });
});

server.listen(PORT, () => {
  console.log(`Rivlr server on :${PORT}  (livekit ${LIVEKIT_URL ? 'ON' : 'OFF'}, solo ${ALLOW_SOLO}, db ${db.dbEnabled ? 'ON' : 'OFF'})`);
});

void db.initDb().then(async () => {
  // matches-today survives restarts — pick up where the day left off
  const n = await db.loadMatches(matchesDay);
  if (n > matchesToday) matchesToday = n;
});
