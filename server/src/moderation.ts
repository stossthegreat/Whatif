import { run, dbEnabled, addBan } from './db.js';

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
