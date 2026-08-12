import { run, dbEnabled, addBan } from './db.js';

/// Proactive content filtering — the piece Apple's UGC guideline (1.2)
/// actually asks for on top of report+block: a way to catch objectionable
/// content BEFORE it's posted, not only after someone complains. Free tier
/// (OpenAI's moderation endpoint has no cost) so this stays on even for a
/// solo-founder budget. If OPENAI_API_KEY isn't set, or the call fails, we
/// fail OPEN — the upload/message goes through — because report, block and
/// the human queue below are the real backstop; a moderation outage should
/// never brick the app for everyone.
const OPENAI_KEY = process.env.OPENAI_API_KEY || '';
export const aiModerationEnabled = !!OPENAI_KEY;
if (!OPENAI_KEY) {
  console.warn('[moderation] OPENAI_API_KEY not set — AI pre-filtering is OFF; report+block+human queue still work');
}

export interface ModResult {
  flagged: boolean;
  categories: string[]; // the specific categories that tripped, e.g. 'sexual/minors'
}

type OaContent = string | { type: 'image_url'; image_url: { url: string } }[];

async function callModeration(input: OaContent): Promise<ModResult | null> {
  if (!OPENAI_KEY) return null;
  try {
    const resp = await fetch('https://api.openai.com/v1/moderations', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${OPENAI_KEY}` },
      body: JSON.stringify({ model: 'omni-moderation-latest', input }),
    });
    if (!resp.ok) {
      console.error('[moderation] openai status', resp.status);
      return null;
    }
    const j = await resp.json() as {
      results?: { flagged?: boolean; categories?: Record<string, boolean> }[];
    };
    const r = j.results?.[0];
    if (!r) return null;
    const categories = Object.entries(r.categories ?? {}).filter(([, v]) => v).map(([k]) => k);
    return { flagged: !!r.flagged, categories };
  } catch (e) {
    console.error('[moderation] openai request failed', e);
    return null;
  }
}

/// Moderate free text — bios, handles, DM messages. Empty/whitespace-only
/// text is trivially clean; skip the network round trip for it.
export async function moderateText(text: string): Promise<ModResult | null> {
  const t = text.trim();
  if (!t) return { flagged: false, categories: [] };
  return callModeration(t);
}

/// Moderate an uploaded image (profile photo, chat photo) before it's ever
/// stored or served to anyone else. Voice notes aren't covered — this model
/// doesn't take audio — so those stay on the reactive report/block path.
export async function moderateImage(bytes: Buffer, mime: string): Promise<ModResult | null> {
  const url = `data:${mime};base64,${bytes.toString('base64')}`;
  return callModeration([{ type: 'image_url', image_url: { url } }]);
}

/// Categories severe enough to hard-block a DM outright even between two
/// friends who matched each other — sexualizing a minor, self-harm coaching,
/// graphic violence, real threats. Ordinary flirty/adult "sexual" or
/// "harassment" scores are deliberately let through here: this is a flirty
/// duo-game app where consenting-adult banter is expected product behaviour,
/// and it's still covered by report + block + the human queue if it crosses
/// a line the model didn't score high enough to catch.
const SEVERE_CATEGORIES = new Set([
  'sexual/minors', 'self-harm/intent', 'self-harm/instructions',
  'violence/graphic', 'illicit/violent', 'harassment/threatening', 'hate/threatening',
]);
export function isSevere(categories: string[]): boolean {
  return categories.some((c) => SEVERE_CATEGORIES.has(c));
}

/// Report triage.
///
/// A raw count is trivially gameable — three friends can erase anyone — so a
/// report is a SIGNAL, never a verdict. We weigh:
///   • distinct reporters (a repeat reporter adds almost nothing)
///   • each reporter's own standing (rep), so brigading accounts count less
///   • a recency window, not a lifetime tally
///   • category severity (child safety outranks spam by an order of magnitude)
/// Automatic action is only ever a TEMPORARY hold, and only at high confidence.
/// Permanent bans require a human in the admin queue. Everything else is
/// queued for review — the queue is the product, not the auto-ban.

export const CATEGORIES: Record<string, { severity: number; label: string }> = {
  child_safety: { severity: 5, label: 'Child safety' },
  nudity:       { severity: 4, label: 'Nudity / sexual' },
  violence:     { severity: 3, label: 'Violence / threats' },
  harassment:   { severity: 3, label: 'Harassment / hate' },
  impersonation:{ severity: 2, label: 'Impersonation' },
  other:        { severity: 1, label: 'Spam / other' },
};

export function severityOf(reason: string): number {
  return CATEGORIES[reason]?.severity ?? 1;
}
export function normalizeReason(raw: unknown): string {
  const r = typeof raw === 'string' ? raw : '';
  return CATEGORIES[r] ? r : 'other';
}

const WINDOW_HOURS = 72;      // recent behaviour, not a lifetime record
const HOLD_THRESHOLD = 6;     // weighted score that triggers a temporary hold
const HOLD_HOURS = 24;

export interface Verdict {
  score: number;
  distinct: number;
  topSeverity: number;
  action: 'none' | 'hold';
  reason: string;
  /// ISO expiry of an automatic hold — never null when action==='hold', so the
  /// client can honestly say "back in N hours" instead of implying permanent.
  until: string | null;
}

/// Score the recent reports against [target] and decide whether an automatic
/// TEMPORARY hold is warranted. Never returns a permanent ban.
export async function assess(target: string): Promise<Verdict> {
  const empty: Verdict = { score: 0, distinct: 0, topSeverity: 0, action: 'none', reason: '', until: null };
  if (!dbEnabled) return empty;

  // one row per distinct reporter: their worst category in the window, plus
  // that reporter's own reputation (default 0 for accounts with no history)
  const r = await run(
    `SELECT rp.reporter,
            MAX(rp.severity) AS sev,
            COUNT(*) AS n,
            COALESCE(st.rep, 0) AS rep
       FROM reports rp
       LEFT JOIN user_stats st ON st.uid = rp.reporter
      WHERE rp.target = $1
        AND rp.created_at > now() - interval '${WINDOW_HOURS} hours'
        AND rp.reporter <> ''
      GROUP BY rp.reporter, st.rep`,
    [target]);
  const rows = r?.rows ?? [];
  if (!rows.length) return empty;

  let score = 0;
  let topSeverity = 0;
  for (const row of rows) {
    const sev = Number(row.sev ?? 1);
    const rep = Number(row.rep ?? 0);
    // credibility: a well-regarded reporter counts double, a badly-regarded
    // one counts a fraction — brigading from junk accounts barely moves it
    const credibility = Math.max(0.25, Math.min(2, 1 + rep / 50));
    // a reporter who filed five times is not five reporters
    const repeatDamping = 1 + Math.min(0.5, (Number(row.n ?? 1) - 1) * 0.1);
    score += sev * credibility * repeatDamping;
    if (sev > topSeverity) topSeverity = sev;
  }

  const distinct = rows.length;
  // a single reporter can never trip the automatic path, whatever they claim
  const action: 'none' | 'hold' =
    distinct >= 2 && score >= HOLD_THRESHOLD ? 'hold' : 'none';

  return {
    score: Math.round(score * 10) / 10,
    distinct,
    topSeverity,
    action,
    reason: action === 'hold'
      ? `automatic ${HOLD_HOURS}h hold — ${distinct} independent reports pending review`
      : '',
    until: action === 'hold'
      ? new Date(Date.now() + HOLD_HOURS * 3600_000).toISOString()
      : null,
  };
}

/// Called after every report/block. Applies a temporary hold when the signal
/// is strong enough, and reports back so the caller can disconnect.
export async function onReportFiled(target: string): Promise<Verdict> {
  const v = await assess(target);
  if (v.action === 'hold') addBan('uid', target, v.reason, HOLD_HOURS);
  return v;
}
