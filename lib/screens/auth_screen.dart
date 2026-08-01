import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/haptics.dart';
import '../models/mock_data.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../widgets/aurora_button.dart';
import '../widgets/gradient_text.dart';
import '../widgets/presence_orb.dart';
import '../widgets/reveal.dart';
import '../widgets/whatif_scaffold.dart';

/// Sign-in. No form. No "create a password". Three one-tap doors and you're
/// through. The hero line is *social proof* — a live count of who's already
/// inside — because the research is clear: the reason to join is "your people
/// are already here," not "make an account." Safety is stated up front as a
/// brand value, not buried in a ToS.
class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key, required this.onAuthed});
  final VoidCallback onAuthed;

  @override
  Widget build(BuildContext context) {
    return WhatIfScaffold(
      energy: 0.55,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const Spacer(flex: 2),
            // A little live crowd floating above the copy.
            const Reveal(child: _FloatingCrowd()),
            const Spacer(),
            Reveal(
              delay: const Duration(milliseconds: 120),
              child: Column(
                children: [
                  const Wordmark(fontSize: 34),
                  const SizedBox(height: 20),
                  GradientText(
                    'Your people are\nalready inside.',
                    textAlign: TextAlign.center,
                    style: WhatIfType.h1.copyWith(fontSize: 34, height: 1.08),
                    gradient: const LinearGradient(colors: [Colors.white, Colors.white]),
                  ),
                  const SizedBox(height: 14),
                  _LiveCounter(),
                ],
              ),
            ),
            const Spacer(flex: 2),
            // The three doors.
            Reveal(
              delay: const Duration(milliseconds: 240),
              child: AuroraButton(
                label: 'Continue with Apple',
                icon: Icons.apple,
                gradient: const [Colors.white, Color(0xFFE9E9F2)],
                onTap: onAuthed,
              ),
            ),
            const SizedBox(height: 12),
            Reveal(
              delay: const Duration(milliseconds: 300),
              child: GhostButton(
                label: 'Continue with Google',
                icon: Icons.g_mobiledata_rounded,
                onTap: () {
                  Buzz.commit();
                  onAuthed();
                },
              ),
            ),
            const SizedBox(height: 12),
            Reveal(
              delay: const Duration(milliseconds: 360),
              child: GhostButton(
                label: 'Use phone number',
                icon: Icons.phone_iphone_rounded,
                onTap: () {
                  Buzz.commit();
                  onAuthed();
                },
              ),
            ),
            const SizedBox(height: 18),
            Reveal(
              delay: const Duration(milliseconds: 440),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.verified_user_rounded, size: 14, color: WhatIfColors.mint),
                  const SizedBox(width: 6),
                  Text('Age-checked. Groups, not strangers. Report anyone, instantly.',
                      style: WhatIfType.caption.copyWith(fontSize: 11, color: WhatIfColors.textLow)),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }
}

class _LiveCounter extends StatefulWidget {
  @override
  State<_LiveCounter> createState() => _LiveCounterState();
}

class _LiveCounterState extends State<_LiveCounter> {
  int _n = 2841;
  @override
  void initState() {
    super.initState();
    // Tick the count so it feels alive.
    _bump();
  }

  void _bump() async {
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    setState(() => _n += 1 + (DateTime.now().millisecond % 4));
    _bump();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: WhatIfColors.live),
        ),
        const SizedBox(width: 8),
        Text(
          '$_n playing right now',
          style: WhatIfType.label.copyWith(color: WhatIfColors.textMed, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

/// A small arc of orbs bobbing gently above the copy.
class _FloatingCrowd extends StatefulWidget {
  const _FloatingCrowd();
  @override
  State<_FloatingCrowd> createState() => _FloatingCrowdState();
}

class _FloatingCrowdState extends State<_FloatingCrowd>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final crowd = Mock.group(5, from: 1);
    return SizedBox(
      height: 110,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          return Stack(
            alignment: Alignment.center,
            children: [
              for (var i = 0; i < crowd.length; i++)
                Transform.translate(
                  offset: Offset(
                    (i - 2) * 62.0,
                    math.sin((_c.value * 2 * math.pi) + i) * 8 - (i == 2 ? 10 : 0),
                  ),
                  child: PresenceOrb(
                    identity: crowd[i],
                    size: i == 2 ? 58 : 44,
                    active: i == 2,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
