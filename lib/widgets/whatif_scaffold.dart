import 'package:flutter/material.dart';
import '../theme/colors.dart';
import 'aurora_background.dart';

/// Every screen sits on the same living aurora, so navigating feels like moving
/// through one continuous space rather than swapping slides. Screens only vary
/// the [energy] and [palette] to change the mood of the room.
class WhatIfScaffold extends StatelessWidget {
  const WhatIfScaffold({
    super.key,
    required this.child,
    this.energy = 0.5,
    this.palette = WhatIfColors.aurora,
    this.safeTop = true,
    this.safeBottom = true,
  });

  final Widget child;
  final double energy;
  final List<Color> palette;
  final bool safeTop;
  final bool safeBottom;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WhatIfColors.ink,
      body: AuroraBackground(
        energy: energy,
        palette: palette,
        child: SafeArea(
          top: safeTop,
          bottom: safeBottom,
          child: child,
        ),
      ),
    );
  }
}
