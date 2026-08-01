import 'package:flutter/material.dart';
import '../theme/colors.dart';
import 'identity.dart';
import 'game.dart';
import 'room.dart';

/// A hand-built cast of characters so every screen feels populated. Solving the
/// "empty room problem" at the demo level: a newcomer walks into a lively board,
/// never a void.
class Mock {
  Mock._();

  static const List<Identity> roster = [
    Identity(handle: 'mira', glyph: '🦊', colors: [WhatIfColors.magenta, WhatIfColors.violet], vibe: 'Chaos gremlin'),
    Identity(handle: 'deqo', glyph: '👾', colors: [WhatIfColors.cyan, WhatIfColors.indigo], vibe: 'Wildcard'),
    Identity(handle: 'juno', glyph: '🐙', colors: [WhatIfColors.mint, WhatIfColors.cyan], vibe: 'Quiet but deadly'),
    Identity(handle: 'kayo', glyph: '🦄', colors: [WhatIfColors.amber, WhatIfColors.coral], vibe: 'Main character'),
    Identity(handle: 'sol', glyph: '🐸', colors: [WhatIfColors.coral, WhatIfColors.magenta], vibe: 'Comic relief'),
    Identity(handle: 'ren', glyph: '🦉', colors: [WhatIfColors.violet, WhatIfColors.cyan], vibe: 'Group therapist'),
    Identity(handle: 'bex', glyph: '🐝', colors: [WhatIfColors.amber, WhatIfColors.mint], vibe: 'Always down'),
    Identity(handle: 'nix', glyph: '🦋', colors: [Color(0xFFB388FF), WhatIfColors.magenta], vibe: 'Certified menace'),
    Identity(handle: 'oz', glyph: '🔥', colors: [WhatIfColors.coral, WhatIfColors.amber], vibe: 'Wildcard'),
    Identity(handle: 'vee', glyph: '⚡️', colors: [WhatIfColors.cyan, WhatIfColors.mint], vibe: 'Main character'),
    Identity(handle: 'lux', glyph: '🌙', colors: [WhatIfColors.violet, WhatIfColors.indigo], vibe: 'Quiet but deadly'),
    Identity(handle: 'ash', glyph: '💫', colors: [WhatIfColors.magenta, WhatIfColors.coral], vibe: 'Chaos gremlin'),
    Identity(handle: 'tam', glyph: '🍄', colors: [WhatIfColors.mint, WhatIfColors.cyan], vibe: 'Comic relief'),
    Identity(handle: 'ivo', glyph: '🎧', colors: [WhatIfColors.indigo, WhatIfColors.violet], vibe: 'Always down'),
    Identity(handle: 'poppy', glyph: '👑', colors: [WhatIfColors.amber, WhatIfColors.magenta], vibe: 'Main character'),
    Identity(handle: 'zed', glyph: '🃏', colors: [Color(0xFFB388FF), WhatIfColors.cyan], vibe: 'Certified menace'),
  ];

  static List<Identity> group(int n, {int from = 0}) =>
      List.generate(n, (i) => roster[(from + i) % roster.length]);

  /// Tonight's live board.
  static List<Room> tonight() => [
        Room(
          name: 'no thoughts just vibes',
          host: roster[0],
          players: group(7, from: 0),
          game: GameType.pack[0], // Impostor
          capacity: 8,
          energy: 0.85,
          friendsInside: 2,
        ),
        Room(
          name: 'certified menace hours',
          host: roster[7],
          players: group(5, from: 5),
          game: GameType.pack[1], // Hot Takes
          capacity: 8,
          energy: 0.7,
          friendsInside: 1,
        ),
        Room(
          name: 'caption crimes',
          host: roster[2],
          players: group(6, from: 2),
          game: GameType.pack[2], // Caption This
          capacity: 10,
          energy: 0.6,
        ),
        Room(
          name: 'the split',
          host: roster[9],
          players: group(4, from: 9),
          game: GameType.pack[3], // WYR
          capacity: 8,
          energy: 0.45,
        ),
      ];

  /// The nightly prime-time headliner (HQ/BeReal appointment energy).
  static Room primeTime() => Room(
        name: 'PRIME TIME',
        host: roster[14],
        players: group(12, from: 0),
        game: GameType.pack[4], // Most Likely To
        capacity: 24,
        energy: 1.0,
        friendsInside: 3,
        startingInSeconds: 1420, // ~23 min
      );
}
