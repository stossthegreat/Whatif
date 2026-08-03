// The rotating game pack — server-authoritative so every client in a cell gets
// the same game + prompt. Mirrors the Flutter client's kinds. Prompts are deep
// and the matchmaker avoids repeating the last kind, so cells never feel samey.

export type GameKind =
  | 'point' | 'poll' | 'wouldRather' | 'thumbs' | 'same' | 'freeze' | 'twoTruths' | 'rapidFire' | 'spin';

export interface GameDef {
  kind: GameKind;
  name: string;
  hint: string;
  minStrangers: number;
  maxStrangers: number;
  prompts: string[][]; // [headline, ...options]
  // session-arc tier: 'warm' (round 1), 'wild' (default), 'spark' (flirty finale)
  vibe?: 'warm' | 'wild' | 'spark';
}

export const PACK: GameDef[] = [
  { kind: 'point', name: 'Point Party', hint: 'tap who fits — everyone points at once',
    minStrangers: 2, maxStrangers: 8, prompts: [
      ['Who woke up 5 minutes ago?'], ['Most likely to start a cult (a fun one)'],
      ['Who texts their ex at 2am?'], ['Most likely to be a secret genius'],
      ['Who is definitely lying right now?'], ['Most likely to cry at a dog video'],
      ['Who would survive a horror movie?'], ['Most likely to fight a goose and lose'],
      ['Who has the worst screen time?'], ['Most likely to become famous'],
      ['Who is the main character here?'], ['Most likely to ghost the group'],
    ] },
  { kind: 'poll', name: 'Hot Take', vibe: 'warm', hint: 'pick a side',
    minStrangers: 1, maxStrangers: 8, prompts: [
      ['Pineapple on pizza?', 'crime', 'genius'], ['Socks in bed?', 'yes', 'never'],
      ['Text or call?', 'text', 'call'], ['Cereal then milk?', 'right', 'chaos'],
      ['Front camera or back?', 'front', 'back'], ['TP over or under?', 'over', 'under'],
      ['Beach or mountains?', 'beach', 'mountains'], ['Morning person?', 'yes', 'absolutely not'],
      ['Cats or dogs?', 'cats', 'dogs'], ['Is a hotdog a sandwich?', 'yes', 'how dare you'],
    ] },
  { kind: 'thumbs', name: 'Confession Cam', hint: 'thumbs up = guilty · on 3',
    minStrangers: 1, maxStrangers: 8, prompts: [
      ['Never have I ever been kicked out of a bar'], ['…ghosted someone mid-conversation'],
      ['…sent a text to the completely wrong person'], ['…faked being busy to skip plans'],
      ['…stalked an ex online this week'], ['…cried in a public bathroom'],
      ['…pretended to know a song I didn’t'], ['…re-gifted a present'],
      ['…googled myself'], ['…lied to get out of a date'],
    ] },
  { kind: 'same', name: 'Same Brain', vibe: 'warm', hint: 'match the room — pick fast',
    minStrangers: 1, maxStrangers: 8, prompts: [
      ['Name a fruit', 'banana', 'apple', 'mango', 'grape'],
      ['A colour, go', 'blue', 'red', 'green', 'black'],
      ['Pick a vibe', 'chaotic', 'chill', 'menace', 'soft'],
      ['A random animal', 'cat', 'dog', 'fox', 'shark'],
      ['Say a country', 'japan', 'italy', 'brazil', 'egypt'],
      ['A drink', 'coffee', 'tea', 'water', 'chaos'],
    ] },
  { kind: 'freeze', name: 'Freeze Face', hint: 'hold it — last to laugh wins',
    minStrangers: 1, maxStrangers: 8, prompts: [
      ['Hold your most SHOCKED face'], ['Hold a straight face. No matter what.'],
      ['Give your worst fake cry — and hold'], ['Your best villain smile — freeze'],
      ['Most confused face — hold it'], ['Puppy eyes. Do not break.'],
    ] },
  { kind: 'wouldRather', name: 'Would You Rather', vibe: 'warm', hint: 'lock your choice, then compare',
    minStrangers: 1, maxStrangers: 6, prompts: [
      ['Fight 100 duck-sized horses, or…', '100 tiny horses', '1 giant duck'],
      ['Always be 10 min late, or…', 'always late', 'always 20 early'],
      ['Read minds, or…', 'read minds', 'be invisible'],
      ['Be famous, or…', 'famous', 'filthy rich'],
      ['Teleport, or…', 'teleport', 'fly'],
    ] },
  { kind: 'twoTruths', name: 'Two Truths', vibe: 'spark', hint: 'read their face — spot the lie',
    minStrangers: 1, maxStrangers: 2, prompts: [
      ['Which one is the lie?', 'skydived once', 'has four siblings', 'hates coffee'],
      ['Spot the lie', 'met a celebrity', 'speaks 3 languages', 'broke a bone at 7'],
      ['Which is fake?', 'ran a marathon', 'was on TV once', 'can’t swim'],
    ] },
  { kind: 'rapidFire', name: 'Rapid Fire', hint: '10 seconds. don’t overthink.',
    minStrangers: 1, maxStrangers: 1, prompts: [
      ['Say the first word you think of: SUNDAY'], ['Describe your week in one word — go'],
      ['Best food, worst food. Fast.'], ['Your hype song, right now'],
    ] },

  // ---- the wild ones (perform, then the room crowns someone) ----------------
  { kind: 'point', name: 'Red Flag', hint: 'point at your suspect',
    minStrangers: 2, maxStrangers: 8, prompts: [
      ['Most likely to forget your birthday'], ['Most likely to text back in 3 days'],
      ['Most likely to get arrested for something dumb'], ['Biggest red-flag energy'],
      ['Most likely to start drama'], ['Most likely to ghost after one date'],
    ] },
  { kind: 'point', name: 'Voice Swap', hint: 'do the voice — then point at who nailed it',
    minStrangers: 1, maxStrangers: 8, prompts: [
      ['Everyone talk like a PIRATE 🏴‍☠️'], ['Talk like a ROBOT 🤖'],
      ['Talk like your GRANDMA 👵'], ['Talk like a movie VILLAIN 😈'], ['Talk like a BABY 👶'],
    ] },
  { kind: 'point', name: 'Sell It', hint: '30 seconds — then crown the best pitch',
    minStrangers: 1, maxStrangers: 8, prompts: [
      ['Sell a single sock to the room'], ['Sell a banana like it’s a supercar'],
      ['Convince the room to give you £100'], ['Sell a rock as a life-changing product'],
    ] },
  { kind: 'point', name: 'Survival', hint: 'argue your case — then vote the survivor',
    minStrangers: 2, maxStrangers: 8, prompts: [
      ['Zombie apocalypse — who survives? Make your case'], ['Plane crash on an island — who’s useful?'],
      ['Prison break — who’s the brains?'], ['Last one in the bunker — why you?'],
    ] },
  { kind: 'point', name: 'Sound Effect', hint: 'recreate it — funniest wins',
    minStrangers: 2, maxStrangers: 8, prompts: [
      ['Everyone make a COW 🐄 — point at the best'], ['Make a police SIREN 🚨'],
      ['Do your best EVIL LAUGH 😈'], ['Make a phone RINGTONE 📱'],
    ] },
  { kind: 'point', name: 'First Impression', vibe: 'spark', hint: 'first 5 seconds — vote your fave',
    minStrangers: 2, maxStrangers: 8, prompts: [
      ['Who’s the main character of this room?'], ['Who would you grab a drink with?'],
      ['Who’s got the best energy?'], ['Who’s the most chaotic?'],
    ] },
  { kind: 'freeze', name: 'Laugh Lock', hint: 'do NOT laugh first',
    minStrangers: 1, maxStrangers: 8, prompts: [
      ['Laugh Lock — first to laugh loses'], ['Straightest face wins. Go.'],
      ['Try not to smile. Impossible.'],
    ] },
  { kind: 'point', name: 'Caption This', hint: 'best caption wins — say it out loud',
    minStrangers: 1, maxStrangers: 8, prompts: [
      ['Caption this: 🐸🚗💨'], ['Caption this: 👵🛹🔥'], ['Caption this: 🦆👮‍♂️🚨'],
      ['Caption this: 🧍‍♂️🕳️👀'], ['Caption this: 🐱💼📉'], ['Caption this: 🤡🎂😭'],
    ] },
  { kind: 'point', name: 'Roast Me', hint: 'gentle roasts only — crown the best',
    minStrangers: 2, maxStrangers: 8, prompts: [
      ['Roast the person on your left (with love)'], ['Roast this app. Go.'],
      ['Roast your own haircut before someone else does'], ['Roast Mondays like they owe you money'],
    ] },
  { kind: 'same', name: 'Emoji Only', vibe: 'warm', hint: 'answer in one emoji — match the room',
    minStrangers: 1, maxStrangers: 8, prompts: [
      ['Your week, in one emoji', '😂', '💀', '😭', '🔥'],
      ['Your love life, one emoji', '📉', '🔥', '👻', '🤡'],
      ['This room, one emoji', '🎪', '✨', '💀', '🧠'],
      ['Your bank account rn', '😭', '💀', '📉', '🤑'],
    ] },
  { kind: 'thumbs', name: 'Truth Meter', hint: '👍 = cap. call it out',
    minStrangers: 1, maxStrangers: 8, prompts: [
      ['“I could survive a week without my phone”'], ['“I’ve never stalked an ex online”'],
      ['“I always tip 20%”'], ['“I read the terms & conditions”'], ['“I’m a good texter”'],
    ] },
  { kind: 'point', name: 'Five Second Rule', hint: '5 seconds — then crown who nailed it',
    minStrangers: 1, maxStrangers: 8, prompts: [
      ['Name 5 fruits. FIVE SECONDS.'], ['Name 5 apps on your phone. GO.'],
      ['5 excuses for being late. NOW.'], ['5 things in your fridge. QUICK.'], ['5 red flags. FAST.'],
    ] },
  { kind: 'point', name: 'Act It Out', hint: 'mime it — first right guess crowns you',
    minStrangers: 1, maxStrangers: 8, prompts: [
      ['Mime: making a pizza'], ['Mime: losing your phone'], ['Mime: a cat at 3am'],
      ['Mime: airport security'], ['Mime: your morning routine'], ['Mime: winning the lottery'],
    ] },
  { kind: 'point', name: 'First To Find', hint: 'run — first back with it wins',
    minStrangers: 1, maxStrangers: 8, prompts: [
      ['First to show something RED'], ['First to show a spoon'], ['First to show shoes'],
      ['First to show something older than you'], ['First to show a snack'],
    ] },
  { kind: 'point', name: 'Worst Impression', hint: 'do it badly on purpose — funniest wins',
    minStrangers: 1, maxStrangers: 8, prompts: [
      ['Your worst BATMAN'], ['Your worst British accent'], ['Your worst influencer apology'],
      ['Your worst gym bro'], ['Your worst weather reporter'],
    ] },
  { kind: 'point', name: 'Finish The Lyric', hint: 'no music. full confidence.',
    minStrangers: 1, maxStrangers: 8, prompts: [
      ['Sing any chorus like it’s the final'], ['Finish a lyric everyone knows — wrong words allowed'],
      ['Hum a song — first to guess crowns you'],
    ] },
  { kind: 'point', name: 'One Word Story', hint: 'one word each — funniest ending wins',
    minStrangers: 2, maxStrangers: 8, prompts: [
      ['Start with: “Yesterday…”'], ['Start with: “Officer…”'], ['Start with: “Unfortunately…”'],
      ['Start with: “My therapist…”'],
    ] },
  { kind: 'point', name: 'Finish The Sentence', hint: 'funniest answer takes it',
    minStrangers: 1, maxStrangers: 8, prompts: [
      ['“My last search was…”'], ['“I knew it was over when…”'], ['“My villain origin story is…”'],
      ['“The weirdest thing I own is…”'], ['“My red flag is…”'],
    ] },
  { kind: 'point', name: 'Odd One Out', hint: 'someone got a different prompt. find them',
    minStrangers: 2, maxStrangers: 8, prompts: [
      ['One of you is describing a DIFFERENT thing 👀 — find them'],
      ['One of you got the fake prompt. Sniff them out.'],
      ['Someone here is improvising. Point at who.'],
    ] },
  // ---- the confessional block ----
  { kind: 'point', name: 'Hot Seat', hint: 'answer for real — juiciest wins',
    minStrangers: 1, maxStrangers: 8, prompts: [
      ['Hot seat: your most embarrassing camera-roll photo — describe it'],
      ['Hot seat: the dumbest thing you’ve ever cried about'],
      ['Hot seat: your worst text-to-the-wrong-person story'],
      ['Hot seat: the biggest L you’ve ever taken'],
      ['Hot seat: your most irrational fear'],
      ['Hot seat: the weirdest thing you’ve googled this week'],
    ] },
  { kind: 'point', name: 'Storytime', hint: '20 seconds — best story takes it',
    minStrangers: 1, maxStrangers: 8, prompts: [
      ['Most embarrassing moment. 20 seconds. GO'],
      ['Your worst date ever — make it quick'],
      ['The dumbest thing you believed as a kid'],
      ['Your most unhinged 3am decision'],
      ['A time you got caught lying'],
      ['Your biggest public L'],
    ] },
  { kind: 'point', name: 'Petty Court', hint: 'confess — the pettiest wins',
    minStrangers: 2, maxStrangers: 8, prompts: [
      ['Confess your pettiest move ever — pettiest wins'],
      ['The pettiest reason you’ve ever ghosted someone'],
      ['Your pettiest revenge story. GO'],
      ['The pettiest hill you will die on'],
    ] },
  // ---- the performance block ----
  { kind: 'point', name: 'Speed Debate', hint: '15 seconds. full confidence.',
    minStrangers: 1, maxStrangers: 8, prompts: [
      ['Defend: pineapple pizza is ELITE. 15 seconds'],
      ['Argue: cereal is a soup. Mean it.'],
      ['Defend: socks with sandals are fashion'],
      ['Argue: pigeons are government drones'],
      ['Defend: showering at night is superior'],
      ['Argue: the gym at 6am is a personality disorder'],
    ] },
  { kind: 'point', name: 'Rap Battle', hint: 'one bar. no beat. all heart.',
    minStrangers: 2, maxStrangers: 8, prompts: [
      ['One bar about the person on your right. GO'],
      ['Freestyle about your breakfast'],
      ['Drop a bar about this app'],
      ['Rap your morning routine'],
    ] },
  { kind: 'point', name: 'Scam Call', hint: 'commit to the bit — best scam wins',
    minStrangers: 1, maxStrangers: 8, prompts: [
      ['You’re a scam caller. Convince the room they won a cruise'],
      ['Sell the room a fake crypto coin'],
      ['You’re tech support. The problem is fake. Fix it anyway'],
      ['Cold-call the room about their car’s extended warranty'],
    ] },
  { kind: 'point', name: 'Conspiracy Corner', hint: 'pitch it like you believe it',
    minStrangers: 1, maxStrangers: 8, prompts: [
      ['Pitch a conspiracy about birds. Full confidence'],
      ['Explain why the moon is fake'],
      ['Convince us your neighbour is a time traveller'],
      ['Reveal what’s REALLY in airline food'],
    ] },
  { kind: 'point', name: 'Oscar Bait', hint: 'dramatic acting. tiny problem.',
    minStrangers: 1, maxStrangers: 8, prompts: [
      ['Dramatic scene: your toast burned. ACT.'],
      ['Cry about losing the TV remote — Oscar level'],
      ['Dramatic monologue: the wifi went down'],
      ['Win an award. Thank your haters. Tears.'],
    ] },
  { kind: 'point', name: 'Show & Tell', hint: 'grab it — best object wins',
    minStrangers: 1, maxStrangers: 8, prompts: [
      ['Grab the weirdest thing within reach — best object wins'],
      ['Show the oldest thing in the room'],
      ['Grab something that describes your personality'],
      ['Show your most prized possession under a tenner'],
    ] },
  // ---- the judgement block ----
  { kind: 'point', name: 'Superlatives', hint: 'the room decides who',
    minStrangers: 2, maxStrangers: 8, prompts: [
      ['Most likely to have a secret finsta'],
      ['Most likely to cry over a situationship'],
      ['Most likely to join a pyramid scheme'],
      ['Most likely to get famous for something embarrassing'],
      ['Most likely to argue with a self-checkout machine'],
      ['Most likely to text their ex tonight'],
    ] },
  { kind: 'poll', name: 'Green Flag Red Flag', vibe: 'warm', hint: 'judge them. instantly.',
    minStrangers: 1, maxStrangers: 8, prompts: [
      ['They reply in 0.2 seconds', 'green flag', 'red flag'],
      ['They still follow all their exes', 'green flag', 'red flag'],
      ['They clap when the plane lands', 'green flag', 'red flag'],
      ['All their exes are “crazy”', 'green flag', 'red flag'],
      ['They talk to their pet in a baby voice', 'green flag', 'red flag'],
      ['Their camera roll is 90% selfies', 'green flag', 'red flag'],
    ] },
  { kind: 'thumbs', name: 'Delulu Check', vibe: 'warm', hint: '👍 = you actually believe it',
    minStrangers: 1, maxStrangers: 8, prompts: [
      ['I could land a plane in an emergency'],
      ['I could survive a zombie apocalypse'],
      ['I’d win an argument with my therapist'],
      ['I’m the funniest person I know'],
      ['I could go pro if I trained for a year'],
      ['A celebrity would 100% date me'],
    ] },
  { kind: 'same', name: 'Cursed Combos', vibe: 'warm', hint: 'pick the worst — match the room',
    minStrangers: 1, maxStrangers: 8, prompts: [
      ['Worst pizza topping', 'toothpaste', 'mayo ice cream', 'wet socks', 'gravel'],
      ['Worst superpower', 'always slightly damp', 'teleport 3cm', 'invisible when nobody looks', 'talk to pigeons'],
      ['Worst thing to say at a funeral', 'nice turnout', 'he owed me money', 'who’s hungry?', 'awkwarddd'],
      ['Worst wifi name', 'FBI van 12', 'virus.exe', 'mum click here', 'definitely not spying'],
    ] },
  { kind: 'freeze', name: 'NPC Mode', hint: 'you are not a real person. hold it.',
    minStrangers: 1, maxStrangers: 8, prompts: [
      ['Everyone act like an NPC. First to break loses'],
      ['You’re all mannequins. HOLD IT'],
      ['Buffering robots. Do not un-buffer.'],
    ] },
  // ---- face battles (the camera IS the game) ----
  { kind: 'freeze', name: 'Face Battle', hint: 'pull it. HOLD it. funniest wins.',
    minStrangers: 1, maxStrangers: 8, prompts: [
      ['UGLIEST face contest. 3…2…1 GO'], ['Best fish face 🐟 hold it'],
      ['Cross-eyed + tongue out. HOLD'], ['Double chin championship. Commit.'],
      ['Your best “I just saw my ex” face'], ['Your “wifi dropped mid-message” face'],
      ['Best evil villain smirk. Freeze.'], ['The face you make reading old texts'],
    ] },
  // ---- SPARK — the flirty finale ----
  { kind: 'spin', name: 'Spin the Bottle', vibe: 'spark', hint: 'the bottle picks. no escape.',
    minStrangers: 1, maxStrangers: 8, prompts: [
      ['{target} — what’s your actual type? Be honest'],
      ['{target} — rate your own rizz out of 10'],
      ['{target} — best pickup line. Right now.'],
      ['{target} — who in this room would you take on a date? 👀'],
      ['{target} — blow the room a kiss. Commit.'],
      ['{target} — describe your dream date in 10 seconds'],
      ['{target} — your most romantic move ever. Spill.'],
      ['{target} — flirt with the camera for 5 seconds'],
    ] },
  { kind: 'point', name: 'Rizz Battle', vibe: 'spark', hint: 'smoothest wins. or funniest fail.',
    minStrangers: 1, maxStrangers: 8, prompts: [
      ['Best pickup line wins. GO'], ['Worst pickup line on purpose'],
      ['Rizz up an imaginary barista'], ['Shoot your shot at the camera — smoothest wins'],
      ['Compliment someone so hard they short-circuit'],
    ] },
  { kind: 'freeze', name: 'Kiss Face', vibe: 'spark', hint: 'fully commit. do not laugh.',
    minStrangers: 1, maxStrangers: 8, prompts: [
      ['Practice your kiss face 😗 HOLD IT'], ['Slow-motion air kiss. Fully commit 😂'],
      ['Wink at the camera like a movie star. Freeze.'], ['Your best “hey you” face. Hold it.'],
      ['Blow a kiss in extreme slow motion'],
    ] },
  { kind: 'freeze', name: 'Eye Contact', vibe: 'spark', hint: 'hold it. no laughing.',
    minStrangers: 1, maxStrangers: 8, prompts: [
      ['Dead-eye contact with the camera. 10 seconds. No laughing'],
      ['Stare-off. First to blink loses'], ['Look into the lens like you’re in love. HOLD.'],
      ['Eye contact + slow smile. Do not crack.'],
    ] },
  { kind: 'point', name: 'Compliment Battle', vibe: 'spark', hint: 'make someone blush — words only',
    minStrangers: 2, maxStrangers: 8, prompts: [
      ['Best compliment to the person on your left'], ['Hype up a stranger like they’re your best mate'],
      ['Make someone blush with words only'], ['Give the most oddly specific compliment'],
    ] },
  { kind: 'point', name: 'Date Pitch', vibe: 'spark', hint: '30 seconds. sell it.',
    minStrangers: 1, maxStrangers: 8, prompts: [
      ['30 seconds: why you’d be an elite date'], ['Pitch the WORST date idea ever'],
      ['Sell your love life like a startup'], ['Plan a first date with £5. Convince us.'],
    ] },
];

