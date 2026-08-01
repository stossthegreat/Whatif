import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/identity.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

/// A player, rendered as a glowing orb with their glyph. Optionally pulses with
/// concentric rings when [speaking]/[active] — the "who's live right now"
/// signal. Wrapped in a [RepaintBoundary]; the pulse only runs when active so
/// idle orbs cost nothing.
class PresenceOrb extends StatefulWidget {
  const PresenceOrb({
    super.key,
    required this.identity,
    this.size = 64,
    this.active = false,
    this.showLabel = false,
    this.dimmed = false,
  });

  final Identity identity;
  final double size;
  final bool active; // pulse rings + brighten
  final bool showLabel;
  final bool dimmed;

  @override
  State<PresenceOrb> createState() => _PresenceOrbState();
}

class _PresenceOrbState extends State<PresenceOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    if (widget.active) _pulse.repeat();
  }

  @override
  void didUpdateWidget(covariant PresenceOrb old) {
    super.didUpdateWidget(old);
    if (widget.active && !_pulse.isAnimating) {
      _pulse.repeat();
    } else if (!widget.active && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.identity;
    final s = widget.size;
    final orb = RepaintBoundary(
      child: SizedBox(
        width: s * 1.5,
        height: s * 1.5,
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) {
            return CustomPaint(
              painter: widget.active
                  ? _PulsePainter(_pulse.value, id.accent)
                  : null,
              child: Center(child: child),
            );
          },
          child: Opacity(
            opacity: widget.dimmed ? 0.4 : 1.0,
            child: Container(
              width: s,
              height: s,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: id.gradient,
                boxShadow: [
                  BoxShadow(
                    color: id.accent.withOpacity(widget.active ? 0.6 : 0.35),
                    blurRadius: widget.active ? 28 : 16,
                    spreadRadius: widget.active ? 1 : -2,
                  ),
                ],
                border: Border.all(
                  color: Colors.white.withOpacity(0.18),
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: Text(id.glyph, style: TextStyle(fontSize: s * 0.44)),
            ),
          ),
        ),
      ),
    );

    if (!widget.showLabel) return orb;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        orb,
        Text(
          id.handle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: WhatIfType.caption.copyWith(
            color: widget.dimmed ? WhatIfColors.textFaint : WhatIfColors.textMed,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _PulsePainter extends CustomPainter {
  _PulsePainter(this.t, this.color);
  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final base = size.width * 0.32;
    // Two rings, offset in phase, expanding and fading outward.
    for (final phase in [0.0, 0.5]) {
      final p = (t + phase) % 1.0;
      final radius = base + (size.width * 0.5 - base) * p;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 * (1 - p)
        ..color = color.withOpacity((1 - p) * 0.5);
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_PulsePainter old) => old.t != t || old.color != color;
}

/// A small floating orb used decoratively (splash, empty states).
class DriftingGlyph extends StatelessWidget {
  const DriftingGlyph({super.key, required this.glyph, this.size = 40});
  final String glyph;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: math.pi / 24,
      child: Text(glyph, style: TextStyle(fontSize: size)),
    );
  }
}
