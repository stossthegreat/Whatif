import 'package:flutter/material.dart';

/// WhatIf color philosophy — "Midnight Amusement Park".
///
/// The product opens after dark. The base is a deep, near-black canvas with a
/// faint violet undertone so the screen never feels like a flat black void — it
/// feels like *night*, with something glowing just over the horizon. On top of
/// that canvas we paint with a small, disciplined set of luminous accents that
/// behave like neon: magenta, violet and cyan for energy and mystery, warm amber
/// reserved *only* for earned, celebratory moments (wins, unlocks, reveals).
///
/// Rule of restraint: color is a reward. Most of the UI is ink and glass. The
/// aurora only blooms where we want the eye — and warmth only appears when the
/// user has *earned* a feeling.
class WhatIfColors {
  WhatIfColors._();

  // ---- Canvas (the night) ---------------------------------------------------
  /// The deepest background. Not pure black — a violet-tinted ink.
  static const Color ink = Color(0xFF080611);
  static const Color inkSoft = Color(0xFF0D0A1A);
  static const Color inkRaised = Color(0xFF15112A);

  // ---- Glass / surfaces -----------------------------------------------------
  static const Color glass = Color(0x14FFFFFF); // 8% white
  static const Color glassStrong = Color(0x24FFFFFF); // 14% white
  static const Color hairline = Color(0x1FFFFFFF); // 12% white borders
  static const Color hairlineStrong = Color(0x33FFFFFF);

  // ---- The aurora (signature accents) --------------------------------------
  static const Color magenta = Color(0xFFFF3D9A);
  static const Color violet = Color(0xFF8A5CFF);
  static const Color indigo = Color(0xFF5B4BFF);
  static const Color cyan = Color(0xFF22E1FF);
  static const Color mint = Color(0xFF4DF0C0);

  // ---- Warmth (earned only) -------------------------------------------------
  static const Color amber = Color(0xFFFFC14D);
  static const Color coral = Color(0xFFFF7A59);

  // ---- Semantic -------------------------------------------------------------
  static const Color danger = Color(0xFFFF5470);
  static const Color live = Color(0xFFFF3D6E); // the "we are LIVE" pulse

  // ---- Text ----------------------------------------------------------------
  static const Color textHigh = Color(0xFFFFFFFF);
  static const Color textMed = Color(0xB3FFFFFF); // 70%
  static const Color textLow = Color(0x80FFFFFF); // 50%
  static const Color textFaint = Color(0x4DFFFFFF); // 30%

  // ---- Signature gradients --------------------------------------------------
  /// The WhatIf brand sweep — used on the wordmark and primary moments.
  static const List<Color> aurora = [magenta, violet, cyan];

  /// A hotter variant for LIVE / high-energy surfaces.
  static const List<Color> ember = [coral, magenta, violet];

  /// Celebration — only for confetti / victory.
  static const List<Color> celebration = [amber, magenta, cyan, mint, coral];

  static const LinearGradient auroraSweep = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: aurora,
  );

  static const LinearGradient emberSweep = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: ember,
  );

  /// A soft radial glow used behind focal elements.
  static RadialGradient glow(Color c, {double opacity = 0.5}) => RadialGradient(
        colors: [c.withOpacity(opacity), c.withOpacity(0)],
      );
}
