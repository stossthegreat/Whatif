import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../core/analytics.dart';
import '../core/haptics.dart';
import '../core/iap.dart';
import '../revenuecat_config.dart';
import '../state/session.dart';
import '../theme/tokens.dart';
import '../widgets/glass.dart';
import 'legal_screen.dart';

/// The paywall. ONE screen — no scrolling, CTA always visible at the bottom.
///
/// Four things here are not decoration; Apple rejects builds without them,
/// and all four have to be visible WITHOUT scrolling or a reviewer may never
/// see them at all:
///   • the exact price and billing period of each option
///   • a Restore purchases control
///   • links to Terms and Privacy
///   • a plain-English auto-renewal statement
///
/// Prices are never hardcoded. Whatever the store says is what shows, in the
/// viewer's own currency, and a price change needs no new build.
class PlusScreen extends StatefulWidget {
  const PlusScreen({super.key, this.reason});

  /// What the user was trying to do — makes the pitch specific instead of
  /// a generic "go premium".
  final String? reason;

  static Future<void> push(BuildContext context, {String? reason}) {
    Track.event('plus_paywall', {'reason': reason ?? 'direct'});
    return Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PlusScreen(reason: reason),
      fullscreenDialog: true,
    ));
  }

  @override
  State<PlusScreen> createState() => _PlusScreenState();
}

