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

const MAX_ROWS = 40; // online, ranked by the matching brain
const TOTAL_ROWS = 60; // topped up with recently-seen offline people

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
      // the full avatar rides along so a dead thumbnail can fall back to it
      // client-side rather than showing a faceless card
      photoId: card.photoId,
      title: card.title,
      country: card.country,
      age: card.age,
      shared,
      online: true,
      // in a room or queued — the card greys out so taps don't bounce as busy
      busy: u.state !== 'idle',
    }];
  });

  // ---- beyond the online roster: everyone discoverable, freshest first.
  // The wall must never be empty just because the clock says 4am — away
  // people can't be rung, but they CAN be added as friends.
  if (people.length < TOTAL_ROWS) {
    const exclude = [viewer.uid, ...people.map((p) => p.uid)];
    const roster = await dbs.discoverRoster(exclude, (TOTAL_ROWS - people.length) * 2);
    for (const p of roster) {
      if (people.length >= TOTAL_ROWS) break;
      if (store.isBlocked(viewer.uid, p.uid)) continue;
      if (social.isNeverPair(viewer.uid, p.uid)) continue;
      if (matching.quarantined(p.uid)) continue;
      if (store.userByUid(p.uid)) continue; // actually online — already ranked above
      if (!meetOk(viewer.meet, p.gender ?? undefined)) continue;
      if (!meetOk((p.meet ?? 'Everyone') as Meet, viewer.gender)) continue;
      const shared = p.interests.filter((i) => mine.has(i.toLowerCase())).slice(0, 2);
      people.push({
        uid: p.uid,
        name: p.name,
        hue: p.hue,
        thumbId: p.thumbId,
        // discoverRoster already folds the full avatar into thumbId when no
        // derivative exists, so it IS the best fallback available here
        photoId: p.thumbId,
        title: p.title,
        country: p.country,
        age: p.age,
        shared,
        online: false,
        busy: false,
      });
    }
  }

  send(viewer, { t: 'explore', people });
}
