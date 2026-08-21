import { createPublicKey, createVerify } from 'crypto';

/// Verify a Sign in with Apple identity token.
///
/// Until now the client just SAID "my apple id is X" over the socket and we
/// believed it — meaning anyone who learned someone's Apple user id could
/// claim their account, friends, and messages. The identity token is a JWT
/// signed by Apple; verifying it against Apple's published keys is what makes
/// "signed in" mean anything.
///
/// Zero dependencies: Node's crypto can verify RS256 directly once the JWK is
/// converted to a public key. Fail-soft — an unverifiable token returns null
/// and the caller treats the session as a guest.

const JWKS_URL = 'https://appleid.apple.com/auth/keys';
const ISSUER = 'https://appleid.apple.com';
const AUDIENCE = process.env.APPLE_BUNDLE_ID || 'com.rivler.app';

interface Jwk { kty: string; kid: string; n: string; e: string; alg?: string }

let keyCache: { at: number; keys: Jwk[] } | null = null;
const KEY_TTL = 6 * 3600_000;

async function appleKeys(): Promise<Jwk[]> {
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

/// Returns the verified Apple user id (the token's `sub`), or null.
export async function verifyAppleToken(token: string): Promise<string | null> {
  try {
    const parts = token.split('.');
    if (parts.length !== 3) return null;
    const header = JSON.parse(b64urlToBuf(parts[0]).toString()) as { kid?: string; alg?: string };
    const payload = JSON.parse(b64urlToBuf(parts[1]).toString()) as {
      iss?: string; aud?: string; exp?: number; sub?: string;
    };
    if (header.alg !== 'RS256' || !header.kid) return null;
    if (payload.iss !== ISSUER) return null;
    if (payload.aud !== AUDIENCE) return null;
    if (!payload.exp || Date.now() / 1000 > payload.exp) return null;
    if (!payload.sub) return null;

    const jwk = (await appleKeys()).find((k) => k.kid === header.kid);
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
