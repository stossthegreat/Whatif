import 'package:flutter/material.dart';
import 'colors.dart';

/// WhatIf type system.
///
/// One family, dramatic weight range. Headlines are *loud* — big, tight,
/// negative letter-spacing so the wordmark and moments feel like posters, not
/// paragraphs. Body stays quiet and readable. We rely on the platform's premium
/// default (SF Pro on iOS, Roboto on Android) so the app ships with zero font
/// assets and always renders — the drama comes from weight, size and spacing,
/// not a downloaded typeface.
class WhatIfType {
  WhatIfType._();

  static const String? _family = null; // platform default (SF Pro / Roboto)

  /// Poster-scale display — used sparingly for hero moments.
  static const TextStyle display = TextStyle(
    fontFamily: _family,
    fontSize: 52,
    height: 1.02,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.6,
    color: WhatIfColors.textHigh,
  );

  static const TextStyle h1 = TextStyle(
    fontFamily: _family,
    fontSize: 34,
    height: 1.06,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.0,
    color: WhatIfColors.textHigh,
  );

  static const TextStyle h2 = TextStyle(
    fontFamily: _family,
    fontSize: 26,
    height: 1.1,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
    color: WhatIfColors.textHigh,
  );

  static const TextStyle h3 = TextStyle(
    fontFamily: _family,
    fontSize: 20,
    height: 1.15,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    color: WhatIfColors.textHigh,
  );

  static const TextStyle body = TextStyle(
    fontFamily: _family,
    fontSize: 16,
    height: 1.4,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.1,
    color: WhatIfColors.textMed,
  );

  static const TextStyle bodyStrong = TextStyle(
    fontFamily: _family,
    fontSize: 16,
    height: 1.4,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    color: WhatIfColors.textHigh,
  );

  static const TextStyle label = TextStyle(
    fontFamily: _family,
    fontSize: 14,
    height: 1.2,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    color: WhatIfColors.textMed,
  );

  /// All-caps micro-label used for eyebrows, tags, "LIVE" chips.
  static const TextStyle overline = TextStyle(
    fontFamily: _family,
    fontSize: 12,
    height: 1.1,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.6,
    color: WhatIfColors.textMed,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: _family,
    fontSize: 13,
    height: 1.3,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    color: WhatIfColors.textLow,
  );

  /// Tabular-ish numerals for dramatic countdowns.
  static const TextStyle counter = TextStyle(
    fontFamily: _family,
    fontSize: 72,
    height: 1.0,
    fontWeight: FontWeight.w800,
    letterSpacing: -3,
    color: WhatIfColors.textHigh,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
