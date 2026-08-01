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
  const MomentsScreen({super.key, this.embedded = false});

  /// Hides the back button when shown as a bottom-nav tab.
  final bool embedded;

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
                      if (!embedded) ...[
                        Press(
                          onTap: () => Navigator.of(context).maybePop(),
                          child: Container(
                            width: 38, height: 38,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: C.glass, border: Border.all(color: C.hair)),
                            child: const Icon(Icons.arrow_back_rounded, size: 20, color: C.tx2),
                          ),
                        ),
                        const SizedBox(width: 14),
                      ],
                      Text('Your moments', style: T.big.copyWith(fontSize: 26)),
                    ],
                  ),
                ),
                Expanded(
                  child: moments.isEmpty
                      ? const _EmptyMoments()
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

/// A captured moment as a mini share-card — dark gradient, a purple glow, the
/// game tag, the punchline in bold, the people who were there, and the laughs.
/// Tapping opens the full shareable card.
class _MomentCard extends StatelessWidget {
  const _MomentCard(this.m);
  final Moment m;
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0xFF17091F), Color(0xFF0A0B10)],
          ),
          border: Border.all(color: C.hair2),
        ),
        child: Stack(
          children: [
            // purple glow, top-right
            Positioned(
              top: -34, right: -30,
              child: Container(
                width: 120, height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [C.sig.withOpacity(0.45), Colors.transparent]),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(m.game.toUpperCase(), style: T.eyebrow.copyWith(color: C.sig, fontSize: 9.5, letterSpacing: 1.6)),
                      const Spacer(),
                      const Icon(Icons.play_circle_fill_rounded, size: 18, color: Colors.white24),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Text(m.result,
                        style: T.h3.copyWith(color: Colors.white, fontWeight: FontWeight.w800, height: 1.16, fontSize: 17)),
                  ),
                  Row(children: [
                    for (final h in m.hues.take(4))
                      Align(
                        widthFactor: 0.7,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF0A0B10), width: 2),
                          ),
                          child: IdentityOrb(hue: h, size: 24),
                        ),
                      ),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Text('😂 ${m.laughs}', style: T.tiny.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                    const Spacer(),
                    Text(m.ago, style: T.tiny.copyWith(color: C.tx3)),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A designed empty state — never a lonely line of text.
class _EmptyMoments extends StatelessWidget {
  const _EmptyMoments();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 92, height: 92,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [C.sig.withOpacity(0.3), C.purpleDeep.withOpacity(0.2)]),
                border: Border.all(color: C.sig.withOpacity(0.5)),
                boxShadow: [BoxShadow(color: C.sigGlow, blurRadius: 34, spreadRadius: -10)],
              ),
              child: const Text('🎬', style: TextStyle(fontSize: 40)),
            ),
            const SizedBox(height: 22),
            Text('Your moments live here', style: T.big.copyWith(fontSize: 22), textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text('Every big reveal gets captured as a card built to share. Drop into a room and make one.',
                style: T.body, textAlign: TextAlign.center),
          ],
        ),
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
                const Wordmark(size: 26),
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
