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
  cellId: string | null;
  queuedAt: number;
  lastPong: number;
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
  isBlocked(a: string, b: string): boolean {
    return (this.blocks.get(a)?.has(b) ?? false) || (this.blocks.get(b)?.has(a) ?? false);
  }

  report(uid: string): number {
    const n = (this.reports.get(uid) ?? 0) + 1;
    this.reports.set(uid, n);
    return n;
  }
}

export const store = new Store();
