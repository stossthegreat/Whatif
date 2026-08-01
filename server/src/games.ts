// The rotating game pack — server-authoritative so every client in a cell gets
// the same game + prompt. Mirrors the Flutter client's kinds. Prompts are deep
// and the matchmaker avoids repeating the last kind, so cells never feel samey.

export type GameKind =
  | 'point' | 'poll' | 'wouldRather' | 'thumbs' | 'same' | 'freeze' | 'twoTruths' | 'rapidFire';

export interface GameDef {
  kind: GameKind;
  name: string;
  hint: string;
  minStrangers: number;
  maxStrangers: number;
  prompts: string[][]; // [headline, ...options]
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
  { kind: 'poll', name: 'Hot Take', hint: 'pick a side',
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
  { kind: 'same', name: 'Same Brain', hint: 'match the room — pick fast',
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
  { kind: 'wouldRather', name: 'Would You Rather', hint: 'lock your choice, then compare',
    minStrangers: 1, maxStrangers: 6, prompts: [
      ['Fight 100 duck-sized horses, or…', '100 tiny horses', '1 giant duck'],
      ['Always be 10 min late, or…', 'always late', 'always 20 early'],
      ['Read minds, or…', 'read minds', 'be invisible'],
      ['Be famous, or…', 'famous', 'filthy rich'],
      ['Teleport, or…', 'teleport', 'fly'],
    ] },
  { kind: 'twoTruths', name: 'Two Truths', hint: 'read their face — spot the lie',
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
  { kind: 'point', name: 'First Impression', hint: 'first 5 seconds — vote your fave',
    minStrangers: 2, maxStrangers: 8, prompts: [
      ['Who’s the main character of this room?'], ['Who would you grab a drink with?'],
      ['Who’s got the best energy?'], ['Who’s the most chaotic?'],
    ] },
  { kind: 'freeze', name: 'Laugh Lock', hint: 'do NOT laugh first',
    minStrangers: 1, maxStrangers: 8, prompts: [
      ['Laugh Lock — first to laugh loses'], ['Straightest face wins. Go.'],
      ['Try not to smile. Impossible.'],
    ] },
];

const pick = <T>(a: T[]): T => a[Math.floor(Math.random() * a.length)];

// Weighted member counts (a cell of N members = each person sees N-1 strangers).
const SIZE_BAG = [2, 2, 2, 3, 3, 4, 6];
export const rollMemberCount = () => pick(SIZE_BAG);

export function rollGame(strangers: number, avoidKind?: GameKind, avoidName?: string) {
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
