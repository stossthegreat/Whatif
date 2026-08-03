import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/tokens.dart';

/// The Portal — Rivlr's living mark and the Home hero. A breathing ring
/// stroked in the signature gradient with an acid comet orbiting it; the
/// call to action sits inside. Nobody else has this: it's a doorway, not a
/// button, and it's always moving.
class PortalRing extends StatefulWidget {
  const PortalRing({super.key, required this.title, required this.line, this.size = 250});
  final String title;
  final String line;
  final double size;

  @override
  State<PortalRing> createState() => _PortalRingState();
}

class _PortalRingState extends State<PortalRing> with TickerProviderStateMixin {
  // breath: radius + glow swell
  late final AnimationController _breath = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1600))
    ..repeat(reverse: true);
  // orbit: the acid comet's lap
  late final AnimationController _orbit =
      AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();

  @override
  void dispose() {
    _breath.dispose();
    _orbit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_breath, _orbit]),
      builder: (context, _) => SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            CustomPaint(
              size: Size.square(widget.size),
              painter: _PortalPainter(breath: _breath.value, orbit: _orbit.value),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 26),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // gradient type — the hero is never flat white (that's them)
                  ShaderMask(
                    shaderCallback: (r) => C.gradSigHot.createShader(r),
                    blendMode: BlendMode.srcIn,
                    child: Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      style: T.display(31).copyWith(
                        shadows: const [Shadow(color: Color(0xB3000000), blurRadius: 16)],
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    widget.line,
                    textAlign: TextAlign.center,
                    style: T.body.copyWith(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      shadows: const [Shadow(color: Color(0xCC000000), blurRadius: 10)],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PortalPainter extends CustomPainter {
  _PortalPainter({required this.breath, required this.orbit});
  final double breath; // 0..1 breathing
  final double orbit; // 0..1 lap position

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 14 + 6 * breath;
    final rect = Rect.fromCircle(center: c, radius: r);

    // soft interior pool so the type always reads over any camera frame
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(colors: [
          const Color(0x59000000),
          C.purpleDeep.withOpacity(0.10 + 0.08 * breath),
          const Color(0x00000000),
        ], stops: const [0.0, 0.72, 1.0]).createShader(rect),
    );

    // bloom behind the ring
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..color = C.sig.withOpacity(0.18 + 0.16 * breath)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );

    // the ring — sweep gradient sig → deep → sig so the seam is invisible,
    // slowly rotating with the orbit so the light feels alive
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..shader = SweepGradient(
        colors: const [C.sig, C.purpleDeep, C.sig],
        transform: GradientRotation(orbit * 2 * math.pi),
      ).createShader(rect);
    canvas.drawCircle(c, r, ring);

    // the acid comet: a fading trail arc, then the head
    final a = orbit * 2 * math.pi - math.pi / 2;
    const trail = 0.9; // radians of tail
    final tail = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: trail,
        colors: [C.acid.withOpacity(0), C.acid],
        transform: GradientRotation(a - trail),
      ).createShader(rect);
    canvas.drawArc(rect, a - trail, trail, false, tail);

    final head = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
    canvas.drawCircle(
      head,
      6,
      Paint()
        ..color = C.acidGlow
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawCircle(head, 3.4, Paint()..color = C.acid);
  }

  @override
  bool shouldRepaint(_PortalPainter old) => old.breath != breath || old.orbit != orbit;
}
