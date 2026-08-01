import 'package:flutter/material.dart';
import '../config.dart';
import '../core/camera_service.dart';
import '../core/haptics.dart';
import '../theme/tokens.dart';
import '../widgets/glass.dart';
import '../widgets/self_view.dart';

/// First run, ≤60s to a live face. Opens on a value moment, not a form. The 18+
/// gate and camera permission are framed as "getting ready", requested at the
/// moment of intent (the button), never as a wall.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _asked = false;

  Future<void> _go() async {
    Buzz.commit();
    setState(() => _asked = true);
    // In simulated mode the camera plugin powers the self-view. In live mode
    // LiveKit owns the camera (and prompts for permission on first match), so we
    // don't open the plugin here — that would fight LiveKit for the device.
    if (!AppConfig.isLive) {
      await CameraService.instance.ensure();
    }
    if (mounted) widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    return Scaffold(
      backgroundColor: C.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // a faint self-preview already breathing behind the words
          const Opacity(opacity: 0.5, child: SelfView(grade: true, label: null)),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: r.gutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Wordmark(size: 30),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                        decoration: BoxDecoration(
                          color: C.glass,
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(color: C.hair),
                        ),
                        child: Text('18+ · verified adults', style: T.tiny),
                      ),
                    ],
                  ),
                  const Spacer(),
                  RichText(
                    text: TextSpan(
                      style: T.huge(44 * r.scale),
                      children: const [
                        TextSpan(text: 'Meet someone\nnew. '),
                        TextSpan(text: 'Right now', style: TextStyle(color: C.sig)),
                        TextSpan(text: '.'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'One tap drops you live with a stranger — sometimes a few. '
                    'You never know who you’ll get. That’s the fun.',
                    style: T.body.copyWith(fontSize: 17),
                  ),
                  const SizedBox(height: 34),
                  Cta(
                    label: _asked ? 'Getting ready…' : 'Enable camera & go',
                    onTap: _asked ? null : _go,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(Icons.lock_outline_rounded, size: 14, color: C.tx3),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Groups, not just strangers. Report or block anyone, instantly. '
                          'We never record your video.',
                          style: T.tiny.copyWith(height: 1.35),
                        ),
                      ),
                    ],
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
