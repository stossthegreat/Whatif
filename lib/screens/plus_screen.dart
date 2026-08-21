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

/// The paywall. Four things here are not decoration — Apple rejects builds
/// without them: the exact price and period, a Restore purchases control,
/// links to Terms and Privacy, and a plain-English auto-renewal statement.
///
/// Prices are never hardcoded. Whatever App Store Connect says is what shows,
/// in the viewer's own currency, and a price change needs no new build.
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
  int _pick = 0;
  List<Package> _packages = const [];

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
      // default to the better-value plan, not the cheapest sticker price
      if (_packages.length > 1) _pick = _packages.length - 1;
    });
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
    if (_busy || _packages.isEmpty) return;
    setState(() => _busy = true);
    final r = await Plus.instance.buy(_packages[_pick]);
    if (!mounted) return;
    setState(() => _busy = false);
    switch (r) {
      case PlusResult.success:
        Buzz.commit();
        _toast('You’re Rivler+ ✨');
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
        _toast('No subscription found on this Apple ID');
      default:
        _toast('Couldn’t reach the store — try again');
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final s = AppSession.instance;
    return Scaffold(
      backgroundColor: C.black,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 0.45],
            colors: [C.purpleDeep.withOpacity(0.35), Colors.transparent],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(r.gutter, 8, r.gutter, 0),
                child: Row(
                  children: [
                    const Spacer(),
                    Press(
                      onTap: () => Navigator.of(context).maybePop(),
                      child: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: C.glass,
                            border: Border.all(color: C.hair)),
                        child: const Icon(Icons.close_rounded, size: 19, color: C.tx2),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(r.gutter, 4, r.gutter, 20),
                  children: [
                    Center(
                      child: ShaderMask(
                        shaderCallback: (b) => C.gradSigHot.createShader(b),
                        blendMode: BlendMode.srcIn,
                        child: Text('Rivler+', style: T.display(46 * r.scale)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        widget.reason ??
                            'Every party game, Roulette and your own Groups room. '
                            '1-on-1 stays free.',
                        textAlign: TextAlign.center,
                        style: T.body.copyWith(fontSize: 15, height: 1.45),
                      ),
                    ),
                    const SizedBox(height: 26),
                    const _Perk(
                      emoji: '🍾',
                      title: 'Every party game',
                      line: 'Spin the Bottle, Truth or Dare, Never Have I Ever, '
                          'Would You Rather — the whole catalogue, in any room.',
                    ),
                    const _Perk(
                      emoji: '🎰',
                      title: 'Roulette',
                      line: 'No choosing — we throw you at someone new and the '
                          'games hit back to back.',
                    ),
                    const _Perk(
                      emoji: '👥',
                      title: 'Your own Groups room',
                      line: 'A permanent code your people can drop into any '
                          'time. Everyone in your room plays free.',
                    ),
                    const _Perk(
                      emoji: '♀︎♂︎',
                      title: 'Choose who you meet',
                      line: 'Match with women only, men only, or everyone — '
                          'switch any time.',
                    ),
                    const _Perk(
                      emoji: '💜',
                      title: 'See who wants to meet you',
                      line: 'Everyone who said they’d meet you again, before '
                          'you decide about them.',
                    ),
                    const _Perk(
                      emoji: '⚡',
                      title: 'Skip the queue',
                      line: 'Your turn comes first when the app is busy.',
                    ),
                    const SizedBox(height: 22),
                    if (!RcCfg.configured)
                      _Notice('Subscriptions aren’t switched on in this build yet.')
                    else if (_packages.isEmpty)
                      _Notice('Loading plans…')
                    else
                      for (var i = 0; i < _packages.length; i++)
                        _PlanRow(
                          package: _packages[i],
                          selected: i == _pick,
                          best: _packages.length > 1 && i == _packages.length - 1,
                          onTap: () { Buzz.tick(); setState(() => _pick = i); },
                        ),
                    const SizedBox(height: 18),
                    if (s.plus)
                      _Notice('You’re already Rivler+. Thank you ✨')
                    else
                      Cta(
                        label: _busy ? 'One moment…' : 'Start Rivler+',
                        onTap: _busy || _packages.isEmpty ? null : _buy,
                      ),
                    const SizedBox(height: 12),
                    Center(
                      child: Press(
                        haptic: false,
                        onTap: _busy ? null : _restore,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
                          child: Text('Restore purchases',
                              style: T.body.copyWith(
                                  color: C.tx2,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Apple requires the renewal terms in plain language,
                    // visible before purchase — not buried in the Terms.
                    Text(
                      'Your subscription renews automatically at the price shown '
                      'until you cancel. Cancel any time in your Apple ID '
                      'settings, at least 24 hours before the period ends. '
                      'Payment is charged to your Apple ID.',
                      textAlign: TextAlign.center,
                      style: T.tiny.copyWith(fontSize: 11.5, height: 1.5),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _LegalLink('Terms',
                            () => LegalScreen.push(context, 'Terms of Service', LegalCopy.terms)),
                        Text('  ·  ', style: T.tiny),
                        _LegalLink('Privacy',
                            () => LegalScreen.push(context, 'Privacy Policy', LegalCopy.privacy)),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Perk extends StatelessWidget {
  const _Perk({required this.emoji, required this.title, required this.line});
  final String emoji;
  final String title;
  final String line;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 34,
            child: Text(emoji, style: const TextStyle(fontSize: 19)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: T.display(17)),
                const SizedBox(height: 3),
                Text(line,
                    style: T.body.copyWith(fontSize: 13.5, height: 1.4, color: C.tx2)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One purchasable plan. Everything shown — price, period, currency — comes
/// straight from the store.
class _PlanRow extends StatelessWidget {
  const _PlanRow({
    required this.package,
    required this.selected,
    required this.best,
    required this.onTap,
  });
  final Package package;
  final bool selected;
  final bool best;
  final VoidCallback onTap;

  String get _period {
    switch (package.packageType) {
      case PackageType.weekly:
        return 'per week';
      case PackageType.monthly:
        return 'per month';
      case PackageType.annual:
        return 'per year';
      case PackageType.lifetime:
        return 'one time';
      default:
        return package.storeProduct.subscriptionPeriod ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Press(
        haptic: false,
        onTap: onTap,
        child: AnimatedContainer(
          duration: M.quick,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            gradient: selected ? C.gradSig : null,
            color: selected ? null : C.glass,
            borderRadius: BorderRadius.circular(R.btn),
            border: Border.all(color: selected ? const Color(0x47FFFFFF) : C.hair2),
            boxShadow: selected ? C.glowSig(blur: 16, spread: -6) : null,
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                size: 20,
                color: selected ? Colors.white : C.tx3,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(package.storeProduct.priceString, style: T.display(19)),
                    const SizedBox(height: 2),
                    Text(_period,
                        style: T.tiny.copyWith(
                            color: selected ? Colors.white70 : C.tx3, fontSize: 12)),
                  ],
                ),
              ),
              if (best)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: C.acid,
                    borderRadius: BorderRadius.circular(R.chip),
                  ),
                  child: Text('Best value',
                      style: T.tiny.copyWith(
                          color: Colors.black,
                          fontSize: 11,
                          fontWeight: FontWeight.w800)),
                ),
            ],
          ),
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: C.glass,
        borderRadius: BorderRadius.circular(R.btn),
        border: Border.all(color: C.hair2),
      ),
      child: Text(text,
          textAlign: TextAlign.center,
          style: T.body.copyWith(fontSize: 14, color: C.tx2)),
    );
  }
}

class _LegalLink extends StatelessWidget {
  const _LegalLink(this.label, this.onTap);
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Press(
      haptic: false,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Text(label,
            style: T.tiny.copyWith(color: C.sig, fontWeight: FontWeight.w800)),
      ),
    );
  }
}
