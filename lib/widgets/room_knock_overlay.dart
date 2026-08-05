import 'package:flutter/material.dart';
import '../core/haptics.dart';
import '../core/sound.dart';
import '../state/social.dart';
import '../theme/tokens.dart';
import 'avatar.dart';
import 'glass.dart';

/// A friend is holding a room open for you.
///
/// This is the whole of "linking up" from the other side: one card, their
/// face, one Join. No code to read, no message to open, nothing to type.
/// Unlike a call there's no countdown — the room stays open until they close
/// it, so the knock waits as long as it needs to and Later just dismisses it.
class RoomKnockOverlay extends StatefulWidget {
  const RoomKnockOverlay({super.key, required this.knock, required this.onJoin});
  final RoomKnock knock;
  final VoidCallback onJoin;

  @override
  State<RoomKnockOverlay> createState() => _RoomKnockOverlayState();
}

class _RoomKnockOverlayState extends State<RoomKnockOverlay>
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

  /// Their photo if we already hold it — the knock only ever comes from a
  /// friend, so this is nearly always a hit.
  int? get _photoId => SocialState.instance.photoOf(widget.knock.uid);

  @override
  Widget build(BuildContext context) {
    final k = widget.knock;
    final safeHue = ((k.hue % 360) + 360) % 360;
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
                          hue: k.hue, photoId: _photoId, size: 116, ring: C.sig),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('@${k.name}',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: T.display(27)),
                  const SizedBox(height: 8),
                  Text('wants you in their room',
                      style: T.body.copyWith(
                          color: C.tx2, fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 26),
                  Press(
                    haptic: false,
                    onTap: () {
                      Buzz.commit();
                      Sfx.pop();
                      widget.onJoin();
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
                      child: Text('Join', style: T.display(18).copyWith(letterSpacing: 0.6)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Press(
                    haptic: false,
                    onTap: () {
                      Buzz.tick();
                      SocialState.instance.clearKnock();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                      child: Text('Later',
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
}
