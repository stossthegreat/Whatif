import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/apple_auth.dart';
import '../core/haptics.dart';
import '../core/sound.dart';
import '../state/session.dart';
import '../state/social.dart';
import 'avatar.dart';
import '../theme/tokens.dart';
import '../widgets/glass.dart';
import '../widgets/identity_orb.dart';

/// 🎉 The payoff. Both of you said "meet again" — the two orbs pull together,
/// a burst of particles, and a friendship exists that didn't before.
class MatchOverlay extends StatefulWidget {
  const MatchOverlay({super.key, required this.friend, required this.onSeePeople});
  final FriendInfo friend;
  final VoidCallback onSeePeople;

  @override
  State<MatchOverlay> createState() => _MatchOverlayState();
}

class _MatchOverlayState extends State<MatchOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..forward();

  @override
  void initState() {
    super.initState();
    Buzz.impact();
    Sfx.fanfare();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.friend;
    return Positioned.fill(
      child: Container(
        color: const Color(0xF2000000),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final t = Curves.easeOutBack.transform(_c.value.clamp(0.0, 1.0));
              return Stack(
                children: [
                  // particle burst
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(painter: _BurstPainter(_c.value, f.hue)),
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // the two orbs pull together
                        SizedBox(
                          height: 96,
                          child: Stack(
                            alignment: Alignment.center,
                            clipBehavior: Clip.none,
                            children: [
                              Transform.translate(
                                offset: Offset(-70 + 34 * t, 0),
                                child: Avatar(
                                    hue: AppSession.instance.myHue,
                                    photoId: AppSession.instance.photoId,
                                    size: 84,
                                    ring: C.sig),
                              ),
                              Transform.translate(
                                offset: Offset(70 - 34 * t, 0),
                                child: Avatar(
                                    hue: f.hue, photoId: f.photoId, size: 84, ring: C.sig),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 26),
                        Opacity(
                          opacity: t.clamp(0.0, 1.0),
                          child: Column(
                            children: [
                              Text('🎉  It’s mutual', style: T.huge(34), textAlign: TextAlign.center),
                              const SizedBox(height: 10),
                              Text('@${f.name} is in your people now',
                                  style: T.body.copyWith(color: C.tx2, fontSize: 16)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 34),
                        Opacity(
                          opacity: t.clamp(0.0, 1.0),
                          child: Column(
                            children: [
                              SizedBox(
                                width: 240,
                                child: Cta(label: 'See your people', onTap: () {
                                  Buzz.commit();
                                  SocialState.instance.popCelebration();
                                  widget.onSeePeople();
                                }),
                              ),
                              const SizedBox(height: 12),
                              Press(
                                haptic: false,
                                onTap: () { Buzz.tick(); SocialState.instance.popCelebration(); },
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Text('keep playing',
                                      style: T.body.copyWith(color: C.tx3, fontWeight: FontWeight.w600)),
                                ),
                              ),
                              if (!AppSession.instance.signedIn) ...[
                                const SizedBox(height: 14),
                                Press(
                                  haptic: false,
                                  onTap: () async {
                                    Buzz.commit();
                                    await appleSignIn();
                                    if (mounted) setState(() {});
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 24),
                                    child: Text(
                                      '⭐ you’re a guest — sign in with Apple so your people are never lost',
                                      textAlign: TextAlign.center,
                                      style: T.tiny.copyWith(
                                          color: C.sig, fontWeight: FontWeight.w700, height: 1.5),
                                    ),
                                  ),
                                ),
                              ],
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
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  _BurstPainter(this.t, this.hue);
  final double t;
  final double hue;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0.05) return;
    final center = Offset(size.width / 2, size.height / 2 - 60);
    final p = Paint();
    final rng = math.Random(7);
    for (var i = 0; i < 26; i++) {
      final ang = rng.nextDouble() * math.pi * 2;
      final speed = 90 + rng.nextDouble() * 150;
      final dist = speed * Curves.easeOut.transform(t);
      final op = (1 - t).clamp(0.0, 1.0);
      final col = i.isEven ? C.sig : HSLColor.fromAHSL(1, hue, 0.7, 0.65).toColor();
      p.color = col.withOpacity(op * 0.85);
      canvas.drawCircle(
        center + Offset(math.cos(ang) * dist, math.sin(ang) * dist),
        2.2 + rng.nextDouble() * 2.4,
        p,
      );
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.t != t;
}