class _PlusScreenState extends State<PlusScreen> {
  bool _busy = false;
  List<Package> _packages = const [];
  Package? _pick;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await Plus.instance.refresh();
    if (!mounted) return;
    setState(() {
      _packages = Plus.instance.packages;
      // default to MONTHLY: it's the better value per day and the higher
      // LTV, and defaulting to the cheapest sticker price trains everyone
      // into the weekly plan
      _pick = _monthly ?? _weekly ?? (_packages.isEmpty ? null : _packages.first);
    });
  }

  Package? get _weekly => _packages
      .where((p) => p.packageType == PackageType.weekly)
      .cast<Package?>()
      .firstWhere((_) => true, orElse: () => null);

  Package? get _monthly => _packages
      .where((p) => p.packageType == PackageType.monthly)
      .cast<Package?>()
      .firstWhere((_) => true, orElse: () => null);

  void _toast(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: C.char2,
      content: Text(s, style: T.body.copyWith(color: Colors.white)),
    ));
  }

  Future<void> _buy() async {
    final p = _pick;
    if (_busy || p == null) return;
    setState(() => _busy = true);
    final r = await Plus.instance.buy(p);
    if (!mounted) return;
    setState(() => _busy = false);
    switch (r) {
      case PlusResult.success:
        Buzz.commit();
        _toast('You’re Rivler Pro ✨');
        Navigator.of(context).maybePop();
      case PlusResult.pending:
        _toast('Payment taken — unlocking in a moment');
        Navigator.of(context).maybePop();
      case PlusResult.cancelled:
        break; // they changed their mind; saying anything would be nagging
      case PlusResult.unavailable:
        _toast('The store isn’t available right now');
      case PlusResult.failed:
      case PlusResult.nothingToRestore:
        _toast('That didn’t go through — nothing was charged');
    }
  }

  Future<void> _restore() async {
    if (_busy) return;
    setState(() => _busy = true);
    final r = await Plus.instance.restore();
    if (!mounted) return;
    setState(() => _busy = false);
    switch (r) {
      case PlusResult.success:
        Buzz.commit();
        _toast('Restored — welcome back ✨');
        Navigator.of(context).maybePop();
      case PlusResult.nothingToRestore:
        _toast('No subscription found on this account');
      default:
        _toast('Couldn’t reach the store — try again');
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final s = AppSession.instance;
    return Scaffold(
      backgroundColor: C.char,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 0.5],
            colors: [C.purpleDeep.withOpacity(0.40), Colors.transparent],
          ),
        ),
        child: SafeArea(
          // ONE screen. Spacers absorb the difference between a small phone
          // and a tall one instead of pushing the CTA off the bottom, which
          // is the single most expensive thing a paywall can do.
          child: Padding(
            padding: EdgeInsets.fromLTRB(r.gutter, 4, r.gutter, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Press(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: C.glass2,
                          border: Border.all(color: C.hair)),
                      child: const Icon(Icons.close_rounded, size: 18, color: C.tx2),
                    ),
                  ),
                ),

                const Spacer(flex: 2),

                // ---- ONE hero outcome ------------------------------------
                ShaderMask(
                  shaderCallback: (b) => C.gradSigHot.createShader(b),
                  blendMode: BlendMode.srcIn,
                  child: Text('RIVLER PRO',
                      textAlign: TextAlign.center,
                      style: T.eyebrow.copyWith(fontSize: 12, letterSpacing: 3)),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.reason == null
                      ? 'Every party game,\nunlocked.'
                      : widget.reason!,
                  textAlign: TextAlign.center,
                  style: T.display(30 * r.scale).copyWith(height: 1.12),
                ),

                const Spacer(flex: 2),

                // ---- FOUR points -----------------------------------------
                const _Point(emoji: '🍾', text: 'Spin the Bottle, Truth or Dare, Never Have I Ever — 17 games'),
                const _Point(emoji: '🎰', text: 'Roulette — someone new, back to back'),
                const _Point(emoji: '👥', text: 'Your own room your friends drop into'),
                const _Point(emoji: '♀︎♂︎', text: 'Choose who you meet'),

                const Spacer(flex: 3),

                // ---- TWO identical boxes ---------------------------------
                if (!RcCfg.configured)
                  _Notice('Subscriptions aren’t switched on in this build yet.')
                else if (_packages.isEmpty)
                  _Notice('Loading plans…')
                else
                  Row(
                    children: [
                      Expanded(
                        child: _PlanBox(
                          label: 'WEEKLY',
                          package: _weekly,
                          per: 'per week',
                          selected: _pick != null && _pick == _weekly,
                          onTap: () { Buzz.tick(); setState(() => _pick = _weekly); },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _PlanBox(
                          label: 'MONTHLY',
                          package: _monthly,
                          per: 'per month',
                          best: true,
                          selected: _pick != null && _pick == _monthly,
                          onTap: () { Buzz.tick(); setState(() => _pick = _monthly); },
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 14),

                // ---- the CTA, always on screen ---------------------------
                if (s.plus)
                  _Notice('You’re already Rivler Pro. Thank you ✨')
                else
                  Cta(
                    label: _busy ? 'One moment…' : 'Start Rivler Pro',
                    onTap: _busy || _pick == null ? null : _buy,
                  ),

                const SizedBox(height: 10),

                // Apple requires the renewal terms in plain language, visible
                // BEFORE purchase — not buried in the Terms document.
                Text(
                  'Renews automatically until cancelled. Cancel any time in your '
                  'account settings, at least 24 hours before the period ends.',
                  textAlign: TextAlign.center,
                  style: T.tiny.copyWith(fontSize: 10.5, height: 1.35, color: C.tx3),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _Mini('Restore', _busy ? null : _restore),
                    _dot(),
                    _Mini('Terms', () => LegalScreen.push(
                        context, 'Terms of Service', LegalCopy.terms)),
                    _dot(),
                    _Mini('Privacy', () => LegalScreen.push(
                        context, 'Privacy Policy', LegalCopy.privacy)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dot() => Text('  ·  ', style: T.tiny.copyWith(color: C.tx3, fontSize: 11));
}

/// One selling point — one line, one glance. Four of these is the whole pitch.
class _Point extends StatelessWidget {
  const _Point({required this.emoji, required this.text});
  final String emoji;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 26, child: Text(emoji, style: const TextStyle(fontSize: 15))),
          Expanded(
            child: Text(text,
                style: T.body.copyWith(fontSize: 14, height: 1.3, color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

/// One plan. Both boxes are the SAME shape and size on purpose — a paywall
/// where one option is visually bigger reads as a trick, and price is the
/// only thing that should be doing the persuading.
class _PlanBox extends StatelessWidget {
  const _PlanBox({
    required this.label,
    required this.package,
    required this.per,
    required this.selected,
    required this.onTap,
    this.best = false,
  });
  final String label;
  final Package? package;
  final String per;
  final bool selected;
  final bool best;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // price and period come STRAIGHT from the store, in the viewer's currency
    final price = package?.storeProduct.priceString ?? '—';
    return Press(
      haptic: false,
      onTap: package == null ? () {} : onTap,
      child: AnimatedContainer(
        duration: M.quick,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? null : C.char2,
          gradient: selected ? C.gradSig : null,
          borderRadius: BorderRadius.circular(R.card),
          border: Border.all(
              color: selected ? const Color(0x59FFFFFF) : C.hair2,
              width: selected ? 1.5 : 1),
          boxShadow: selected ? C.glowSig(blur: 18, spread: -8) : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: T.eyebrow.copyWith(
                    fontSize: 9.5,
                    letterSpacing: 1.6,
                    color: selected ? Colors.white70 : C.tx3)),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(price, maxLines: 1, style: T.display(22)),
            ),
            const SizedBox(height: 2),
            Text(per,
                style: T.tiny.copyWith(
                    fontSize: 11, color: selected ? Colors.white70 : C.tx3)),
            if (best) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: selected ? Colors.white : C.acid,
                  borderRadius: BorderRadius.circular(R.chip),
                ),
                child: Text('BEST VALUE',
                    style: T.tiny.copyWith(
                        color: Colors.black,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini(this.label, this.onTap);
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Press(
      haptic: false,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(label,
            style: T.tiny.copyWith(
                color: C.tx2, fontSize: 11.5, fontWeight: FontWeight.w800)),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: C.glass,
        borderRadius: BorderRadius.circular(R.btn),
        border: Border.all(color: C.hair2),
      ),
      child: Text(text,
          textAlign: TextAlign.center,
          style: T.body.copyWith(fontSize: 13.5, color: C.tx2)),
    );
  }
}
