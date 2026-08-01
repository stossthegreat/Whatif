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
    GameDef(
      kind: GameKind.point, name: 'Caption This', hint: 'best caption wins — say it out loud',
      minStrangers: 1, maxStrangers: 8,
      prompts: [
        ['Caption this: 🐸🚗💨'], ['Caption this: 👵🛹🔥'], ['Caption this: 🦆👮‍♂️🚨'],
        ['Caption this: 🧍‍♂️🕳️👀'], ['Caption this: 🐱💼📉'], ['Caption this: 🤡🎂😭'],
      ],
    ),
    GameDef(
      kind: GameKind.point, name: 'Roast Me', hint: 'gentle roasts only — crown the best',
      minStrangers: 2, maxStrangers: 8,
      prompts: [
        ['Roast the person on your left (with love)'], ['Roast this app. Go.'],
        ['Roast your own haircut before someone else does'], ['Roast Mondays like they owe you money'],
      ],
    ),
    GameDef(
      kind: GameKind.same, name: 'Emoji Only', hint: 'answer in one emoji — match the room',
      minStrangers: 1, maxStrangers: 8,
      prompts: [
        ['Your week, in one emoji', '😂', '💀', '😭', '🔥'],
        ['Your love life, one emoji', '📉', '🔥', '👻', '🤡'],
        ['This room, one emoji', '🎪', '✨', '💀', '🧠'],
        ['Your bank account rn', '😭', '💀', '📉', '🤑'],
      ],
    ),
    GameDef(
      kind: GameKind.thumbs, name: 'Truth Meter', hint: '👍 = cap. call it out',
      minStrangers: 1, maxStrangers: 8,
      prompts: [
        ['“I could survive a week without my phone”'], ['“I’ve never stalked an ex online”'],
        ['“I always tip 20%”'], ['“I read the terms & conditions”'],
        ['“I’m a good texter”'], ['“I’ve never lied in this app”'],
      ],
    ),
    GameDef(
      kind: GameKind.point, name: 'Five Second Rule', hint: '5 seconds — then crown who nailed it',
      minStrangers: 1, maxStrangers: 8,
      prompts: [
        ['Name 5 fruits. FIVE SECONDS.'], ['Name 5 apps on your phone. GO.'],
        ['5 excuses for being late. NOW.'], ['5 things in your fridge. QUICK.'],
        ['5 red flags. FAST.'],
      ],
    ),
    GameDef(
      kind: GameKind.point, name: 'Act It Out', hint: 'mime it — first right guess crowns you',
      minStrangers: 1, maxStrangers: 8,
      prompts: [
        ['Mime: making a pizza'], ['Mime: losing your phone'], ['Mime: a cat at 3am'],
        ['Mime: airport security'], ['Mime: your morning routine'], ['Mime: winning the lottery'],
      ],
    ),
    GameDef(
      kind: GameKind.point, name: 'First To Find', hint: 'run — first back with it wins',
      minStrangers: 1, maxStrangers: 8,
      prompts: [
        ['First to show something RED'], ['First to show a spoon'], ['First to show shoes'],
        ['First to show something older than you'], ['First to show a snack'],
      ],
    ),
    GameDef(
      kind: GameKind.point, name: 'Worst Impression', hint: 'do it badly on purpose — funniest wins',
      minStrangers: 1, maxStrangers: 8,
      prompts: [
        ['Your worst BATMAN'], ['Your worst British accent'], ['Your worst influencer apology'],
        ['Your worst gym bro'], ['Your worst weather reporter'],
      ],
    ),
    GameDef(
      kind: GameKind.point, name: 'Finish The Lyric', hint: 'no music. full confidence.',
      minStrangers: 1, maxStrangers: 8,
      prompts: [
        ['Sing any chorus like it’s the final'], ['Finish a lyric everyone knows — wrong words allowed'],
        ['Hum a song — first to guess crowns you'],
      ],
    ),
    GameDef(
      kind: GameKind.point, name: 'One Word Story', hint: 'one word each — funniest ending wins',
      minStrangers: 2, maxStrangers: 8,
      prompts: [
        ['Start with: “Yesterday…”'], ['Start with: “Officer…”'], ['Start with: “Unfortunately…”'],
        ['Start with: “My therapist…”'],
      ],
    ),
    GameDef(
      kind: GameKind.point, name: 'Finish The Sentence', hint: 'funniest answer takes it',
      minStrangers: 1, maxStrangers: 8,
      prompts: [
        ['“My last search was…”'], ['“I knew it was over when…”'], ['“My villain origin story is…”'],
        ['“The weirdest thing I own is…”'], ['“My red flag is…”'],
      ],
    ),
    GameDef(
      kind: GameKind.point, name: 'Odd One Out', hint: 'someone got a different prompt. find them',
      minStrangers: 2, maxStrangers: 8,
      prompts: [
        ['One of you is describing a DIFFERENT thing 👀 — find them'],
        ['One of you got the fake prompt. Sniff them out.'],
        ['Someone here is improvising. Point at who.'],
      ],
    ),
    // ---- the confessional block (juice — people remember these) ------------
    GameDef(
      kind: GameKind.point, name: 'Hot Seat', hint: 'answer for real — juiciest wins',
      minStrangers: 1, maxStrangers: 8,
      prompts: [
        ['Hot seat: your most embarrassing camera-roll photo — describe it'],
        ['Hot seat: the dumbest thing you’ve ever cried about'],
        ['Hot seat: your worst text-to-the-wrong-person story'],
        ['Hot seat: the biggest L you’ve ever taken'],
        ['Hot seat: your most irrational fear'],
        ['Hot seat: the weirdest thing you’ve googled this week'],
      ],
    ),
    GameDef(
      kind: GameKind.point, name: 'Storytime', hint: '20 seconds — best story takes it',
      minStrangers: 1, maxStrangers: 8,
      prompts: [
        ['Most embarrassing moment. 20 seconds. GO'],
        ['Your worst date ever — make it quick'],
        ['The dumbest thing you believed as a kid'],
        ['Your most unhinged 3am decision'],
        ['A time you got caught lying'],
        ['Your biggest public L'],
      ],
    ),
    GameDef(
      kind: GameKind.point, name: 'Petty Court', hint: 'confess — the pettiest wins',
      minStrangers: 2, maxStrangers: 8,
      prompts: [
        ['Confess your pettiest move ever — pettiest wins'],
        ['The pettiest reason you’ve ever ghosted someone'],
        ['Your pettiest revenge story. GO'],
        ['The pettiest hill you will die on'],
      ],
    ),
    // ---- the performance block (chaos on camera) ---------------------------
    GameDef(
      kind: GameKind.point, name: 'Speed Debate', hint: '15 seconds. full confidence.',
      minStrangers: 1, maxStrangers: 8,
      prompts: [
        ['Defend: pineapple pizza is ELITE. 15 seconds'],
        ['Argue: cereal is a soup. Mean it.'],
        ['Defend: socks with sandals are fashion'],
        ['Argue: pigeons are government drones'],
        ['Defend: showering at night is superior'],
        ['Argue: the gym at 6am is a personality disorder'],
      ],
    ),
    GameDef(
      kind: GameKind.point, name: 'Rap Battle', hint: 'one bar. no beat. all heart.',
      minStrangers: 2, maxStrangers: 8,
      prompts: [
        ['One bar about the person on your right. GO'],
        ['Freestyle about your breakfast'],
        ['Drop a bar about this app'],
        ['Rap your morning routine'],
      ],
    ),
    GameDef(
      kind: GameKind.point, name: 'Scam Call', hint: 'commit to the bit — best scam wins',
      minStrangers: 1, maxStrangers: 8,
      prompts: [
        ['You’re a scam caller. Convince the room they won a cruise'],
        ['Sell the room a fake crypto coin'],
        ['You’re tech support. The problem is fake. Fix it anyway'],
        ['Cold-call the room about their car’s extended warranty'],
      ],
    ),
    GameDef(
      kind: GameKind.point, name: 'Conspiracy Corner', hint: 'pitch it like you believe it',
      minStrangers: 1, maxStrangers: 8,
      prompts: [
        ['Pitch a conspiracy about birds. Full confidence'],
        ['Explain why the moon is fake'],
        ['Convince us your neighbour is a time traveller'],
        ['Reveal what’s REALLY in airline food'],
      ],
    ),
    GameDef(
      kind: GameKind.point, name: 'Oscar Bait', hint: 'dramatic acting. tiny problem.',
      minStrangers: 1, maxStrangers: 8,
      prompts: [
        ['Dramatic scene: your toast burned. ACT.'],
        ['Cry about losing the TV remote — Oscar level'],
        ['Dramatic monologue: the wifi went down'],
        ['Win an award. Thank your haters. Tears.'],
      ],
    ),
    GameDef(
      kind: GameKind.point, name: 'Show & Tell', hint: 'grab it — best object wins',
      minStrangers: 1, maxStrangers: 8,
      prompts: [
        ['Grab the weirdest thing within reach — best object wins'],
        ['Show the oldest thing in the room'],
        ['Grab something that describes your personality'],
        ['Show your most prized possession under a tenner'],
      ],
    ),
    // ---- the judgement block (vote on each other — addictive) --------------
    GameDef(
      kind: GameKind.point, name: 'Superlatives', hint: 'the room decides who',
      minStrangers: 2, maxStrangers: 8,
      prompts: [
        ['Most likely to have a secret finsta'],
        ['Most likely to cry over a situationship'],
        ['Most likely to join a pyramid scheme'],
        ['Most likely to get famous for something embarrassing'],
        ['Most likely to argue with a self-checkout machine'],
        ['Most likely to text their ex tonight'],
      ],
    ),
    GameDef(
      kind: GameKind.poll, name: 'Green Flag Red Flag', hint: 'judge them. instantly.',
      minStrangers: 1, maxStrangers: 8,
      prompts: [
        ['They reply in 0.2 seconds', 'green flag', 'red flag'],
        ['They still follow all their exes', 'green flag', 'red flag'],
        ['They clap when the plane lands', 'green flag', 'red flag'],
        ['All their exes are “crazy”', 'green flag', 'red flag'],
        ['They talk to their pet in a baby voice', 'green flag', 'red flag'],
        ['Their camera roll is 90% selfies', 'green flag', 'red flag'],
      ],
    ),
    GameDef(
      kind: GameKind.thumbs, name: 'Delulu Check', hint: '👍 = you actually believe it',
      minStrangers: 1, maxStrangers: 8,
      prompts: [
        ['I could land a plane in an emergency'],
        ['I could survive a zombie apocalypse'],
        ['I’d win an argument with my therapist'],
        ['I’m the funniest person I know'],
        ['I could go pro if I trained for a year'],
        ['A celebrity would 100% date me'],
      ],
    ),
    GameDef(
      kind: GameKind.same, name: 'Cursed Combos', hint: 'pick the worst — match the room',
      minStrangers: 1, maxStrangers: 8,
      prompts: [
        ['Worst pizza topping', 'toothpaste', 'mayo ice cream', 'wet socks', 'gravel'],
        ['Worst superpower', 'always slightly damp', 'teleport 3cm', 'invisible when nobody looks', 'talk to pigeons'],
        ['Worst thing to say at a funeral', 'nice turnout', 'he owed me money', 'who’s hungry?', 'awkwarddd'],
        ['Worst wifi name', 'FBI van 12', 'virus.exe', 'mum click here', 'definitely not spying'],
      ],
    ),
    GameDef(
      kind: GameKind.freeze, name: 'NPC Mode', hint: 'you are not a real person. hold it.',
      minStrangers: 1, maxStrangers: 8,
      prompts: [
        ['Everyone act like an NPC. First to break loses'],
        ['You’re all mannequins. HOLD IT'],
        ['Buffering robots. Do not un-buffer.'],
      ],
    ),
  ];

  static const bag = [1, 1, 1, 2, 2, 3, 3, 5];
  static int rollGroupSize(Random r) => bag[r.nextInt(bag.length)];

  static GameDef byKind(GameKind k) => pack.firstWhere((g) => g.kind == k);
}

