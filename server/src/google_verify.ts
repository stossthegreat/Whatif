import { createPublicKey, createVerify } from 'crypto';

/// Verify a Google Sign-In ID token — the exact mirror of apple_verify.ts.
///
/// Same threat model: the bare Google user id is only a claim; the ID token
/// is a JWT signed by Google, and verifying it against Google's published
/// keys is what makes "signed in with Google" mean anything. Zero deps —
/// Node's crypto verifies RS256 once the JWK becomes a public key.
///
/// Fail-soft: unverifiable token (or no GOOGLE_CLIENT_ID configured) returns
/// null and the caller treats the session as a guest.

const JWKS_URL = 'https://www.googleapis.com/oauth2/v3/certs';
// Google tokens appear with both issuer spellings, per their own docs.
const ISSUERS = new Set(['accounts.google.com', 'https://accounts.google.com']);
// The WEB application OAuth client id — the same one the app passes as
// serverClientId, which is what Google mints the idToken's audience for.
const AUDIENCE = process.env.GOOGLE_CLIENT_ID || '';

let warned = false;

interface Jwk { kty: string; kid: string; n: string; e: string; alg?: string }

let keyCache: { at: number; keys: Jwk[] } | null = null;
const KEY_TTL = 6 * 3600_000;

async function googleKeys(): Promise<Jwk[]> {
  if (keyCache && Date.now() - keyCache.at < KEY_TTL) return keyCache.keys;
  try {
    const r = await fetch(JWKS_URL);
    const j = (await r.json()) as { keys?: Jwk[] };
    const keys = j.keys ?? [];
    if (keys.length) keyCache = { at: Date.now(), keys };
    return keys;
  } catch {
    return keyCache?.keys ?? []; // network blip: reuse whatever we had
  }
}

function b64urlToBuf(s: string): Buffer {
  return Buffer.from(s.replace(/-/g, '+').replace(/_/g, '/'), 'base64');
}

/// Returns the verified Google user id (the token's `sub`), or null.
export async function verifyGoogleToken(token: string): Promise<string | null> {
  if (!AUDIENCE) {
    if (!warned) {
      warned = true;
      console.warn('ℹ️  GOOGLE_CLIENT_ID not set — Google sign-in tokens are ignored (Apple-only).');
    }
    return null;
  }
  try {
    const parts = token.split('.');
    if (parts.length !== 3) return null;
    const header = JSON.parse(b64urlToBuf(parts[0]).toString()) as { kid?: string; alg?: string };
    const payload = JSON.parse(b64urlToBuf(parts[1]).toString()) as {
      iss?: string; aud?: string; exp?: number; sub?: string;
    };
    if (header.alg !== 'RS256' || !header.kid) return null;
    if (!payload.iss || !ISSUERS.has(payload.iss)) return null;
    if (payload.aud !== AUDIENCE) return null;
    if (!payload.exp || Date.now() / 1000 > payload.exp) return null;
    if (!payload.sub) return null;

    const jwk = (await googleKeys()).find((k) => k.kid === header.kid);
    if (!jwk) return null;

    const pub = createPublicKey({ key: { kty: 'RSA', n: jwk.n, e: jwk.e } as never, format: 'jwk' });
    const v = createVerify('RSA-SHA256');
    v.update(`${parts[0]}.${parts[1]}`);
    v.end();
    if (!v.verify(pub, b64urlToBuf(parts[2]))) return null;

    return payload.sub;
  } catch {
    return null;
  }
}
