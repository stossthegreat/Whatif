import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

/// The dramatic countdown. A ring that drains as time runs out, its color
/// shifting from cyan → amber → hot red in the final seconds, with a big number
/// in the middle that pulses on each tick. Peak party-game tension. The caller
/// drives [progress] (1.0 → 0.0) and [secondsLeft]; the ring handles the drama.
class CountdownRing extends StatelessWidget {
  const CountdownRing({
    super.key,
    required this.progress,
    required this.secondsLeft,
    this.size = 160,
  });

  final double progress; // 1.0 full -> 0.0 empty
  final int secondsLeft;
  final double size;

  Color get _color {
    if (secondsLeft <= 3) return WhatIfColors.live;
    if (secondsLeft <= 6) return WhatIfColors.amber;
    return WhatIfColors.cyan;
  }

  @override
  Widget build(BuildContext context) {
    final urgent = secondsLeft <= 3;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _RingPainter(progress: progress, color: _color),
          ),
          // Number pops each second via an animated key.
          TweenAnimationBuilder<double>(
            key: ValueKey(secondsLeft),
            tween: Tween(begin: urgent ? 1.4 : 1.18, end: 1.0),
            duration: const Duration(milliseconds: 340),
            curve: Curves.easeOutBack,
            builder: (context, v, child) => Transform.scale(scale: v, child: child),
            child: Text(
              '$secondsLeft',
              style: WhatIfType.counter.copyWith(
                fontSize: size * 0.42,
                color: urgent ? _color : WhatIfColors.textHigh,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.color});
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 8;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Track.
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..color = WhatIfColors.hairline;
    canvas.drawCircle(center, radius, track);

    // Glow underlay.
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10)
      ..shader = SweepGradient(
        colors: [color, color.withOpacity(0.4)],
        startAngle: -math.pi / 2,
        endAngle: math.pi * 1.5,
      ).createShader(rect);

    // Progress arc, drawn from the top, draining clockwise.
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [color.withOpacity(0.5), color],
        startAngle: -math.pi / 2,
        endAngle: math.pi * 1.5,
      ).createShader(rect);

    final sweep = (progress.clamp(0.0, 1.0)) * math.pi * 2;
    canvas.drawArc(rect, -math.pi / 2, sweep, false, glow);
    canvas.drawArc(rect, -math.pi / 2, sweep, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress || old.color != color;
}
