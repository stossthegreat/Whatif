import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/tokens.dart';

/// The ambient layer behind every "quiet" screen — two purple/blue glows
/// drifting on true black with a few glossy obsidian orbs floating through.
/// Subtle on purpose: atmosphere, never noise. This is what separates a
/// premium black screen from a flat one.
class Aurora extends StatefulWidget {
  const Aurora({super.key, this.orbs = 4, this.opacity = 1});
  final int orbs;
  final double opacity;

  @override
  State<Aurora> createState() => _AuroraState();
}

class _AuroraState extends State<Aurora> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 26))..repeat();
  late final List<_Orb> _orbs;

  @override
  void initState() {
    super.initState();
    final r = math.Random();
    _orbs = List.generate(widget.orbs, (_) => _Orb.random(r));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Opacity(
        opacity: widget.opacity,
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) => CustomPaint(
              size: Size.infinite,
              painter: _AuroraPainter(_c.value, _orbs),
            ),
          ),
        ),
      ),
    );
  }
}

class _Orb {
  _Orb(this.ax, this.ay, this.fx, this.fy, this.phase, this.size);
  final double ax, ay, fx, fy, phase, size;
  static _Orb random(math.Random r) => _Orb(
        0.12 + r.nextDouble() * 0.76,
        0.08 + r.nextDouble() * 0.5,
        0.03 + r.nextDouble() * 0.05,
        0.025 + r.nextDouble() * 0.045,
        r.nextDouble(),
        16 + r.nextDouble() * 22,
      );
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter(this.t, this.orbs);
  final double t;
  final List<_Orb> orbs;

  @override
  void paint(Canvas canvas, Size size) {
    final tau = math.pi * 2;

    void glow(Color c, double cx, double cy, double rad, double op) {
      final paint = Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(colors: [c.withOpacity(op), c.withOpacity(0)])
            .createShader(Rect.fromCircle(
                center: Offset(cx * size.width, cy * size.height), radius: rad));
      canvas.drawCircle(Offset(cx * size.width, cy * size.height), rad, paint);
    }

    glow(C.purpleDeep, 0.24 + 0.1 * math.sin(t * tau), 0.24 + 0.07 * math.cos(t * tau),
        size.width * 0.75, 0.10);
    glow(C.blue, 0.8 + 0.07 * math.cos(t * tau * 0.7), 0.65 + 0.06 * math.sin(t * tau * 0.9),
        size.width * 0.5, 0.035);

    // glossy obsidian orbs drifting through
    for (final o in orbs) {
      final cx = (o.ax + o.fx * math.sin((t + o.phase) * tau)) * size.width;
      final cy = (o.ay + o.fy * math.cos((t + o.phase) * tau * 0.8)) * size.height;
      final c = Offset(cx, cy);
      final body = Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.45, -0.55),
          radius: 1.05,
          colors: const [Color(0xFF262930), Color(0xFF0B0C0F), Color(0xFF000000)],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: o.size));
      canvas.drawCircle(c, o.size, body);
      canvas.drawCircle(
          c, o.size, Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = Colors.white.withOpacity(0.05));
      // specular glint
      final glint = Paint()
        ..shader = RadialGradient(
          colors: [Colors.white.withOpacity(0.35), Colors.white.withOpacity(0)],
        ).createShader(Rect.fromCircle(
            center: c.translate(-o.size * 0.35, -o.size * 0.4), radius: o.size * 0.35));
      canvas.drawCircle(c.translate(-o.size * 0.35, -o.size * 0.4), o.size * 0.35, glint);
    }
  }

  @override
  bool shouldRepaint(_AuroraPainter old) => old.t != t;
}
