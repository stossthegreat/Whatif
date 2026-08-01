import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// A WhatIf identity is deliberately *not* a photo. Research: a photo-first
/// stranger loop reads as dating and puts a "rate my face" tax on shy users.
/// Instead every player is a luminous **orb** — a two-color gradient plus a
/// single expressive glyph and a handle. It's instantly yours, costs nothing to
/// make, and carries across every screen (shared-element) so the game feels like
/// one living room.
class Identity {
  const Identity({
    required this.handle,
    required this.glyph,
    required this.colors,
    this.vibe,
  });

  final String handle;
  final String glyph; // an emoji or single char
  final List<Color> colors; // gradient [a, b]
  final String? vibe;

  Identity copyWith({
    String? handle,
    String? glyph,
    List<Color>? colors,
    String? vibe,
  }) =>
      Identity(
        handle: handle ?? this.handle,
        glyph: glyph ?? this.glyph,
        colors: colors ?? this.colors,
        vibe: vibe ?? this.vibe,
      );

  LinearGradient get gradient => LinearGradient(
        colors: colors,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  Color get accent => colors.first;

  /// A palette of ready-made orb gradients to pick from during avatar creation.
  static const List<List<Color>> palettes = [
    [WhatIfColors.magenta, WhatIfColors.violet],
    [WhatIfColors.cyan, WhatIfColors.indigo],
    [WhatIfColors.mint, WhatIfColors.cyan],
    [WhatIfColors.amber, WhatIfColors.coral],
    [WhatIfColors.coral, WhatIfColors.magenta],
    [WhatIfColors.violet, WhatIfColors.cyan],
    [Color(0xFF7AF0A8), WhatIfColors.mint],
    [Color(0xFFB388FF), WhatIfColors.magenta],
  ];

  static const List<String> glyphs = [
    '🦊', '👾', '🐙', '🦄', '🐸', '🦉', '🐝', '🦋',
    '🔥', '⚡️', '🌙', '💫', '🍄', '🎧', '👑', '🃏',
  ];

  static const List<String> vibes = [
    'Chaos gremlin',
    'Certified menace',
    'Quiet but deadly',
    'Always down',
    'Main character',
    'Comic relief',
    'Group therapist',
    'Wildcard',
  ];

  /// A guest identity used before the user has made their own.
  static const Identity guest = Identity(
    handle: 'you',
    glyph: '👾',
    colors: [WhatIfColors.violet, WhatIfColors.cyan],
  );
}
