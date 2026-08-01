import 'dart:math';
import 'person.dart';

/// The rotating game pack. Each game is a template + a prompt pool. The live
/// screen interprets [kind] to render the interaction. Games are tagged by how
/// many *strangers* they need, so the matchmaker can serve genuinely different
/// experiences — including 1:1-only games — depending on the (unpredictable)
/// group size.
enum GameKind { point, poll, wouldRather, thumbs, same, freeze, twoTruths, rapidFire }

class GameDef {
  const GameDef({
    required this.kind,
    required this.name,
    required this.hint,
    required this.minStrangers,
    required this.maxStrangers,
    required this.prompts,
  });

  final GameKind kind;
  final String name;
  final String hint;
  final int minStrangers;
  final int maxStrangers;

  /// Each prompt is [headline, ...options]. Some kinds ignore options.
  final List<List<String>> prompts;

  List<String> pick(Random r) => prompts[r.nextInt(prompts.length)];

  bool fits(int strangers) => strangers >= minStrangers && strangers <= maxStrangers;

  static const pack = <GameDef>[
    // ---- group (needs someone to point at) ----
    GameDef(
      kind: GameKind.point, name: 'Point Party', hint: 'tap who fits — everyone points at once',
      minStrangers: 2, maxStrangers: 8,
      prompts: [
        ['Who woke up 5 minutes ago?'],
        ['Most likely to start a cult (a fun one)'],
        ['Who texts their ex at 2am?'],
        ['Most likely to be a secret genius'],
        ['Who is definitely lying right now?'],
        ['Most likely to cry at a dog video'],
      ],
    ),
    // ---- works at any size, including 1:1 ----
    GameDef(
      kind: GameKind.poll, name: 'Hot Take', hint: 'pick a side',
      minStrangers: 1, maxStrangers: 8,
      prompts: [
        ['Pineapple on pizza?', 'crime', 'genius'],
        ['Socks in bed?', 'yes', 'never'],
        ['Text or call?', 'text', 'call'],
        ['Cereal then milk?', 'right', 'chaos'],
      ],
    ),
    GameDef(
      kind: GameKind.thumbs, name: 'Confession Cam', hint: 'thumbs up = guilty · on 3',
      minStrangers: 1, maxStrangers: 8,
      prompts: [
        ['Never have I ever been kicked out of a bar'],
        ['…ghosted someone mid-conversation'],
        ['…sent a text to the completely wrong person'],
        ['…faked being busy to skip plans'],
      ],
    ),
    GameDef(
      kind: GameKind.same, name: 'Same Brain', hint: 'match the room — pick fast',
      minStrangers: 1, maxStrangers: 8,
      prompts: [
        ['Name a fruit', 'banana', 'apple', 'mango', 'grape'],
        ['A colour, go', 'blue', 'red', 'green', 'black'],
        ['Pick a vibe', 'chaotic', 'chill', 'menace', 'soft'],
      ],
    ),
    GameDef(
      kind: GameKind.freeze, name: 'Freeze Face', hint: 'hold it — last to laugh wins',
      minStrangers: 1, maxStrangers: 8,
      prompts: [
        ['Hold your most SHOCKED face'],
        ['Hold a straight face. No matter what.'],
        ['Give your worst fake cry — and hold'],
      ],
    ),
    // ---- 1:1 flavoured ----
    GameDef(
      kind: GameKind.wouldRather, name: 'Would You Rather', hint: 'lock your choice, then compare',
      minStrangers: 1, maxStrangers: 6,
      prompts: [
        ['Fight 100 duck-sized horses, or…', '100 tiny horses', '1 giant duck'],
        ['Always be 10 min late, or…', 'always late', 'always 20 early'],
        ['Read minds, or…', 'read minds', 'be invisible'],
      ],
    ),
    GameDef(
      kind: GameKind.twoTruths, name: 'Two Truths', hint: 'read their face — spot the lie',
      minStrangers: 1, maxStrangers: 2,
      prompts: [
        ['Which one is the lie?', 'skydived once', 'has four siblings', 'hates coffee'],
        ['Spot the lie', 'met a celebrity', 'speaks 3 languages', 'broke a bone at 7'],
        ['Which is fake?', 'ran a marathon', 'was on TV once', 'can’t swim'],
      ],
    ),
    GameDef(
      kind: GameKind.rapidFire, name: 'Rapid Fire', hint: '10 seconds. don’t overthink.',
      minStrangers: 1, maxStrangers: 1,
      prompts: [
        ['Say the first word you think of: SUNDAY'],
        ['Describe your week in one word — go'],
        ['Best food, worst food. Fast.'],
      ],
    ),
  ];

  /// Weighted toward small cells, with the occasional crowd. Returns the number
  /// of *strangers* in the cell (you are always the +1).
  static int rollGroupSize(Random r) {
    const bag = [1, 1, 1, 2, 2, 3, 3, 5];
    return bag[r.nextInt(bag.length)];
  }

  static GameDef rollGame(Random r, int strangers) {
    final fits = pack.where((g) => g.fits(strangers)).toList();
    return fits[r.nextInt(fits.length)];
  }
}

/// One live cell: who's here, the game, and the chosen prompt.
class Cell {
  Cell({required this.people, required this.game, required this.prompt});
  final List<Person> people;
  final GameDef game;
  final List<String> prompt;

  int get strangers => people.length;
  bool get isOneToOne => people.length == 1;

  static Cell random(Random r) {
    final n = GameDef.rollGroupSize(r);
    final game = GameDef.rollGame(r, n);
    return Cell(people: Person.group(r, n), game: game, prompt: game.pick(r));
  }
}
