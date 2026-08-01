import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import 'glass.dart';

/// The one control on Home. A glass disc with a play glyph, sitting in a soft
/// cool glow that breathes slowly — the single ambient motion in the app.
class PlayButton extends StatefulWidget {
  const PlayButton({super.key, required this.onTap, this.size = 132});
  final VoidCallback onTap;
  final double size;

  @override
  State<PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<PlayButton> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 3600))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return Press(
      haptic: false,
      onTap: widget.onTap,
      child: SizedBox(
        width: s * 1.45,
        height: s * 1.45,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                final t = _c.value;
                return Container(
                  width: s * (1.15 + 0.12 * t),
                  height: s * (1.15 + 0.12 * t),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [C.sigGlow.withOpacity(0.4 + 0.35 * t), const Color(0x00000000)],
                      stops: const [0.1, 0.72],
                    ),
                  ),
                );
              },
            ),
            ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  width: s,
                  height: s,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      center: Alignment(-0.3, -0.5),
                      radius: 1.2,
                      colors: [Color(0x38FFFFFF), Color(0x0AFFFFFF), Color(0x05FFFFFF)],
                      stops: [0.0, 0.45, 1.0],
                    ),
                    border: Border.all(color: const Color(0x47FFFFFF), width: 1),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 40, offset: const Offset(0, 18)),
                    ],
                  ),
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.only(left: s * 0.06),
                      child: CustomPaint(size: Size(s * 0.32, s * 0.32), painter: _TriPainter()),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TriPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawShadow(path, Colors.black.withOpacity(0.4), 6, false);
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
