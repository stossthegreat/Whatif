import { createHmac, randomBytes, timingSafeEqual } from 'crypto';

/// Stateless HMAC auth tokens for the HTTP surface (media uploads etc.).
/// Minted into every `welcome`; verified by express middleware.
///
/// AUTH_SECRET MUST be set in production. A random per-boot secret is NOT
/// harmless: every already-rendered image URL 401s the moment the process
/// restarts (and multiple replicas can never agree) — the exact
/// "text works but photos don't" symptom. The client does re-mint on
/// welcome, but everything in flight or cached dies.
const SECRET = process.env.AUTH_SECRET || randomBytes(32).toString('hex');
if (!process.env.AUTH_SECRET) {
  console.warn(
    '⚠️  AUTH_SECRET is not set — media tokens die on every restart/redeploy ' +
    '(photos & voice will intermittently 401 while text keeps working). ' +
    'Set a long random AUTH_SECRET in the environment.');
}

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
