import 'package:flutter/material.dart';
import '../core/haptics.dart';
import '../state/session.dart';
import '../theme/tokens.dart';
import '../widgets/glass.dart';
import '../widgets/identity_orb.dart';

/// Your Moments — every reveal, captured. The growth loop: each one opens a
/// share card built to spread. (Video capture is a native add-on later; the
/// experience and the shareable card are here now.)
class MomentsScreen extends StatelessWidget {
  const MomentsScreen({super.key});

  static void push(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MomentsScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.black,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: AppSession.instance,
          builder: (context, _) {
            final moments = AppSession.instance.moments;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
                  child: Row(
                    children: [
                      Press(
                        onTap: () => Navigator.of(context).maybePop(),
                        child: Container(
                          width: 38, height: 38,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: C.glass, border: Border.all(color: C.hair)),
                          child: const Icon(Icons.arrow_back_rounded, size: 20, color: C.tx2),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text('Your moments', style: T.big.copyWith(fontSize: 26)),
                    ],
                  ),
                ),
                Expanded(
                  child: moments.isEmpty
                      ? Center(child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: Text('Play a few rooms — your best moments land here, ready to share.',
                              style: T.body, textAlign: TextAlign.center)))
                      : GridView.builder(
                          padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.72),
                          itemCount: moments.length,
                          itemBuilder: (context, i) => Press(
                            onTap: () { Buzz.tap(); ShareCardScreen.push(context, moments[i]); },
                            child: _MomentCard(moments[i]),
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MomentCard extends StatelessWidget {
  const _MomentCard(this.m);
  final Moment m;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [C.sig.withOpacity(0.16), C.glass],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        border: Border.all(color: C.hair),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(m.game.toUpperCase(), style: T.eyebrow.copyWith(color: C.sig, fontSize: 10)),
          const SizedBox(height: 10),
          Expanded(child: Text(m.result, style: T.body.copyWith(color: Colors.white, fontWeight: FontWeight.w700, height: 1.2))),
          Row(children: [
            for (final h in m.hues.take(4)) Padding(padding: const EdgeInsets.only(right: 4), child: IdentityOrb(hue: h, size: 20)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Text('😂 ${m.laughs}', style: T.tiny.copyWith(color: C.tx2, fontWeight: FontWeight.w700)),
            const Spacer(),
            Text(m.ago, style: T.tiny),
          ]),
        ],
      ),
    );
  }
}

/// The shareable card — a TikTok-ready graphic. In production this renders to a
/// short watermarked video/image; here it's the pixel-perfect card + share.
class ShareCardScreen extends StatelessWidget {
  const ShareCardScreen({super.key, required this.moment});
  final Moment moment;

  static void push(BuildContext context, Moment m) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ShareCardScreen(moment: m)));
  }

  void _toast(BuildContext c, String m) {
    ScaffoldMessenger.of(c)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating, backgroundColor: C.char3,
        content: Text(m, style: T.sub.copyWith(color: Colors.white))));
  }

  @override
  Widget build(BuildContext context) {
    final m = moment;
    return Scaffold(
      backgroundColor: C.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Press(
                  onTap: () => Navigator.of(context).maybePop(),
                  child: Container(
                    width: 38, height: 38, margin: const EdgeInsets.only(top: 6),
                    decoration: BoxDecoration(shape: BoxShape.circle, color: C.glass, border: Border.all(color: C.hair)),
                    child: const Icon(Icons.close_rounded, size: 20, color: C.tx2),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 9 / 15,
                    child: _ShareCard(m),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Press(
                      onTap: () { Buzz.commit(); _toast(context, 'link copied — paste it anywhere 🔗'); },
                      child: Container(
                        height: 56, alignment: Alignment.center,
                        decoration: BoxDecoration(color: C.glass, borderRadius: BorderRadius.circular(18), border: Border.all(color: C.hair2)),
                        child: Text('Copy link', style: T.body.copyWith(color: C.tx, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Press(
                      haptic: false,
                      onTap: () { Buzz.impact(); _toast(context, 'sharing to your story ✨'); },
                      child: Container(
                        height: 56, alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [C.sig, C.purpleDeep]),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [BoxShadow(color: C.sigGlow, blurRadius: 26, spreadRadius: -6)],
                        ),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.ios_share_rounded, size: 20, color: Colors.white),
                          const SizedBox(width: 8),
                          Text('Share', style: T.body.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                        ]),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShareCard extends StatelessWidget {
  const _ShareCard(this.m);
  final Moment m;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color(0xFF17091F), Color(0xFF090A10)],
        ),
        border: Border.all(color: C.hair2),
        boxShadow: [BoxShadow(color: C.sigGlow, blurRadius: 50, spreadRadius: -20)],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -30, right: -20,
            child: Container(
              width: 200, height: 200,
              decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [C.sig.withOpacity(0.5), Colors.transparent])),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Wordmark(size: 22),
                const Spacer(),
                Text(m.game.toUpperCase(), style: T.eyebrow.copyWith(color: C.sig, letterSpacing: 2)),
                const SizedBox(height: 14),
                Text(m.result, style: T.huge(34).copyWith(height: 1.08)),
                const SizedBox(height: 20),
                Row(children: [
                  for (final h in m.hues.take(6)) Padding(padding: const EdgeInsets.only(right: 6), child: IdentityOrb(hue: h, size: 34)),
                ]),
                const SizedBox(height: 16),
                Text('😂 ${m.laughs} laughs', style: T.body.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(100), border: Border.all(color: C.hair)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Text('▶', style: TextStyle(color: Colors.white, fontSize: 12)),
                    const SizedBox(width: 8),
                    Text('meet strangers on rivlr', style: T.tiny.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
