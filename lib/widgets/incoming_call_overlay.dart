import 'dart:async';
import 'package:flutter/material.dart';
import '../core/haptics.dart';
import '../core/sound.dart';
import '../net/network_client.dart';
import '../state/social.dart';
import '../theme/tokens.dart';
import '../widgets/avatar.dart';
import '../widgets/glass.dart';

/// Someone wants you on camera — a friend calling, or a stranger's meet
/// request from Explore. One dark card, their face big, one giant gradient
/// ACCEPT with the seconds draining, and a quiet Skip. Floats over
/// everything except a live room (rooms auto-decline as busy).
///
/// The countdown is cosmetic: the server times the ring out at 30s and its
/// `callState: timeout` clears [SocialState.incomingCall], which unmounts
/// this overlay — no local dismissal logic.
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
  Timer? _tick;
  int _left = 30; // mirrors the server's ring timeout

  @override
  void initState() {
    super.initState();
    Buzz.impact();
    Sfx.match();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_left > 0) setState(() => _left--);
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  /// Callers who are friends get their photo and title; strangers from
  /// Explore simply aren't in the list and fall back to the orb.
  FriendInfo? get _friend {
    for (final f in SocialState.instance.friends) {
      if (f.uid == widget.call.uid) return f;
    }
    return null;
  }

  void _decline() {
    Buzz.tick();
    NetworkClient.instance.callDecline(widget.call.callId);
    SocialState.instance.clearIncomingCall();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.call;
    final f = _friend;
    // the card glows in the caller's own hue, blended into brand purple
    final safeHue = ((c.hue % 360) + 360) % 360;
    final tint = Color.lerp(const Color(0xFF8B3DFF),
        HSLColor.fromAHSL(1.0, safeHue, 0.55, 0.5).toColor(), 0.4)!;
    return Positioned.fill(
      child: Container(
        color: const Color(0xF2000000),
        child: SafeArea(
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              constraints: const BoxConstraints(maxWidth: 380),
              padding: const EdgeInsets.fromLTRB(24, 34, 24, 22),
              decoration: BoxDecoration(
                color: C.char2,
                borderRadius: BorderRadius.circular(R.card + 4),
                border: Border.all(color: C.hair2),
                boxShadow: [
                  BoxShadow(
                      color: tint.withOpacity(0.55), blurRadius: 60, spreadRadius: -18),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                      child: Avatar(
                          hue: c.hue, photoId: f?.photoId, size: 116, ring: C.sig),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('@${c.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: T.display(27)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    alignment: WrapAlignment.center,
                    children: [
                      _chip(c.video ? '📹 VIDEO CALL' : '📞 VOICE CALL'),
                      if (f?.title != null && f!.title!.isNotEmpty) _chip(f.title!),
                    ],
                  ),
                  const SizedBox(height: 26),
                  Press(
                    haptic: false,
                    onTap: () {
                      Buzz.commit();
                      Sfx.pop();
                      widget.onAccept();
                    },
                    child: Container(
                      height: 58,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: C.gradSigHot,
                        borderRadius: BorderRadius.circular(R.btn),
                        border: Border.all(color: const Color(0x38FFFFFF)),
                        boxShadow: C.glowSig(),
                      ),
                      child: Text('Accept ($_left)',
                          style: T.display(18).copyWith(letterSpacing: 0.6)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Press(
                    haptic: false,
                    onTap: _decline,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                      child: Text('Skip',
                          style: T.body.copyWith(
                              color: C.tx2, fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: C.glass2,
        borderRadius: BorderRadius.circular(R.chip),
        border: Border.all(color: C.hair2),
      ),
      child: Text(label,
          style: T.tiny.copyWith(
              color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800)),
    );
  }
}
