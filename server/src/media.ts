import type { Express, Request, Response } from 'express';
import express from 'express';
import { run, dbEnabled } from './db.js';
import { verifyAuthToken } from './auth.js';

/// Media over HTTP (WS is the wrong pipe for bytes): photos, voice notes,
/// avatars into Postgres BYTEA, plus the Tenor GIF proxy. Auth = the HMAC
/// token minted into welcome — accepted as a Bearer header OR ?tk= query
/// param (audio/image loaders can't always set headers).

const MAX_BYTES = 420 * 1024;
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

// gif search cache — 5 minutes per query
const gifCache = new Map<string, { at: number; data: unknown }>();

export function mountMedia(app: Express): void {
  app.post('/api/media', express.raw({ type: () => true, limit: `${MAX_BYTES}b` }),
      async (req: Request, res: Response) => {
    const uid = uidOf(req);
    if (!uid) return res.status(401).json({ err: 'auth' });
    if (!dbEnabled) return res.status(503).json({ err: 'noDb' });
    const kind = String(req.query.kind ?? '');
    if (!['photo', 'voice', 'avatar'].includes(kind)) return res.status(400).json({ err: 'kind' });
    const mime = String(req.headers['content-type'] ?? '');
    if (!MIMES.has(mime)) return res.status(415).json({ err: 'mime' });
    const bytes = req.body as Buffer;
    if (!Buffer.isBuffer(bytes) || bytes.length === 0) return res.status(400).json({ err: 'empty' });
    if (bytes.length > MAX_BYTES) return res.status(413).json({ err: 'tooBig' });
    if (!magicOk(mime, bytes)) return res.status(415).json({ err: 'magic' });

    const r = await run(
      'INSERT INTO media (owner, kind, mime, bytes, size) VALUES ($1,$2,$3,$4,$5) RETURNING id',
      [uid, kind, mime, bytes, bytes.length]);
    const id = r?.rows?.[0]?.id;
    if (id == null) return res.status(500).json({ err: 'db' });

    if (kind === 'avatar') {
      // swap the avatar pointer and delete the old blob
      const prev = await run('SELECT photo_media_id FROM users WHERE uid=$1', [uid]);
      await run('UPDATE users SET photo_media_id=$2 WHERE uid=$1', [uid, id]);
      const old = prev?.rows?.[0]?.photo_media_id;
      if (old != null) void run('DELETE FROM media WHERE id=$1 AND owner=$2', [old, uid]);
    }
    res.json({ id: Number(id), size: bytes.length });
  });

  app.get('/api/media/:id', async (req: Request, res: Response) => {
    const uid = uidOf(req);
    if (!uid) return res.status(401).json({ err: 'auth' });
    if (!dbEnabled) return res.status(503).json({ err: 'noDb' });
    const id = Number(req.params.id);
    if (!Number.isFinite(id)) return res.status(400).json({ err: 'id' });
    const r = await run('SELECT owner, kind, mime, bytes, pair_key FROM media WHERE id=$1', [id]);
    const row = r?.rows?.[0];
    if (!row) return res.status(404).json({ err: 'gone' });
    const allowed = row.kind === 'avatar'
        || row.owner === uid
        || (typeof row.pair_key === 'string' && row.pair_key.split('|').includes(uid));
    if (!allowed) return res.status(403).json({ err: 'forbidden' });
    res.setHeader('Cache-Control', 'private, max-age=31536000, immutable');
    res.setHeader('ETag', String(id));
    res.type(row.mime as string).send(row.bytes as Buffer);
  });

  app.get('/api/gifs', async (req: Request, res: Response) => {
    const uid = uidOf(req);
    if (!uid) return res.status(401).json({ err: 'auth' });
    if (!TENOR_KEY) return res.status(503).json({ err: 'noKey' });
    const q = String(req.query.q ?? '').slice(0, 64) || 'trending';
    const hit = gifCache.get(q);
    if (hit && Date.now() - hit.at < 300_000) return res.json(hit.data);
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
      gifCache.set(q, { at: Date.now(), data });
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
    void run("DELETE FROM media WHERE kind <> 'avatar' AND created_at < now() - interval '90 days'");
  };
  sweep();
  setInterval(sweep, 24 * 3600_000);
}

/// Stamp a media row into a DM pair (ownership verified) — returns ok.
export async function claimForPair(mediaId: number, owner: string, pairKey: string): Promise<boolean> {
  const r = await run(
    'UPDATE media SET pair_key=$3 WHERE id=$1 AND owner=$2 AND pair_key IS NULL RETURNING id',
    [mediaId, owner, pairKey]);
  return !!r?.rows?.length;
}

