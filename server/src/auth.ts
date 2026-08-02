import { createHmac, randomBytes, timingSafeEqual } from 'crypto';

/// Stateless HMAC auth tokens for the HTTP surface (media uploads etc.).
/// Minted into every `welcome`; verified by express middleware. If
/// AUTH_SECRET isn't set we use a random per-boot secret — tokens then die on
/// redeploy, which is harmless because the client refreshes on every welcome.
const SECRET = process.env.AUTH_SECRET || randomBytes(32).toString('hex');

export function mintAuthToken(uid: string, ttlMs = 24 * 3600_000): string {
  const payload = Buffer.from(`${uid}|${Date.now() + ttlMs}`).toString('base64url');
  const sig = createHmac('sha256', SECRET).update(payload).digest('base64url');
  return `${payload}.${sig}`;
}

export function verifyAuthToken(token: string): string | null {
  const dot = token.lastIndexOf('.');
  if (dot < 1) return null;
  const payload = token.slice(0, dot);
  const sig = token.slice(dot + 1);
  const want = createHmac('sha256', SECRET).update(payload).digest('base64url');
  const a = Buffer.from(sig);
  const b = Buffer.from(want);
  if (a.length !== b.length || !timingSafeEqual(a, b)) return null;
  const text = Buffer.from(payload, 'base64url').toString();
  const cut = text.lastIndexOf('|');
  if (cut < 1) return null;
  const uid = text.slice(0, cut);
  const exp = Number(text.slice(cut + 1));
  if (!uid || !Number.isFinite(exp) || Date.now() > exp) return null;
  return uid;
}
