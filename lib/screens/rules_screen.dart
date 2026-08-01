import 'package:flutter/material.dart';
import '../core/haptics.dart';
import '../state/session.dart';
import '../theme/tokens.dart';
import '../widgets/aurora.dart';
import '../widgets/glass.dart';

/// House Rules — the agreement beat App Review requires for user-generated
/// content (and the promise that makes strangers feel safe). Four rules,
/// one accept. Elite-minimal.
class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key, required this.onAgree});
  final VoidCallback onAgree;

  static const _rules = [
    (Icons.verified_user_outlined, '18+ only', 'Everyone here is an adult. No exceptions.'),
    (Icons.favorite_border_rounded, 'Be decent on camera', 'No nudity, harassment, hate, or threats — instant ban.'),
    (Icons.videocam_off_outlined, 'Never record anyone', 'Rooms are never recorded by us — don’t you record them either.'),
    (Icons.gavel_rounded, 'The room protects itself', 'Report or block anyone with a long-press. Reports remove people fast.'),
  ];

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    return Scaffold(
      backgroundColor: C.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Aurora(orbs: 3, opacity: 0.6),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: r.gutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 18),
                  const Wordmark(size: 30),
                  const Spacer(),
                  RichText(
                    text: TextSpan(
                      style: T.huge(40 * r.scale),
                      children: const [
                        TextSpan(text: 'House '),
                        TextSpan(text: 'rules', style: TextStyle(color: C.sig)),
                        TextSpan(text: '.'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text('Four of them. They keep this place good.',
                      style: T.body.copyWith(fontSize: 15, color: C.tx2)),
                  const SizedBox(height: 28),
                  for (final rule in _rules) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: C.hair2),
                          ),
                          child: Icon(rule.$1, size: 19, color: Colors.white),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(rule.$2,
                                  style: T.body.copyWith(
                                      color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                              const SizedBox(height: 2),
                              Text(rule.$3, style: T.sub.copyWith(color: C.tx2, fontSize: 13.5, height: 1.3)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                  ],
                  const Spacer(),
                  Cta(
                    label: 'I agree — let me in',
                    onTap: () {
                      Buzz.commit();
                      AppSession.instance.acceptRules();
                      onAgree();
                    },
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: Text('Breaking these gets you removed. The room decides fast.',
                        style: T.tiny),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
