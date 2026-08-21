import type { Express, Request, Response } from 'express';
import express from 'express';
import { run, dbEnabled } from './db.js';
import { verifyAuthToken } from './auth.js';
import { store } from './store.js';
import { moderateImage } from './moderation.js';
import { storageEnabled, putObject, signedUrl, deleteObject, keyFor } from './storage.js';

/// A face just changed — tell every connected phone RIGHT NOW instead of
/// letting each surface discover it on its own next poll/snapshot. Avatar
/// changes are rare (per user), the payload is tiny, and instant propagation
/// is what makes the app feel like one coherent memory instead of a set of
/// caches that disagree for a while.
const pendingFresh = new Map<string, { patch: { photoId?: number; thumbId?: number }; timer: NodeJS.Timeout }>();

function broadcastFaceFresh(uid: string, patch: { photoId?: number; thumbId?: number }): void {
  // avatar + thumb land as two uploads back to back — coalesce into ONE
  // broadcast so every online client re-pulls Explore once per change,
  // not twice. 1.2s covers the gap between the two POSTs comfortably.
  const cur = pendingFresh.get(uid);
  const merged = { ...(cur?.patch ?? {}), ...patch };
  if (cur) clearTimeout(cur.timer);
  pendingFresh.set(uid, {
    patch: merged,
    timer: setTimeout(() => {
      pendingFresh.delete(uid);
      const msg = JSON.stringify({ t: 'faceFresh', uid, ...merged });
      for (const u of store.users.values()) {
        if (u.ws.readyState === 1 /* OPEN */) {
          try { u.ws.send(msg); } catch { /* socket died mid-iteration */ }
        }
      }
    }, 1200),
  });
}

/// Media over HTTP (WS is the wrong pipe for bytes): photos, voice notes,
/// avatars into Postgres BYTEA, plus the Tenor GIF proxy. Auth = the HMAC
/// token minted into welcome — accepted as a Bearer header OR ?tk= query
/// param (audio/image loaders can't always set headers).

const MAX_BYTES = 1024 * 1024; // clients compress to ~900KB; this is the hard ceiling
const TENOR_KEY = process.env.TENOR_API_KEY || '';
export const gifsEnabled = !!TENOR_KEY;

const MIMES = new Set([
  'image/jpeg', 'image/webp', 'image/png',
  'audio/mp4', 'audio/aac', 'audio/mpeg', 'audio/m4a', 'audio/x-m4a',
]);

function uidOf(req: Request): string | null {
  const h = req.headers.authorization;
  const raw = h?.startsWith('Bearer ') ? h.slice(7) : (req.query.tk as string | undefined);
  return raw ? verifyAuthToken(raw) : null;
}

function magicOk(mime: string, b: Buffer): boolean {
  if (b.length < 12) return false;
  if (mime === 'image/jpeg') return b[0] === 0xff && b[1] === 0xd8;
  if (mime === 'image/png') return b[0] === 0x89 && b[1] === 0x50;
  if (mime === 'image/webp') return b.toString('ascii', 8, 12) === 'WEBP';
  // audio containers vary (m4a/aac/mp3) — accept if it isn't obviously an image
  return true;
}

/// Avatar byte cache. Explore turns avatars into the hottest read in the
/// system — every grid cell is a media GET, and each one otherwise drags a
/// BYTEA back out of Postgres. Avatars are small (thumbnails), immutable
/// (a new photo mints a new id) and public to signed-in users, so they are
/// perfectly cacheable in-process. Same LRU shape as the GIF cache below.
const AVATAR_CACHE_MAX = 500;
const avatarCache = new Map<number, { mime: string; bytes: Buffer }>();
function avatarCacheGet(id: number): { mime: string; bytes: Buffer } | undefined {
  const hit = avatarCache.get(id);
  if (!hit) return undefined;
  avatarCache.delete(id); avatarCache.set(id, hit); // refresh recency
  return hit;
}
function avatarCacheSet(id: number, mime: string, bytes: Buffer): void {
  avatarCache.set(id, { mime, bytes });
  while (avatarCache.size > AVATAR_CACHE_MAX) {
    avatarCache.delete(avatarCache.keys().next().value!);
  }
}
/// A replaced or moderated-away avatar must not linger in memory.
export function dropAvatarCache(id: number): void {
  avatarCache.delete(id);
}

