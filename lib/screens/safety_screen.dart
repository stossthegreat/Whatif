import 'package:flutter/material.dart';
import '../state/session.dart';
import '../theme/tokens.dart';
import 'legal_screen.dart';
import 'onboarding_shell.dart';

/// The trust screen. The old version was a list of rules being imposed on you;
/// this presents the same commitments as things you're GETTING — which is both
/// friendlier and what App Review wants to see spelled out.
///
/// Every claim here is one we can actually defend, and the prohibitions match
/// Terms §5 word for word in plain language.
class SafetyScreen extends StatelessWidget {
  const SafetyScreen({super.key, required this.onAgree, required this.onBack});
  final VoidCallback onAgree;
  final VoidCallback onBack;

  static const _pillars = [
    (
      Icons.videocam_off_rounded,
      Color(0xFF3BE07A),
      'Never recorded',
      'Room video and audio are never recorded, stored or analysed. When a room ends, it’s gone.',
    ),
    (
      Icons.verified_user_rounded,
      Color(0xFFA36BFF),
      'Adults only',
      'Everyone confirms they’re 18+. Under-18 accounts are removed on sight.',
    ),
    (
      Icons.block_rounded,
      Color(0xFFFF3B5C),
      'Block instantly',
      'One tap, any room. They can never be matched with you again.',
    ),
    (
      Icons.flag_rounded,
      Color(0xFF4DA6FF),
      'Reports read by humans',
      'Every report is reviewed within 24 hours — nudity and safety reports jump the queue.',
    ),
    (
      Icons.lock_rounded,
      Color(0xFFFFD54A),
      'No ads, nothing sold',
      'We don’t track you, don’t sell your data, and never train AI on your conversations.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return OnboardStep(
      step: 7,
      total: 7,
      title: 'How we keep this good.',
      accent: 'good',
      onBack: onBack,
      ctaLabel: 'I agree — let me in',
      onCta: () {
        AppSession.instance.acceptRules();
        onAgree();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final p in _pillars) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: p.$2.withOpacity(0.14),
                    border: Border.all(color: p.$2.withOpacity(0.5)),
                  ),
                  child: Icon(p.$1, size: 20, color: p.$2),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.$3,
                          style: T.body.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16)),
                      const SizedBox(height: 3),
                      Text(p.$4,
                          style: T.sub.copyWith(fontSize: 13.5, height: 1.35)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: C.glass,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: C.hair2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AND THE RULES', style: T.eyebrow),
                const SizedBox(height: 9),
                Text(
                  'No nudity or sexual content. No harassment, hate or threats. '
                  'No one under 18. No pretending to be someone else. '
                  'And never record anyone — we don’t, and neither do you.\n\n'
                  'Break these and you’re removed.',
                  style: T.sub.copyWith(fontSize: 13.5, height: 1.45),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => LegalScreen.push(context, 'House Rules', LegalCopy.rules),
                  child: Text('Read the full House Rules',
                      style: T.tiny.copyWith(
                          color: C.sig,
                          fontWeight: FontWeight.w800,
                          decoration: TextDecoration.underline,
                          decorationColor: C.sig)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
