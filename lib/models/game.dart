import 'dart:math';
import 'person.dart';

/// The rotating game pack. Each game is a template + a big prompt pool. The live
/// screen interprets [kind] to render the interaction. Games are tagged by how
/// many *strangers* they need, so the matchmaker can serve genuinely different
/// experiences — including 1:1-only games — depending on the (unpredictable)
/// group size. Prompts are deep and never repeat back-to-back, so no two plays
/// feel the same.
enum GameKind { point, poll, wouldRather, thumbs, same, freeze, twoTruths, rapidFire, spin }

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
    this.vibe = 'wild',
  });

  final GameKind kind;
  final String name;
  final String hint;
  final int minStrangers;
  final int maxStrangers;

  /// Session-arc tier: 'warm' (round 1 — instant answers), 'wild' (the chaos
  /// middle), 'spark' (the flirty finale — the seed of the dating vision).
  final String vibe;

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
      kind: GameKind.poll, name: 'Hot Take', vibe: 'warm', hint: 'pick a side',
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
      kind: GameKind.same, name: 'Same Brain', vibe: 'warm', hint: 'match the room — pick fast',
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
      kind: GameKind.wouldRather, name: 'Would You Rather', vibe: 'warm', hint: 'lock your choice, then compare',
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
      kind: GameKind.twoTruths, name: 'Two Truths', vibe: 'spark', hint: 'read their face — spot the lie',
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
      kind: GameKind.point, name: 'First Impression', vibe: 'spark', hint: 'first 5 seconds — vote your fave',
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
      kind: GameKind.same, name: 'Emoji Only', vibe: 'warm', hint: 'answer in one emoji — match the room',
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
      kind: GameKind.poll, name: 'Green Flag Red Flag', vibe: 'warm', hint: 'judge them. instantly.',
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
      kind: GameKind.thumbs, name: 'Delulu Check', vibe: 'warm', hint: '👍 = you actually believe it',
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
      kind: GameKind.same, name: 'Cursed Combos', vibe: 'warm', hint: 'pick the worst — match the room',
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
    // ---- face battles (the camera IS the game) -----------------------------
    GameDef(
      kind: GameKind.freeze, name: 'Face Battle', hint: 'pull it. HOLD it. funniest wins.',
      minStrangers: 1, maxStrangers: 8,
      prompts: [
        ['UGLIEST face contest. 3…2…1 GO'],
        ['Best fish face 🐟 hold it'],
        ['Cross-eyed + tongue out. HOLD'],
        ['Double chin championship. Commit.'],
        ['Your best “I just saw my ex” face'],
        ['Your “wifi dropped mid-message” face'],
        ['Best evil villain smirk. Freeze.'],
        ['The face you make reading old texts'],
      ],
    ),
    // ---- SPARK — the flirty finale (the seed of the dating vision) ---------
    GameDef(
      kind: GameKind.spin, name: 'Spin the Bottle', vibe: 'spark', hint: 'the bottle picks. no escape.',
      minStrangers: 1, maxStrangers: 8,
      prompts: [
        ['{target} — what’s your actual type? Be honest'],
        ['{target} — rate your own rizz out of 10'],
        ['{target} — best pickup line. Right now.'],
        ['{target} — who in this room would you take on a date? 👀'],
        ['{target} — blow the room a kiss. Commit.'],
        ['{target} — describe your dream date in 10 seconds'],
        ['{target} — your most romantic move ever. Spill.'],
        ['{target} — flirt with the camera for 5 seconds'],
      ],
    ),
    GameDef(
      kind: GameKind.point, name: 'Rizz Battle', vibe: 'spark', hint: 'smoothest wins. or funniest fail.',
      minStrangers: 1, maxStrangers: 8,
      prompts: [
        ['Best pickup line wins. GO'],
        ['Worst pickup line on purpose'],
        ['Rizz up an imaginary barista'],
        ['Shoot your shot at the camera — smoothest wins'],
        ['Compliment someone so hard they short-circuit'],
      ],
    ),
    GameDef(
      kind: GameKind.freeze, name: 'Kiss Face', vibe: 'spark', hint: 'fully commit. do not laugh.',
      minStrangers: 1, maxStrangers: 8,
      prompts: [
        ['Practice your kiss face 😗 HOLD IT'],
        ['Slow-motion air kiss. Fully commit 😂'],
        ['Wink at the camera like a movie star. Freeze.'],
        ['Your best “hey you” face. Hold it.'],
        ['Blow a kiss in extreme slow motion'],
      ],
    ),
    GameDef(
      kind: GameKind.freeze, name: 'Eye Contact', vibe: 'spark', hint: 'hold it. no laughing.',
      minStrangers: 1, maxStrangers: 8,
      prompts: [
        ['Dead-eye contact with the camera. 10 seconds. No laughing'],
        ['Stare-off. First to blink loses'],
        ['Look into the lens like you’re in love. HOLD.'],
        ['Eye contact + slow smile. Do not crack.'],
      ],
    ),
    GameDef(
      kind: GameKind.point, name: 'Compliment Battle', vibe: 'spark', hint: 'make someone blush — words only',
      minStrangers: 2, maxStrangers: 8,
      prompts: [
        ['Best compliment to the person on your left'],
        ['Hype up a stranger like they’re your best mate'],
        ['Make someone blush with words only'],
        ['Give the most oddly specific compliment'],
      ],
    ),
    GameDef(
      kind: GameKind.point, name: 'Date Pitch', vibe: 'spark', hint: '30 seconds. sell it.',
      minStrangers: 1, maxStrangers: 8,
      prompts: [
        ['30 seconds: why you’d be an elite date'],
        ['Pitch the WORST date idea ever'],
        ['Sell your love life like a startup'],
        ['Plan a first date with £5. Convince us.'],
      ],
    ),
  ];

  static const bag = [1, 1, 1, 2, 2, 3, 3, 5];
  static int rollGroupSize(Random r) => bag[r.nextInt(bag.length)];

  static GameDef byKind(GameKind k) => pack.firstWhere((g) => g.kind == k);
}