// gif search cache — 5 minutes per query, LRU-bounded (Map insertion order):
// keyed by user-typed text, so without a cap it grows forever.
const GIF_CACHE_MAX = 400;
const gifCache = new Map<string, { at: number; data: unknown }>();
function gifCacheGet(q: string): unknown | undefined {
  const hit = gifCache.get(q);
  if (!hit) return undefined;
  if (Date.now() - hit.at > 300_000) { gifCache.delete(q); return undefined; }
  gifCache.delete(q); gifCache.set(q, hit); // refresh recency
  return hit.data;
}
function gifCacheSet(q: string, data: unknown): void {
  gifCache.delete(q);
  gifCache.set(q, { at: Date.now(), data });
  while (gifCache.size > GIF_CACHE_MAX) gifCache.delete(gifCache.keys().next().value!);
}

/// Serve bytes with HTTP Range support.
///
/// This is why voice notes appeared in the thread but refused to play. iOS
/// AVPlayer (what audioplayers uses for a remote URL) does not simply GET an
/// audio file — it probes with `Range: bytes=0-1` first, and expects a 206
/// with a Content-Range telling it the total length. `res.send(buffer)`
/// ignores the Range header entirely and answers 200 with the whole body,
/// and AVPlayer treats that as a server that cannot stream and gives up.
/// Android's player is more forgiving, which is exactly the kind of bug that
/// looks like "it's broken on my phone" rather than "the server is wrong".
///
/// Images don't need this, but it costs nothing to answer them the same way,
/// and Accept-Ranges is the honest header for a route that can now serve one.
function sendMaybeRanged(
  req: Request, res: Response, mime: string, bytes: Buffer, kind: string,
): void {
  res.setHeader('Accept-Ranges', 'bytes');
  // AVPlayer also sniffs the filename for a container hint, and our URLs are
  // extensionless (/api/media/123?tk=…) — give it one.
  if (kind === 'voice') {
    res.setHeader('Content-Disposition', 'inline; filename="voice.m4a"');
  }
  const range = req.headers.range;
  const total = bytes.length;
  if (typeof range === 'string' && range.startsWith('bytes=')) {
    const [rawStart, rawEnd] = range.slice(6).split('-');
    let start = rawStart ? Number(rawStart) : 0;
    let end = rawEnd ? Number(rawEnd) : total - 1;
    if (!Number.isFinite(start) || start < 0) start = 0;
    if (!Number.isFinite(end) || end >= total) end = total - 1;
    // an unsatisfiable range has its own status code; answering 206 with
    // nonsense makes the player retry forever
    if (start > end || start >= total) {
      res.status(416).setHeader('Content-Range', `bytes */${total}`);
      return void res.end();
    }
    res.status(206);
    res.setHeader('Content-Range', `bytes ${start}-${end}/${total}`);
    res.setHeader('Content-Length', String(end - start + 1));
    res.type(mime);
    return void res.end(bytes.subarray(start, end + 1));
  }
  res.setHeader('Content-Length', String(total));
  res.type(mime);
  res.end(bytes);
}


/// Delete a media row AND its object in the bucket. Every delete path must go
/// through here: deleting only the row leaves the bytes paid for forever, and
/// an orphaned object is invisible — nothing will ever reference it again to
/// tell you it's there.
export async function dropMedia(id: number, owner?: string): Promise<void> {
  const r = await run(
    owner
      ? 'DELETE FROM media WHERE id=$1 AND owner=$2 RETURNING storage_key'
      : 'DELETE FROM media WHERE id=$1 RETURNING storage_key',
    owner ? [id, owner] : [id]);
  const key = r?.rows?.[0]?.storage_key as string | null | undefined;
  if (key) await deleteObject(key);
  dropAvatarCache(id);
}

