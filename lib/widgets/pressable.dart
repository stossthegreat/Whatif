import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import '../core/haptics.dart';
import '../theme/motion.dart';

/// Every tappable thing in WhatIf squishes. On press it springs down to ~0.94
/// and, on release, overshoots back past 1.0 and settles — the tiny bounce that
/// makes a button feel like a physical object with weight. The press fires a
/// light haptic on the *same frame* the finger lands (craft commandment #4).
///
/// Built on a raw [SpringSimulation] rather than a tween so the motion is
/// interruptible and velocity-aware: tap again mid-bounce and it redirects from
/// wherever it is, never snapping.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.94,
    this.haptic = true,
    this.spring = Motion.pressSpring,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;
  final bool haptic;
  final SpringDescription spring;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  double _scale = 1.0;

  @override
  void initState() {
    super.initState();
    _c = AnimationController.unbounded(vsync: this, value: 1.0)
      ..addListener(() => setState(() => _scale = _c.value));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _springTo(double target) {
    final sim = SpringSimulation(widget.spring, _c.value, target, _c.velocity);
    _c.animateWith(sim);
  }

  void _down(_) {
    if (widget.haptic) Buzz.tap();
    _c.stop();
    _c.value = widget.pressedScale; // snap down — immediate tactile response
  }

  void _up(_) {
    _springTo(1.0);
    widget.onTap?.call();
  }

  void _cancel() => _springTo(1.0);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null ? null : _down,
      onTapUp: widget.onTap == null ? null : _up,
      onTapCancel: widget.onTap == null ? null : _cancel,
      child: Transform.scale(scale: _scale, child: widget.child),
    );
  }
}
