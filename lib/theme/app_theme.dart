import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'colors.dart';
import 'typography.dart';

/// The single WhatIf theme. Dark, always. The product lives after dark.
class WhatIfTheme {
  WhatIfTheme._();

  static ThemeData get dark {
    const scheme = ColorScheme.dark(
      primary: WhatIfColors.violet,
      secondary: WhatIfColors.cyan,
      tertiary: WhatIfColors.magenta,
      surface: WhatIfColors.inkSoft,
      error: WhatIfColors.danger,
      onPrimary: Colors.white,
      onSecondary: Colors.black,
      onSurface: WhatIfColors.textHigh,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: WhatIfColors.ink,
      splashFactory: NoSplash.splashFactory, // we do our own touch feedback
      highlightColor: Colors.transparent,
      textTheme: const TextTheme(
        displayLarge: WhatIfType.display,
        headlineLarge: WhatIfType.h1,
        headlineMedium: WhatIfType.h2,
        headlineSmall: WhatIfType.h3,
        bodyLarge: WhatIfType.body,
        bodyMedium: WhatIfType.body,
        labelLarge: WhatIfType.label,
        labelSmall: WhatIfType.overline,
      ),
      fontFamily: null,
    );
  }

  /// Light-on-dark system chrome (status bar / nav bar) for the whole app.
  static const SystemUiOverlayStyle systemOverlay = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: WhatIfColors.ink,
    systemNavigationBarIconBrightness: Brightness.light,
  );
}