/// One round of a room's session: a game and its (pre-shuffled) prompt.
class RoundDef {
  RoundDef({required this.game, required this.prompt});
  final GameDef game;
  final List<String> prompt; // [head, ...options], options already shuffled
}

/// One live cell: who's here, a full session of rounds — and a personality.
/// Rooms are never "Room #421"; they're places you remember being thrown into.
class Cell {
  Cell({required this.people, required this.rounds, String? roomName})
      : roomName = roomName ?? roomNames[_rn.nextInt(roomNames.length)];
  final List<Person> people;

  /// A proper game session — several rounds before the ceremony, never a
  /// single question. The revive wheel can re-roll these to run it back.
  List<RoundDef> rounds;
  final String roomName;

  // convenience: the opening round (used by session memory / legacy callers)
  GameDef get game => rounds.first.game;
  List<String> get prompt => rounds.first.prompt;

  static final _rn = Random();
  static const roomNames = [
    '🔥 Chaos Kitchen', '👀 Red Flag Factory', '😂 Laugh Prison',
    '💀 Therapy Gone Wrong', '🤖 NPC Headquarters', '🧠 Galaxy Brain Zone',
    '🎪 The Circus', '🚨 Drama Department', '✨ Delulu Lounge',
    '🎭 Main Character School', '🧃 Vibe Check Point', '🌀 The Spin Cycle',
  ];

