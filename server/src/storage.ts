/// Supabase Storage — where media bytes actually belong.
///
/// Photos and voice notes used to live in a Postgres BYTEA column. That is
/// the single worst scaling decision a media app can make:
///   • an 8GB database fills after ~8,000 photos and then EVERYTHING stops
///   • every avatar in Explore became a database read, so the DB was both
///     the bottleneck and the bill
///   • backups grew to the size of every photo ever uploaded
///   • bytes streamed out through the app server, paying egress twice
///
/// Object storage fixes all four: bytes sit in a bucket, are served straight
/// from Supabase's CDN (which handles Range requests natively, so voice notes
/// stream properly), and the database goes back to holding rows.
///
/// DUAL-READ BY DESIGN. Nothing is force-migrated. A media row now has EITHER
/// a storage_key (new) or bytes (legacy), and the read path handles both, so
/// every photo uploaded before this shipped keeps working untouched and no
/// migration window can lose anyone's face.
///
/// Unconfigured (no SUPABASE_URL / SUPABASE_SERVICE_KEY) = every function
/// here reports "not available" and media.ts silently keeps using BYTEA.
/// Same fail-soft contract as push, analytics and moderation.

const BASE = (process.env.SUPABASE_URL || '').replace(/\/+$/, '');
const KEY = process.env.SUPABASE_SERVICE_KEY || '';
const BUCKET = process.env.SUPABASE_BUCKET || 'media';

export const storageEnabled = !!(BASE && KEY);

if (!storageEnabled) {
  console.warn(
    '[storage] SUPABASE_URL / SUPABASE_SERVICE_KEY not set — media stays in ' +
    'Postgres BYTEA. Fine for now; it will not scale (see storage.ts).');
} else {
  console.log(`[storage] Supabase Storage on, bucket "${BUCKET}"`);
}

/// How long a signed read URL stays valid. Long enough that a slow feed scroll
/// never 403s mid-load, short enough that a leaked URL is worthless tomorrow.
const SIGN_TTL_SECS = 60 * 60;

/// Upload bytes. Returns the object key to store on the media row, or null if
/// storage isn't configured or the upload failed — callers MUST treat null as
/// "fall back to BYTEA" rather than as a failed upload, so a storage outage
/// degrades instead of breaking uploads entirely.
export async function putObject(
  key: string, bytes: Buffer, mime: string,
): Promise<string | null> {
  if (!storageEnabled) return null;
  try {
    const r = await fetch(`${BASE}/storage/v1/object/${BUCKET}/${key}`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${KEY}`,
        'Content-Type': mime,
        // media ids are unique per row, so a collision means a retry of the
        // same upload — overwriting is the correct, idempotent answer
        'x-upsert': 'true',
      },
      body: new Uint8Array(bytes),
    });
    if (!r.ok) {
      console.error('[storage] upload failed', r.status, await r.text().catch(() => ''));
      return null;
    }
    return key;
  } catch (e) {
    console.error('[storage] upload threw', e);
    return null;
  }
}

/// A short-lived signed URL for a private object. The bucket stays PRIVATE —
/// avatars are readable by any signed-in user, but "any signed-in user" is a
/// decision our server makes per request, not something a public bucket URL
/// should let the whole internet make for us.
export async function signedUrl(key: string): Promise<string | null> {
  if (!storageEnabled) return null;
  try {
    const r = await fetch(`${BASE}/storage/v1/object/sign/${BUCKET}/${key}`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ expiresIn: SIGN_TTL_SECS }),
    });
    if (!r.ok) return null;
    const j = await r.json() as { signedURL?: string; signedUrl?: string };
    const path = j.signedURL ?? j.signedUrl;
    return path ? `${BASE}/storage/v1${path.startsWith('/') ? '' : '/'}${path}` : null;
  } catch {
    return null;
  }
}

/// Delete an object — used when an avatar is replaced or moderated away, so
/// the bucket doesn't accumulate every photo anyone ever had.
export async function deleteObject(key: string): Promise<void> {
  if (!storageEnabled) return;
  try {
    await fetch(`${BASE}/storage/v1/object/${BUCKET}/${key}`, {
      method: 'DELETE',
      headers: { Authorization: `Bearer ${KEY}` },
    });
  } catch { /* an orphaned object is untidy, never broken */ }
}

/// Object key for a media row. Sharded by kind so the bucket stays browsable
/// and a lifecycle rule can treat chat media differently from avatars.
export function keyFor(id: number, kind: string, mime: string): string {
  const ext = mime.includes('png') ? 'png'
    : mime.includes('webp') ? 'webp'
    : mime.startsWith('audio') ? 'm4a'
    : 'jpg';
  return `${kind}/${id}.${ext}`;
}
