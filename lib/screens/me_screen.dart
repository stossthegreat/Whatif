import 'package:flutter/material.dart';
import '../state/session.dart';
import '../theme/tokens.dart';
import '../widgets/glass.dart';
import '../widgets/identity_orb.dart';

/// Your profile — funny, not serious. Your glow, your rank, and the stats that
/// matter here: streak, laughs, biggest-liar, chaos score, sparks.
class MeScreen extends StatelessWidget {
  const MeScreen({super.key});

  static void push(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MeScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.black,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: AppSession.instance,
          builder: (context, _) {
            final s = AppSession.instance;
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 30),
              children: [
                Row(
                  children: [
                    Press(
                      onTap: () => Navigator.of(context).maybePop(),
                      child: Container(
                        width: 38, height: 38,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: C.glass, border: Border.all(color: C.hair)),
                        child: const Icon(Icons.arrow_back_rounded, size: 20, color: C.tx2),
                      ),
                    ),
                    const Spacer(),
                    Press(
                      onTap: () {},
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          color: C.glass, borderRadius: BorderRadius.circular(100), border: Border.all(color: C.hair)),
                        child: Text('share', style: T.tiny.copyWith(color: C.tx, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Center(
                  child: Column(
                    children: [
                      IdentityOrb(hue: s.myHue, size: 108, ring: C.sig),
                      const SizedBox(height: 16),
                      Text('@${s.myHandle}', style: T.big.copyWith(fontSize: 26)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [C.sig.withOpacity(0.3), C.purpleDeep.withOpacity(0.25)]),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(color: C.sig.withOpacity(0.5)),
                        ),
                        child: Text(s.rankTitle, style: T.body.copyWith(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.5,
                  children: [
                    _Stat('🔥', '${s.streak}', 'day streak'),
                    _Stat('🎬', '${s.matchesPlayed}', 'rooms'),
                    _Stat('😂', '${s.laughs}', 'laughs'),
                    _Stat('🤥', '${s.lies}', 'lies told'),
                    _Stat('🌀', '${s.chaosScore}', 'chaos score'),
                    _Stat('✨', '${s.sparks.length}', 'sparks'),
                  ],
                ),
                const SizedBox(height: 20),
                Glass(
                  radius: 24,
                  child: Row(
                    children: [
                      const Text('🎞️', style: TextStyle(fontSize: 30)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Your funniest moment', style: T.body.copyWith(color: C.tx, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 3),
                            Text('auto-saved clips land here — play a few rooms', style: T.tiny),
                          ],
                        ),
                      ),
                    ],
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

class _Stat extends StatelessWidget {
  const _Stat(this.emoji, this.value, this.label);
  final String emoji;
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Glass(
      radius: 22,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: T.mono.copyWith(fontSize: 28)),
              Text(label, style: T.tiny),
            ],
          ),
        ],
      ),
    );
  }
}