  int get strangers => people.length;
  bool get isOneToOne => people.length == 1;

  /// Roll a full session of [count] rounds for a group of [strangers] —
  /// each round a different game (no kind or name repeats back-to-back) with a
  /// prompt not seen recently, options shuffled. Unpredictable by construction.
  static List<RoundDef> rollRounds(
    Random r,
    int strangers, {
    int count = 5,
    GameKind? avoidKind,
    Set<String> recentHeads = const {},
  }) {
    final rounds = <RoundDef>[];
    var lastKind = avoidKind;
    String? lastName;
    final seen = {...recentHeads};

    for (var i = 0; i < count; i++) {
      var fits = GameDef.pack.where((g) => g.fits(strangers)).toList();
      if (fits.isEmpty) fits = [...GameDef.pack];
      final varied = fits.where((g) => g.kind != lastKind && g.name != lastName).toList();
      if (varied.isNotEmpty) fits = varied;
      final game = fits[r.nextInt(fits.length)];
      lastKind = game.kind;
      lastName = game.name;

      List<String> chosen = game.prompts[r.nextInt(game.prompts.length)];
      for (var t = 0; t < 6 && seen.contains(chosen.first); t++) {
        chosen = game.prompts[r.nextInt(game.prompts.length)];
      }
      seen.add(chosen.first);

      final head = chosen.first;
      final opts = chosen.skip(1).toList()..shuffle(r);
      rounds.add(RoundDef(game: game, prompt: [head, ...opts]));
    }
    return rounds;
  }

  /// Re-roll this room's session in place — the revive wheel's "run it back".
  void reroll(Random r) {
    rounds = rollRounds(r, people.length, avoidKind: rounds.last.game.kind);
  }

  static Cell random(
    Random r, {
    GameKind? avoidKind,
    Set<String> recentHeads = const {},
  }) {
    final n = GameDef.rollGroupSize(r);
    return Cell(
      people: Person.group(r, n),
      rounds: rollRounds(r, n, avoidKind: avoidKind, recentHeads: recentHeads),
    );
  }
}