const pick = <T>(a: T[]): T => a[Math.floor(Math.random() * a.length)];

// Weighted member counts (a cell of N members = each person sees N-1 strangers).
const SIZE_BAG = [2, 2, 2, 3, 3, 4, 6];
export const rollMemberCount = () => pick(SIZE_BAG);

export function rollGame(strangers: number, avoidKind?: GameKind, avoidName?: string, vibe?: string) {
  let fits = PACK.filter((g) => strangers >= g.minStrangers && strangers <= g.maxStrangers);
  if (!fits.length) fits = PACK; // solo / edge — never crash
  // prefer a different kind AND a different name than last time, so no two
  // rooms in a row ever feel like the same game
  const varied = fits.filter((g) => g.kind !== avoidKind && g.name !== avoidName);
  if (varied.length) fits = varied;
  else {
    const byName = fits.filter((g) => g.name !== avoidName);
    if (byName.length) fits = byName;
  }
  // session arc: open warm, end on spark — strangers warm up before kiss faces
  if (vibe) {
    const tiered = fits.filter((g) => (g.vibe ?? 'wild') === vibe);
    if (tiered.length) fits = tiered;
  }
  const game = pick(fits);
  const chosen = pick(game.prompts);
  const [head, ...opts] = chosen;
  // shuffle options
  for (let i = opts.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [opts[i], opts[j]] = [opts[j], opts[i]];
  }
  return { game, prompt: [head, ...opts] };
}

