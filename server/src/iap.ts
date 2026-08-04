import type { Express, Request, Response } from 'express';
import express from 'express';
import { timingSafeEqual } from 'crypto';
import { dbEnabled } from './db.js';
import * as dbs from './db_social.js';
import { verifyAuthToken } from './auth.js';
import { fetchEntitlement, rcEnabled } from './revenuecat.js';

/// Rivlr+ purchase surface. Two routes:
///   POST /api/rc/webhook — RevenueCat tells us something changed
///   POST /api/iap/sync   — the app asks us to re-check right now
/// Both end in the same place: ask RevenueCat for the truth, write
/// users.plus_until, tell the user if they're online. The client NEVER
/// asserts its own plan — it only ever asks us to look again.

const WEBHOOK_AUTH = process.env.RC_WEBHOOK_AUTH || '';

/// Entitlement landed — injected by index.ts, which owns both the live
/// user objects and the sockets. It must update the in-memory user too:
/// without that, someone who just paid stays un-entitled until they
/// reconnect, which reads as "I paid and nothing happened".
type Applied = (uid: string, until: Date | null) => void;
let applied: Applied = () => {};

function uidOf(req: Request): string | null {
  const h = req.headers.authorization;
  const raw = h?.startsWith('Bearer ') ? h.slice(7) : (req.query.tk as string | undefined);
  return raw ? verifyAuthToken(raw) : null;
}

function authOk(header: string | undefined): boolean {
  if (!WEBHOOK_AUTH) return false; // unset = webhook disabled, never open
  const got = Buffer.from(header ?? '');
  const want = Buffer.from(WEBHOOK_AUTH);
  return got.length === want.length && timingSafeEqual(got, want);
}

/// Apply RevenueCat's current truth for a user. Returns the paid-until
/// instant. A failed lookup leaves whatever we already had — a RevenueCat
/// outage must never revoke someone who paid.
async function applyEntitlement(uid: string, fallback: Date | null): Promise<Date | null> {
  const look = await fetchEntitlement(uid);
  if (!look.ok) {
    // RevenueCat unreachable: trust the event's own expiry if it had one,
    // otherwise change nothing at all rather than risk revoking a payer
    if (fallback == null) return null;
    dbs.setPlusUntil(uid, fallback);
    applied(uid, fallback);
    return fallback;
  }
  dbs.setPlusUntil(uid, look.until);
  applied(uid, look.until);
  return look.until;
}

export function mountIap(app: Express, onApplied: Applied): void {
  applied = onApplied;

  app.post('/api/rc/webhook', express.json({ limit: '256kb' }),
      async (req: Request, res: Response) => {
    if (!authOk(req.headers.authorization)) return res.status(401).json({ err: 'auth' });
    if (!dbEnabled) return res.status(503).json({ err: 'noDb' });

    const ev = (req.body as { event?: Record<string, unknown> } | undefined)?.event;
    if (!ev || typeof ev !== 'object') return res.status(400).json({ err: 'shape' });

    const eventId = String(ev.id ?? '');
    const uid = String(ev.app_user_id ?? '');
    // anonymous ids belong to a device that never identified itself — there
    // is no account to grant anything to
    if (!eventId || !uid || uid.startsWith('$RCAnonymousID:')) {
      return res.json({ ok: true, skipped: true });
    }

    const expMs = Number(ev.expiration_at_ms ?? 0);
    const fallback = Number.isFinite(expMs) && expMs > 0 ? new Date(expMs) : null;

    // idempotency: RevenueCat retries, and applying an event twice is a bug
    const fresh = await dbs.recordPurchase({
      eventId,
      uid,
      productId: ev.product_id == null ? null : String(ev.product_id),
      kind: ev.type == null ? null : String(ev.type),
      expiresAt: fallback,
      raw: ev,
    });
    if (!fresh) return res.json({ ok: true, duplicate: true });

    await applyEntitlement(uid, fallback);
    res.json({ ok: true });
  });

  // The app calls this straight after a purchase or a restore, so access is
  // never waiting on a webhook to arrive.
  app.post('/api/iap/sync', async (req: Request, res: Response) => {
    const uid = uidOf(req);
    if (!uid) return res.status(401).json({ err: 'auth' });
    if (!dbEnabled) return res.status(503).json({ err: 'noDb' });
    if (!rcEnabled) return res.json({ plus: false, until: null });
    const until = await applyEntitlement(uid, null);
    res.json({ plus: !!until && until > new Date(), until: until?.toISOString() ?? null });
  });
}
