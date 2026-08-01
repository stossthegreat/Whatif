import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/tokens.dart';

/// A ring drawn from the top. [progress] 0→1 controls the arc length. Used both
/// for the Finding "fill" (progress rises to 1) and small game timers (progress
/// drains toward 0). The caller owns the semantics; this just draws.
class RingPaint extends StatelessWidget {
  const RingPaint({
    super.key,
    required this.progress,
    this.size = 220,
    this.stroke = 3,
    this.color = C.sig,
    this.track = C.hair,
    this.child,
  });

  final double progress;
  final double size;
  final double stroke;
  final Color color;
  final Color track;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(progress.clamp(0, 1), stroke, color, track),
        child: Center(child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.progress, this.stroke, this.color, this.track);
  final double progress;
  final double stroke;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - stroke;
    final t = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawCircle(center, radius, t);

    if (progress <= 0) return;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    // glow
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke + 3
      ..strokeCap = StrokeCap.round
      ..color = color.withOpacity(0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final rect = Rect.fromCircle(center: center, radius: radius);
    final sweep = progress * math.pi * 2;
    canvas.drawArc(rect, -math.pi / 2, sweep, false, glow);
    canvas.drawArc(rect, -math.pi / 2, sweep, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter o) =>
      o.progress != progress || o.color != color || o.stroke != stroke;
}
