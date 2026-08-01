import 'dart:math';
import 'person.dart';

/// The rotating game pack. Each game is a template + a big prompt pool. The live
/// screen interprets [kind] to render the interaction. Games are tagged by how
/// many *strangers* they need, so the matchmaker can serve genuinely different
/// experiences — including 1:1-only games — depending on the (unpredictable)
/// group size. Prompts are deep and never repeat back-to-back, so no two plays
/// feel the same.
enum GameKind { point, poll, wouldRather, thumbs, same, freeze, twoTruths, rapidFire }

GameKind gameKindFrom(String s) =>
    GameKind.values.firstWhere((k) => k.name == s, orElse: () => GameKind.poll);

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

  bool fits(int strangers) => strangers >= minStrangers && strangers <= maxStrangers;

  static const pack = <GameDef>[
    GameDef(
      kind: GameKind.point, name: 'Point Party', hint: 'tap who fits — everyone points at once',
      minStrangers: 2, maxStrangers: 8,
      prompts: [
        ['Who woke up 5 minutes ago?'], ['Most likely to start a cult (a fun one)'],
        ['Who texts their ex at 2am?'], ['Most likely to be a secret genius'],
        ['Who is definitely lying right now?'], ['Most likely to cry at a dog video'],
        ['Who would survive a horror movie?'], ['Most likely to fight a goose and lose'],
        ['Who has the worst screen time?'], ['Most likely to become famous'],
        ['Who is the main character here?'], ['Most likely to ghost the group'],
        ['Who gives the best advice?'], ['Most likely to start dancing right now'],
      ],
    ),
    GameDef(
      kind: GameKind.poll, name: 'Hot Take', hint: 'pick a side',
      minStrangers: 1, maxStrangers: 8,
      prompts: [
        ['Pineapple on pizza?', 'crime', 'genius'], ['Socks in bed?', 'yes', 'never'],
        ['Text or call?', 'text', 'call'], ['Cereal then milk?', 'right', 'chaos'],
        ['Front camera or back?', 'front', 'back'], ['TP over or under?', 'over', 'under'],
        ['Beach or mountains?', 'beach', 'mountains'], ['Morning person?', 'yes', 'absolutely not'],
        ['Tattoos?', 'love them', 'never'], ['Cats or dogs?', 'cats', 'dogs'],
        ['Is a hotdog a sandwich?', 'yes', 'how dare you'], ['Reply-all?', 'chaos', 'crime'],
      ],
    ),
    GameDef(
      kind: GameKind.thumbs, name: 'Confession Cam', hint: 'thumbs up = guilty · on 3',
      minStrangers: 1, maxStrangers: 8,
      prompts: [
        ['Never have I ever been kicked out of a bar'], ['…ghosted someone mid-conversation'],
        ['…sent a text to the completely wrong person'], ['…faked being busy to skip plans'],
        ['…stalked an ex online this week'], ['…cried in a public bathroom'],
        ['…pretended to know a song I didn’t'], ['…re-gifted a present'],
        ['…screenshotted a chat to send to friends'], ['…had a crush on a friend’s partner'],
        ['…googled myself'], ['…lied to get out of a date'],
      ],
    ),
    GameDef(
      kind: GameKind.same, name: 'Same Brain', hint: 'match the room — pick fast',
      minStrangers: 1, maxStrangers: 8,
      prompts: [
        ['Name a fruit', 'banana', 'apple', 'mango', 'grape'],
        ['A colour, go', 'blue', 'red', 'green', 'black'],
        ['Pick a vibe', 'chaotic', 'chill', 'menace', 'soft'],
        ['A random animal', 'cat', 'dog', 'fox', 'shark'],
        ['Say a country', 'japan', 'italy', 'brazil', 'egypt'],
        ['Pick a season', 'summer', 'winter', 'spring', 'autumn'],
        ['A drink', 'coffee', 'tea', 'water', 'chaos'],
        ['Number 1–4', '1', '2', '3', '4'],
      ],
    ),
    GameDef(
      kind: GameKind.freeze, name: 'Freeze Face', hint: 'hold it — last to laugh wins',
      minStrangers: 1, maxStrangers: 8,
      prompts: [
        ['Hold your most SHOCKED face'], ['Hold a straight face. No matter what.'],
        ['Give your worst fake cry — and hold'], ['Your best villain smile — freeze'],
        ['Most confused face — hold it'], ['Puppy eyes. Do not break.'],
        ['Your “I smelled something” face'], ['Hold your happiest fake laugh'],
      ],
    ),
    GameDef(
      kind: GameKind.wouldRather, name: 'Would You Rather', hint: 'lock your choice, then compare',
      minStrangers: 1, maxStrangers: 6,
      prompts: [
        ['Fight 100 duck-sized horses, or…', '100 tiny horses', '1 giant duck'],
        ['Always be 10 min late, or…', 'always late', 'always 20 early'],
        ['Read minds, or…', 'read minds', 'be invisible'],
        ['Never use a phone again, or…', 'no phone', 'no music'],
        ['Be famous, or…', 'famous', 'filthy rich'],
        ['Only whisper forever, or…', 'whisper', 'shout'],
        ['Teleport, or…', 'teleport', 'fly'],
        ['No pizza forever, or…', 'no pizza', 'no burgers'],
      ],
    ),
    GameDef(
      kind: GameKind.twoTruths, name: 'Two Truths', hint: 'read their face — spot the lie',
      minStrangers: 1, maxStrangers: 2,
      prompts: [
        ['Which one is the lie?', 'skydived once', 'has four siblings', 'hates coffee'],
        ['Spot the lie', 'met a celebrity', 'speaks 3 languages', 'broke a bone at 7'],
        ['Which is fake?', 'ran a marathon', 'was on TV once', 'can’t swim'],
        ['Find the lie', 'been to 10 countries', 'allergic to cats', 'plays guitar'],
        ['Which is made up?', 'has a twin', 'failed the driving test 4x', 'ate a bug on a dare'],
      ],
    ),
    GameDef(
      kind: GameKind.rapidFire, name: 'Rapid Fire', hint: '10 seconds. don’t overthink.',
      minStrangers: 1, maxStrangers: 1,
      prompts: [
        ['Say the first word you think of: SUNDAY'], ['Describe your week in one word — go'],
        ['Best food, worst food. Fast.'], ['Name 3 things in your room — go'],
        ['Your hype song, right now'], ['Sum up your day in one emoji'],
        ['Last thing you ate — quick'], ['Say a red thing, a blue thing, a green thing'],
      ],
    ),
    // ---- the wild ones (perform, then the room crowns someone) ----
    GameDef(
      kind: GameKind.point, name: 'Red Flag', hint: 'point at your suspect',
      minStrangers: 2, maxStrangers: 8,
      prompts: [
        ['Most likely to forget your birthday'], ['Most likely to cry first in a movie'],
        ['Most likely to text back in 3 days'], ['Most likely to get arrested for something dumb'],
        ['Most likely to ghost after one date'], ['Biggest red-flag energy'],
        ['Most likely to start drama'], ['Most likely to fake their own disappearance'],
      ],
    ),
    GameDef(
      kind: GameKind.point, name: 'Voice Swap', hint: 'do the voice — then point at who nailed it',
      minStrangers: 1, maxStrangers: 8,
      prompts: [
        ['Everyone talk like a PIRATE 🏴‍☠️'], ['Talk like a ROBOT 🤖'],
        ['Talk like your GRANDMA 👵'], ['Talk like a CEO on a podcast 💼'],
        ['Talk like a BABY 👶'], ['Talk like a movie VILLAIN 😈'],
      ],
    ),
    GameDef(
      kind: GameKind.point, name: 'Sell It', hint: '30 seconds — then crown the best pitch',
      minStrangers: 1, maxStrangers: 8,
      prompts: [
        ['Sell a single sock to the room'], ['Sell a banana like it’s a supercar'],
        ['Sell this app to a stranger'], ['Sell a rock as a life-changing product'],
        ['Convince the room to give you £100'],
      ],
    ),
    GameDef(
      kind: GameKind.point, name: 'Survival', hint: 'argue your case — then vote the survivor',
      minStrangers: 2, maxStrangers: 8,
      prompts: [
        ['Zombie apocalypse — who survives? Make your case'], ['Plane crash on an island — who’s useful?'],
        ['Last one in the bunker — why you?'], ['Prison break — who’s the brains?'],
      ],
    ),
    GameDef(
      kind: GameKind.point, name: 'Fake Flex', hint: 'one of you is secretly rich — find them',
      minStrangers: 2, maxStrangers: 8,
      prompts: [
        ['Convince everyone you’re secretly a millionaire — point at the real one'],
        ['One of you has a private jet — point at who’s telling the truth'],
        ['Spot the secret genius in the room'],
      ],
    ),
    GameDef(
      kind: GameKind.point, name: 'Sound Effect', hint: 'recreate it — funniest wins',
      minStrangers: 2, maxStrangers: 8,
      prompts: [
        ['Everyone make a COW 🐄 — point at the best'], ['Make a police SIREN 🚨'],
        ['Make a phone RINGTONE 📱'], ['Do your best EVIL LAUGH 😈'],
      ],
    ),
    GameDef(
      kind: GameKind.point, name: 'First Impression', hint: 'first 5 seconds — vote your fave',
      minStrangers: 2, maxStrangers: 8,
      prompts: [
        ['Who’s the main character of this room?'], ['Who would you grab a drink with?'],
        ['Who’s got the best energy?'], ['Who’s the most chaotic?'],
      ],
    ),
    GameDef(
      kind: GameKind.freeze, name: 'Laugh Lock', hint: 'do NOT laugh first',
      minStrangers: 1, maxStrangers: 8,
      prompts: [
        ['Laugh Lock — first to laugh loses'], ['Straightest face wins. Go.'],
        ['Try not to smile. Impossible.'],
      ],
    ),
  ];

  static const bag = [1, 1, 1, 2, 2, 3, 3, 5];
  static int rollGroupSize(Random r) => bag[r.nextInt(bag.length)];

  static GameDef byKind(GameKind k) => pack.firstWhere((g) => g.kind == k);
}

