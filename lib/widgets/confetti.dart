import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// Controls a [ConfettiOverlay]. Call [fire] on a *deserved* moment (a win, a
/// reveal). Reserved on purpose — if confetti fired all the time it would stop
/// meaning "you did it".
class ConfettiController extends ChangeNotifier {
  int _shots = 0;
  Offset _origin = const Offset(0.5, 0.4); // fractional
  int get shots => _shots;
  Offset get origin => _origin;

  void fire({Offset origin = const Offset(0.5, 0.4)}) {
    _origin = origin;
    _shots++;
    notifyListeners();
  }
}

/// A full-screen particle burst. Colors come from the celebration palette; each
/// piece is a small rounded rect that tumbles as it falls under gravity, fading
/// near the end. Particle count is capped (perf) and the overlay ignores
/// pointers so it never blocks the UI beneath.
class ConfettiOverlay extends StatefulWidget {
  const ConfettiOverlay({super.key, required this.controller, this.count = 90});
  final ConfettiController controller;
  final int count;

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));
  final math.Random _rng = math.Random(7);
  List<_Piece> _pieces = [];
  int _lastShot = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onFire);
  }

  void _onFire() {
    if (widget.controller.shots == _lastShot) return;
    _lastShot = widget.controller.shots;
    _pieces = List.generate(widget.count, (_) => _spawn(widget.controller.origin));
    _c.forward(from: 0);
  }

  _Piece _spawn(Offset origin) {
    final angle = -math.pi / 2 + (_rng.nextDouble() - 0.5) * 1.7;
    final speed = 0.6 + _rng.nextDouble() * 0.9;
    return _Piece(
      ox: origin.dx,
      oy: origin.dy,
      vx: math.cos(angle) * speed,
      vy: math.sin(angle) * speed,
      color: WhatIfColors.celebration[_rng.nextInt(WhatIfColors.celebration.length)],
      size: 6 + _rng.nextDouble() * 8,
      spin: (_rng.nextDouble() - 0.5) * 12,
      phase: _rng.nextDouble(),
    );
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onFire);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          if (_c.isDismissed || _pieces.isEmpty) {
            return const SizedBox.expand();
          }
          return CustomPaint(
            size: Size.infinite,
            painter: _ConfettiPainter(_pieces, _c.value),
          );
        },
      ),
    );
  }
}

class _Piece {
  _Piece({
    required this.ox,
    required this.oy,
    required this.vx,
    required this.vy,
    required this.color,
    required this.size,
    required this.spin,
    required this.phase,
  });
  final double ox, oy, vx, vy, size, spin, phase;
  final Color color;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.t);
  final List<_Piece> pieces;
  final double t; // 0..1

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in pieces) {
      // Position: launch outward, then gravity pulls down. Units are fractions
      // of the screen so it scales to any device.
      final gx = p.ox + p.vx * t * 0.9;
      final gy = p.oy + p.vy * t + 1.2 * t * t; // gravity term
      if (gy > 1.15) continue;
      final pos = Offset(gx * size.width, gy * size.height);
      final fade = t < 0.7 ? 1.0 : (1 - (t - 0.7) / 0.3);
      paint.color = p.color.withOpacity(fade.clamp(0.0, 1.0));

      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(p.spin * t + p.phase * 6.28);
      // Flatten on the spin to fake 3D tumbling.
      final w = p.size;
      final h = p.size * (0.4 + 0.6 * (0.5 + 0.5 * math.sin(t * 10 + p.phase * 6.28)).abs());
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: w, height: h),
          Radius.circular(w * 0.3),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t || old.pieces != pieces;
}