// ---- THE TEN ---------------------------------------------------------------
// Ten blended games. Each one is a SEQUENCE of beats played back-to-back —
// never a single throwaway prompt. A beat is a kind + a prompt pool; the
// engine chains them with a quick flip between each.

export interface SeqBeat {
  kind: GameKind;
  pool: string[][]; // candidate prompts for this beat: [head, ...options]
  secs?: number;    // optional duration override
}

export interface SeqDef {
  name: string;
  icon: string;     // the picker's animated emoji
  hint: string;
  vibe: 'warm' | 'wild' | 'spark';
  /// Works with exactly two people in the room. Point beats resolve through
  /// the client's me/them vote, so freeze/poll/thumbs/point all qualify —
  /// what doesn't is group-shaped copy (roasting "the person on your left",
  /// crowning winners of a circle, spinning a bottle at two faces).
  duo: boolean;
  beats: SeqBeat[];
}

export const SEQ_PACK: SeqDef[] = [
  { name: 'Face Off', icon: '😜', hint: 'pull it · hold it · crown it', vibe: 'warm', duo: true, beats: [
    { kind: 'freeze', secs: 11, pool: [['UGLIEST face contest. 3…2…1 GO'], ['Best fish face 🐟 HOLD IT'], ['Double chin championship. Commit.']] },
    { kind: 'freeze', secs: 11, pool: [['Now your best villain smirk. Freeze.'], ['The face you make reading old texts'], ['Your “I just saw my ex” face']] },
    { kind: 'point', secs: 13, pool: [['Crown the funniest face 👑']] },
  ]},
  { name: 'Eye Contact', icon: '👀', hint: 'hold it · smile · don’t crack', vibe: 'spark', duo: true, beats: [
    { kind: 'freeze', secs: 11, pool: [['Dead-eye contact with the camera. No laughing.']] },
    { kind: 'freeze', secs: 11, pool: [['Now a SLOW smile. Do not crack.'], ['Now wink like a movie star. Hold it.']] },
    { kind: 'point', secs: 13, pool: [['Who broke first?']] },
  ]},
  { name: 'Hot Takes', icon: '🔥', hint: 'three takes · pick sides · argue', vibe: 'warm', duo: true, beats: [
    { kind: 'poll', pool: [['Pineapple on pizza?', 'crime', 'genius'], ['Is a hotdog a sandwich?', 'yes', 'how dare you'], ['Cereal then milk?', 'right', 'chaos']] },
    { kind: 'poll', pool: [['Texting “lol” means nothing?', 'facts', 'lies'], ['Gym at 6am?', 'built different', 'lying'], ['Voice notes?', 'elite', 'jail']] },
    { kind: 'poll', pool: [['They clap when the plane lands', 'green flag', 'red flag'], ['They still follow all their exes', 'green flag', 'red flag'], ['All their exes are “crazy”', 'green flag', 'red flag']] },
  ]},
  { name: 'Storytime', icon: '🎤', hint: 'real stories · best one wins', vibe: 'wild', duo: false, beats: [
    { kind: 'point', pool: [['Most embarrassing moment. Full story. GO'], ['Your most unhinged 3am decision'], ['Your biggest public L']] },
    { kind: 'point', pool: [['Worst date you’ve ever been on'], ['A time you got caught lying'], ['The dumbest thing you believed as a kid']] },
  ]},
  { name: 'Rizz Off', icon: '😏', hint: 'best line · worst line · shoot your shot', vibe: 'spark', duo: false, beats: [
    { kind: 'point', secs: 18, pool: [['Best pickup line. GO']] },
    { kind: 'point', secs: 18, pool: [['Now the WORST pickup line on purpose']] },
    { kind: 'point', secs: 18, pool: [['Shoot your shot at the camera — smoothest wins']] },
  ]},
  { name: 'Spin the Bottle', icon: '🍾', hint: 'the bottle picks · no escape', vibe: 'spark', duo: false, beats: [
    { kind: 'spin', pool: [['{target} — what’s your actual type? Be honest'], ['{target} — rate your own rizz out of 10'], ['{target} — who in this room would you take on a date? 👀']] },
    { kind: 'spin', pool: [['{target} — blow the room a kiss. Commit.'], ['{target} — describe your dream date in 10 seconds'], ['{target} — your most romantic move ever. Spill.']] },
  ]},
  { name: 'Confessions', icon: '🙊', hint: 'never have I ever · thumbs up = guilty', vibe: 'wild', duo: true, beats: [
    { kind: 'thumbs', pool: [['Never have I ever ghosted someone mid-conversation'], ['…sent a text to the completely wrong person'], ['…stalked an ex online this week']] },
    { kind: 'thumbs', pool: [['…pretended not to see someone I know in public'], ['…flirted my way out of trouble'], ['…lied to get out of a date']] },
    { kind: 'thumbs', pool: [['…checked a partner’s phone'], ['…cried to get out of trouble'], ['…had a crush on a friend’s partner']] },
  ]},
  { name: 'Would You Rather', icon: '🤔', hint: 'three impossible choices', vibe: 'warm', duo: true, beats: [
    { kind: 'wouldRather', pool: [['Fight 100 duck-sized horses, or…', '100 tiny horses', '1 giant duck'], ['Read minds, or…', 'read minds', 'be invisible']] },
    { kind: 'wouldRather', pool: [['Know how you die, or…', 'know when', 'know how'], ['Be famous, or…', 'famous', 'filthy rich']] },
    { kind: 'wouldRather', pool: [['Always say what you think, or…', 'brutal honesty', 'never speak again'], ['Teleport, or…', 'teleport', 'fly']] },
  ]},
  { name: 'Impressions', icon: '🎭', hint: 'do it badly · funniest wins', vibe: 'wild', duo: false, beats: [
    { kind: 'point', pool: [['Your worst BATMAN'], ['Your worst British accent'], ['Your worst influencer apology']] },
    { kind: 'point', pool: [['Talk like a movie VILLAIN 😈 — best one wins'], ['Talk like your GRANDMA 👵'], ['Talk like a CEO on a podcast 💼']] },
    { kind: 'point', secs: 18, pool: [['Do your best EVIL LAUGH — crown the winner']] },
  ]},
  { name: 'Roast Circle', icon: '💀', hint: 'roast · get roasted · make up', vibe: 'wild', duo: false, beats: [
    { kind: 'point', pool: [['Roast the person on your left (with love)'], ['Roast this app. Go.']] },
    { kind: 'point', pool: [['Roast your OWN haircut before someone else does'], ['Confess your pettiest move ever — pettiest wins']] },
    { kind: 'point', secs: 18, pool: [['Now the best COMPLIMENT — make someone blush to make up']] },
  ]},
];

export const seqByName = (name: string) => SEQ_PACK.find((s) => s.name === name);