/// One live cell: who's here, the game, and the chosen prompt.
class Cell {
  Cell({required this.people, required this.game, required this.prompt});
  final List<Person> people;
  final GameDef game;
  final List<String> prompt; // [head, ...options], options already shuffled

  int get strangers => people.length;
  bool get isOneToOne => people.length == 1;

  /// Unpredictable by construction: rolls a group size, then a game valid for it
  /// (avoiding the last kind), then a prompt not seen recently, with options
  /// shuffled — so a repeated game type never plays identically.
  static Cell random(
    Random r, {
    GameKind? avoidKind,
    Set<String> recentHeads = const {},
  }) {
    final n = GameDef.rollGroupSize(r);
    var fits = GameDef.pack.where((g) => g.fits(n)).toList();
    final varied = fits.where((g) => g.kind != avoidKind).toList();
    if (varied.isNotEmpty) fits = varied;
    final game = fits[r.nextInt(fits.length)];

    // pick a prompt not used recently (try a handful of times)
    List<String> chosen = game.prompts[r.nextInt(game.prompts.length)];
    for (var i = 0; i < 6 && recentHeads.contains(chosen.first); i++) {
      chosen = game.prompts[r.nextInt(game.prompts.length)];
    }

    // shuffle the options (keep the headline first)
    final head = chosen.first;
    final opts = chosen.skip(1).toList()..shuffle(r);
    final prompt = [head, ...opts];

    return Cell(people: Person.group(r, n), game: game, prompt: prompt);
  }
}
