import 'package:flutter/material.dart';
import '../theme/motion.dart';

/// Fades + lifts its child into place on mount. The building block of every
/// staggered reveal in the app — give siblings increasing [delay] (30–60ms
/// apart) and a list cascades in instead of dumping all at once.
class Reveal extends StatefulWidget {
  const Reveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.dy = 22,
    this.duration = Motion.slow,
    this.curve = Motion.entrance,
  });

  final Widget child;
  final Duration delay;
  final double dy;
  final Duration duration;
  final Curve curve;

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration);
  bool _cancelled = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(widget.delay, () {
      if (!_cancelled && mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _cancelled = true;
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _c, curve: widget.curve);
    return AnimatedBuilder(
      animation: curved,
      builder: (context, child) {
        return Opacity(
          opacity: curved.value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, widget.dy * (1 - curved.value)),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Convenience: wrap the children of a column/list so they cascade in.
List<Widget> staggered(
  List<Widget> children, {
  Duration start = Duration.zero,
  Duration step = const Duration(milliseconds: 70),
}) {
  final out = <Widget>[];
  for (var i = 0; i < children.length; i++) {
    out.add(Reveal(
      delay: start + step * i,
      child: children[i],
    ));
  }
  return out;
}
