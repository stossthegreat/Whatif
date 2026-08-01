import 'package:flutter/material.dart';
import '../core/haptics.dart';
import '../theme/tokens.dart';
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
          const Opacity(opacity: 0.45, child: SelfView(grade: true)),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: r.gutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 18),
                  Row(children: [
                    const Text('What', style: T.mark),
                    Text('If', style: T.mark.copyWith(fontWeight: FontWeight.w800)),
                  ]),
                  const Spacer(),
                  Text('Meet someone\nnew. Every\nsingle night.', style: T.huge(46 * r.scale)),
                  const SizedBox(height: 18),
                  Text(
                    'One tap. A live room of strangers. A quick game to break the ice. '
                    'You never know who you’ll get.',
                    style: T.body.copyWith(fontSize: 17),
                  ),
                  const SizedBox(height: 34),
                  Press(
                    haptic: false,
                    onTap: () { Buzz.commit(); onNext(); },
                    child: Container(
                      height: 62,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                      child: Text('Get started', style: T.h3.copyWith(color: Colors.black, fontSize: 17)),
                    ),
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