/// One round of a room's session: a game and its (pre-shuffled) prompt.
/// [targetId] / [lieIdx] arrive only from a sync-capable server — their
/// presence is what switches the room into server-authoritative mode.
class RoundDef {
  RoundDef({required this.game, required this.prompt, this.targetId, this.lieIdx, this.secs});
  final GameDef game;
  final List<String> prompt; // [head, ...options], options already shuffled
  final String? targetId; // conn-id of the member "on the spot"
  final int? lieIdx; // twoTruths: which option is the lie
  final int? secs; // beat-specific duration override
}

/// One live cell: who's here, a full session of rounds — and a personality.
/// Rooms are never "Room #421"; they're places you remember being thrown into.
class Cell {
  Cell({required this.people, required this.rounds, String? roomName, this.golden, this.luckyId, this.mode})
      : roomName = roomName ?? roomNames[_rn.nextInt(roomNames.length)];

  /// 'roulette' (games auto-chain, no choices) or 'hang' (talk-first).
  final String? mode;
  final List<Person> people;

  /// Server-rolled room state (null in simulated mode → client rolls locally).
  final bool? golden;
  final String? luckyId;

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
      // the session arc: open warm (instant answers), end on spark (flirty).
      // Strangers need a warm-up before they'll do a kiss face.
      final wantVibe = i == 0 ? 'warm' : (i == count - 1 ? 'spark' : null);
      if (wantVibe != null) {
        final tiered = fits.where((g) => g.vibe == wantVibe).toList();
        if (tiered.isNotEmpty) fits = tiered;
      }
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
    String? mode,
  }) {
    final n = GameDef.rollGroupSize(r);
    return Cell(
      people: Person.group(r, n),
      rounds: rollRounds(r, n, avoidKind: avoidKind, recentHeads: recentHeads),
      mode: mode,
    );
  }
}

/// One beat of a blended game: a kind + a pool of candidate prompts.
class SeqBeat {
  const SeqBeat({required this.kind, required this.pool, this.secs});
  final GameKind kind;
  final List<List<String>> pool;
  final int? secs;
}

/// One of THE TEN — a blended sequence of beats, never a single throwaway
/// prompt. Mirrors the server pack (names must match for pickGame).
class SeqDef {
  const SeqDef({required this.name, required this.icon, required this.hint, required this.vibe, required this.beats});
  final String name;
  final String icon;
  final String hint;
  final String vibe;
  final List<SeqBeat> beats;