export function mountMedia(app: Express): void {
  app.post('/api/media', express.raw({ type: () => true, limit: `${MAX_BYTES}b` }),
      async (req: Request, res: Response) => {
    const uid = uidOf(req);
    if (!uid) return res.status(401).json({ err: 'auth' });
    if (!dbEnabled) return res.status(503).json({ err: 'noDb' });
    const kind = String(req.query.kind ?? '');
    if (!['photo', 'voice', 'avatar', 'thumb'].includes(kind)) return res.status(400).json({ err: 'kind' });
    const mime = String(req.headers['content-type'] ?? '');
    if (!MIMES.has(mime)) return res.status(415).json({ err: 'mime' });
    const bytes = req.body as Buffer;
    if (!Buffer.isBuffer(bytes) || bytes.length === 0) return res.status(400).json({ err: 'empty' });
    if (bytes.length > MAX_BYTES) return res.status(413).json({ err: 'tooBig' });
    if (!magicOk(mime, bytes)) return res.status(415).json({ err: 'magic' });

    // proactive filter — photos are the highest-risk surface on a live video
    // app and the easiest to auto-screen. Voice notes aren't image content,
    // so they stay on the reactive report/block path.
    if (kind === 'photo' || kind === 'avatar' || kind === 'thumb') {
      const mod = await moderateImage(bytes, mime);
      if (mod?.flagged) return res.status(422).json({ err: 'flagged', categories: mod.categories });
    }

    // The row is written first so the id exists to key the object by; the
    // bytes column stays NULL when storage takes them. If the upload to the
    // bucket fails we fall back to BYTEA on the same row rather than losing
    // the media — a storage outage degrades, it doesn't break uploading.
    const r = await run(
      'INSERT INTO media (owner, kind, mime, size) VALUES ($1,$2,$3,$4) RETURNING id',
      [uid, kind, mime, bytes.length]);
    const id = r?.rows?.[0]?.id;
    if (id == null) return res.status(500).json({ err: 'db' });
    let stored: string | null = null;
    if (storageEnabled) {
      stored = await putObject(keyFor(Number(id), kind, mime), bytes, mime);
    }
    if (stored) {
      await run('UPDATE media SET storage_key=$2 WHERE id=$1', [id, stored]);
    } else {
      await run('UPDATE media SET bytes=$2 WHERE id=$1', [id, bytes]);
    }

    if (kind === 'avatar') {
      // swap the avatar pointer and delete the old blob. NEVER upload the
      // small derivative with this kind — that's what silently destroyed
      // every full-size avatar before build 61 (the thumb re-entered here,
      // repointed photo_media_id and deleted the photo it belonged to).
      //
      // photo_thumb_id is repointed at the SAME id, provisionally. The small
      // derivative is a separate, fire-and-forget upload that can fail (bad
      // network, app backgrounded, compressor returning nothing) — and when
      // it did, the grid was left pointing at the PREVIOUS thumb, whose blob
      // this same request had every right to delete. That is the "photo shows
      // on my profile but not in Explore" bug: the full avatar was fine,
      // the grid pointer was dangling. Pointing both at the new full image
      // means the grid is correct the instant the avatar lands; the real
      // thumbnail simply replaces it moments later as an optimisation.
      const prev = await run('SELECT photo_media_id, photo_thumb_id FROM users WHERE uid=$1', [uid]);
      await run('UPDATE users SET photo_media_id=$2, photo_thumb_id=$2 WHERE uid=$1', [uid, id]);
      for (const col of ['photo_media_id', 'photo_thumb_id']) {
        const old = prev?.rows?.[0]?.[col];
        // never delete what we just pointed at (both columns can hold it)
        if (old != null && Number(old) !== Number(id)) {
          void dropMedia(Number(old), uid);
        }
      }
      broadcastFaceFresh(uid, { photoId: Number(id), thumbId: Number(id) });
    } else if (kind === 'thumb') {
      // the grid derivative: swaps ONLY the thumb pointer, full photo untouched
      const prev = await run('SELECT photo_thumb_id, photo_media_id FROM users WHERE uid=$1', [uid]);
      await run('UPDATE users SET photo_thumb_id=$2 WHERE uid=$1', [uid, id]);
      const old = prev?.rows?.[0]?.photo_thumb_id;
      const currentPhoto = prev?.rows?.[0]?.photo_media_id;
      // the avatar branch above parks the FULL image in photo_thumb_id until
      // this arrives — so "the old thumb" is very often the live avatar.
      // Deleting it here would destroy the profile photo outright.
      if (old != null && Number(old) !== Number(id) && Number(old) !== Number(currentPhoto)) {
        void dropMedia(Number(old), uid);
      }
      broadcastFaceFresh(uid, { thumbId: Number(id) });
    }
    res.json({ id: Number(id), size: bytes.length });
  });

  app.get('/api/media/:id', async (req: Request, res: Response) => {
    const uid = uidOf(req);
    if (!uid) return res.status(401).json({ err: 'auth' });
    if (!dbEnabled) return res.status(503).json({ err: 'noDb' });
    const id = Number(req.params.id);
    if (!Number.isFinite(id)) return res.status(400).json({ err: 'id' });
    // avatars short-circuit the database entirely on a cache hit
    const cached = avatarCacheGet(id);
    if (cached) {
      res.setHeader('Cache-Control', 'private, max-age=31536000, immutable');
      res.setHeader('ETag', String(id));
      // same Range-aware path as the cold read below — an early return that
      // quietly ignored Range headers would reintroduce the bug for anything
      // warm in the cache
      return sendMaybeRanged(req, res, cached.mime, cached.bytes, 'avatar');
    }
    const r = await run(
      'SELECT owner, kind, mime, bytes, pair_key, storage_key FROM media WHERE id=$1', [id]);
    const row = r?.rows?.[0];
    if (!row) return res.status(404).json({ err: 'gone' });
    const allowed = row.kind === 'avatar' || row.kind === 'thumb'
        || row.owner === uid
        || (typeof row.pair_key === 'string' && row.pair_key.split('|').includes(uid));
    if (!allowed) return res.status(403).json({ err: 'forbidden' });
    res.setHeader('Cache-Control', 'private, max-age=31536000, immutable');
    res.setHeader('ETag', String(id));
    // face derivatives are cached: small, immutable, readable by any signed-in
    // user, so there is no per-viewer authorization to preserve
    if (row.kind === 'avatar' || row.kind === 'thumb') {
      avatarCacheSet(id, row.mime as string, row.bytes as Buffer);
    }
    // 'audio/m4a' is not a registered type and iOS AVPlayer often refuses to
    // sniff the container from an extensionless URL — serve the real one
    const mime = row.mime === 'audio/m4a' || row.mime === 'audio/x-m4a'
        ? 'audio/mp4' : (row.mime as string);

    // NEW PATH: bytes live in the bucket. Redirect to a short-lived signed
    // URL so the file streams from Supabase's CDN and never passes through
    // this server — that's the whole point (no egress here, and the CDN
    // answers Range requests natively, which is what voice notes need).
    // Authorisation still happened above; the signed URL is the result of it.
    const skey = row.storage_key as string | null;
    if (skey) {
      const url = await signedUrl(skey);
      if (url) return res.redirect(302, url);
      // signing failed (storage blip) — fall through to bytes if this row
      // happens to still have them, else say so honestly
      if (!row.bytes) return res.status(503).json({ err: 'storage' });
    }

    // LEGACY PATH: every row uploaded before build 90 still has its bytes.
    if (!row.bytes) return res.status(404).json({ err: 'gone' });
    sendMaybeRanged(req, res, mime, row.bytes as Buffer, row.kind as string);
  });

  app.get('/api/gifs', async (req: Request, res: Response) => {
    const uid = uidOf(req);
    if (!uid) return res.status(401).json({ err: 'auth' });
    if (!TENOR_KEY) return res.status(503).json({ err: 'noKey' });
    const q = String(req.query.q ?? '').slice(0, 64) || 'trending';
    const hit = gifCacheGet(q);
    if (hit !== undefined) return res.json(hit);
    try {
      const url = q === 'trending'
        ? `https://tenor.googleapis.com/v2/featured?key=${TENOR_KEY}&limit=24&media_filter=tinygif,gif`
        : `https://tenor.googleapis.com/v2/search?key=${TENOR_KEY}&q=${encodeURIComponent(q)}&limit=24&media_filter=tinygif,gif`;
      const resp = await fetch(url);
      const j = await resp.json() as { results?: { id: string; media_formats?: Record<string, { url: string; dims: number[] }> }[] };
      const data = (j.results ?? []).map((g) => {
        const tiny = g.media_formats?.tinygif;
        const full = g.media_formats?.gif ?? tiny;
        return tiny && full ? {
          id: g.id, tinyUrl: tiny.url, url: full.url,
          w: full.dims?.[0] ?? 200, h: full.dims?.[1] ?? 200,
        } : null;
      }).filter(Boolean);
      gifCacheSet(q, data);
      res.json(data);
    } catch {
      res.status(502).json({ err: 'tenor' });
    }
  });
}

