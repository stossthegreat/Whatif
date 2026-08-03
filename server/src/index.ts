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
import { rollGame, SEQ_PACK, seqByName, type GameKind, type SeqDef } from './games.js';
import { store, type User, type Meet, type Cell, type RoundWire } from './store.js';
import { mintToken, LIVEKIT_URL } from './livekit.js';
import * as db from './db.js';
import { sendPush, pushEnabled } from './push.js';
import * as legal from './legal.js';
import * as social from './social.js';
import * as chat from './chat.js';
import * as dbs from './db_social.js';
import { mintAuthToken } from './auth.js';
import { mountMedia, startRetentionSweep, gifsEnabled } from './media.js';
import * as calls from './calls.js';
import * as matching from './matching.js';

const PORT = Number(process.env.PORT || 8080);
const ALLOW_SOLO = (process.env.ALLOW_SOLO || 'true') === 'true';
const SOLO_WAIT_MS = Number(process.env.SOLO_WAIT_MS || 6000);
const LIVE_BASELINE = Number(process.env.LIVE_BASELINE || 0);
// P2P: 1:1 stranger rooms carry video phone-to-phone (server only signals);
// LiveKit is the automatic fallback and still carries groups + calls.
// Kill-switch: set P2P=false on Railway and redeploy.
const P2P_ENABLED = (process.env.P2P ?? 'true') === 'true';
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
    && !social.isNeverPair(a.uid, b.uid) // "never again" is forever
    && !matching.hardBlocked(a, b)       // met in the last 24h — keep it fresh
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
  cell.joinedAt.set(u.id, Date.now());
  cell.meta.set(u.id, { uid: u.uid, name: u.name, hue: u.hue });
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

// Fairness cursor over the queue — advancing an index is free; the old
// shift()+push() rotation was O(N) per unmatched seed and O(N²) per pulse.
let matchRot = 0;

