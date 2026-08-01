import 'package:flutter/material.dart';
import '../core/haptics.dart';
import '../theme/tokens.dart';
import '../widgets/aurora.dart';
import '../widgets/glass.dart';
import '../widgets/self_view.dart';

/// First thing you see. A value moment, not a form.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.onNext});
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    return Scaffold(
      backgroundColor: C.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Opacity(opacity: 0.4, child: SelfView(grade: true)),
          const Aurora(orbs: 3, opacity: 0.8),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: r.gutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 18),
                  const Wordmark(size: 21),
                  const Spacer(),
                  RichText(
                    text: TextSpan(
                      style: T.huge(46 * r.scale),
                      children: const [
                        TextSpan(text: 'Meet someone\n'),
                        TextSpan(text: 'new', style: TextStyle(color: C.sig)),
                        TextSpan(text: '. Every\nsingle night.'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'One tap. A live room of strangers. A quick game to break the ice. '
                    'You never know who you’ll get.',
                    style: T.body.copyWith(fontSize: 17, color: Colors.white70),
                  ),
                  const SizedBox(height: 34),
                  Cta(
                    label: 'Get started',
                    onTap: () { Buzz.commit(); onNext(); },
                  ),
                  const SizedBox(height: 26),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