/// Nightly retention: DM media older than 90 days goes away (avatars stay).
export function startRetentionSweep(): void {
  const sweep = () => {
    if (!dbEnabled) return;
    // RETURNING so the bucket objects go with the rows — a sweep that only
    // deleted rows would quietly keep paying for every expired voice note
    void (async () => {
      const r = await run(
        `DELETE FROM media
          WHERE kind NOT IN ('avatar','thumb')
            AND created_at < now() - interval '90 days'
          RETURNING storage_key`);
      for (const row of r?.rows ?? []) {
        if (row.storage_key) await deleteObject(row.storage_key as string);
      }
    })();
  };
  sweep();
  setInterval(sweep, 24 * 3600_000);
}

/// Stamp a media row into a DM pair (ownership verified) — returns ok.
/// IDEMPOTENT: a resend of the same dm (reconnect retries do this) must not
/// fail just because the first attempt already claimed the row.
export async function claimForPair(mediaId: number, owner: string, pairKey: string): Promise<boolean> {
  const r = await run(
    `UPDATE media SET pair_key=$3
      WHERE id=$1 AND owner=$2 AND (pair_key IS NULL OR pair_key=$3)
      RETURNING id`,
    [mediaId, owner, pairKey]);
  return !!r?.rows?.length;
}