function tryMatch() {
  // Strangers match STRICTLY 1:1 (groups exist only via friend codes) — the
  // proven format, and the seed picks the BEST-scoring partner, not the first.
  // Work per invocation is CAPPED (16 seeds × 64 candidates) so a huge queue
  // costs the same as a small one; the cursor + 1s pulse guarantee everyone
  // gets looked at within a few ticks. Identical behavior for queues ≤ 65.
  const SCAN = 64, SEEDS = 16;
  for (let attempt = 0; attempt < SEEDS && store.queue.length >= 2; attempt++) {
    const len = store.queue.length;
    if (matchRot >= len) matchRot = 0;
    const seed = store.users.get(store.queue[matchRot]);
    if (!seed) { store.queue.splice(matchRot, 1); continue; }

    let best: User | null = null;
    let bestScore = -Infinity;
    const scan = Math.min(SCAN, len - 1);
    for (let j = 1; j <= scan; j++) {
      const cand = store.users.get(store.queue[(matchRot + j) % len]);
      if (!cand || !compatible(seed, cand)) continue;
      const s = matching.score(seed, cand);
      if (s > bestScore) { bestScore = s; best = cand; }
    }

    const waited = Date.now() - seed.queuedAt;
    // take a great match immediately; take ANY match after 5s — never starve
    if (best && (bestScore >= 4 || waited > 5000)) {
      dequeue(seed.id);
      dequeue(best.id);
      matching.noteMetNow(seed.uid, best.uid);
      void formCell([seed.id, best.id]);
      // cursor stays put — the array shrank underneath it
    } else {
      matchRot++; // next seed gets a look on the next iteration / pulse
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
  point: 23,     // perform/talk games — quick fire, not a monologue
  spin: 18,      // bottle + the target performs
  freeze: 11,
  rapidFire: 13,
};
const secsFor = (kind: string) => ROUND_SECS[kind] ?? 13; // tap-answer kinds

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
    const winnerUid = cell.meta.get(winner)?.uid;
    if (winnerUid) social.onPointWin(winnerUid); // Storyteller badge fuel
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
    later(cell.id, 2000, (c) => startBeat(c));
    return;
  }

  // game complete — the reveal breathes, then back to the hang. Every 3rd
  // game earns a ceremony. Roulette rooms roll the next game automatically.
  cell.seqBeats = undefined;
  cell.gamesPlayed += 1;
  for (const mid of cell.members) {
    const uid = cell.meta.get(mid)?.uid;
    if (uid) social.onGameComplete(uid);
  }
  if (cell.gamesPlayed % 3 === 0) {
    later(cell.id, 3500, (c) => sendAwards(c));
    if (cell.mode === 'roulette') {
      later(cell.id, 12000, (c) => { if (!c.inRound) startPickedGame(c); });
    }
  } else {
    later(cell.id, 3500, (c) => broadcastCell(c.id, { t: 'talk' }));
    if (cell.mode === 'roulette') {
      later(cell.id, 8000, (c) => { if (!c.inRound) startPickedGame(c); });
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
  for (const a of list) {
    const uid = cell.meta.get(a.winnerId)?.uid;
    if (!uid) continue;
    social.onAward(uid, a.label === 'MVP');
    if (a.emoji === '😂') social.onLaugh(uid);
  }
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

async function formCell(memberIds: string[], modeOverride?: 'call') {
  const live = memberIds.filter((id) => store.users.get(id)?.ws.readyState === WebSocket.OPEN);
  if (live.length === 0) return;

  const strangers = live.length - 1;
  const rounds = rollSession(strangers);
  assignTargets(rounds, live);

  const cellId = randomUUID();
  const room = `cell_${cellId}`;
  const mode = modeOverride ?? (store.users.get(live[0])?.mode ?? 'hang');
  const now = Date.now();
  const cell: Cell = {
    id: cellId, room, members: [...live], kind: rounds[0].kind as GameKind,
    rounds, roundIdx: -1, answers: new Map(), votes: new Map(),
    golden: Math.random() < 0.04, luckyId: pick(live), timers: [],
    gamesPlayed: 0, inRound: false, mode, seqPos: 0,
    joinedAt: new Map(live.map((id) => [id, now])),
    leftAt: new Map(),
    meta: new Map(live.map((id) => {
      const o = store.users.get(id)!;
      return [id, { uid: o.uid, name: o.name, hue: o.hue }];
    })),
    prompted: new Set(),
    credited: new Set(),
  };
  if (mode === 'call') cell.callVideo = calls.pendingVideo;
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
      game: rounds[0], rounds, golden: cell.golden, luckyId: cell.luckyId, mode,
      // exactly-two stranger rooms may go phone-to-phone; groups/calls never
      p2p: P2P_ENABLED && mode !== 'call' && live.length === 2 });
  }

  // talk-first: the room opens as a hang. In HANG mode games start when the
  // room picks one; in ROULETTE they auto-chain. CALLS get none of it — no
  // auto-games, no chaos cards: it's your private room (games still work if
  // you pick one).
  later(cellId, 1300, (c) => broadcastCell(c.id, { t: 'talk' }));
  if (mode === 'roulette') later(cellId, 6000, (c) => startPickedGame(c));
  if (mode !== 'call') {
    const chaosCount = 1 + Math.floor(Math.random() * 2);
    for (let i = 0; i < chaosCount; i++) {
      const [e, x] = pick(CHAOS_CARDS);
      later(cellId, 15000 + Math.floor(Math.random() * 90000), (c) =>
        broadcastCell(c.id, { t: 'chaos', e, x }));
    }
  }
  console.log(`[cell] ${cellId} · ${live.length} people · ${mode}${cell.golden ? ' · GOLDEN' : ''}`);
}

