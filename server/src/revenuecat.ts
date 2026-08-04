/// RevenueCat — the subscription authority.
///
/// We deliberately do NOT interpret webhook event types to decide who has
/// access. Event semantics are a minefield (a CANCELLATION means "auto-renew
/// is off", NOT "access ends now" — treating it as revocation would cut off
/// people who already paid for the rest of the period). Instead: a webhook
/// is only a signal that something changed for a user, and we then ASK
/// RevenueCat what that user's entitlement actually is. One source of truth,
/// no event table to get subtly wrong.
///
/// Fail-soft like every other integration here: no key configured means
/// nobody is Plus, and the app runs exactly as it did before payments.

const KEY = process.env.RC_SECRET_KEY || '';
const ENTITLEMENT = process.env.RC_ENTITLEMENT || 'plus';
export const rcEnabled = !!KEY;

if (!rcEnabled) {
  console.warn('ℹ️  RC_SECRET_KEY not set — Rivlr+ is off; every account is free.');
}

/// `ok: false` means we couldn't reach RevenueCat — which is NOT the same as
/// "not subscribed", and must never revoke a paying customer.
export type Lookup =
  | { ok: true; until: Date | null }
  | { ok: false };

interface RcEntitlement { expires_date?: string | null }
interface RcResponse { subscriber?: { entitlements?: Record<string, RcEntitlement> } }

/// The paid-until instant for a user. A lifetime/non-expiring entitlement
/// reports `expires_date: null` — that means "active forever", not
/// "expired", so it maps to a far-future date.
export async function fetchEntitlement(uid: string): Promise<Lookup> {
  // no REST key = we cannot verify anything. That's "unknown", not "free":
  // a webhook-only deployment still has the event's own expiry to fall back
  // on, and saying "not subscribed" here would throw that away.
  if (!rcEnabled || !uid) return { ok: false };
  try {
    const res = await fetch(
      `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(uid)}`,
      { headers: { Authorization: `Bearer ${KEY}`, Accept: 'application/json' } });
    // 404 = RevenueCat has never seen this user: not a subscriber, not an error
    if (res.status === 404) return { ok: true, until: null };
    if (!res.ok) {
      console.error('[rc] lookup failed', res.status);
      return { ok: false };
    }
    const j = await res.json() as RcResponse;
    const ent = j.subscriber?.entitlements?.[ENTITLEMENT];
    if (!ent) return { ok: true, until: null };
    if (ent.expires_date == null) {
      return { ok: true, until: new Date(Date.now() + 100 * 365 * 24 * 3600_000) };
    }
    const d = new Date(ent.expires_date);
    if (Number.isNaN(d.getTime())) return { ok: true, until: null };
    return { ok: true, until: d > new Date() ? d : null };
  } catch (e) {
    console.error('[rc]', (e as Error).message);
    return { ok: false };
  }
}
