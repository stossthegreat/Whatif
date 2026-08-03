import 'package:flutter/material.dart';
import '../theme/tokens.dart';

/// A luminous identity orb built from a hue — used for your profile, sparks,
/// and floating avatars. No photos; you're a glow.
class IdentityOrb extends StatelessWidget {
  const IdentityOrb({super.key, required this.hue, this.size = 64, this.ring, this.live = false});
  final double hue;
  final double size;
  final Color? ring;
  final bool live;

  Color get _light => HSLColor.fromAHSL(1, hue, 0.55, 0.62).toColor();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [_light, C.char2],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        border: Border.all(color: ring ?? Colors.white.withOpacity(0.16), width: ring != null ? 2.5 : 1.4),
        boxShadow: [BoxShadow(color: _light.withOpacity(0.45), blurRadius: size * 0.4, spreadRadius: -size * 0.08)],
      ),
      child: live
          ? Align(
              alignment: Alignment.bottomRight,
              child: Container(
                margin: const EdgeInsets.all(3),
                width: size * 0.22, height: size * 0.22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle, color: C.acid,
                  border: Border.all(color: C.black, width: 2),
                ),
              ),
            )
          : null,
    );
  }
}
