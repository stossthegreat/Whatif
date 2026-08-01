import 'package:flutter/material.dart';
import '../state/session.dart';
import '../theme/tokens.dart';
import '../widgets/play_button.dart';
import '../widgets/self_view.dart';

/// Home — already alive. Your mirrored self-view fills the screen (getting-ready
/// delight), one PLAY, a live count. No menu, no feed. The whole screen is a dare.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onPlay});
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    return Scaffold(
      backgroundColor: C.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const SelfView(grade: true),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: r.gutter),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Row(children: [
                        const Text('What', style: T.mark),
                        Text('If', style: T.mark.copyWith(fontWeight: FontWeight.w800)),
                      ]),
                      const Spacer(),
                      AnimatedBuilder(
                        animation: AppSession.instance,
                        builder: (context, _) => Row(
                          children: [
                            Container(width: 6, height: 6, decoration: BoxDecoration(
                              shape: BoxShape.circle, color: C.live,
                              boxShadow: [BoxShadow(color: C.live.withOpacity(0.6), blurRadius: 8)],
                            )),
                            const SizedBox(width: 7),
                            Text('${AppSession.instance.liveCount.toString().replaceAllMapped(
                                  RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')} live',
                                style: T.tiny.copyWith(color: C.tx2, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text('press to meet someone',
                      style: T.sub.copyWith(color: Colors.white.withOpacity(0.8))),
                  const SizedBox(height: 22),
                  PlayButton(onTap: onPlay),
                  const SizedBox(height: 30),
                  Text('YOU NEVER KNOW WHO YOU’LL GET',
                      style: T.eyebrow.copyWith(fontSize: 11, letterSpacing: 2.2)),
                  const SizedBox(height: 20),
                  AnimatedBuilder(
                    animation: AppSession.instance,
                    builder: (context, _) {
                      final n = AppSession.instance.saved.length;
                      return AnimatedOpacity(
                        duration: M.quick,
                        opacity: n > 0 ? 1 : 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: C.glass,
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(color: C.hair),
                          ),
                          child: Text('♡ $n saved', style: T.tiny.copyWith(color: C.tx2)),
                        ),
                      );
                    },
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
