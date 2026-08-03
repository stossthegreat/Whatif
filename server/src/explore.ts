import { store, type User, type Meet } from './store.js';
import * as dbs from './db_social.js';
import * as social from './social.js';
import * as matching from './matching.js';
import { dbEnabled } from './db.js';

/// Explore — the browsable grid of who's on right now.
///
/// The roster is already in memory (`store.users`), so building this list
/// costs no database work at all: every exclusion below is an in-memory set
/// lookup. The ONE query is a bulk card fetch for the people who survive
/// filtering — never `profileCard`, which is nine round-trips per person and
/// exists for the tap-through detail sheet only.
///
/// Everything here is opt-out-able: `users.discoverable` removes you from the
/// grid entirely, and `cardsFor` enforces it at the SQL level as a backstop.

type Send = (u: User | undefined, obj: unknown) => void;
let send: Send = () => {};
let meetOk: (meet: Meet, gender?: string) => boolean = () => true;

export function init(s: Send, meetFn: (meet: Meet, gender?: string) => boolean): void {
  send = s;
  meetOk = meetFn;
}

const MAX_ROWS = 40;

/// Everyone [viewer] is allowed to see, best matches first.
export async function list(viewer: User): Promise<void> {
  if (!dbEnabled) return send(viewer, { t: 'err', code: 'noDb' });

  const candidates: User[] = [];
  for (const u of store.users.values()) {
    if (u.uid === viewer.uid) continue;
    if (!u.helloed) continue;                          // socket that never introduced itself
    if (store.isBlocked(viewer.uid, u.uid)) continue;  // symmetric — either direction
    if (social.isNeverPair(viewer.uid, u.uid)) continue;
    // NOTE: quarantined() directly, NOT quarantineBlocks() — that one keys off
    // queuedAt and silently no-ops for idle users, which is everyone browsing.
    if (matching.quarantined(u.uid)) continue;
    if (!meetOk(viewer.meet, u.gender)) continue;
    if (!meetOk(u.meet, viewer.gender)) continue;
    candidates.push(u);
  }

  // best matches first — same scorer the queue uses, so Explore and the
  // random pool agree about who suits you
  candidates.sort((a, b) => matching.score(viewer, b) - matching.score(viewer, a));
  const top = candidates.slice(0, MAX_ROWS);

  const cards = await dbs.cardsFor(top.map((u) => u.uid));
  const mine = new Set(matching.interestsOf(viewer.uid));

  const people = top.flatMap((u) => {
    const card = cards.get(u.uid); // absent => not discoverable, drop the row
    if (!card) return [];
    const shared = card.interests.filter((i) => mine.has(i.toLowerCase())).slice(0, 2);
    return [{
      uid: u.uid,
      name: card.name || u.name,
      hue: card.hue ?? u.hue,
      // thumb first: a grid must never pull full-size avatars
      thumbId: card.thumbId ?? card.photoId,
      title: card.title,
      country: card.country,
      shared,
      // in a room or queued — the card greys out so taps don't bounce as busy
      busy: u.state !== 'idle',
    }];
  });

  send(viewer, { t: 'explore', people });
}
