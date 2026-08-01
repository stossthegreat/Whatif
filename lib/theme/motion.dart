import 'package:flutter/animation.dart';
import 'package:flutter/physics.dart';

/// WhatIf motion language.
///
/// Everything moves like it has weight and joy. We prefer *spring physics* over
/// fixed easing for anything the finger touches — a spring overshoots and
/// settles, which reads as "alive" and "tactile" where a cubic curve reads as
/// "software". Fixed curves are reserved for choreographed reveals where timing
/// must be exact.
class Motion {
  Motion._();

  // ---- Durations ------------------------------------------------------------
  static const Duration instant = Duration(milliseconds: 120);
  static const Duration quick = Duration(milliseconds: 240);
  static const Duration base = Duration(milliseconds: 380);
  static const Duration slow = Duration(milliseconds: 620);
  static const Duration dramatic = Duration(milliseconds: 900);

  // ---- Curves ---------------------------------------------------------------
  /// Our house easing — decisive out, gentle in. Feels expensive.
  static const Curve entrance = Cubic(0.16, 1.0, 0.3, 1.0); // "expo-out"-ish
  static const Curve exit = Cubic(0.7, 0.0, 0.84, 0.0);
  static const Curve emphatic = Cubic(0.34, 1.56, 0.64, 1.0); // slight overshoot
  static const Curve breathe = Curves.easeInOut;

  // ---- Spring descriptions --------------------------------------------------
  /// A lively press spring — noticeable overshoot, quick settle. Buttons/cards.
  static const SpringDescription pressSpring = SpringDescription(
    mass: 1,
    stiffness: 520,
    damping: 20,
  );

  /// A softer, bouncier spring for playful arrivals (orbs, chips popping in).
  static const SpringDescription bouncySpring = SpringDescription(
    mass: 1,
    stiffness: 380,
    damping: 14,
  );

  /// A tight, controlled spring for sheets and drawers.
  static const SpringDescription snappySpring = SpringDescription(
    mass: 1,
    stiffness: 700,
    damping: 32,
  );
}
