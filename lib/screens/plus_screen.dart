import 'dart:math' as math;

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
/// viewer's own currency, and a price change needs no new build. The only
/// exception is a build with no RevenueCat key at all, which falls back to
/// [RcCfg]'s display hints purely so the layout is reviewable on a device.
class PlusScreen extends StatefulWidget {
  const PlusScreen({super.key, this.reason});

  /// What the user was trying to do. This is a SUBLINE, never the headline —
  /// it arrives as free prose from a dozen call sites, and rendering prose at
  /// display size produced a five-line headline that ate the whole screen.
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

enum _Plan { weekly, monthly }

class _PlusScreenState extends State<PlusScreen> {
  bool _busy = false;
  List<Package> _packages = const [];

  /// Which card is lit. Held as a plain enum, not a Package, so the two cards
  /// still select correctly in a build with no store behind them.
  _Plan _plan = _Plan.monthly; // the better value per day, and the higher LTV

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await Plus.instance.refresh();
    if (!mounted) return;
    setState(() => _packages = Plus.instance.packages);
  }

  Package? _pkg(PackageType t) => _packages
      .where((p) => p.packageType == t)
      .cast<Package?>()
      .firstWhere((_) => true, orElse: () => null);

  Package? get _weekly => _pkg(PackageType.weekly);
  Package? get _monthly => _pkg(PackageType.monthly);
  Package? get _picked => _plan == _Plan.weekly ? _weekly : _monthly;

  /// What each card shows. Store price when we have it, [RcCfg] hint when the
  /// SDK is dormant, an em dash while the offering is still loading.
  String _priceOf(_Plan p) {
    final pkg = p == _Plan.weekly ? _weekly : _monthly;
    if (pkg != null) return pkg.storeProduct.priceString;
    if (!RcCfg.configured) {
      return p == _Plan.weekly ? RcCfg.weeklyPriceHint : RcCfg.monthlyPriceHint;
    }
    return '—';
  }

  double? _valueOf(_Plan p) {
    final pkg = p == _Plan.weekly ? _weekly : _monthly;
    if (pkg != null) return pkg.storeProduct.price;
    if (!RcCfg.configured) {
      return p == _Plan.weekly
          ? RcCfg.weeklyPriceHintValue
          : RcCfg.monthlyPriceHintValue;
    }
    return null;
  }

  /// How much cheaper a month of monthly is than a month of weekly.
  ///
  /// Computed from the live prices, never hardcoded: the two products can be
  /// repriced independently in either store, and a badge claiming a discount
  /// that the checkout then contradicts is the kind of thing that gets a
  /// build rejected. A month is 52/12 weeks, not 4 — using 4 overstates the
  /// saving by about seven points.
  int? get _savePct {
    final w = _valueOf(_Plan.weekly);
    final m = _valueOf(_Plan.monthly);
    if (w == null || m == null || w <= 0 || m <= 0) return null;
    final weeklyPerMonth = w * 52 / 12;
    final pct = (1 - m / weeklyPerMonth) * 100;
    // below ~5% it isn't a selling point, it's noise
    return pct >= 5 ? pct.round() : null;
  }

  /// The single line under the button. Three states, and each one has to be
  /// true — a paywall that claims a price it cannot charge is the fastest way
  /// to fail review.
  ///
  ///  • no SDK key compiled in  -> say so plainly
  ///  • key present, no offering back -> the key, the offering id or the store
  ///    is wrong. Do NOT print "—/month · auto-renews", which reads like a
  ///    rendering glitch and hides a real misconfiguration.
  ///  • offering loaded -> price, period and renewal for the SELECTED plan,
  ///    which is everything Apple requires visible before purchase.
  String get _footerLine {
    if (!RcCfg.configured) return 'Subscriptions aren’t live in this build yet';
    if (_packages.isEmpty) {
      // The real reason, not "check your connection". Every one of these is a
      // dashboard or App Store Connect state with a specific fix, and a
      // generic message costs a build per guess.
      return Plus.instance.lastError ?? 'Plans couldn’t load';
    }
    final price = _priceOf(_plan);
    final per = _plan == _Plan.weekly ? 'week' : 'month';
    return '$price/$per · Auto-renews until cancelled';
  }

