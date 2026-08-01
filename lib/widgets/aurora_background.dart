import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// The hero material. A living mesh of luminous "blobs" drifting behind the ink,
/// like distant neon seen through fog. Every screen sits on this so the whole
/// app feels like one continuous, breathing space — never a slideshow.
///
/// It is *reactive*: [energy] scales the glow and drift speed so the surface can
/// go calm in the lobby and blow wide open at the reveal, and [palette] lets a
/// screen tint the whole world (e.g. warm for a win). No shader assets required
/// — pure [CustomPainter] with cached radial-gradient paints, wrapped in a
/// [RepaintBoundary] so it never repaints the tree above it.
class AuroraBackground extends StatefulWidget {
  const AuroraBackground({
    super.key,
    this.energy = 0.5,
    this.palette = WhatIfColors.aurora,
    this.child,
  });

  /// 0.0 = calm and slow, 1.0 = frantic and bright.
  final double energy;
  final List<Color> palette;
  final Widget? child;

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _t;

  @override
  void initState() {
    super.initState();
    // A long, non-repeating-feeling loop so the drift never looks periodic.
    _t = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
    )..repeat();
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _t,
        builder: (context, child) {
          return CustomPaint(
            painter: _AuroraPainter(
              t: _t.value,
              energy: widget.energy.clamp(0.0, 1.0),
              palette: widget.palette,
            ),
            isComplex: true,
            willChange: true,
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter({
    required this.t,
    required this.energy,
    required this.palette,
  });

  final double t; // 0..1 loop phase
  final double energy;
  final List<Color> palette;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Base ink — a faint vertical fall from raised-violet to pure ink so the
    // top of the screen glows a touch more than the bottom.
    final basePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [WhatIfColors.inkSoft, WhatIfColors.ink],
      ).createShader(rect);
    canvas.drawRect(rect, basePaint);

    final tau = math.pi * 2;
    final speed = 0.6 + energy * 1.4;
    final glow = 0.32 + energy * 0.30;
    final blobR = size.shortestSide * (0.72 + energy * 0.18);

    // Each blob drifts on its own Lissajous path at its own frequency, so the
    // composition never repeats to the eye within a session.
    final blobs = <_Blob>[
      _Blob(
        color: palette[0 % palette.length],
        cx: 0.22 + 0.16 * math.sin(tau * (t * speed + 0.00)),
        cy: 0.20 + 0.14 * math.cos(tau * (t * speed * 0.8 + 0.10)),
        scale: 1.0,
      ),
      _Blob(
        color: palette[1 % palette.length],
        cx: 0.82 + 0.14 * math.sin(tau * (t * speed * 1.15 + 0.55)),
        cy: 0.30 + 0.18 * math.cos(tau * (t * speed * 0.9 + 0.30)),
        scale: 1.1,
      ),
      _Blob(
        color: palette[2 % palette.length],
        cx: 0.55 + 0.20 * math.sin(tau * (t * speed * 0.7 + 0.80)),
        cy: 0.86 + 0.12 * math.cos(tau * (t * speed * 1.1 + 0.60)),
        scale: 0.95,
      ),
    ];

    for (final b in blobs) {
      final center = Offset(b.cx * size.width, b.cy * size.height);
      final r = blobR * b.scale;
      final paint = Paint()
        ..blendMode = BlendMode.plus // additive neon accumulation on black
        ..shader = RadialGradient(
          colors: [
            b.color.withOpacity(glow),
            b.color.withOpacity(glow * 0.35),
            b.color.withOpacity(0),
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: r));
      canvas.drawCircle(center, r, paint);
    }

    // A subtle top vignette to seat status-bar content.
    final vignette = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.center,
        colors: [WhatIfColors.ink.withOpacity(0.55), WhatIfColors.ink.withOpacity(0)],
      ).createShader(rect);
    canvas.drawRect(rect, vignette);
  }

  @override
  bool shouldRepaint(_AuroraPainter old) =>
      old.t != t || old.energy != energy || old.palette != palette;
}

class _Blob {
  _Blob({
    required this.color,
    required this.cx,
    required this.cy,
    required this.scale,
  });
  final Color color;
  final double cx;
  final double cy;
  final double scale;
}
