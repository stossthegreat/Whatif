import type { Express, Request, Response } from 'express';
import express from 'express';
import { run, dbEnabled, addBan, clearBan, devicesFor } from './db.js';
import { CATEGORIES } from './moderation.js';

/// The moderation desk. Reports were write-only until now — nothing could read
/// them, so the Terms' "reviewed within 24 hours" was a promise with no
/// mechanism behind it. This is the mechanism: one protected page, no
/// framework, no build step.
///
/// Access is a shared key in ADMIN_KEY. If it isn't set, every route 404s —
/// an unprotected moderation console is worse than none.

const KEY = process.env.ADMIN_KEY || '';

function authed(req: Request): boolean {
  if (!KEY) return false;
  const q = typeof req.query.key === 'string' ? req.query.key : '';
  const b = typeof req.body?.key === 'string' ? (req.body.key as string) : '';
  return q === KEY || b === KEY;
}

const esc = (s: unknown) =>
  String(s ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

function shell(body: string): string {
  return `<!doctype html><html lang="en"><head><meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<title>Rivlr · moderation</title><style>
 body{background:#08090b;color:#e8e8ec;font:15px/1.5 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif;margin:0}
 main{max-width:1000px;margin:0 auto;padding:28px 18px 80px}
 h1{font-size:22px;margin:0 0 4px} .sub{color:#8b8b94;font-size:13px;margin-bottom:22px}
 .card{background:#111318;border:1px solid #22252c;border-radius:14px;padding:14px 16px;margin-bottom:12px}
 .row{display:flex;align-items:center;gap:12px;flex-wrap:wrap}
 .uid{font-family:ui-monospace,Menlo,monospace;font-size:12.5px;color:#cfcfd6;word-break:break-all}
 .sev{padding:2px 9px;border-radius:99px;font-size:11px;font-weight:800;letter-spacing:.4px}
 .s5{background:#7f1d1d;color:#fff} .s4{background:#9a3412;color:#fff} .s3{background:#854d0e;color:#fff}
 .s2{background:#1e3a8a;color:#fff} .s1{background:#27272a;color:#d4d4d8}
 .meta{color:#8b8b94;font-size:12.5px;margin-top:6px}
 .banned{color:#fca5a5;font-weight:700;font-size:12.5px}
 form{display:inline} button{background:#1b1e25;color:#e8e8ec;border:1px solid #2b2f38;border-radius:9px;
   padding:6px 11px;font-size:12.5px;font-weight:700;cursor:pointer;margin-right:6px}
 button:hover{background:#242832} button.danger{border-color:#7f1d1d;color:#fca5a5}
 button.ok{border-color:#166534;color:#86efac}
 .empty{color:#8b8b94;padding:40px 0;text-align:center}
 a{color:#A36BFF}
</style></head><body><main>${body}</main></body></html>`;
}

export function mountAdmin(app: Express): void {
  const form = express.urlencoded({ extended: false });

  app.get('/admin', async (req: Request, res: Response) => {
    if (!authed(req)) return res.status(404).send('Not found');
    if (!dbEnabled) return res.send(shell('<h1>Moderation</h1><p class="sub">Database offline.</p>'));
    const key = encodeURIComponent(String(req.query.key ?? ''));

    // open reports grouped by target, worst-first — child safety and nudity
    // sort above everything by construction
    const r = await run(
      `SELECT rp.target,
              COUNT(*) AS n,
              COUNT(DISTINCT rp.reporter) FILTER (WHERE rp.reporter <> '') AS distinct_reporters,
              MAX(rp.severity) AS sev,
              MAX(rp.created_at) AS last_at,
              (ARRAY_AGG(rp.reason ORDER BY rp.severity DESC, rp.created_at DESC))[1] AS top_reason,
              (ARRAY_AGG(rp.media_id ORDER BY rp.created_at DESC) FILTER (WHERE rp.media_id IS NOT NULL))[1] AS media_id,
              u.name, u.photo_media_id,
              b.until AS ban_until, b.reason AS ban_reason
         FROM reports rp
         LEFT JOIN users u ON u.uid = rp.target
         LEFT JOIN bans b ON b.subject_type='uid' AND b.subject = rp.target
                         AND (b.until IS NULL OR b.until > now())
        WHERE rp.handled_at IS NULL
        GROUP BY rp.target, u.name, u.photo_media_id, b.until, b.reason
        ORDER BY MAX(rp.severity) DESC, MAX(rp.created_at) DESC
        LIMIT 200`);
    const rows = r?.rows ?? [];

    const cards = rows.map((x) => {
      const sev = Number(x.sev ?? 1);
      const reason = String(x.top_reason ?? 'other');
      const label = CATEGORIES[reason]?.label ?? 'Other';
      const banned = x.ban_until !== undefined && x.ban_until !== null || x.ban_reason != null;
      const until = x.ban_until ? `until ${esc(String(x.ban_until).slice(0, 16))}` : 'permanent';
      const hasPhoto = x.photo_media_id != null;
      const act = (verb: string, label2: string, cls = '', extra = '') =>
        `<form method="post" action="/admin/${verb}"><input type="hidden" name="key" value="${esc(req.query.key)}"/>` +
        `<input type="hidden" name="uid" value="${esc(x.target)}"/>${extra}` +
        `<button class="${cls}" type="submit">${label2}</button></form>`;
      return `<div class="card">
        <div class="row">
          <span class="sev s${sev}">${esc(label)}</span>
          <b>@${esc(x.name ?? 'unknown')}</b>
          <span class="uid">${esc(x.target)}</span>
          ${banned ? `<span class="banned">BANNED ${until}</span>` : ''}
        </div>
        <div class="meta">${esc(x.n)} reports · ${esc(x.distinct_reporters)} distinct reporters · last ${esc(String(x.last_at).slice(0, 16))}${
          hasPhoto ? ` · <a href="/api/media/${esc(x.photo_media_id)}?tk=" target="_blank">has profile photo</a>` : ''
        }</div>
        <div class="meta" style="margin-top:10px">
          ${act('ban', 'Ban 24h', 'danger', '<input type="hidden" name="hours" value="24"/>')}
          ${act('ban', 'Ban 7d', 'danger', '<input type="hidden" name="hours" value="168"/>')}
          ${act('ban', 'Ban permanently', 'danger', '<input type="hidden" name="hours" value="0"/>')}
          ${hasPhoto ? act('removephoto', 'Remove photo') : ''}
          ${banned ? act('unban', 'Lift ban', 'ok') : ''}
          ${act('clear', 'Dismiss', 'ok')}
        </div>
      </div>`;
    }).join('');

    res.type('html').send(shell(
      `<h1>Moderation queue</h1>
       <p class="sub">${rows.length} open · highest severity first · <a href="/admin?key=${key}">refresh</a></p>
       ${rows.length ? cards : '<div class="empty">Nothing waiting. 🎉</div>'}`));
  });

  // Ban: also pins the devices this account has used, so reinstalling with a
  // fresh uid doesn't undo it.
  app.post('/admin/ban', form, async (req: Request, res: Response) => {
    if (!authed(req)) return res.status(404).send('Not found');
    const uid = String(req.body.uid ?? '');
    const hours = Number(req.body.hours ?? 0);
    if (!uid) return res.redirect(`/admin?key=${encodeURIComponent(String(req.body.key))}`);
    addBan('uid', uid, 'moderator action', hours);
    const d = await devicesFor(uid);
    for (const row of d?.rows ?? []) {
      if (row.device_id) addBan('device', String(row.device_id), `linked to banned account ${uid}`, hours);
    }
    void run('UPDATE reports SET handled_at = now() WHERE target=$1 AND handled_at IS NULL', [uid]);
    res.redirect(`/admin?key=${encodeURIComponent(String(req.body.key))}`);
  });

  app.post('/admin/unban', form, async (req: Request, res: Response) => {
    if (!authed(req)) return res.status(404).send('Not found');
    const uid = String(req.body.uid ?? '');
    clearBan('uid', uid);
    const d = await devicesFor(uid);
    for (const row of d?.rows ?? []) if (row.device_id) clearBan('device', String(row.device_id));
    res.redirect(`/admin?key=${encodeURIComponent(String(req.body.key))}`);
  });

  // Take down a profile photo: null the pointer, delete the blob. The client's
  // Avatar already falls back to the identity orb when photoId is null.
  app.post('/admin/removephoto', form, async (req: Request, res: Response) => {
    if (!authed(req)) return res.status(404).send('Not found');
    const uid = String(req.body.uid ?? '');
    const prev = await run('SELECT photo_media_id FROM users WHERE uid=$1', [uid]);
    await run('UPDATE users SET photo_media_id = NULL WHERE uid=$1', [uid]);
    const old = prev?.rows?.[0]?.photo_media_id;
    if (old != null) void run('DELETE FROM media WHERE id=$1', [old]);
    res.redirect(`/admin?key=${encodeURIComponent(String(req.body.key))}`);
  });

  app.post('/admin/clear', form, (req: Request, res: Response) => {
    if (!authed(req)) return res.status(404).send('Not found');
    const uid = String(req.body.uid ?? '');
    void run('UPDATE reports SET handled_at = now() WHERE target=$1 AND handled_at IS NULL', [uid]);
    res.redirect(`/admin?key=${encodeURIComponent(String(req.body.key))}`);
  });
}