  void _toast(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: C.char2,
      content: Text(s, style: T.body.copyWith(color: Colors.white)),
    ));
  }

  Future<void> _buy() async {
    final p = _picked;
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
    final mq = MediaQuery.of(context);
    final s = AppSession.instance;
    final save = _savePct;

    // Both cards are ONE number wide and ONE number tall, and it is the same
    // number for each — there is no code path where they differ. Square on any
    // normal phone; on a short one the height cap wins and they shrink
    // together, which is the only way a fixed square can stay on a screen that
    // never scrolls.
    final usable = mq.size.width - r.gutter * 2;
    final side = math.min((usable - 14) / 2, mq.size.height * 0.185);

    final canBuy = !_busy && _picked != null && !s.plus;

    return Scaffold(
      backgroundColor: C.char,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 0.55],
            colors: [C.purpleDeep.withOpacity(0.42), Colors.transparent],
          ),
        ),
        child: SafeArea(
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
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: C.glass2,
                          border: Border.all(color: C.hair)),
                      child: const Icon(Icons.close_rounded,
                          size: 18, color: C.tx2),
                    ),
                  ),
                ),

                const Spacer(flex: 2),

                // ---- the headline. Fixed, never the caller's prose. -------
                ShaderMask(
                  shaderCallback: (b) => C.gradSigHot.createShader(b),
                  blendMode: BlendMode.srcIn,
                  child: Text(
                    'Unlock unlimited\nRivler Pro',
                    textAlign: TextAlign.center,
                    style: T.display(34 * r.scale).copyWith(height: 1.08),
                  ),
                ),
                if (widget.reason != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    widget.reason!,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: T.sub.copyWith(fontSize: 14.5, color: C.tx2),
                  ),
                ],

                const Spacer(flex: 2),

                // ---- four points, at a size you can actually read ---------
                const _Point(
                    emoji: '🍾',
                    text: 'Spin the Bottle, Truth or Dare, Never Have I '
                        'Ever — 17 games'),
                const _Point(
                    emoji: '🎰', text: 'Roulette — someone new, back to back'),
                const _Point(
                    emoji: '👥', text: 'Your own room your friends drop into'),
                // An icon, not the ♀︎♂︎ pair: two emoji in a 26pt slot wrapped
                // the second one onto its own line on a real device.
                const _Point(
                    icon: Icons.wc_rounded, text: 'Choose who you meet'),

                const Spacer(flex: 2),

                // ---- two cards, identical by construction ------------------
                Row(
                  children: [
                    Expanded(
                      child: _PlanCard(
                        side: side,
                        name: 'WEEKLY',
                        price: _priceOf(_Plan.weekly),
                        per: 'per week',
                        badge: 'STANDARD',
                        selected: _plan == _Plan.weekly,
                        onTap: () {
                          Buzz.tick();
                          setState(() => _plan = _Plan.weekly);
                        },
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _PlanCard(
                        side: side,
                        name: 'MONTHLY',
                        price: _priceOf(_Plan.monthly),
                        per: 'per month',
                        badge: save == null ? 'BEST VALUE' : 'SAVE $save%',
                        hot: true,
                        selected: _plan == _Plan.monthly,
                        onTap: () {
                          Buzz.tick();
                          setState(() => _plan = _Plan.monthly);
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ---- the CTA, always on screen ---------------------------
                if (s.plus)
                  _Notice('You’re already Rivler Pro. Thank you ✨')
                else
                  Cta(
                    label: _busy ? 'One moment…' : 'Start Rivler Pro',
                    onTap: canBuy ? _buy : null,
                  ),

                const SizedBox(height: 10),

                // Price, period and renewal in one line, for the plan that is
                // actually selected. Apple needs all three visible before
                // purchase; the full cancellation terms live one tap away in
                // Terms, which is where a wall of small print belongs.
                if (!s.plus)
                  Text(
                    _footerLine,
                    textAlign: TextAlign.center,
                    // Two, not one: the renewal line fits on one, but a
                    // diagnostic reason clipped at one line is useless.
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: T.tiny.copyWith(fontSize: 12, height: 1.3, color: C.tx2),
                  ),

                const SizedBox(height: 12),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _Mini('Restore', _busy ? null : _restore),
                    _dot(),
                    _Mini(
                        'Terms',
                        () => LegalScreen.push(
                            context, 'Terms of Service', LegalCopy.terms)),
                    _dot(),
                    _Mini(
                        'Privacy',
                        () => LegalScreen.push(
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

  Widget _dot() =>
      Text('  ·  ', style: T.tiny.copyWith(color: C.tx3, fontSize: 11));
}

/// One selling point — one line, one glance. Four of these is the whole pitch.
/// Takes an emoji or an icon; the leading slot is a fixed width either way so
/// the four rows line up on the left edge of their text.
class _Point extends StatelessWidget {
  const _Point({this.emoji, this.icon, required this.text})
      : assert(emoji != null || icon != null);
  final String? emoji;
  final IconData? icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 32,
            child: icon != null
                ? Icon(icon, size: 19, color: C.sig)
                : Text(emoji!,
                    maxLines: 1,
                    softWrap: false,
                    style: const TextStyle(fontSize: 17)),
          ),
          Expanded(
            child: Text(
              text,
              style: T.body.copyWith(
                fontSize: 16.5,
                height: 1.28,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One plan.
///
/// [side] is passed in rather than measured so both cards are literally the
/// same box: same width, same height, same radius, same padding. A paywall
/// where one option is drawn bigger than the other reads as a thumb on the
/// scale, and the price is the only thing here that should be persuading
/// anyone. The only difference between the two is what the badge says.
class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.side,
    required this.name,
    required this.price,
    required this.per,
    required this.badge,
    required this.selected,
    required this.onTap,
    this.hot = false,
  });

  final double side;
  final String name;
  final String price;
  final String per;
  final String badge;

  /// Whether the badge is the acid "this is the deal" pill or the quiet one.
  final bool hot;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Press(
      haptic: false,
      onTap: onTap,
      child: AnimatedContainer(
        duration: M.quick,
        height: side,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? null : C.char2,
          gradient: selected ? C.gradSig : null,
          borderRadius: BorderRadius.circular(R.card),
          border: Border.all(
              color: selected ? const Color(0x66FFFFFF) : C.hair2,
              width: selected ? 1.6 : 1),
          boxShadow: selected ? C.glowSig(blur: 22, spread: -8) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
              decoration: BoxDecoration(
                color: hot
                    ? C.acid
                    : (selected ? const Color(0x2EFFFFFF) : C.glass2),
                borderRadius: BorderRadius.circular(R.chip),
              ),
              child: Text(
                badge,
                maxLines: 1,
                style: T.tiny.copyWith(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                  color: hot
                      ? Colors.black
                      : (selected ? Colors.white : C.tx3),
                ),
              ),
            ),
            const Spacer(),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(price, maxLines: 1, style: T.display(30)),
            ),
            const SizedBox(height: 4),
            Text(
              per,
              maxLines: 1,
              style: T.tiny.copyWith(
                  fontSize: 12,
                  color: selected ? Colors.white70 : C.tx3),
            ),
            const Spacer(),
            Text(
              name,
              maxLines: 1,
              style: T.eyebrow.copyWith(
                  fontSize: 9.5,
                  letterSpacing: 1.8,
                  color: selected ? Colors.white70 : C.tx3),
            ),
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
                color: C.tx2, fontSize: 12, fontWeight: FontWeight.w800)),
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
