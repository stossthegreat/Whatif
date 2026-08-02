import type { User } from './store.js';
import { run, dbEnabled } from './db.js';

/// The matching brain. Still FEELS random — but under the hood the queue
/// prefers shared language, shared interests, closeness in age, country mix,
/// hidden reputation (like-rep drifts together), and avoids rematching pairs
/// who met recently. Hard rule: waiting people are never starved — after 5s
/// the seed takes the best available regardless of score.

interface Hints {
  interests: Set<string>;
  languages: Set<string>;
  country: string | null;
  age: number | null;
  rep: number;
  recent: Map<string, number>; // uid -> last met ms
}

const hints = new Map<string, Hints>();

export async function hydrateHints(user: User): Promise<void> {
  if (!dbEnabled) return;
  const [u, st, enc] = await Promise.all([
    run('SELECT interests, languages, country, age FROM users WHERE uid=$1', [user.uid]),
    run('SELECT rep FROM user_stats WHERE uid=$1', [user.uid]),
    run(
      `SELECT a, b, EXTRACT(EPOCH FROM created_at)*1000 AS ms
       FROM encounters WHERE a=$1 OR b=$1 ORDER BY created_at DESC LIMIT 50`,
      [user.uid]),
  ]);
  const row = u?.rows?.[0];
  const recent = new Map<string, number>();
  for (const e of enc?.rows ?? []) {
    const other = e.a === user.uid ? (e.b as string) : (e.a as string);
    if (!recent.has(other)) recent.set(other, Number(e.ms));
  }
  hints.set(user.uid, {
    interests: new Set(((row?.interests as string[] | null) ?? []).map((s) => s.toLowerCase())),
    languages: new Set(((row?.languages as string[] | null) ?? []).map((s) => s.toLowerCase())),
    country: (row?.country as string | null) ?? null,
    age: row?.age == null ? null : Number(row.age),
    rep: Number(st?.rows?.[0]?.rep ?? 0),
    recent,
  });
}

/// Cells forming right now also count as "met" — no DB round-trip needed.
export function noteMetNow(aUid: string, bUid: string): void {
  hints.get(aUid)?.recent.set(bUid, Date.now());
  hints.get(bUid)?.recent.set(aUid, Date.now());
}

export function metWithin(aUid: string, bUid: string, ms: number): boolean {
  const t = hints.get(aUid)?.recent.get(bUid) ?? hints.get(bUid)?.recent.get(aUid);
  return t != null && Date.now() - t < ms;
}

const DAY = 24 * 3600_000;

export function score(a: User, b: User): number {
  const ha = hints.get(a.uid);
  const hb = hints.get(b.uid);
  if (!ha || !hb) return 0;
  let s = 0;
  for (const l of ha.languages) if (hb.languages.has(l)) { s += 4; break; }
  let shared = 0;
  for (const i of ha.interests) if (hb.interests.has(i)) shared++;
  s += Math.min(3, shared) * 3 / 3 * 3; // up to +9 for 3+ shared interests
  if (ha.country && ha.country === hb.country) s += 2;
  if (ha.age != null && hb.age != null) s += Math.max(0, 3 - Math.abs(ha.age - hb.age) / 3);
  // hidden reputation: similar rep pairs drift together (soft quarantine)
  s += Math.max(-3, Math.min(3, (ha.rep + hb.rep) / 20));
  s -= Math.abs(ha.rep - hb.rep) / 25;
  if (metWithin(a.uid, b.uid, 7 * DAY)) s -= 5;
  return s;
}

/// Cannot be paired at all right now (beyond compatible()): met in the last 24h.
export function hardBlocked(a: User, b: User): boolean {
  return metWithin(a.uid, b.uid, DAY);
}