function leaveCell(u: User) {
  if (!u.cellId) return;
  const cell = store.cells.get(u.cellId);
  u.cellId = null;
  if (!cell) return;
  // a resumed seat means this connection is no longer a member — its late
  // close event must not tear down the room it was reconnected into
  if (!cell.members.includes(u.id)) return;
  cell.leftAt.set(u.id, Date.now());
  // social layer: encounters + rate prompt + room credit for the leaver
  social.onCellLeave(cell, u);
  cell.members = cell.members.filter((x) => x !== u.id);
  broadcastCell(cell.id, { t: 'peerLeft', id: u.id });
  if (cell.members.length < 2) {
    const remaining = [...cell.members];
    clearCellTimers(cell); // never let a dead cell's timers fire into new rooms
    store.cells.delete(cell.id);
    // a finished CALL leaves a receipt in the thread: "Call · 4 min"
    if (cell.mode === 'call') {
      const uids = [...cell.meta.values()].map((x) => x.uid);
      if (uids.length >= 2) {
        const joins = [...cell.joinedAt.values()];
        const secs = Math.max(0, Math.floor((Date.now() - Math.max(...joins)) / 1000));
        void dbs.insertMessage(uids[0], uids[1], uids[0], 'call', '', null,
            { secs, video: cell.callVideo === true });
      }
    }
    for (const id of remaining) {
      const other = store.users.get(id);
      if (other) {
        cell.leftAt.set(id, Date.now());
        social.onCellLeave(cell, other);
        send(other, { t: 'ended' });
        // a call ending is not a reason to throw someone at strangers
        if (cell.mode !== 'call') enqueue(other);
        else other.state = 'idle';
      }
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
    // carry the social snapshots over to the new connection id
    const j = cell.joinedAt.get(oldId);
    if (j != null) { cell.joinedAt.set(user.id, j); cell.joinedAt.delete(oldId); }
    cell.meta.set(user.id, { uid: user.uid, name: user.name, hue: user.hue });
    cell.meta.delete(oldId);
    cell.leftAt.delete(oldId);
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
const lastPushAt = new Map<string, number>(); // recipient uid -> last push ms
const PUSH_COOLDOWN_MS = 6 * 3600_000;

function notifyLive(u: User) {
  // tell everyone who saved me that I just came online
  for (const a of store.savedByOf(u.uid)) {
    const watcher = store.userByUid(a);
    if (watcher) send(watcher, { t: 'sparkLive', uid: u.uid, name: u.name });
  }
  // and push the OFFLINE mutuals (online ones just got the ws event).
  // Rate-limited hard: at most one push per recipient per 6h, mutuals only.
  if (!pushEnabled) return;
  void db.mutualPushTargets(u.uid).then((targets) => {
    const now = Date.now();
    for (const t of targets) {
      if (store.userByUid(t.uid)) continue;
      if (now - (lastPushAt.get(t.uid) ?? 0) < PUSH_COOLDOWN_MS) continue;
      lastPushAt.set(t.uid, now);
      sendPush(t.token, `${u.name} is live on Rivlr`, 'drop in while they’re on 🎥');
    }
  });
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
  // quality-holds expire on a clock, not on the next enqueue — without this
  // pulse two waiting low-score users could sit forever in a quiet queue
  if (store.queue.length >= 2) tryMatch();
  if (ALLOW_SOLO) {
    const now = Date.now();
    for (let i = store.queue.length - 1; i >= 0; i--) {
      const u = store.users.get(store.queue[i]);
      if (u && now - u.queuedAt > SOLO_WAIT_MS) {
        store.queue.splice(i, 1);
        void formCell([u.id]);
      }
    }
  }
}, 1000);

setInterval(() => {
  // rooms + matches are real counts — the client hides anything too small to
  // impress, so low numbers never reach the screen. The payload is identical
  // for everyone: stringify ONCE, not once per connection.
  const payload = JSON.stringify({
    t: 'presence', live: LIVE_BASELINE + store.onlineCount,
    rooms: store.cells.size, matches: matchesToday,
  });
  for (const u of store.users.values()) {
    if (u.ws.readyState === WebSocket.OPEN) {
      try { u.ws.send(payload); } catch { /* ignore */ }
    }
  }
}, 4000);

// heartbeat — drop dead sockets, and sockets that connected but never sent
// a hello (bots, port scanners, wedged clients holding a User slot)
setInterval(() => {
  const now = Date.now();
  for (const u of store.users.values()) {
    if (!u.helloed && now - (u.connectedAt ?? 0) > 15000) {
      try { u.ws.terminate(); } catch { /* ignore */ }
      continue;
    }
    if (now - u.lastPong > 35000) { try { u.ws.terminate(); } catch { /* ignore */ } continue; }
    try { u.ws.ping(); } catch { /* ignore */ }
  }
}, 15000);

// bound the long-lived maps: hints/neverAgain rehydrate on hello so entries
// for offline users are pure dead weight; the push cooldown maps prune by
// AGE (their entire job is rate-limiting pushes to people who are offline).
setInterval(() => {
  const online = (uid: string) => store.byUid.has(uid);
  matching.pruneHints(online);
  social.pruneNeverAgain(online);
  chat.pruneMsgPush();
  const cutoff = Date.now() - PUSH_COOLDOWN_MS;
  for (const [uid, t] of lastPushAt) if (t < cutoff) lastPushAt.delete(uid);
}, 10 * 60_000);

// ---- http + ws -------------------------------------------------------------
const app = express();
app.get('/', (_req, res) => res.json({ ok: true, service: 'rivlr', live: LIVE_BASELINE + store.onlineCount }));
app.get('/health', (_req, res) => res.json({ ok: true }));
// public legal pages — these URLs go in App Store Connect / Play Console
app.get('/privacy', (_req, res) => res.type('html').send(legal.page('Privacy Policy', legal.privacy)));
app.get('/terms', (_req, res) => res.type('html').send(legal.page('Terms of Service', legal.terms)));
app.get('/rules', (_req, res) => res.type('html').send(legal.page('House Rules', legal.rules)));
app.get('/delete-account', (_req, res) => res.type('html').send(legal.page('Delete your account', legal.deleteAccount)));
mountMedia(app);
startRetentionSweep();
app.get('/stats', (_req, res) => res.json({
  online: store.onlineCount, queued: store.queue.length, cells: store.cells.size,
  parties: parties.size, livekit: !!LIVEKIT_URL, db: db.dbEnabled, push: pushEnabled,
  uptimeSec: Math.floor(process.uptime()),
  memMb: Math.round(process.memoryUsage().rss / 1048576),
}));

const server = createServer(app);
// 64KB is generous for every legit message (media rides HTTP) — anything
// bigger is hostile or broken and the socket closes itself.
const wss = new WebSocketServer({ server, path: '/ws', maxPayload: 64 * 1024 });

// Per-IP connection cap. Railway's edge proxy APPENDS the true peer address
// to x-forwarded-for, so the RIGHTMOST entry is the trustworthy one — the
// leftmost is client-supplied and would let an attacker dodge the cap.
const ipConns = new Map<string, number>();
const MAX_CONNS_PER_IP = Number(process.env.MAX_CONNS_PER_IP || 8);
function clientIp(req: import('http').IncomingMessage): string {
  const xff = String(req.headers['x-forwarded-for'] ?? '');
  if (xff) return xff.split(',').pop()!.trim();
  return req.socket.remoteAddress ?? 'unknown';
}

wss.on('connection', (ws, req) => {
  const ip = clientIp(req);
  const ipCount = ipConns.get(ip) ?? 0;
  if (ipCount >= MAX_CONNS_PER_IP) {
    // reject BEFORE allocating anything — 1013 = try again later
    try { ws.close(1013, 'too many connections'); } catch { /* ignore */ }
    return;
  }
  ipConns.set(ip, ipCount + 1);
  ws.once('close', () => {
    const c = (ipConns.get(ip) ?? 1) - 1;
    if (c <= 0) ipConns.delete(ip); else ipConns.set(ip, c);
  });

  const id = randomUUID();
  const user: User = {
    id, ws, uid: id, name: pick(NAMES), hue: pick(HUES),
    meet: 'Everyone', state: 'idle', cellId: null, queuedAt: 0, lastPong: Date.now(),
    connectedAt: Date.now(),
  };
  store.users.set(id, user);
  store.byUid.set(user.uid, id);

  ws.on('pong', () => { user.lastPong = Date.now(); });

  // rate limiting: 40 messages per rolling 5s window. A tripped window costs
  // ONE strike (excess silently dropped); three struck windows closes the
  // connection. Bursts survive, sustained abuse doesn't.
  let msgWindow = Date.now();
  let msgCount = 0;
  let strikes = 0;
  let struckThisWindow = false;

  ws.on('message', (raw) => {
    const now = Date.now();
    if (now - msgWindow > 5000) { msgWindow = now; msgCount = 0; struckThisWindow = false; }
    if (++msgCount > 40) {
      if (!struckThisWindow) {
        struckThisWindow = true;
        if (++strikes >= 3) { try { ws.close(); } catch { /* ignore */ } }
      }
      return;
    }
    let m: any;
    try { m = JSON.parse(raw.toString()); } catch { return; }
    switch (m.t) {
      case 'hello': {
        user.helloed = true; // seen a real client — the no-hello reaper stands down
        void (async () => {
        // Apple id is a RECOVERY KEY: if it already maps to an account, that
        // account's uid wins (reinstalls get their whole graph back); if not,
        // it links to whatever uid this session uses. Zero data migration.
        let appleLink: string | null = null;
        if (typeof m.appleId === 'string' && m.appleId.length) {
          const appleId = (m.appleId as string).slice(0, 64);
          const canonical = db.dbEnabled ? await dbs.uidForApple(appleId) : null;
          if (canonical) m = { ...m, uid: canonical };
          else appleLink = appleId;
        }
        if (typeof m.uid === 'string' && m.uid.length) {
          store.byUid.delete(user.uid);
          user.uid = m.uid.slice(0, 64);
          store.byUid.set(user.uid, id);
        }
        if (typeof m.name === 'string' && m.name.trim()) user.name = m.name.trim().slice(0, 16);
        if (typeof m.gender === 'string') user.gender = m.gender;
        if (m.meet === 'Women' || m.meet === 'Men' || m.meet === 'Everyone') user.meet = m.meet;
        if (typeof m.tz === 'number' && Number.isFinite(m.tz)) user.tz = Math.trunc(m.tz);
        send(user, {
          t: 'welcome', id, uid: user.uid, name: user.name, hue: user.hue,
          live: LIVE_BASELINE + store.onlineCount,
          http: { token: mintAuthToken(user.uid), base: process.env.PUBLIC_URL || '' },
          features: { social: db.dbEnabled, media: db.dbEnabled, gifs: gifsEnabled },
        });
        notifyLive(user);
        void social.hydrate(user);
        void matching.hydrateHints(user);
        void social.sendEvent(user);
        resumeCell(user); // wifi blip? re-seat them in the room they were in
        const vibes = Array.isArray(m.vibes)
          ? (m.vibes as unknown[]).filter((v): v is string => typeof v === 'string').slice(0, 12)
          : [];
        db.upsertUser({ uid: user.uid, name: user.name, hue: user.hue, gender: user.gender, meet: user.meet, vibes });
        if (appleLink && db.dbEnabled) dbs.linkApple(user.uid, appleLink);
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
        })();
        break;
      }
      case 'play':
        if (m.mode === 'roulette' || m.mode === 'hang') user.mode = m.mode;
        leaveParty(id); leaveCell(user); enqueue(user);
        break;
      case 'next': leaveCell(user); enqueue(user); break;
      case 'leave': dequeue(id); leaveCell(user); user.state = 'idle'; break;
      case 'host': {
        // IDEMPOTENT: reopening the screen must NOT rotate the code — a code
        // the host already shared has to stay joinable while they're online.
        const heldCode = partyByUser.get(id);
        const held = heldCode ? parties.get(heldCode) : undefined;
        if (held && held.hostId === id) { send(user, partyState(held)); break; }
        leaveParty(id); dequeue(id); leaveCell(user);
        const p: Party = { code: newPartyCode(), hostId: id, members: [id] };
        parties.set(p.code, p);
        partyByUser.set(id, p.code);
        send(user, partyState(p));
        social.feedToFriends(user,
            { t: 'feedEvent', kind: 'party', uid: user.uid, name: user.name, x: p.code });
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
          // everyone's in — a quick beat to see it, then flip early
          if (cell.answers.size >= cell.members.length && cell.roundTimer) {
            clearTimeout(cell.roundTimer);
            const idx = cell.roundIdx;
            cell.roundTimer = setTimeout(() => {
              const c = store.cells.get(cell.id);
              if (c && c.roundIdx === idx) endRound(c);
            }, 2000);
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
      // ---- social layer (each case a one-line delegate) ----
      case 'rate': void social.rate(user, m); break;
      case 'friendRequest': if (typeof m.target === 'string') void social.friendRequest(user, m.target); break;
      case 'friendAccept': if (typeof m.target === 'string') void social.friendAccept(user, m.target); break;
      case 'friendDecline': if (typeof m.target === 'string') void social.friendDecline(user, m.target); break;
      case 'unfriend': if (typeof m.target === 'string') void social.unfriend(user, m.target); break;
      case 'setTier': void social.setTier(user, m); break;
      case 'pinChat': void social.pinChat(user, m); break;
      case 'friends': void social.snapshot(user); break;
      case 'traitVote': void social.traitVote(user, m); break;
      case 'setProfile': social.setProfile(user, m); break;
      case 'profile': void social.profile(user, m); break;
      case 'setTitle': void social.setTitle(user, m); break;
      case 'titles': void social.titles(user); break;
      case 'callInvite': void calls.invite(user, m); break;
      case 'callAccept': void calls.accept(user, m); break;
      case 'callDecline':
      case 'callCancel': calls.decline(user, m); break;
      case 'dm': void chat.dm(user, m); break;
      case 'dmHistory': void chat.history(user, m); break;
      case 'dmRead': void chat.read(user, m); break;
      case 'typing': chat.typing(user, m); break;
      case 'reactMsg': void chat.react(user, m); break;
      case 'chats': void chat.chats(user); break;
      case 'save': if (typeof m.target === 'string') onSave(user, m.target); break;
      case 'unsave':
        if (typeof m.target === 'string') {
          store.removeSave(user.uid, m.target);
          db.removeSave(user.uid, m.target);
        }
        break;
      case 'report':
        if (typeof m.target === 'string') {
          onReport(m.target, user.uid);
          social.onReported(m.target);
        }
        break;
      case 'unblock':
        if (typeof m.target === 'string') {
          store.unblock(user.uid, m.target);
          db.removeBlock(user.uid, m.target);
        }
        break;
      case 'rtc': {
        // P2P signaling relay: offer/answer/ICE between two members of the
        // SAME cell. The server never inspects the payload.
        const to = typeof m.to === 'string' ? m.to : '';
        const cell = user.cellId ? store.cells.get(user.cellId) : undefined;
        if (!to || !cell || !cell.members.includes(to) || !cell.members.includes(user.id)) break;
        const peer = store.users.get(to);
        if (peer) send(peer, { t: 'rtc', from: user.id, d: m.d });
        break;
      }
      case 'pushToken':
        if (typeof m.token === 'string' && m.token.length) {
          db.savePushToken(user.uid, m.token.slice(0, 512));
        }
        break;
      case 'deleteAccount': {
        // the privacy policy promises immediate server-side deletion — honour it
        console.log(`[delete] account ${user.uid}`);
        db.deleteUser(user.uid);
        dbs.deleteSocial(user.uid);
        store.purgeSocial(user.uid);
        dequeue(id); leaveParty(id); leaveCell(user);
        try { ws.close(); } catch { /* ignore */ }
        break;
      }
      case 'block':
        if (typeof m.target === 'string') {
          store.block(user.uid, m.target);
          db.addBlock(user.uid, m.target);
          onReport(m.target, user.uid);
          social.onBlocked(user, m.target);
        }
        leaveCell(user); enqueue(user);
        break;
    }
  });

  ws.on('close', () => {
    dequeue(id);
    leaveParty(id);
    leaveCell(user);
    if (store.byUid.get(user.uid) === id) {
      social.broadcastPresence(user, false);
      store.byUid.delete(user.uid);
    }
    store.users.delete(id);
  });
  ws.on('error', () => { /* close handler cleans up */ });
});

server.listen(PORT, () => {
  console.log(`Rivlr server on :${PORT}  (livekit ${LIVEKIT_URL ? 'ON' : 'OFF'}, solo ${ALLOW_SOLO}, db ${db.dbEnabled ? 'ON' : 'OFF'})`);
});

social.init(send);
chat.init(send);
calls.init(send, formCell);
social.startRepDecay();

// crash guard: one bad code path must never take down every live room.
process.on('uncaughtException', (e) => console.error('[crash-guard]', e));
process.on('unhandledRejection', (e) => console.error('[crash-guard:rejection]', e));

// graceful shutdown: Railway redeploys send SIGTERM — close sockets so every
// client's auto-reconnect fires immediately instead of waiting out a timeout.
process.on('SIGTERM', () => {
  console.log('[shutdown] SIGTERM — closing sockets');
  for (const u of store.users.values()) { try { u.ws.close(); } catch { /* ignore */ } }
  server.close(() => process.exit(0));
  setTimeout(() => process.exit(0), 2000).unref();
});

void db.initDb().then(async () => {
  await dbs.initSocial();
  // matches-today survives restarts — pick up where the day left off
  const n = await db.loadMatches(matchesDay);
  if (n > matchesToday) matchesToday = n;
});
