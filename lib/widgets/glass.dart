import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import '../core/haptics.dart';
import '../theme/tokens.dart';

/// The Rivlr wordmark — spaced-out display face, purple bookends: the first
/// R and the last r both carry the accent, everything between stays clean.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.size = 28, this.color = C.tx});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: T.display(size).copyWith(color: color, letterSpacing: size * 0.12),
        children: const [
          TextSpan(text: 'R', style: TextStyle(color: C.sig)),
          TextSpan(text: 'ivl'),
          TextSpan(text: 'r', style: TextStyle(color: C.sig)),
        ],
      ),
    );
  }
}

/// A frosted glass surface with a specular top edge (the "gloss").
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.radius = 26,
    this.padding = const EdgeInsets.all(20),
    this.blur = 24,
    this.tint = C.glass,
    this.border = true,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final double blur;
  final Color tint;
  final bool border;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    return ClipRRect(
      borderRadius: r,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: tint,
            borderRadius: r,
            border: border ? Border.all(color: C.hair, width: 1) : null,
          ),
          child: Stack(
            children: [
              child,
              // specular hairline
              Positioned(
                top: 0,
                left: radius * 0.4,
                right: radius * 0.4,
                child: Container(
                  height: 1,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0x00FFFFFF), C.spec, Color(0x00FFFFFF)],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Spring-squish + haptic on anything tappable. Interruptible.
class Press extends StatefulWidget {
  const Press({super.key, required this.child, this.onTap, this.scale = 0.95, this.haptic = true});
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final bool haptic;

  @override
  State<Press> createState() => _PressState();
}

class _PressState extends State<Press> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController.unbounded(vsync: this, value: 1);
  double _s = 1;

  @override
  void initState() {
    super.initState();
    _c.addListener(() => setState(() => _s = _c.value));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _to(double t) => _c.animateWith(SpringSimulation(M.press, _c.value, t, _c.velocity));

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null ? null : (_) {
        if (widget.haptic) Buzz.tap();
        _c.stop();
        _c.value = widget.scale;
      },
      onTapUp: widget.onTap == null ? null : (_) {
        _to(1);
        widget.onTap!();
      },
      onTapCancel: widget.onTap == null ? null : () => _to(1),
      child: Transform.scale(scale: _s, child: widget.child),
    );
  }
}

/// The call-to-action. The primary key wears the signature gradient with a
/// soft glow — one unmistakable button per screen. `quiet: true` keeps the
/// old white key for the rare spot where the gradient would shout twice.
class Cta extends StatelessWidget {
  const Cta({super.key, required this.label, this.onTap, this.height = 60, this.quiet = false});
  final String label;
  final VoidCallback? onTap;
  final double height;
  final bool quiet;

  @override
  Widget build(BuildContext context) {
    return Press(
      haptic: false,
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.4 : 1,
        child: Container(
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: quiet ? Colors.white : null,
            gradient: quiet ? null : C.gradSig,
            borderRadius: BorderRadius.circular(R.btn),
            border: quiet ? null : Border.all(color: const Color(0x38FFFFFF), width: 1),
            boxShadow: quiet || onTap == null ? null : C.glowSig(),
          ),
          child: Text(label,
              style: T.h3.copyWith(
                  color: quiet ? Colors.black : Colors.white,
                  fontSize: 17,
                  letterSpacing: -0.2)),
        ),
      ),
    );
  }
}
