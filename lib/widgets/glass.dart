import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// A frosted glass panel — the app's primary content surface. Sits over the
/// aurora so the neon behind it blooms through a soft blur. Hairline border on
/// top edge catches the "light" for depth.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 28,
    this.blur = 22,
    this.tint = WhatIfColors.glass,
    this.borderColor = WhatIfColors.hairline,
    this.glow,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double blur;
  final Color tint;
  final Color borderColor;

  /// Optional colored halo behind the panel — used to make a card feel "hot".
  final Color? glow;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: [
          if (glow != null)
            BoxShadow(
              color: glow!.withOpacity(0.45),
              blurRadius: 48,
              spreadRadius: -6,
            ),
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: r,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: r,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [tint, tint.withOpacity(0)],
              ),
              color: tint,
              border: Border.all(color: borderColor, width: 1),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
