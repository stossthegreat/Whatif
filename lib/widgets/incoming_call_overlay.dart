import 'package:flutter/material.dart';
import '../core/haptics.dart';
import '../core/sound.dart';
import '../net/network_client.dart';
import '../state/social.dart';
import '../theme/tokens.dart';
import '../widgets/glass.dart';
import '../widgets/identity_orb.dart';

/// A friend is calling. Full-screen ring with accept/decline — floats over
/// everything except a live room (rooms auto-decline as busy).
class IncomingCallOverlay extends StatefulWidget {
  const IncomingCallOverlay({super.key, required this.call, required this.onAccept});
  final IncomingCall call;
  final VoidCallback onAccept;

  @override
  State<IncomingCallOverlay> createState() => _IncomingCallOverlayState();
}

class _IncomingCallOverlayState extends State<IncomingCallOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
        ..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    Buzz.impact();
    Sfx.match();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.call;
    return Positioned.fill(
      child: Container(
        color: const Color(0xF2000000),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),
              AnimatedBuilder(
                animation: _pulse,
                builder: (context, _) => Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: C.sig.withOpacity(0.25 + 0.25 * _pulse.value),
                        blurRadius: 50, spreadRadius: 6,
                      ),
                    ],
                  ),
                  child: IdentityOrb(hue: c.hue, size: 110, ring: C.sig),
                ),
              ),
              const SizedBox(height: 22),
              Text('@${c.name}', style: T.huge(30)),
              const SizedBox(height: 8),
              Text(c.video ? '📹 video call' : '📞 voice call',
                  style: T.body.copyWith(color: C.tx2, fontSize: 15)),
              const Spacer(flex: 3),
              Padding(
                padding: const EdgeInsets.only(bottom: 60),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _round(Icons.call_end_rounded, C.live, () {
                      Buzz.tick();
                      NetworkClient.instance.callDecline(c.callId);
                      SocialState.instance.clearIncomingCall();
                    }),
                    const SizedBox(width: 70),
                    _round(Icons.call_rounded, const Color(0xFF30D158), () {
                      Buzz.commit();
                      Sfx.pop();
                      widget.onAccept();
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _round(IconData icon, Color color, VoidCallback onTap) {
    return Press(
      haptic: false,
      onTap: onTap,
      child: Container(
        width: 72, height: 72,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        child: Icon(icon, size: 32, color: Colors.white),
      ),
    );
  }
}
