import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// A game type in the rotating pack. The product spine (per research) is a
/// *rotating, role-asymmetric, reveal-driven* group game — Among Us × Jackbox —
/// not a single fixed mechanic. Each type is a one-sentence rule (low skill
/// floor) that ends in a public reveal (the screen-recordable "story" moment).
class GameType {
  const GameType({
    required this.name,
    required this.tagline,
    required this.rule,
    required this.glyph,
    required this.colors,
    required this.asymmetric,
    this.spicy = false,
  });

  final String name;
  final String tagline;
  final String rule; // the single-sentence rule shown on the card
  final String glyph;
  final List<Color> colors;
  final bool asymmetric; // does someone know something the others don't?
  final bool spicy; // opt-in flirty energy (spin-the-bottle lives here)

  LinearGradient get gradient =>
      LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight);

  static const List<GameType> pack = [
    GameType(
      name: 'Impostor',
      tagline: 'One of you got a different prompt.',
      rule: 'Everyone answers the same question — except the impostor, who got a slightly different one. Find them.',
      glyph: '🎭',
      colors: [WhatIfColors.magenta, WhatIfColors.violet],
      asymmetric: true,
    ),
    GameType(
      name: 'Hot Takes',
      tagline: 'Anonymous opinions. Guess who.',
      rule: 'Everyone drops their spiciest take anonymously. The room votes on who said what.',
      glyph: '🌶️',
      colors: [WhatIfColors.coral, WhatIfColors.magenta],
      asymmetric: true,
    ),
    GameType(
      name: 'Caption This',
      tagline: 'Make the room laugh.',
      rule: 'Same cursed image. Best caption wins the round — you vote, you don\'t vote for your own.',
      glyph: '💬',
      colors: [WhatIfColors.cyan, WhatIfColors.indigo],
      asymmetric: false,
    ),
    GameType(
      name: 'Would You Rather',
      tagline: 'Reveal the split.',
      rule: 'Two terrible options. Lock your choice — then watch the room split in real time.',
      glyph: '⚖️',
      colors: [WhatIfColors.mint, WhatIfColors.cyan],
      asymmetric: false,
    ),
    GameType(
      name: 'Most Likely To',
      tagline: 'Point the finger.',
      rule: 'A prompt appears. Everyone points at one person at once. Brace yourself.',
      glyph: '👉',
      colors: [WhatIfColors.amber, WhatIfColors.coral],
      asymmetric: false,
    ),
    GameType(
      name: 'Truth Roulette',
      tagline: 'The bottle points at a dare.',
      rule: 'The wheel spins and lands on a truth or a dare — for the whole table, not a forced pairing.',
      glyph: '🍾',
      colors: [WhatIfColors.violet, WhatIfColors.magenta],
      asymmetric: false,
      spicy: true,
    ),
  ];
}

/// The phases a live round moves through. Drives the live-room choreography.
enum RoundPhase {
  gathering, // players arriving, waiting to start
  reveal, // "next up: ???" mystery reveal of the game
  prompt, // the question is shown, you answer
  answering, // players lock answers, countdown
  voting, // the room votes
  results, // the public reveal — the peak
}

extension RoundPhaseX on RoundPhase {
  String get label => switch (this) {
        RoundPhase.gathering => 'Gathering',
        RoundPhase.reveal => 'Next up',
        RoundPhase.prompt => 'Your move',
        RoundPhase.answering => 'Lock it in',
        RoundPhase.voting => 'Vote',
        RoundPhase.results => 'The reveal',
      };
}
