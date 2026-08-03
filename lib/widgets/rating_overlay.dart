import 'package:flutter/material.dart';
import '../core/haptics.dart';
import '../core/sound.dart';
import '../state/social.dart';
import 'avatar.dart';
import '../theme/tokens.dart';
import '../widgets/glass.dart';
import '../widgets/identity_orb.dart';

/// THE signature question — floats over finding/home after a room ends, never
/// a blocking step. Four answers; both sides Friend+ → the match fires.
class RatingOverlay extends StatelessWidget {
  const RatingOverlay({super.key, required this.item});
  final RatePromptItem item;

  static const _options = [
    (0, '💀', 'Never again'),
    (1, '🤝', 'Friend'),
    (2, '🔥', 'Definitely'),
    (3, '👑', 'Legend'),
  ];

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: M.base,
        curve: M.ease,
        builder: (context, v, child) => Opacity(opacity: v, child: child),
        child: Container(
          color: const Color(0xE6000000),
          child: SafeArea(
            child: Stack(
              children: [
                Positioned(
                  top: 8, right: 16,
                  child: Press(
                    onTap: () { Buzz.tick(); SocialState.instance.skipRate(item); },
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle, color: C.glass, border: Border.all(color: C.hair)),
                      child: const Icon(Icons.close_rounded, size: 19, color: C.tx2),
                    ),
                  ),
                ),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                              child: Avatar(
                                  hue: item.hue, photoId: item.photoId, size: 84)),
                          const SizedBox(height: 14),
                          Center(
                            child: Text('@${item.name}',
                                style: T.h3.copyWith(color: C.tx2, fontSize: 17)),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Would you meet\nthem again?',
                            textAlign: TextAlign.center,
                            style: T.huge(30),
                          ),
                          const SizedBox(height: 26),
                          for (final (score, emoji, label) in _options) ...[
                            Press(
                              haptic: false,
                              onTap: () {
                                Buzz.commit();
                                if (score >= 1) Sfx.pop();
                                SocialState.instance.rate(item, score);
                              },
                              child: Container(
                                height: 54,
                                padding: const EdgeInsets.symmetric(horizontal: 18),
                                decoration: BoxDecoration(
                                  color: score >= 1 ? C.glass : Colors.transparent,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: score == 3 ? C.sig : C.hair2),
                                ),
                                child: Row(
                                  children: [
                                    Text(emoji, style: const TextStyle(fontSize: 20)),
                                    const SizedBox(width: 12),
                                    Text(label,
                                        style: T.body.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                        )),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                          const SizedBox(height: 2),
                          Center(
                            child: Text('friend or higher, both ways = you match',
                                style: T.tiny.copyWith(color: C.tx3)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
