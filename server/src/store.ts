import type { WebSocket } from 'ws';
import type { GameKind } from './games.js';

export type Meet = 'Everyone' | 'Women' | 'Men';

export interface User {
  id: string;        // per-connection id (also the LiveKit identity)
  uid: string;       // stable identity supplied by the client (survives reconnects)
  ws: WebSocket;
  name: string;
  hue: number;
  gender?: string;   // 'Woman' | 'Man' | ...
  meet: Meet;        // who they want to meet
  state: 'idle' | 'queued' | 'incell';
  mode?: 'roulette' | 'hang'; // how they want their rooms to run
  cellId: string | null;
  queuedAt: number;
  lastPong: number;
  connectedAt?: number;  // handshake time — the no-hello reaper's clock
  helloed?: boolean;     // real client spoke — reaper stands down
  tz?: number;                 // client tz offset minutes (Night Owl badge etc.)
  friendUids?: Set<string>;    // hydrated on hello — for presence broadcasts
}

/// One round as sent on the wire (and replayed on revive).
export interface RoundWire {
  kind: GameKind;
  name: string;
  hint: string;
  prompt: string[];
  targetId: string | null; // member conn-id "on the spot" (spin / {target}); null = nobody
  lieIdx?: number;         // twoTruths: which option is the lie
}

export interface Cell {
  id: string;
  room: string;
  members: string[]; // connection ids
  kind: GameKind;
  // ---- social layer: snapshots that survive members leaving --------------
  joinedAt: Map<string, number>;                    // conn-id -> ms joined
  leftAt: Map<string, number>;                      // conn-id -> ms left
  meta: Map<string, { uid: string; name: string; hue: number }>;
  prompted: Set<string>;                            // conn-ids already sent ratePrompt
  credited: Set<string>;                            // conn-ids already given room credit
  // ---- server-authoritative session state ----
  rounds: RoundWire[];
  roundIdx: number;
  answers: Map<string, unknown>; // current round only, keyed by conn-id
  votes: Map<string, string>;    // award votes, voter conn-id -> emoji
  lastWinnerId?: string;
  golden: boolean;
  luckyId: string;
  reviveRounds?: RoundWire[];    // shared reroll once any member revives
  timers: NodeJS.Timeout[];      // everything scheduled for this cell
  roundTimer?: NodeJS.Timeout;   // the current round's deadline (cancellable alone)
  gamesPlayed: number;           // ceremony fires every 3rd game
  inRound: boolean;              // a game is currently running
  mode: 'roulette' | 'hang' | 'call'; // call = private 2-person, no auto-games
  callVideo?: boolean;           // call cells: started as video?
  seqBeats?: RoundWire[];        // the current game's remaining beat chain
  seqPos: number;                // index into seqBeats
}

/// In-memory store. Deliberately behind one object so it can be swapped for
/// Redis/Postgres later without touching the matchmaker or protocol.
class Store {
  users = new Map<string, User>();       // by connection id
  byUid = new Map<string, string>();     // uid -> current connection id
  queue: string[] = [];                   // connection ids waiting to match
  cells = new Map<string, Cell>();

  private saves = new Map<string, Set<string>>();   // uid -> uids they saved
  private savedBy = new Map<string, Set<string>>(); // uid -> uids who saved them
  private blocks = new Map<string, Set<string>>();  // uid -> uids they blocked
  reports = new Map<string, number>();              // uid -> report count

  get onlineCount() {
    return this.users.size;
  }

  userByUid(uid: string): User | undefined {
    const id = this.byUid.get(uid);
    return id ? this.users.get(id) : undefined;
  }

  private ensure(map: Map<string, Set<string>>, k: string): Set<string> {
    let s = map.get(k);
    if (!s) { s = new Set(); map.set(k, s); }
    return s;
  }

  addSave(a: string, b: string) {
    this.ensure(this.saves, a).add(b);
    this.ensure(this.savedBy, b).add(a);
  }
  removeSave(a: string, b: string) {
    this.saves.get(a)?.delete(b);
    this.savedBy.get(b)?.delete(a);
  }
  hasSaved(a: string, b: string): boolean {
    return this.saves.get(a)?.has(b) ?? false;
  }
  savedByOf(uid: string): Set<string> {
    return this.savedBy.get(uid) ?? new Set();
  }

  block(a: string, b: string) {
    this.ensure(this.blocks, a).add(b);
  }
  unblock(a: string, b: string) {
    this.blocks.get(a)?.delete(b);
  }
  isBlocked(a: string, b: string): boolean {
    return (this.blocks.get(a)?.has(b) ?? false) || (this.blocks.get(b)?.has(a) ?? false);
  }

  report(uid: string): number {
    const n = (this.reports.get(uid) ?? 0) + 1;
    this.reports.set(uid, n);
    return n;
  }

  /// Account deletion: drop every in-memory trace of a uid's social graph.
  purgeSocial(uid: string) {
    for (const t of this.saves.get(uid) ?? []) this.savedBy.get(t)?.delete(uid);
    for (const s of this.savedBy.get(uid) ?? []) this.saves.get(s)?.delete(uid);
    this.saves.delete(uid);
    this.savedBy.delete(uid);
    this.blocks.delete(uid);
  }

  /// Pour one user's persisted social graph (from Postgres) into the
  /// in-memory maps on hello. Additive — live state always wins.
  hydrateSocial(uid: string, d: {
    saves: string[]; savedBy: string[]; blocks: string[]; blockedBy: string[]; reports: number;
  }) {
    for (const t of d.saves) { this.ensure(this.saves, uid).add(t); this.ensure(this.savedBy, t).add(uid); }
    for (const s of d.savedBy) { this.ensure(this.saves, s).add(uid); this.ensure(this.savedBy, uid).add(s); }
    for (const t of d.blocks) this.ensure(this.blocks, uid).add(t);
    for (const b of d.blockedBy) this.ensure(this.blocks, b).add(uid);
    if (d.reports > (this.reports.get(uid) ?? 0)) this.reports.set(uid, d.reports);
  }
}

export const store = new Store();