  static const ten = <SeqDef>[
    SeqDef(name: 'Face Off', icon: '😜', hint: 'pull it · hold it · crown it', vibe: 'warm', beats: [
      SeqBeat(kind: GameKind.freeze, secs: 8, pool: [['UGLIEST face contest. 3…2…1 GO'], ['Best fish face 🐟 HOLD IT'], ['Double chin championship. Commit.']]),
      SeqBeat(kind: GameKind.freeze, secs: 8, pool: [['Now your best villain smirk. Freeze.'], ['The face you make reading old texts'], ['Your “I just saw my ex” face']]),
      SeqBeat(kind: GameKind.point, secs: 10, pool: [['Crown the funniest face 👑']]),
    ]),
    SeqDef(name: 'Eye Contact', icon: '👀', hint: 'hold it · smile · don’t crack', vibe: 'spark', beats: [
      SeqBeat(kind: GameKind.freeze, secs: 8, pool: [['Dead-eye contact with the camera. No laughing.']]),
      SeqBeat(kind: GameKind.freeze, secs: 8, pool: [['Now a SLOW smile. Do not crack.'], ['Now wink like a movie star. Hold it.']]),
      SeqBeat(kind: GameKind.point, secs: 10, pool: [['Who broke first? Point.']]),
    ]),
    SeqDef(name: 'Hot Takes', icon: '🔥', hint: 'three takes · pick sides · argue', vibe: 'warm', beats: [
      SeqBeat(kind: GameKind.poll, pool: [['Pineapple on pizza?', 'crime', 'genius'], ['Is a hotdog a sandwich?', 'yes', 'how dare you'], ['Cereal then milk?', 'right', 'chaos']]),
      SeqBeat(kind: GameKind.poll, pool: [['Texting “lol” means nothing?', 'facts', 'lies'], ['Gym at 6am?', 'built different', 'lying'], ['Voice notes?', 'elite', 'jail']]),
      SeqBeat(kind: GameKind.poll, pool: [['They clap when the plane lands', 'green flag', 'red flag'], ['They still follow all their exes', 'green flag', 'red flag'], ['All their exes are “crazy”', 'green flag', 'red flag']]),
    ]),
    SeqDef(name: 'Storytime', icon: '🎤', hint: 'real stories · best one wins', vibe: 'wild', beats: [
      SeqBeat(kind: GameKind.point, pool: [['Most embarrassing moment. Full story. GO'], ['Your most unhinged 3am decision'], ['Your biggest public L']]),
      SeqBeat(kind: GameKind.point, pool: [['Worst date you’ve ever been on'], ['A time you got caught lying'], ['The dumbest thing you believed as a kid']]),
    ]),
    SeqDef(name: 'Rizz Off', icon: '😏', hint: 'best line · worst line · shoot your shot', vibe: 'spark', beats: [
      SeqBeat(kind: GameKind.point, secs: 15, pool: [['Best pickup line. GO']]),
      SeqBeat(kind: GameKind.point, secs: 15, pool: [['Now the WORST pickup line on purpose']]),
      SeqBeat(kind: GameKind.point, secs: 15, pool: [['Shoot your shot at the camera — smoothest wins']]),
    ]),
    SeqDef(name: 'Spin the Bottle', icon: '🍾', hint: 'the bottle picks · no escape', vibe: 'spark', beats: [
      SeqBeat(kind: GameKind.spin, pool: [['{target} — what’s your actual type? Be honest'], ['{target} — rate your own rizz out of 10'], ['{target} — who in this room would you take on a date? 👀']]),
      SeqBeat(kind: GameKind.spin, pool: [['{target} — blow the room a kiss. Commit.'], ['{target} — describe your dream date in 10 seconds'], ['{target} — your most romantic move ever. Spill.']]),
    ]),
    SeqDef(name: 'Confessions', icon: '🙊', hint: 'never have I ever · thumbs up = guilty', vibe: 'wild', beats: [
      SeqBeat(kind: GameKind.thumbs, pool: [['Never have I ever ghosted someone mid-conversation'], ['…sent a text to the completely wrong person'], ['…stalked an ex online this week']]),
      SeqBeat(kind: GameKind.thumbs, pool: [['…pretended not to see someone I know in public'], ['…flirted my way out of trouble'], ['…lied to get out of a date']]),
      SeqBeat(kind: GameKind.thumbs, pool: [['…checked a partner’s phone'], ['…cried to get out of trouble'], ['…had a crush on a friend’s partner']]),
    ]),
    SeqDef(name: 'Would You Rather', icon: '🤔', hint: 'three impossible choices', vibe: 'warm', beats: [
      SeqBeat(kind: GameKind.wouldRather, pool: [['Fight 100 duck-sized horses, or…', '100 tiny horses', '1 giant duck'], ['Read minds, or…', 'read minds', 'be invisible']]),
      SeqBeat(kind: GameKind.wouldRather, pool: [['Know how you die, or…', 'know when', 'know how'], ['Be famous, or…', 'famous', 'filthy rich']]),
      SeqBeat(kind: GameKind.wouldRather, pool: [['Always say what you think, or…', 'brutal honesty', 'never speak again'], ['Teleport, or…', 'teleport', 'fly']]),
    ]),
    SeqDef(name: 'Impressions', icon: '🎭', hint: 'do it badly · funniest wins', vibe: 'wild', beats: [
      SeqBeat(kind: GameKind.point, pool: [['Your worst BATMAN'], ['Your worst British accent'], ['Your worst influencer apology']]),
      SeqBeat(kind: GameKind.point, pool: [['Talk like a movie VILLAIN 😈 — best one wins'], ['Talk like your GRANDMA 👵'], ['Talk like a CEO on a podcast 💼']]),
      SeqBeat(kind: GameKind.point, secs: 15, pool: [['Do your best EVIL LAUGH — crown the winner']]),
    ]),
    SeqDef(name: 'Roast Circle', icon: '💀', hint: 'roast · get roasted · make up', vibe: 'wild', beats: [
      SeqBeat(kind: GameKind.point, pool: [['Roast the person on your left (with love)'], ['Roast this app. Go.']]),
      SeqBeat(kind: GameKind.point, pool: [['Roast your OWN haircut before someone else does'], ['Confess your pettiest move ever — pettiest wins']]),
      SeqBeat(kind: GameKind.point, secs: 15, pool: [['Now the best COMPLIMENT — make someone blush to make up']]),
    ]),
  ];

  static SeqDef? byName(String name) {
    for (final s in ten) {
      if (s.name == name) return s;
    }
    return null;
  }
}

