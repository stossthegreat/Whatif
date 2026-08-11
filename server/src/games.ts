// The rotating game pack — server-authoritative so every client in a cell gets
// the same game + prompt. Mirrors the Flutter client's kinds. Prompts are deep
// and the matchmaker avoids repeating the last kind, so cells never feel samey.
//
// CONTENT is harvested from the canonical versions of each format — the
// published Never Have I Ever / Would You Rather / Paranoia / Truth-or-Dare /
// 21 Questions banks (Parade, Bored Panda, Classpop et al all replicate the
// same canon) — then rewritten to be self-contained on a video call. The skew
// is deliberate: duo is the core loop and duo is him-and-her energy, so every
// game's pools run warm → flirty → spicy. Cheeky, never explicit.

export type GameKind =
  | 'point' | 'poll' | 'wouldRather' | 'thumbs' | 'same' | 'freeze' | 'twoTruths' | 'rapidFire' | 'spin'
  // wavelength: one member (targetId) sees a hidden spot on a spectrum
  // (lieIdx), gives one spoken clue, the other picks the zone they think it's
  // in — reuses the same option-tally + lieIdx wire shape as twoTruths, so
  // endRound needs zero new branches.
  | 'wavelength';

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

// ---- played-version memory ---------------------------------------------------
// "It should know they've played this — give another one." Per-uid, per-pool
// memory of which prompt indices a player has already seen. A cell always gets
// the prompt fewest of its members have played; only when EVERY member has
// seen EVERY version does the pool reset for them. In-memory (survives
// reconnects for the life of the process), capped so it can't grow unbounded.
const seenByUid = new Map<string, Map<string, Set<number>>>();
const SEEN_USER_CAP = 20_000;

export function pickFreshIdx(uids: string[], poolKey: string, poolLen: number): number {
  if (poolLen <= 1) return 0;
  if (!uids.length) return Math.floor(Math.random() * poolLen);
  if (seenByUid.size > SEEN_USER_CAP) seenByUid.clear(); // blunt but bounded
  const sets = uids.map((u) => {
    let m = seenByUid.get(u);
    if (!m) { m = new Map(); seenByUid.set(u, m); }
    let s = m.get(poolKey);
    if (!s) { s = new Set(); m.set(poolKey, s); }
    return s;
  });
  // score each version by how many members have already played it; pick a
  // random one among the least-played so fresh content always surfaces first
  let best: number[] = [];
  let bestScore = Infinity;
  for (let i = 0; i < poolLen; i++) {
    const sc = sets.reduce((a, s) => a + (s.has(i) ? 1 : 0), 0);
    if (sc < bestScore) { bestScore = sc; best = [i]; }
    else if (sc === bestScore) best.push(i);
  }
  const idx = best[Math.floor(Math.random() * best.length)];
  // pool exhausted for everyone present → wipe and start the cycle again
  if (bestScore >= uids.length) for (const s of sets) s.clear();
  for (const s of sets) s.add(idx);
  return idx;
}

export const PACK: GameDef[] = [
  // Most Likely To — the canonical juicy lists, roast-y / flirty / wholesome
  // interleaved so the room never stays on one note.
  { kind: 'point', name: 'Most Likely To', hint: 'tap who fits — everyone points at once',
    minStrangers: 2, maxStrangers: 8, prompts: [
      ['Who woke up 5 minutes ago?'], ['Most likely to start a cult (a fun one)'],
      ['Who texts their ex at 2am?'], ['Most likely to be a secret genius'],
      ['Who is definitely lying right now?'], ['Most likely to cry at a dog video'],
      ['Who would survive a horror movie?'], ['Most likely to fight a goose and lose'],
      ['Who has the worst screen time?'], ['Most likely to become famous'],
      ['Who is the main character here?'], ['Most likely to ghost the group'],
      ['Most likely to trip over a perfectly flat surface'], ['Most likely to eat the last slice without asking'],
      ['Most likely to get lost with GPS on'], ['Most likely to cry during a Pixar movie'],
      ['Most likely to fall asleep in an action movie'], ['Most likely to forget their own birthday'],
      ['Most likely to win the lottery and lose the ticket'], ['Most likely to become everyone’s best friend'],
      ['Most likely to plan the best surprise trip'], ['Most likely to make you laugh in a dead-serious moment'],
      ['Most likely to fall in love on this app'], ['Most likely to have a secret admirer right now'],
      ['Most likely to flirt with the waiter for free dessert'], ['Most likely to catch feelings in a week'],
      ['Most likely to kiss a stranger tonight'], ['Most likely to have the wildest DMs'],
      ['Most likely to write poetry about a crush'], ['Most likely to blush the easiest'],
      ['Most likely to get famous on TikTok by accident'], ['Most likely to argue with a self-checkout machine'],
      ['Most likely to wake up in another country'], ['Most likely to spend rent money on concert tickets'],
      ['Most likely to get a tattoo they regret by morning'], ['Most likely to crash a wedding'],
      ['Most likely to quit their job in a dramatic exit'], ['Most likely to adopt five cats this year'],
      ['Most likely to reply “lol” to genuinely bad news'], ['Most likely to sleep through ten alarms'],
    ] },
  { kind: 'poll', name: 'Hot Take', vibe: 'warm', hint: 'pick a side',
    minStrangers: 1, maxStrangers: 8, prompts: [
      ['Pineapple on pizza?', 'crime', 'genius'], ['Socks in bed?', 'yes', 'never'],
      ['Text or call?', 'text', 'call'], ['Cereal then milk?', 'right', 'chaos'],
      ['Front camera or back?', 'front', 'back'], ['TP over or under?', 'over', 'under'],
      ['Beach or mountains?', 'beach', 'mountains'], ['Morning person?', 'yes', 'absolutely not'],
      ['Cats or dogs?', 'cats', 'dogs'], ['Is a hotdog a sandwich?', 'yes', 'how dare you'],
      ['Cold pizza for breakfast?', 'elite', 'have some self-respect'],
      ['Kissing on the first date?', 'if the vibe is right', 'slow down, romeo'],
      ['Getting back with an ex?', 'people change', 'the audacity of hope'],
      ['“Hey” as an opening text?', 'simple, effective', 'zero effort, zero reply'],
      ['Shoes on in the house?', 'freedom', 'absolutely feral'],
      ['Clapping when the plane lands?', 'let joy exist', 'sit down. never.'],
      ['Sliding into DMs?', 'shoot your shot', 'desperate hours'],
      ['Double-dipping the chip?', 'my dip, my rules', 'crimes against the bowl'],
    ] },
  // Never Have I Ever — the canonical clean → funny → spicy tiers. Session
  // position gates which tier surfaces first (rollSession's warm/wild/spark
  // arc naturally does this): round 1 never opens on the spicy end.
  // FULL sentences only — "…used a dating app" renders as a broken fragment
  // when it headlines a round on its own (seen live, build 71).
  { kind: 'thumbs', name: 'Confession Cam', hint: 'thumbs up = guilty · on 3',
    minStrangers: 1, maxStrangers: 8, prompts: [
      // clean
      ['Never have I ever fallen backward off a chair'], ['Never have I ever called a teacher "mom"'],
      ['Never have I ever gone to bed without brushing my teeth'], ['Never have I ever met a celebrity'],
      ['Never have I ever been fired from a job'], ['Never have I ever faked being sick to skip work'],
      ['Never have I ever lied on my resume'], ['Never have I ever cooked something genuinely dangerous'],
      // funny / relatable
      ['Never have I ever ghosted someone mid-conversation'], ['Never have I ever texted the WRONG person something unforgivable'],
      ['Never have I ever broken up with someone over text'], ['Never have I ever texted "love you" to the wrong person'],
      ['Never have I ever waved back at someone who wasn’t waving at me'], ['Never have I ever pushed a door that clearly said pull'],
      ['Never have I ever stalked an ex online this week'], ['Never have I ever cried in a public bathroom'],
      ['Never have I ever pretended to know a song I didn’t'], ['Never have I ever re-gifted a present'],
      ['Never have I ever googled myself'], ['Never have I ever gotten a tattoo'], ['Never have I ever fought with someone in public'],
      ['Never have I ever said “you too” when the waiter said “enjoy your meal”'],
      ['Never have I ever screenshotted a chat to send to another chat'],
      ['Never have I ever practised an argument in the shower'],
      ['Never have I ever eaten a whole pizza alone in one sitting'],
      ['Never have I ever muted the group chat and lied about it'],
      // spicy
      ['Never have I ever kissed someone whose name I never knew'], ['Never have I ever had a one-night stand'],
      ['Never have I ever used a dating app'], ['Never have I ever ghosted someone I was dating'],
      ['Never have I ever lied to get out of a date'], ['Never have I ever gone through a partner’s phone'],
      ['Never have I ever skinny-dipped'], ['Never have I ever kissed two people in the same night'],
      ['Never have I ever kissed someone to make an ex jealous'], ['Never have I ever given out a fake number'],
      ['Never have I ever pretended to be single when I wasn’t'],
    ] },
  { kind: 'same', name: 'Same Brain', vibe: 'warm', hint: 'match the room — pick fast',
    minStrangers: 1, maxStrangers: 8, prompts: [
      ['Name a fruit', 'banana', 'apple', 'mango', 'grape'],
      ['A colour, go', 'blue', 'red', 'green', 'black'],
      ['Pick a vibe', 'chaotic', 'chill', 'menace', 'soft'],
      ['A random animal', 'cat', 'dog', 'fox', 'shark'],
      ['Say a country', 'japan', 'italy', 'brazil', 'egypt'],
      ['A drink', 'coffee', 'tea', 'water', 'chaos'],
      ['A first-date spot', 'coffee shop', 'cinema', 'beach walk', 'rooftop bar'],
      ['A love language', 'words', 'touch', 'gifts', 'time'],
    ] },
  // Gurning is real: the World Gurning Championship at Egremont Crab Fair,
  // Cumbria — pulling the ugliest face possible through a horse collar,
  // held since medieval times, Guinness-recognized as the longest-running
  // gurning championship on record. Simplified to "pull it on 3."
  { kind: 'freeze', name: 'Freeze Face', hint: 'hold it — last to laugh wins',
    minStrangers: 1, maxStrangers: 8, prompts: [
      ['Hold your most SHOCKED face'], ['Hold a straight face. No matter what.'],
      ['Give your worst fake cry — and hold'], ['Your best villain smile — freeze'],
      ['Most confused face — hold it'], ['Puppy eyes. Do not break.'],
      ['Gurning: pull the UGLIEST face you can. 3…2…1 GO'],
      ['Gurning round two: worse than that. Go again.'],
      ['Your best fish face 🐟 — hold it'], ['Double chin championship. Commit.'],
      ['Your “they texted first” face 😏 — hold it'],
      ['Your face when your card declines in front of everyone'],
    ] },
  // Match or Split — real WYR questions, chosen for an actual tradeoff on
  // both sides (the craft rule from the research: "pizza vs tacos" has no
  // cost either way, which is why it never sparks debate). Tiered
  // silly → thought-provoking → spicy, same warm→spark arc as everything else.
  { kind: 'wouldRather', name: 'Match or Split', vibe: 'warm', hint: 'lock your choice, then compare',
    minStrangers: 1, maxStrangers: 2, prompts: [
      // silly
      ['Always hiccup when you talk, or…', 'hiccup talking', 'sneeze laughing'],
      ['Only ever whisper, or…', 'only whisper', 'only shout'],
      ['Fight 100 duck-sized horses, or…', '100 tiny horses', '1 giant duck'],
      ['Skip everywhere instead of walking, or…', 'always skip', 'always sing instead of talk'],
      ['Sweat glitter, or…', 'sweat glitter ✨', 'cry chocolate milk'],
      ['Have a theme song play when you enter, or…', 'entrance theme song', 'applause every time you sit'],
      ['Have hands for feet, or…', 'hands for feet', 'feet for hands'],
      // thought-provoking
      ['Say every thought out loud, or…', 'say everything', 'never speak again'],
      ['Be a legendary storyteller from embarrassing moments, or…', 'great stories', 'never embarrass yourself'],
      ['Be the star player on a losing team, or…', 'star, losing team', 'bench, championship team'],
      ['Know all the mysteries of the universe but lose your memories, or…', 'cosmic secrets', 'keep your memories'],
      ['Know everyone’s honest opinion of you, or…', 'hear it all', 'blissful ignorance'],
      ['Have unlimited money but no friends, or…', 'rich and alone', 'broke with your people'],
      // spicy
      ['Be talked dirty to in person, or…', 'in person', 'over text'],
      ['Wake up next to a stranger, or…', 'a stranger', 'a room of everyone you’ve dated'],
      ['Watch your partner flirt with someone you don’t know, or…', 'flirt, stranger', 'flirt, someone you know'],
      ['Kiss badly forever, or…', 'terrible kisser, great texter', 'elite kisser, dry texter'],
      ['Have your search history leaked to your crush, or…', 'search history leaked', 'camera roll leaked'],
      ['Marry wild love that fades, or…', 'wild love, short', 'calm love, forever'],
    ] },
  // Spot The Lie — SPOKEN, never typed: say your 2 truths + 1 lie out loud,
  // in order. The options are positions, not text, because the content is
  // your own voice, not a server-authored fact. The craft trick (coached to
  // the speaker before they talk): make your truths sound unbelievable and
  // your lie sound boring — that's what actually lands the reaction.
  { kind: 'twoTruths', name: 'Spot The Lie', vibe: 'spark', hint: 'say 2 truths + 1 lie, out loud — they guess which',
    minStrangers: 1, maxStrangers: 2, prompts: [
      ['Which one was the lie?', 'The first thing they said', 'The second thing they said', 'The third thing they said'],
    ] },
  // Word Collide — the real improv game "Mind Meld." Entirely spoken, so it
  // reuses `thumbs` as-is: 👍 = we melded, 👎 = go again. No typing, no new
  // wire shape needed — self-reported, exactly like the real game is.
  { kind: 'thumbs', name: 'Word Collide', vibe: 'warm', hint: '3-2-1, say a word together — did you meld?',
    minStrangers: 1, maxStrangers: 2, prompts: [
      ['3…2…1 — say a word. Same beat. GO'],
      ['Didn’t meld? Say a word that bridges your last two. Go again.'],
      ['Keep going until you say the SAME word at the same time — that’s the meld.'],
    ] },
  // Judge Says — Cards Against Humanity's real DNA ($500M-scale, Amazon's
  // #1 card game): a fill-in-the-blank prompt, everyone taps one of the
  // pre-written options (never typed — that's the "hand of cards"), one
  // rotating judge crowns the funniest. Voting rides `same` unmodified;
  // index.ts's startJudgeSays/the endRound hook own the judge half.
  { kind: 'same', name: 'Judge Says', vibe: 'wild', hint: 'everyone answers — one judge crowns the funniest',
    minStrangers: 2, maxStrangers: 8, prompts: [
      ['What’s that smell?', 'my ex’s new relationship', 'the sound of my dreams dying', 'unpaid rent', 'existential dread', 'gas station sushi'],
      ['What’s my secret power?', 'crying in public bathrooms', 'reheating fish in the office microwave', 'never replying to texts', 'winning arguments with strangers online', 'summoning Wi-Fi with pure willpower'],
      ['What ended my last relationship?', 'my group chat', 'a poorly timed pineapple pizza order', 'my mother', 'reply-all to the wrong email', 'my true crime podcast obsession'],
      ['Instead of coal, Santa now gives bad children ___', 'a group project', 'dial-up internet', 'a participation trophy', 'my browser history', 'expired milk'],
      ['Coming to Broadway this season: ___ The Musical', 'Reply-All', 'My Landlord', 'Buffering', 'The Group Chat', 'Monday Morning'],
      ['This is the way the world ends — not with a bang but with ___', 'a dead phone battery', 'a Wi-Fi outage', 'someone muted on a work call', 'an autocorrect fail', 'a group project'],
      ['My dating profile says I love travel, but really I love ___', 'napping competitively', 'judging strangers', 'snacks I hide from guests', 'cancelling plans', 'my phone at 2am'],
      ['The real reason I’m still single: ___', 'my standards and my couch', 'I flirt like a fax machine', 'my playlist is a red flag', 'I said “u” instead of “you”', 'my horoscope told me to wait'],
    ] },
  // Whisper Challenge — the format that went viral via Jimmy Fallon and
  // YouTube/TikTok. Reuses `thumbs` (same trick as Word Collide): the
  // round's target is the mouther and sees the phrase, everyone else can't
  // hear anything by design. The mouther taps guilty/not to judge the
  // guess — index.ts's endRound needs zero new branches for this either.
  { kind: 'thumbs', name: 'Whisper Challenge', vibe: 'wild', hint: 'loud music, silent lips, wildly wrong guesses',
    minStrangers: 1, maxStrangers: 2, prompts: [
      ['purple dinosaur'], ['I forgot my password'], ['spicy chicken sandwich'],
      ['your camera’s frozen'], ['I have three cats'], ['pineapple on pizza'],
      ['my wifi is dying'], ['send help immediately'], ['I love Mondays'],
      ['where are my keys'], ['that’s a weird flex'], ['call me later'],
      ['you look nice today'], ['meet me at midnight'], ['this is my villain era'],
    ] },
  // Wavelength — "the best party game since Codenames." One member
  // (targetId) sees the hidden zone (lieIdx) and gives ONE spoken clue word;
  // the other guesses which zone it's in. Options stay in spectrum order —
  // rollGame/startPickedGame both skip the shuffle for this kind, on purpose.
  { kind: 'wavelength', name: 'Wavelength', vibe: 'wild', hint: 'one clue, one guess — how close did you get?',
    minStrangers: 1, maxStrangers: 2, prompts: [
      ['Overrated ↔ Underrated', 'Way overrated', 'Slightly overrated', 'Right down the middle', 'Slightly underrated', 'Way underrated'],
      ['Boring ↔ Thrilling', 'Deeply boring', 'A bit dull', 'Right down the middle', 'Pretty thrilling', 'Wildly thrilling'],
      ['Wholesome ↔ Unhinged', 'Fully wholesome', 'Mostly wholesome', 'Right down the middle', 'A little unhinged', 'Fully unhinged'],
      ['Safe ↔ Risky', 'Very safe', 'Somewhat safe', 'Right down the middle', 'Somewhat risky', 'Very risky'],
      ['Plan-ahead ↔ Wing-it', 'Full itinerary', 'Loose plan', 'Right down the middle', 'Barely a plan', 'Zero plan'],
      ['Green flag ↔ Red flag', 'Total green flag', 'Mostly green', 'Right down the middle', 'Mostly red', 'Total red flag'],
      ['Ick ↔ Instant crush', 'Full ick', 'Mild ick', 'Right down the middle', 'Kind of cute', 'Instant crush'],
      ['First-date safe ↔ First-date chaos', 'Totally safe', 'Mostly safe', 'Right down the middle', 'A bit chaotic', 'Full chaos'],
    ] },
  { kind: 'rapidFire', name: 'Rapid Fire', hint: '10 seconds. don’t overthink.',
    minStrangers: 1, maxStrangers: 1, prompts: [
      ['Say the first word you think of: SUNDAY'], ['Describe your week in one word — go'],
      ['Best food, worst food. Fast.'], ['Your hype song, right now'],
      ['Your type, in exactly three words. GO'], ['Dream date city. One answer. NOW'],
    ] },

  // ---- the wild ones (perform, then the room crowns someone) ----------------
  { kind: 'point', name: 'Red Flag', hint: 'point at your suspect',
    minStrangers: 2, maxStrangers: 8, prompts: [
      ['Most likely to forget your birthday'], ['Most likely to text back in 3 days'],
      ['Most likely to get arrested for something dumb'], ['Biggest red-flag energy'],
      ['Most likely to start drama'], ['Most likely to ghost after one date'],
      ['Most likely to have two dates in one day'], ['Most likely to check their phone mid-kiss'],
    ] },
  { kind: 'point', name: 'Voice Swap', hint: 'do the voice — then point at who nailed it',
    minStrangers: 1, maxStrangers: 8, prompts: [
      ['Everyone talk like a PIRATE 🏴‍☠️'], ['Talk like a ROBOT 🤖'],
      ['Talk like your GRANDMA 👵'], ['Talk like a movie VILLAIN 😈'], ['Talk like a BABY 👶'],
      ['Talk like a nature documentary narrator'],
    ] },
  { kind: 'point', name: 'Sell It', hint: '30 seconds — then crown the best pitch',
    minStrangers: 1, maxStrangers: 8, prompts: [
      ['Sell a single sock to the room'], ['Sell a banana like it’s a supercar'],
      ['Convince the room to give you £100'], ['Sell a rock as a life-changing product'],
      ['Sell yourself as the world’s best date in 30 seconds'],
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
      ['Who would you take home to meet your mum?'], ['Who’s got the best smile here?'],
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
      ['Caption this: 💘📉🏃'], ['Caption this: 🥀😭📱'],
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
      ['Your last date, one emoji', '😍', '💀', '🏃', '🤝'],
    ] },
  { kind: 'thumbs', name: 'Truth Meter', hint: '👍 = cap. call it out',
    minStrangers: 1, maxStrangers: 8, prompts: [
      ['“I could survive a week without my phone”'], ['“I’ve never stalked an ex online”'],
      ['“I always tip 20%”'], ['“I read the terms & conditions”'], ['“I’m a good texter”'],
      ['“I’ve never faked a laugh on a date”'], ['“I don’t have a type”'],
    ] },
  { kind: 'point', name: 'Five Second Rule', hint: '5 seconds — then crown who nailed it',
    minStrangers: 1, maxStrangers: 8, prompts: [
      ['Name 5 fruits. FIVE SECONDS.'], ['Name 5 apps on your phone. GO.'],
      ['5 excuses for being late. NOW.'], ['5 things in your fridge. QUICK.'], ['5 red flags. FAST.'],
      ['5 green flags. GO.'], ['5 first-date spots. QUICK.'],
    ] },
  { kind: 'point', name: 'Act It Out', hint: 'mime it — first right guess crowns you',
    minStrangers: 1, maxStrangers: 8, prompts: [
      ['Mime: making a pizza'], ['Mime: losing your phone'], ['Mime: a cat at 3am'],
      ['Mime: airport security'], ['Mime: your morning routine'], ['Mime: winning the lottery'],
      ['Mime: a terrible first date'], ['Mime: seeing your crush unexpectedly'],
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
      ['Hum a song — first to guess crowns you'], ['Sing one line of a love song to the camera'],
    ] },
  { kind: 'point', name: 'One Word Story', hint: 'one word each — funniest ending wins',
    minStrangers: 2, maxStrangers: 8, prompts: [
      ['Start with: “Yesterday…”'], ['Start with: “Officer…”'], ['Start with: “Unfortunately…”'],
      ['Start with: “My therapist…”'], ['Start with: “Our first date…”'],
    ] },
  { kind: 'point', name: 'Finish The Sentence', hint: 'funniest answer takes it',
    minStrangers: 1, maxStrangers: 8, prompts: [
      ['“My last search was…”'], ['“I knew it was over when…”'], ['“My villain origin story is…”'],
      ['“The weirdest thing I own is…”'], ['“My red flag is…”'], ['“My toxic trait on dates is…”'],
      ['“I catch feelings when…”'],
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
      ['Hot seat: the cringiest thing you did to impress a crush'],
      ['Hot seat: your worst pickup line that actually WORKED'],
      ['Hot seat: how long do you wait before texting back — and why?'],
    ] },
  { kind: 'point', name: 'Storytime', hint: '20 seconds — best story takes it',
    minStrangers: 1, maxStrangers: 8, prompts: [
      ['Most embarrassing moment. 20 seconds. GO'],
      ['Your worst date ever — make it quick'],
      ['The dumbest thing you believed as a kid'],
      ['Your most unhinged 3am decision'],
      ['A time you got caught lying'],
      ['Your biggest public L'],
      ['The most awkward run-in with an ex — set the scene'],
      ['Your smoothest moment ever — flex it'],
    ] },
  { kind: 'point', name: 'Petty Court', hint: 'confess — the pettiest wins',
    minStrangers: 2, maxStrangers: 8, prompts: [
      ['Confess your pettiest move ever — pettiest wins'],
      ['The pettiest reason you’ve ever ghosted someone'],
      ['Your pettiest revenge story. GO'],
      ['The pettiest hill you will die on'],
      ['The pettiest reason you’ve rejected someone'],
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
      ['Defend: the “hey” text is a complete message'],
      ['Argue: love at first sight is real. Full conviction.'],
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
      ['Dramatic scene: they left you on read. ACT.'],
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
      ['Most likely to fall for someone on this app'],
      ['Most likely to have the messiest love life'],
      ['Most likely to be planning their wedding on Pinterest already'],
    ] },
  { kind: 'poll', name: 'Green Flag Red Flag', vibe: 'warm', hint: 'judge them. instantly.',
    minStrangers: 1, maxStrangers: 8, prompts: [
      ['They reply in 0.2 seconds', 'green flag', 'red flag'],
      ['They still follow all their exes', 'green flag', 'red flag'],
      ['They clap when the plane lands', 'green flag', 'red flag'],
      ['All their exes are “crazy”', 'green flag', 'red flag'],
      ['They talk to their pet in a baby voice', 'green flag', 'red flag'],
      ['Their camera roll is 90% selfies', 'green flag', 'red flag'],
      ['Texts back “k” when they’re mad instead of saying why', 'green flag', 'red flag'],
      ['Sends full sentences instead of just “k”', 'green flag', 'red flag'],
      ['Says “I feel…” instead of assuming what you’re thinking', 'green flag', 'red flag'],
      ['Double-texts without shame', 'green flag', 'red flag'],
      ['Says “you always…” or “you never…” mid-argument', 'green flag', 'red flag'],
      ['They never post you online', 'green flag', 'red flag'],
      ['They know your star sign before your surname', 'green flag', 'red flag'],
      ['They plan the whole date without asking', 'green flag', 'red flag'],
      ['They bring you snacks unprompted', 'green flag', 'red flag'],
    ] },
  { kind: 'thumbs', name: 'Delulu Check', vibe: 'warm', hint: '👍 = you actually believe it',
    minStrangers: 1, maxStrangers: 8, prompts: [
      ['I could land a plane in an emergency'],
      ['I could survive a zombie apocalypse'],
      ['I’d win an argument with my therapist'],
      ['I’m the funniest person I know'],
      ['I could go pro if I trained for a year'],
      ['A celebrity would 100% date me'],
      ['I’m the best kisser I know'],
      ['My ex still thinks about me daily'],
    ] },
  { kind: 'same', name: 'Cursed Combos', vibe: 'warm', hint: 'pick the worst — match the room',
    minStrangers: 1, maxStrangers: 8, prompts: [
      ['Worst pizza topping', 'toothpaste', 'mayo ice cream', 'wet socks', 'gravel'],
      ['Worst superpower', 'always slightly damp', 'teleport 3cm', 'invisible when nobody looks', 'talk to pigeons'],
      ['Worst thing to say at a funeral', 'nice turnout', 'he owed me money', 'who’s hungry?', 'awkwarddd'],
      ['Worst wifi name', 'FBI van 12', 'virus.exe', 'mum click here', 'definitely not spying'],
      ['Worst first-date opener', 'you look taller online', 'my ex loved this place', 'I brought my mum', 'so what’s your credit score?'],
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
      ['{target} — first thing you notice about someone?'],
      ['{target} — celebrity crush. No hesitation. NOW'],
      ['{target} — your dating profile in one sentence. GO'],
      ['{target} — biggest ick. Be honest.'],
      ['{target} — the app deletes tomorrow: who here gets your number?'],
      ['{target} — sing one line of a love song to the room'],
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

export function rollGame(strangers: number, avoidKind?: GameKind, avoidName?: string, vibe?: string, uids: string[] = []) {
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
  // played-version memory: whoever's in the room gets the prompt they've
  // seen least — never the same version twice until the pool runs dry
  const chosen = game.prompts[pickFreshIdx(uids, `pack:${game.name}`, game.prompts.length)];
  const [head, ...opts] = chosen;
  // shuffle options — EXCEPT kinds where order carries meaning: twoTruths'
  // options are "first/second/third thing they said" (spoken in that order,
  // must stay in that order) and wavelength's options are a spectrum (must
  // stay low-to-high or the "how close were you" scoring is nonsense).
  if (game.kind !== 'twoTruths' && game.kind !== 'wavelength') {
    for (let i = opts.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [opts[i], opts[j]] = [opts[j], opts[i]];
    }
  }
  return { game, prompt: [head, ...opts] };
}

// ---- THE CATALOGUE -----------------------------------------------------------
// Blended games, each a SEQUENCE of beats played back-to-back — never a single
// throwaway prompt. A beat is a kind + a prompt pool; the engine chains them
// with a quick flip between each. Every pool is deep enough that the
// played-version memory can serve a different show every single time.

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

// CONTENT RULES, learned the hard way from live screenshots:
// 1. Every option is self-contained — "chaos"/"right" as bare buttons is
//    gibberish; "milk first, like a menace" needs no context.
// 2. Every confession is a FULL sentence — "…used a dating app" renders as
//    a broken fragment when the beat header isn't on screen.
// 3. The prompt itself carries the joke. If reading it flat doesn't make
//    someone smirk, it doesn't ship.
export const SEQ_PACK: SeqDef[] = [
  { name: 'Face Off', icon: '😜', hint: 'pull it · hold it · crown it', vibe: 'warm', duo: true, beats: [
    // Gurning — real 750-year-old British "ugliest face" championship
    // (Egremont Crab Fair), simplified to "pull it on 3."
    { kind: 'freeze', secs: 26, pool: [
      ['Gurning: UGLIEST face contest. 3…2…1 GO'],
      ['Fish face 🐟 — but make it seductive. HOLD IT'],
      ['Double chin championship. Every chin you own. Commit.'],
      ['Your face when the text says “we need to talk”. HOLD IT'],
      ['Your face when your card declines in front of everyone. HOLD'],
      ['Duck lips + shocked eyebrows. AT THE SAME TIME.'],
      ['Your “I said something wrong in the group chat” face'],
      ['The face you pull in the mirror when nobody’s watching'],
      ['Your “trying to look hot in a passport photo” face. HOLD'],
      ['One eyebrow up. Just one. If you can’t — improvise. HOLD'],
      ['Cheeks full of air like a hamster. Do not pop. HOLD'],
      ['Your best mugshot face. You did NOT do it.'],
      ['Chin up, eyes squinting — your “I’m the CEO now” face'],
      ['Your “pretending to understand the plot” face. HOLD'],
      ['The face you make when your food arrives. Freeze it.'],
      ['Your “laughing at a joke you didn’t hear” face. HOLD'],
    ] },
    { kind: 'freeze', secs: 26, pool: [
      ['Villain smirk — you just stole their fries. Freeze.'],
      ['The face you make reading your own texts from 3am. HOLD'],
      ['Your “I just saw my ex thriving” face. HOLD IT'],
      ['Sexy stare and fish lips AT THE SAME TIME. Do not laugh.'],
      ['Your “they texted first” face 😏 — hold it'],
      ['Your “I know something you don’t” smirk. HOLD'],
      ['Your “caught checking someone out” recovery face'],
      ['Slow-motion shocked face — take 5 full seconds to get there'],
      ['Your “this meeting could’ve been an email” face. HOLD'],
      ['The face you’d pull on a rollercoaster drop. FREEZE mid-drop'],
      ['Your most dramatic soap-opera betrayal face. HOLD'],
      ['Your “I forgot their name mid-sentence” face'],
      ['Kiss face + crossed eyes. Yes, both. HOLD IT'],
      ['Your “the lift doors closed on someone waving” guilt face'],
      ['Your “my phone is at 1% and the charger is upstairs” face'],
    ] },
    { kind: 'point', secs: 28, pool: [
      ['Crown the funniest face 👑'],
      ['Who committed hardest? Crown them 👑'],
      ['Whose face haunted you? Crown it 👑'],
    ] },
  ]},
  { name: 'Eye Contact', icon: '👀', hint: 'hold it · smile · don’t crack', vibe: 'spark', duo: true, beats: [
    { kind: 'freeze', secs: 26, pool: [
      ['Dead-eye contact. No laughing. The first blink is a confession.'],
      ['Stare into their soul. Whoever laughs first loses.'],
      ['Eye contact + total silence. The first sound loses.'],
      ['Stare like you’re trying to guess their phone PIN.'],
      ['Eye contact like a wild-west standoff. Squint. HOLD.'],
      ['Look at them like they owe you money. Do not blink.'],
      ['Eye contact while both counting to ten out loud. No laughing.'],
      ['Stare like you recognise them from somewhere. Keep deciding.'],
    ] },
    { kind: 'freeze', secs: 26, pool: [
      ['Now a SLOW smile. Do not crack.'],
      ['Now wink like a movie star. Hold it.'],
      ['Mouth “I know your secret” in total silence. HOLD.'],
      ['Now heart-eyes. Cheesiest possible. HOLD IT'],
      ['Now the smoulder. Full Blue Steel. Commit.'],
      ['The slowest wink in recorded history. Begin… now.'],
      ['Whisper “I see you” without breaking the stare. HOLD.'],
      ['Mouth their name in slow motion. Keep the eye contact.'],
    ] },
    { kind: 'point', secs: 28, pool: [
      ['Who broke first?'],
      ['Who had the deadlier stare? Crown them.'],
    ] },
  ]},
  { name: 'Hot Takes', icon: '🔥', hint: 'three takes · pick sides · argue', vibe: 'warm', duo: true, beats: [
    { kind: 'poll', pool: [
      ['Pineapple on pizza?', 'elite — fight me', 'a crime against Italy'],
      ['Cereal or milk first?', 'milk first, like a menace', 'cereal first, like a person'],
      ['Is a hotdog a sandwich?', 'legally, yes', 'take that back'],
      ['Toilet paper: over or under?', 'over — civilised', 'under — feral'],
      ['Night shower or morning shower?', 'night — superior being', 'morning — you sleep dirty??'],
      ['Ketchup: fridge or cupboard?', 'fridge — obviously', 'cupboard — psychopath'],
      ['Cold pizza for breakfast?', 'elite breakfast', 'have some self-respect'],
      ['Crocs in public?', 'comfort is king', 'a cry for help'],
      ['Well-done steak?', 'let people enjoy things', 'call the police'],
      ['Milk before cereal?', 'chaos, respectfully', 'jail. immediately.'],
      ['Sleeping with socks on?', 'cosy genius', 'serial killer behaviour'],
      ['Speaker calls in public?', 'main character energy', 'straight to prison'],
      ['Clapping when the plane lands?', 'let joy exist', 'sit down. never.'],
      ['Eating fries with a fork?', 'clean hands, clear mind', 'you eat wrong'],
      ['Pizza crust?', 'the best bit', 'bread tax — leave it'],
      ['Shoes on in the house?', 'freedom', 'absolutely feral'],
      ['Breakfast for dinner?', 'genius move', 'unsettling behaviour'],
      ['Talking to yourself out loud?', 'best conversations ever', 'seek help (lovingly)'],
      ['Double-dipping the chip?', 'my dip, my rules', 'crimes against the bowl'],
      ['GIFs in serious conversations?', 'emotional support GIFs', 'read the room'],
      ['Ice in water?', 'ice — civilised', 'no ice — lukewarm lifestyle'],
      ['Toothpaste before breakfast?', 'minty juice enjoyer', 'after food, like a person'],
    ] },
    { kind: 'poll', pool: [
      ['Voice notes over a minute long?', 'a love language', 'straight to jail'],
      ['Texting “lol” with a dead face?', 'we all do it', 'psychotic behaviour'],
      ['Gym at 6am?', 'built different', 'built LYING'],
      ['Splitting the bill on a first date?', 'fair is fair', 'the date is over'],
      ['Texting your ex at 2am?', 'human nature', 'throw the phone in the sea'],
      ['Kissing on the first date?', 'if the vibe is right', 'slow down, romeo'],
      ['Saying “I love you” first?', 'brave and correct', 'never — hold the line'],
      ['Checking your phone on a date?', 'one peek is fine', 'date over. leave.'],
      ['Soft-launching your relationship?', 'soft launch everything', 'private life, happy life'],
      ['Liking your crush’s photo from 2019?', 'strategic and bold', 'delete your account'],
      ['“Hey” as an opening text?', 'simple, effective', 'zero effort, zero reply'],
      ['Flirting with emojis only?', 'a whole language 😏', 'use your words'],
      ['Waiting 2 hours to reply on purpose?', 'the game is the game', 'games are for children'],
      ['Dating your friend’s ex?', 'love is love', 'absolutely never'],
      ['Getting back with an ex?', 'people change', 'the audacity of hope'],
      ['Matching outfits as a couple?', 'adorable', 'a hostage situation'],
      ['First date at the cinema?', 'classic', 'you can’t even TALK'],
      ['Ordering for your date?', 'smooth if done right', 'controlling. red flag.'],
      ['Long distance relationships?', 'love finds a way', 'a subscription to sadness'],
      ['Keeping photos of your ex?', 'memories are memories', 'burn the archive'],
      ['Sliding into DMs?', 'shoot your shot', 'desperate hours'],
      ['Flirting with the waiter for free dessert?', 'hustle respected', 'shameless'],
    ] },
    { kind: 'poll', pool: [
      ['They clap when the plane lands', 'green flag — pure joy', 'red flag — arrest them'],
      ['They still follow all their exes', 'green — secure', 'red — runs an ex museum'],
      ['All their exes are “crazy”', 'green — just unlucky', 'red — THEY are the crazy ex'],
      ['They baby-talk their dog', 'green — marry them', 'red — the dog is embarrassed'],
      ['Phone permanently on Do Not Disturb', 'green — inner peace', 'red — hiding something'],
      ['They reply instantly, every time', 'green — they care', 'red — no life??'],
      ['They have 4,000 selfies', 'green — self-love', 'red — run'],
      ['They’re best friends with their ex', 'green — mature', 'red — unfinished business'],
      ['They plan the whole date without asking', 'green — decisive', 'red — control issues'],
      ['They talk gym PBs on date one', 'green — passion', 'red — the gym is their ex'],
      ['They send memes at 3am', 'green — love language', 'red — go to SLEEP'],
      ['They never post you online', 'green — private', 'red — you’re a secret'],
      ['They know your star sign before your surname', 'green — spiritual', 'red — reading your chart already'],
      ['They call instead of texting', 'green — old school', 'red — psychological warfare'],
      ['They keep score in arguments', 'green — good memory', 'red — you’re in court'],
      ['They order the same food as you', 'green — soulmates', 'red — no personality'],
      ['They say “we’ll see” instead of no', 'green — optimistic', 'red — coward'],
      ['They’re friends with ALL their exes', 'green — no bad blood', 'red — a collection'],
      ['They bring you snacks unprompted', 'green — marry them', 'red — what do they want'],
      ['They double-text without shame', 'green — confident', 'red — down bad'],
    ] },
  ]},
  // Perform-then-crown games need real time to breathe — Charades/Heads Up!
  // research converges on 60-90s as the sweet spot; the old flat ~23s
  // (secsFor's point default) cut people off before the funny part landed.
  { name: 'Storytime', icon: '🎤', hint: 'real stories · best one wins', vibe: 'wild', duo: true, beats: [
    { kind: 'point', secs: 55, pool: [
      ['Most embarrassing moment of your LIFE. Full story. GO'],
      ['Your most unhinged 3am decision — and why it made sense at the time'],
      ['The biggest public L you’ve ever taken. Spare NO detail'],
      ['The time you flirted and it went catastrophically wrong'],
      ['The most trouble you’ve ever been in — start from the beginning'],
      ['Your worst haircut era. Paint the picture.'],
      ['The moment you realised you were NOT the main character'],
      ['A time you confidently said the wrong thing to the wrong person'],
      ['Your most embarrassing gym or sports moment. Build it up.'],
      ['The family story they STILL bring up at every gathering'],
      ['Your worst holiday disaster in 30 seconds'],
      ['The dumbest injury you’ve ever had to explain to a doctor'],
      ['The time you got caught singing when you thought you were alone'],
      ['Your biggest kitchen disaster. List the casualties.'],
      ['The lie that spiralled so far you had to move on with your life'],
    ] },
    { kind: 'point', secs: 55, pool: [
      ['Worst date you’ve ever been on. Build the scene.'],
      ['A lie you told that spiralled completely out of control'],
      ['The dumbest thing you fully believed as a kid'],
      ['A story that starts: “so security was NOT happy with me”'],
      ['Your most catastrophic crush confession. Every detail.'],
      ['The date that ended so badly it became a legend'],
      ['A text you sent that still haunts you at night'],
      ['The most awkward run-in with an ex. Set the scene.'],
      ['Your smoothest moment EVER — you get to flex once'],
      ['A time you completely misread a romantic situation'],
      ['The wildest coincidence that ever happened to you'],
      ['A first impression you spectacularly failed'],
      ['The most embarrassing thing your parents did in public'],
      ['The moment you knew you’d caught feelings — and panicked'],
      ['Your worst “meeting the parents” story. GO'],
    ] },
  ]},
  { name: 'Rizz Off', icon: '😏', hint: 'best line · worst line · shoot your shot', vibe: 'spark', duo: true, beats: [
    { kind: 'point', secs: 37, pool: [
      ['Cheesiest pickup line you know. Full eye contact. GO'],
      ['“Are you a parking ticket? Because you’ve got FINE written all over you.” Now beat it.'],
      ['A pickup line using their name. 10 seconds to craft it. GO'],
      ['A pickup line themed on FOOD. Make it work.'],
      ['Your best line — delivered without breaking eye contact once'],
      ['A pickup line so smooth it should be illegal. GO'],
      ['Compliment their smile without using the word “smile”'],
      ['A pickup line about this app. Meta rizz. GO'],
      ['Your opening line if you matched with them online. Say it out loud.'],
      ['A line that would work on YOU. Reveal your own weakness.'],
    ] },
    { kind: 'point', secs: 37, pool: [
      ['WORST pickup line on purpose. Make it foul.'],
      ['A pickup line so bad it loops back around to smooth. GO'],
      ['The worst line: something about star signs. Make it awful.'],
      ['A pickup line a DAD would use. Full dad energy.'],
      ['The most 2014 pickup line you can produce'],
      ['A line so cringe they’ll physically recoil. That IS the win.'],
      ['A pickup line involving wifi. It cannot be good.'],
      ['The clumsiest compliment ever assembled. GO'],
    ] },
    { kind: 'point', secs: 37, pool: [
      ['Shoot your shot at the camera like your crush is watching'],
      ['Flirt with the camera in a whisper. Fully commit 😳'],
      ['Ask them out like you’re in a 90s rom-com. Full scene.'],
      ['Shoot your shot in exactly five words. Choose wisely.'],
      ['Slide into their DMs OUT LOUD. Narrate the whole message.'],
      ['Recreate your smoothest real-life moment. On camera. NOW'],
      ['Wink, point, and say something smooth. One take only.'],
      ['Say “hey you” like it’s 2am and you mean it 😳'],
    ] },
  ]},
  { name: 'Spin the Bottle', icon: '🍾', hint: 'the bottle picks · no escape', vibe: 'spark', duo: false, beats: [
    { kind: 'spin', pool: [
      ['{target} — what’s your actual type? Be brutally honest'],
      ['{target} — rate your own rizz out of 10. Now prove it.'],
      ['{target} — who in this room would you take on a date? 👀'],
      ['{target} — most scandalous first-date story. Spill.'],
      ['{target} — first thing you notice about someone?'],
      ['{target} — your worst pickup line, deployed with full confidence. GO'],
      ['{target} — celebrity crush. No hesitation. NOW'],
      ['{target} — what’s your love language? Prove it in 5 seconds.'],
      ['{target} — smoothest thing you’ve ever said. Repeat it for the room.'],
      ['{target} — your dating profile in one sentence. GO'],
      ['{target} — biggest ick. Be honest. The room is judging.'],
      ['{target} — your top three green flags. GO'],
      ['{target} — describe your first kiss in exactly 3 words'],
      ['{target} — the app deletes tomorrow: who here gets your number?'],
      ['{target} — rate this room’s collective rizz out of 10'],
      ['{target} — confess: how many dating apps are on your phone RIGHT NOW?'],
    ] },
    { kind: 'spin', pool: [
      ['{target} — blow a kiss in extreme slow motion. Commit.'],
      ['{target} — describe your dream date in 10 seconds. GO'],
      ['{target} — say “hey you” to the camera like it’s 2am 😳'],
      ['{target} — your most romantic move ever. Details.'],
      ['{target} — wink at everyone. One at a time. Slowly.'],
      ['{target} — dramatic hair flip. No hair? Improvise. Commit.'],
      ['{target} — flirt with your own reflection for 10 seconds'],
      ['{target} — best slow-motion movie entrance. Leave and re-enter the frame.'],
      ['{target} — invent a Shakespearean love line for the camera. Thee and thou required.'],
      ['{target} — show the room your smile, then your wink. The room votes which is deadlier.'],
      ['{target} — one bar of a love rap about anyone here. GO'],
      ['{target} — teach the room your signature dance move'],
      ['{target} — sing one line of a love song. Full feeling.'],
      ['{target} — say “oh stop it” like you’re being complimented. Flustered. GO'],
    ] },
  ]},
  { name: 'Confessions', icon: '🙊', hint: 'never have I ever · thumbs up = guilty', vibe: 'wild', duo: true, beats: [
    { kind: 'thumbs', pool: [
      ['Never have I ever ghosted someone mid-conversation'],
      ['Never have I ever texted the WRONG person something unforgivable'],
      ['Never have I ever stalked an ex online this week'],
      ['Never have I ever pretended to be busy to dodge plans'],
      ['Never have I ever pretended to laugh at a joke I didn’t get'],
      ['Never have I ever eaten food off the floor and enjoyed it'],
      ['Never have I ever blamed a smell on someone else'],
      ['Never have I ever screenshotted a chat straight into another chat'],
      ['Never have I ever pretended my phone died to end a conversation'],
      ['Never have I ever practised an argument in the shower'],
      ['Never have I ever cried to get out of trouble'],
      ['Never have I ever waved at someone waving at the person behind me'],
      ['Never have I ever forgotten someone’s name WHILE introducing them'],
      ['Never have I ever snooped in someone’s bathroom cabinet'],
      ['Never have I ever faked a phone call to avoid a person'],
      ['Never have I ever worn clothes off the floor and called them clean'],
      ['Never have I ever said “you too” when the waiter said “enjoy your meal”'],
      ['Never have I ever answered “yeah” without hearing the question'],
      ['Never have I ever posted something purely to make ONE person jealous'],
      ['Never have I ever muted the group chat and lied about it'],
      ['Never have I ever eaten a whole pizza alone in one sitting'],
      ['Never have I ever tripped in public and walked faster to escape the shame'],
      ['Never have I ever sniffed clothes to decide if they’re clean'],
      ['Never have I ever laughed at the worst possible moment'],
    ] },
    { kind: 'thumbs', pool: [
      ['Never have I ever pretended not to see someone I know in public'],
      ['Never have I ever flirted my way out of trouble'],
      ['Never have I ever lied about my age'],
      ['Never have I ever faked an entire personality on a first date'],
      ['Never have I ever had a crush on a teacher'],
      ['Never have I ever flirted with a bartender for a free drink'],
      ['Never have I ever kissed someone within an hour of meeting them'],
      ['Never have I ever practised kissing on my hand'],
      ['Never have I ever fancied my friend’s sibling'],
      ['Never have I ever sent a risky text and stared at my phone in fear'],
      ['Never have I ever dated two people in the same week'],
      ['Never have I ever pretended to like a hobby to impress someone'],
      ['Never have I ever got butterflies from a two-word text'],
      ['Never have I ever rehearsed a conversation with my crush beforehand'],
      ['Never have I ever asked a friend to stalk my crush’s profile for me'],
      ['Never have I ever laughed WAY too hard at a crush’s terrible joke'],
      ['Never have I ever “accidentally” bumped into a crush on purpose'],
      ['Never have I ever dressed up because THEY might be there'],
      ['Never have I ever changed my route to walk past someone cute'],
      ['Never have I ever fake-yawned to put an arm around someone'],
      ['Never have I ever given out a fake number'],
      ['Never have I ever been caught checking someone out'],
      ['Never have I ever flirted with someone out of my league — and WON'],
      ['Never have I ever winked at a stranger just to see what happens'],
    ] },
    { kind: 'thumbs', pool: [
      ['Never have I ever kissed someone whose name I never knew'],
      ['Never have I ever had a one-night stand'],
      ['Never have I ever gone through a partner’s phone'],
      ['Never have I ever had a crush on a friend’s partner'],
      ['Never have I ever skinny-dipped'],
      ['Never have I ever kissed two people in the same night'],
      ['Never have I ever had a friends-with-benefits situation'],
      ['Never have I ever been someone’s secret'],
      ['Never have I ever kissed someone to make an ex jealous'],
      ['Never have I ever dated someone purely out of boredom'],
      ['Never have I ever been on a date with someone I met that same day'],
      ['Never have I ever said “I love you” without meaning it'],
      ['Never have I ever been caught sneaking out — or in'],
      ['Never have I ever been the reason two people broke up'],
      ['Never have I ever sent a flirty text to the wrong person'],
      ['Never have I ever pretended to be single when I wasn’t'],
      ['Never have I ever had a holiday romance that died at the airport'],
      ['Never have I ever ghosted someone… then matched with them again later'],
      ['Never have I ever kissed a best friend'],
      ['Never have I ever met someone’s parents by accident'],
      ['Never have I ever got someone’s number and forgot whose it was'],
      ['Never have I ever had a dream about someone in this room 👀'],
    ] },
  ]},
  { name: 'Would You Rather', icon: '🤔', hint: 'three impossible choices', vibe: 'warm', duo: true, beats: [
    { kind: 'wouldRather', pool: [
      ['Fight 100 duck-sized horses, or…', '100 tiny horses', '1 giant duck'],
      ['Read minds, or…', 'read minds', 'be invisible'],
      ['Always hiccup when you talk, or…', 'hiccup talking', 'sneeze laughing'],
      ['Have fingers as long as legs, or…', 'finger legs', 'legs as short as fingers'],
      ['Sweat glitter, or…', 'sweat glitter ✨', 'cry chocolate milk'],
      ['Have an entrance theme song, or…', 'theme song plays when you enter', 'applause every time you sit down'],
      ['Only ever whisper, or…', 'whisper forever', 'shout forever'],
      ['Talk like a pirate for a year, or…', 'pirate year 🏴‍☠️', 'baby voice for a month'],
      ['Smell like cheese only YOU can smell, or…', 'secret cheese smell', 'everyone else smells it, not you'],
      ['Have hands for feet, or…', 'hands for feet', 'feet for hands'],
      ['Get famous for a sneeze compilation, or…', 'sneeze famous', 'never famous at all'],
      ['Live with no music, or…', 'no music ever', 'no movies ever'],
      ['Never eat pizza again, or…', 'no pizza for life', 'ONLY pizza for a year'],
      ['Type with your nose forever, or…', 'nose-typing', 'scrolling with your elbows'],
    ] },
    { kind: 'wouldRather', pool: [
      ['Your search history goes public, or…', 'search history public', 'texts read out loud'],
      ['Know how you die, or…', 'know when', 'know how'],
      ['Be famous, or…', 'famous', 'filthy rich'],
      ['Know everyone’s honest opinion of you, or…', 'hear it all', 'blissful ignorance'],
      ['Relive your best day forever, or…', 'best day on loop', 'skip to something new'],
      ['Never feel embarrassment again, or…', 'no embarrassment ever', 'no jealousy ever'],
      ['Always be 10 minutes late, or…', 'always late', '20 minutes early, forever'],
      ['Pause life whenever you want, or…', 'pause button', 'rewind button'],
      ['Win every argument but be secretly wrong, or…', 'always “win”', 'be right, never win'],
      ['Have unlimited money but no friends, or…', 'rich and alone', 'broke with your people'],
      ['Read minds but can’t turn it off, or…', 'hear EVERY thought', 'stay blissfully deaf'],
      ['Be a legendary storyteller from your Ls, or…', 'great stories', 'never embarrass yourself'],
    ] },
    { kind: 'wouldRather', pool: [
      ['Date someone hotter than you, or…', 'hotter — live in fear', 'less hot — live in peace'],
      ['Be talked dirty to in person, or…', 'in person 😳', 'over text'],
      ['Always say what you think, or…', 'brutal honesty', 'never speak again'],
      ['Date someone your friends hate, or…', 'friends hate them', 'they hate your friends'],
      ['Your ex briefs your next date, or…', 'ex writes the intro', 'mum writes your dating bio'],
      ['Kiss badly forever, or…', 'terrible kisser, elite texter', 'elite kisser, dry texter'],
      ['Know your soulmate exists but never meet, or…', 'never meet them', 'meet them — they’re taken'],
      ['Get caught mid-flirt by their friends, or…', 'caught by THEIR friends', 'caught by YOUR friends'],
      ['Your crush sees your search history, or…', 'search history leaked', 'camera roll leaked'],
      ['Fall for your best friend, or…', 'fall for the best friend', 'they fall for you first'],
      ['A clingy partner who’s always there, or…', 'clingy but present', 'loving but always “omw”'],
      ['Wild love that fades, or…', 'wild love, short', 'calm love, forever'],
      ['Never flirt again, or…', 'retire from flirting', 'flirt with EVERYONE, no off switch'],
    ] },
  ]},
  { name: 'Impressions', icon: '🎭', hint: 'do it badly · funniest wins', vibe: 'wild', duo: true, beats: [
    { kind: 'point', secs: 50, pool: [
      ['Your worst BATMAN'],
      ['Your worst British accent'],
      ['Your worst influencer apology video'],
      ['Order a pizza like a movie VILLAIN 😈'],
      ['Your worst Aussie accent — narrate a nature documentary'],
      ['A GPS voice slowly losing patience'],
      ['A robot learning to feel love 🤖'],
      ['An angry chef reviewing YOUR cooking'],
      ['A pirate ordering coffee at a drive-thru'],
      ['A wise old master giving dating advice'],
      ['A news anchor reporting on their own bad day'],
      ['A wrestler announcing they’re going to bed early'],
    ] },
    { kind: 'point', secs: 50, pool: [
      ['Your GRANDMA describing your love life 👵'],
      ['A CEO on a podcast explaining why you’re single 💼'],
      ['A flight attendant calmly announcing the plane IS going down'],
      ['A BABY negotiating a business deal 👶'],
      ['Your MUM finding out about this app'],
      ['A medieval knight discovering wifi'],
      ['An alien explaining human dating to its boss'],
      ['A toddler CEO firing someone (lovingly)'],
      ['Your PE teacher’s motivational speech'],
      ['A vampire at a dentist appointment'],
      ['A nature narrator describing THIS exact room'],
      ['A royal announcing they’ve run out of snacks'],
    ] },
    { kind: 'point', secs: 37, pool: [
      ['Best EVIL LAUGH — commit or lose. Crown the winner'],
      ['Best dramatic gasp — full soap opera. Crown it.'],
      ['Best fake cry on demand. Crown the actor.'],
    ] },
  ]},
  { name: 'Roast Circle', icon: '💀', hint: 'roast · get roasted · make up', vibe: 'wild', duo: false, beats: [
    { kind: 'point', secs: 50, pool: [
      ['Roast the person on your left (with love)'],
      ['Roast this app to its face. Go.'],
      ['Roast each other’s camera angle. NOW.'],
      ['Roast their wifi quality based on this call alone'],
      ['Roast the room’s combined fashion sense'],
      ['Roast how long they took to answer the last round'],
      ['Roast the person most likely to screenshot this'],
    ] },
    { kind: 'point', secs: 50, pool: [
      ['Roast your OWN haircut before someone else does'],
      ['Roast your own dating history in one sentence'],
      ['Confess your pettiest move ever — pettiest wins'],
      ['Roast your own gym attendance. Be honest.'],
      ['Roast your own sleep schedule. The truth.'],
      ['Roast your own screen time. Say the NUMBER.'],
      ['Roast your own cooking with one specific example'],
    ] },
    { kind: 'point', secs: 37, pool: [
      ['Now the best COMPLIMENT — make someone blush to make up'],
      ['Undo the damage: hype someone up like their biggest fan'],
    ] },
  ]},

  // ---- THE NEW WING — the giants, in full ----------------------------------
  // Truth or Dare — THE party game. Truths from the canonical flirty lists,
  // dares filtered hard for "doable alone on camera in a video call."
  { name: 'Truth or Dare', icon: '🎯', hint: 'a truth · a dare · a spicy finale', vibe: 'wild', duo: true, beats: [
    { kind: 'point', secs: 38, pool: [
      ['TRUTH: the most embarrassing thing in your camera roll — describe it'],
      ['TRUTH: your first crush. Name, story, what happened.'],
      ['TRUTH: what’s your biggest ick?'],
      ['TRUTH: ever been caught stalking someone’s profile? Details.'],
      ['TRUTH: longest you’ve waited to text back ON PURPOSE?'],
      ['TRUTH: the worst excuse you’ve ever used to cancel plans'],
      ['TRUTH: a lie you tell on every first date'],
      ['TRUTH: your most-used emoji — and what it says about you'],
      ['TRUTH: rate your own flirting out of 10. Justify the score.'],
      ['TRUTH: what would your ex say your worst habit is?'],
      ['TRUTH: the cringiest thing you’ve done to impress someone'],
      ['TRUTH: the song you secretly perform in the mirror'],
      ['TRUTH: the pettiest reason you’ve ever rejected someone'],
      ['TRUTH: the last thing you googled. Be honest. Word for word.'],
      ['TRUTH: who in your phone would you never want to lose?'],
      ['TRUTH: your guilty-pleasure song — sing one line NOW'],
      ['TRUTH: the weirdest food combo you genuinely love'],
      ['TRUTH: when did you last cry and what was it REALLY about?'],
      ['TRUTH: the most childish thing you still do'],
      ['TRUTH: your worst date story in exactly one sentence'],
      ['TRUTH: ever pretended to love a gift? What was it?'],
      ['TRUTH: a secret talent nobody ever asks about — show it'],
      ['TRUTH: how long do you ACTUALLY take to get ready?'],
      ['TRUTH: the app you open first every morning. No lying.'],
    ] },
    { kind: 'point', secs: 38, pool: [
      ['DARE: serenade the camera. Full chorus. No shame.'],
      ['DARE: runway walk across the room. And BACK.'],
      ['DARE: talk in slow motion until your next turn'],
      ['DARE: 10 push-ups right now. Form counts.'],
      ['DARE: speak in an accent of their choosing for the next round'],
      ['DARE: dance for 15 seconds. No music. Full commitment.'],
      ['DARE: dramatic-read your last sent text out loud'],
      ['DARE: your best impression of the other person. GO'],
      ['DARE: keep a straight face while they try to break you'],
      ['DARE: the alphabet backwards. Fail = pull a forfeit face.'],
      ['DARE: red-carpet pose. HOLD it like the paparazzi are real.'],
      ['DARE: talk to the camera like it’s a puppy for 10 seconds'],
      ['DARE: your morning routine in fast-forward. GO'],
      ['DARE: freestyle rap about the other person for 15 seconds'],
      ['DARE: mime your worst date until they guess what happened'],
      ['DARE: evil villain monologue… about doing laundry'],
      ['DARE: win an Oscar. Acceptance speech. Real tears.'],
      ['DARE: catwalk twirl. Slow. Dramatic. Eye contact.'],
      ['DARE: laugh for 10 seconds straight for no reason'],
      ['DARE: eat an invisible lemon. Face and all.'],
      ['DARE: propose to an object within reach. MEAN it.'],
      ['DARE: movie-trailer voice: dramatically announce what you had for lunch'],
      ['DARE: describe the last photo in your camera roll. In full.'],
    ] },
    { kind: 'point', secs: 38, pool: [
      ['TRUTH: your actual type — be specific, “good vibes” doesn’t count'],
      ['TRUTH: the smoothest line anyone’s ever used on you'],
      ['TRUTH: ever had a crush on someone in this room? 👀'],
      ['DARE: flirt with the camera for 10 seconds like it’s your crush'],
      ['TRUTH: your idea of a perfect first kiss. Paint it.'],
      ['DARE: blow a kiss in the most dramatic way physically possible'],
      ['TRUTH: what makes you instantly swipe right?'],
      ['DARE: say “hey you” to the camera like it’s 2am'],
      ['TRUTH: the most romantic thing you’ve ever actually done'],
      ['TRUTH: describe your dream date — unlimited budget'],
      ['DARE: give them your best compliment. Unbroken eye contact.'],
      ['TRUTH: beach kiss or rain kiss — and defend it'],
      ['TRUTH: your green-flag checklist. Top three only.'],
      ['DARE: wink like a movie star. Hold it 3 full seconds.'],
      ['TRUTH: the fastest you’ve ever caught feelings'],
      ['TRUTH: something flirty you did that you’ll never live down'],
      ['DARE: recreate the Titanic bow pose. Alone. Commit.'],
      ['TRUTH: be pursued or do the pursuing — which one, honestly?'],
      ['TRUTH: your love language — and prove it in 10 seconds'],
      ['DARE: mouth “call me” at the camera like a celeb leaving a club'],
    ] },
  ]},
  // 21 Questions — the get-to-know-you giant, tiered warm → flirty → juicy.
  { name: '21 Questions', icon: '💬', hint: 'get warm · get flirty · get deep', vibe: 'spark', duo: true, beats: [
    { kind: 'point', secs: 38, pool: [
      ['Your dream city to live in — and what’s actually stopping you?'],
      ['The best compliment you’ve ever received?'],
      ['What are you weirdly, specifically good at?'],
      ['Your comfort movie — the one you never get tired of?'],
      ['The most spontaneous thing you’ve ever done?'],
      ['You win the lottery tonight. FIRST thing you do?'],
      ['A smell that takes you straight back to childhood?'],
      ['Your 3am snack of choice?'],
      ['One thing you could talk about for an hour, zero notes?'],
      ['Beach holiday or city adventure — describe your dream version'],
      ['The best meal of your life — where were you?'],
      ['What did 8-year-old you want to be?'],
      ['Your most controversial food opinion. Own it.'],
      ['Your celebrity lookalike — according to OTHER people?'],
      ['One bucket-list thing you WILL actually do?'],
      ['Your go-to karaoke song?'],
      ['Early bird or night owl — and what happens at your peak hour?'],
      ['The last thing that made you laugh until it hurt?'],
      ['Your hidden green flag?'],
      ['If you could master one skill overnight — which?'],
    ] },
    { kind: 'point', secs: 38, pool: [
      ['Your idea of a perfect lazy Sunday with someone?'],
      ['What catches your attention FIRST about a person?'],
      ['Love at first sight — believe it? Has it happened?'],
      ['The most attractive quality that has nothing to do with looks?'],
      ['Your flirting style: smooth, chaotic, or accidental?'],
      ['First date, money doesn’t exist — what are we doing?'],
      ['A deal-breaker most people would call harsh?'],
      ['How do you KNOW when you like someone — what’s the tell?'],
      ['The best date you’ve ever been on — what made it?'],
      ['Slow dancing in the kitchen — cute or cringe?'],
      ['Your favourite compliment to GIVE?'],
      ['Deep talk at 2am or breakfast at 8am?'],
      ['Something small that instantly wins you over?'],
      ['First move: always you, never you, or depends?'],
      ['Your texting style when you LIKE someone — fast, slow, chaotic?'],
      ['The most romantic movie scene ever, in your opinion?'],
      ['Who says “I love you” first — you or them?'],
      ['Grand gestures: yes or too much?'],
      ['What song plays in the movie scene where we met?'],
      ['Dream kiss location. No details spared.'],
    ] },
    { kind: 'point', secs: 38, pool: [
      ['The biggest risk you’ve ever taken for a crush?'],
      ['Your most-repeated dating mistake?'],
      ['Ever fallen for someone you REALLY shouldn’t have?'],
      ['Longest you’ve liked someone without ever telling them?'],
      ['One thing ALL your exes would agree about you?'],
      ['Your honest opinion of dating apps?'],
      ['Ever ghosted someone and regretted it?'],
      ['Your hardest rejection — and did you deserve it?'],
      ['A secret you’ve never told a partner?'],
      ['Who was the one that got away?'],
      ['Do you compare new people to your ex? Honestly.'],
      ['The most jealous you’ve ever been?'],
      ['Ever stayed “friends” hoping it would become more?'],
      ['Catching feelings: fight it or embrace it?'],
      ['The red flag YOU bring to relationships?'],
      ['Your love life as a movie genre right now — which is it?'],
      ['The wildest thing you’ve done to get someone’s attention?'],
      ['One romantic thing you pretend to hate but secretly love?'],
    ] },
  ]},
  // This or That — rapid-fire compatibility, the dating-app classic.
  { name: 'This or That', icon: '⚡', hint: 'instant picks · zero thinking', vibe: 'warm', duo: true, beats: [
    { kind: 'poll', pool: [
      ['Coffee or tea?', 'coffee — run on chaos', 'tea — inner peace'],
      ['Summer or winter?', 'summer — sun creature', 'winter — cosy season'],
      ['Series or films?', 'series — commit to the plot', 'films — one sitting, done'],
      ['Sweet or salty?', 'sweet tooth', 'salt gang'],
      ['Gym or sofa marathon?', 'gym — endorphins', 'sofa — scrolling IS cardio'],
      ['City or countryside?', 'city lights', 'fields and peace'],
      ['Cook or order in?', 'chef mode', 'delivery believer'],
      ['Window seat or aisle?', 'window — views', 'aisle — freedom'],
      ['Know the gift early or be surprised?', 'tell me now', 'surprise me'],
      ['Books or podcasts?', 'books — full focus', 'podcasts — multitask magic'],
      ['Big party or small dinner?', 'big party energy', 'intimate dinner club'],
      ['Pool or ocean?', 'pool — controlled fun', 'ocean — salty freedom'],
      ['Cats or dogs?', 'cat person', 'dog person'],
      ['Pancakes or waffles?', 'pancakes', 'waffles — superior grid'],
      ['Rain sounds or total silence?', 'rain — cosy', 'silence — peace'],
      ['Text first or wait?', 'text first — life is short', 'wait — power move'],
      ['Plan everything or wing it?', 'itinerary lover', 'chaos traveller'],
      ['Breakfast: sweet or savoury?', 'pastries and joy', 'eggs and purpose'],
    ] },
    { kind: 'poll', pool: [
      ['First date: dinner or activity?', 'dinner — actually talk', 'activity — actually do'],
      ['Coffee date or cocktails?', 'coffee — daylight honesty', 'cocktails — evening magic'],
      ['Beach date or mountain hike?', 'beach — easy', 'hike — earn the view'],
      ['Cinema date or picnic?', 'cinema classic', 'picnic — main character'],
      ['Morning texts or goodnight texts?', 'good morning ☀️', 'goodnight 🌙'],
      ['Calls or voice notes?', 'call me', 'voice notes only'],
      ['Tall or funny?', 'tall', 'funny — laughter lasts'],
      ['Cute smile or nice eyes?', 'the smile', 'the eyes'],
      ['Handwritten note or 3am paragraph?', 'handwritten note', 'the 3am paragraph'],
      ['Slow burn or instant spark?', 'slow burn', 'instant spark'],
      ['Public proposal or private?', 'flash-mob energy', 'private and perfect'],
      ['Meet the friends or the family first?', 'friends first', 'straight to the family'],
      ['Adventure partner or homebody?', 'adventure buddy', 'homebody heart'],
      ['Love letters or love songs?', 'letters', 'songs'],
      ['Their playlist or yours?', 'theirs — learn them', 'mine — educate them'],
      ['Breakfast in bed or midnight snack run?', 'breakfast in bed', '2am snack mission'],
      ['Bad dancing together or bad singing together?', 'bad dancing', 'bad duets'],
    ] },
    { kind: 'poll', pool: [
      ['Forehead kiss or hand hold?', 'forehead kiss', 'hand hold'],
      ['Flirty texts all day or one long night call?', 'texts all day', 'the night call'],
      ['A little jealous or never jealous?', 'a little is cute', 'zero jealousy'],
      ['Date your best friend or a total stranger?', 'the best friend', 'the stranger'],
      ['Kiss on date one or wait?', 'date one — carpe diem', 'wait — build it'],
      ['Matching tattoos or matching pets?', 'matching ink', 'matching pets'],
      ['They steal your hoodie or you steal theirs?', 'they take mine', 'I’m taking theirs'],
      ['Big spoon or little spoon?', 'big spoon', 'little spoon'],
      ['PDA or private affection?', 'PDA — announce it', 'private — ours only'],
      ['Love at first sight or grow into it?', 'first sight', 'grows like a plot twist'],
      ['Sunset date or sunrise date?', 'sunset', 'sunrise — unhinged but romantic'],
      ['The whisper or the eye contact?', 'the whisper', 'the eye contact'],
      ['Caught feelings: tell them or suffer?', 'tell them immediately', 'suffer beautifully'],
    ] },
  ]},
  // Mind Reader — guess facts about the other face, then they confess.
  { name: 'Mind Reader', icon: '🔮', hint: 'call it · they confess · crown the psychic', vibe: 'spark', duo: true, beats: [
    { kind: 'thumbs', pool: [
      ['They’ve cried at a Disney film — 👍 or 👎, then they confess'],
      ['They’ve been in a real food fight — call it'],
      ['They sing full concerts in the shower — call it'],
      ['They’ve broken a bone doing something stupid — call it'],
      ['They talk to themselves in the mirror — call it'],
      ['They’ve won a trophy for SOMETHING — call it'],
      ['They’ve been on TV — call it'],
      ['They cook better than they’re letting on — call it'],
      ['They’ve hidden crying at work or school — call it'],
      ['They’ve eaten something off the floor this week — call it'],
      ['They know every word of a guilty-pleasure song — call it'],
      ['They’ve faked sick to skip something big — call it'],
      ['They have a playlist specifically for crying — call it'],
      ['They’ve laughed hard enough to fall over — call it'],
      ['They’ve been kicked out of somewhere — call it'],
      ['They’d lose a fight with a seagull — call it'],
      ['They fake-laugh at their boss’s jokes — call it'],
      ['They have 3,000+ photos of themselves — call it'],
      ['They’d survive zero days in the wild — call it'],
    ] },
    { kind: 'thumbs', pool: [
      ['They’ve had a holiday romance — 👍 or 👎, then they confess'],
      ['They’ve kissed someone within an hour of meeting — call it'],
      ['They’ve dated two people at once — call it'],
      ['They fall in love embarrassingly fast — call it'],
      ['They’ve practised kissing on their hand — call it'],
      ['They’ve sent a risky text and instantly regretted it — call it'],
      ['They’ve flirted their way out of trouble — call it'],
      ['They’ve had a crush on a friend’s ex — call it'],
      ['They’ve faked a hobby for a crush — call it'],
      ['They ALWAYS text first — call it'],
      ['They’ve rehearsed a flirty line in the mirror — call it'],
      ['They’ve been someone’s secret crush and never knew — call it'],
      ['They’d date someone their friends hate — call it'],
      ['They’ve ghosted someone nice for no reason — call it'],
      ['They believe in love at first sight — call it'],
      ['They’d answer their ex at 2am — call it'],
      ['They’ve cried over someone they never even dated — call it'],
      ['They’d say “I love you” first — call it'],
      ['They’ve kissed someone at midnight on New Year’s — call it'],
      ['They’re a jealous texter — call it'],
    ] },
    { kind: 'point', secs: 28, pool: [
      ['Who read minds better? Crown the psychic 🔮'],
      ['Who was hardest to read? Crown the mystery.'],
    ] },
  ]},
  // Kiss Marry Ghost — the classic, PG-flipped ("ghost" not "kill"), spoken.
  { name: 'Kiss Marry Ghost', icon: '💍', hint: 'three picks · zero mercy · out loud', vibe: 'spark', duo: true, beats: [
    { kind: 'point', secs: 38, pool: [
      ['Kiss, marry, ghost: your last three crushes. Out loud. GO'],
      ['Kiss, marry, ghost: Batman, Spider-Man, Superman'],
      ['Kiss, marry, ghost: your top 3 most-played artists'],
      ['Kiss, marry, ghost: coffee, pizza, chocolate — they’re people now'],
      ['Kiss, marry, ghost: the last 3 people who texted you 💀'],
      ['Kiss, marry, ghost: Monday, Friday, Sunday'],
      ['Kiss, marry, ghost: the gym, Netflix, the group chat'],
      ['Kiss, marry, ghost: your 3 favourite fictional characters'],
      ['Kiss, marry, ghost: beach holiday, city break, road trip'],
      ['Kiss, marry, ghost: texting, calling, voice notes'],
      ['Kiss, marry, ghost: pick any three celebrities yourself. GO'],
      ['Kiss, marry, ghost: breakfast, lunch, dinner'],
      ['Kiss, marry, ghost: your phone, your bed, your mirror'],
      ['Kiss, marry, ghost: summer, winter, autumn'],
    ] },
    { kind: 'point', secs: 38, pool: [
      ['Kiss, marry, ghost: your ex, your crush, your best friend 💀 explain yourself'],
      ['Kiss, marry, ghost: someone older, someone younger, someone your age'],
      ['Kiss, marry, ghost: the gym rat, the bookworm, the party animal'],
      ['Kiss, marry, ghost: great texter/bad kisser, bad texter/great kisser, aggressively average'],
      ['Kiss, marry, ghost: love letters, spontaneous trips, breakfast in bed'],
      ['Kiss, marry, ghost: the one that got away, the one that stayed, the one that never noticed'],
      ['Kiss, marry, ghost: rich and boring, broke and hilarious, mysterious and unavailable'],
      ['Kiss, marry, ghost: your celebrity crush at 20, at 40, at 60'],
      ['Kiss, marry, ghost: morning person, night owl, permanently nocturnal gremlin'],
      ['Kiss, marry, ghost: the DJ, the chef, the poet'],
    ] },
    { kind: 'point', secs: 28, pool: [
      ['Whose answers were most unhinged? Crown them 👑'],
      ['Who ghosted someone they shouldn’t have? Crown the coward 👑'],
    ] },
  ]},
  // Dare Machine — the physical/silly wing: the camera IS the arena.
  { name: 'Dare Machine', icon: '🎲', hint: 'hold it · perform it · crown it', vibe: 'wild', duo: true, beats: [
    { kind: 'freeze', secs: 26, pool: [
      ['Plank until the timer ends. On camera. GO'],
      ['Arms straight out. Don’t you dare drop them. HOLD'],
      ['Balance on one leg, eyes closed. HOLD IT'],
      ['Air chair. No wall. Sit on nothing. HOLD'],
      ['Superhero landing pose. Commit. FREEZE'],
      ['T-rex arms for the whole round. Live like this.'],
      ['The Thinker pose. Look genuinely wise. FREEZE'],
      ['Ballerina pose. Point EVERYTHING. HOLD'],
      ['Museum statue. You are art now. HOLD'],
      ['Flamingo mode: one leg, chin up, majestic. HOLD'],
    ] },
    { kind: 'point', secs: 38, pool: [
      ['Dance battle: 15 seconds, no music, full send'],
      ['Air guitar solo. This is Wembley. GO'],
      ['Invisible skipping rope. Double-unders. NOW'],
      ['Run on the spot like you’re late for a flight'],
      ['Slow-motion sports celebration. Full drama.'],
      ['Conduct an invisible orchestra. The finale. GO'],
      ['Shadow-box the air like it owes you money'],
      ['Invisible basketball: dribble, spin, dunk. Commentate it.'],
      ['Robot dance. Minimum 10 seconds. Beep as needed.'],
      ['Cheerleader routine for the other person. Spell their name.'],
    ] },
    { kind: 'point', secs: 28, pool: [
      ['Crown the performance of the night 🏆'],
      ['Who suffered most beautifully? Crown them 🏆'],
    ] },
  ]},
  // Most Likely To — the group judgement giant, three escalating rounds.
  { name: 'Most Likely To', icon: '👉', hint: 'point on 3 · majority rules · no mercy', vibe: 'wild', duo: false, beats: [
    { kind: 'point', secs: 28, pool: [
      ['Most likely to trip over absolutely nothing'],
      ['Most likely to eat the last slice without asking'],
      ['Most likely to get lost WITH the GPS on'],
      ['Most likely to argue with a self-checkout machine'],
      ['Most likely to fall asleep in the cinema'],
      ['Most likely to forget their own birthday'],
      ['Most likely to become a meme by accident'],
      ['Most likely to cry at an advert'],
      ['Most likely to get famous on TikTok without trying'],
      ['Most likely to adopt five cats this year'],
      ['Most likely to walk into a glass door today'],
      ['Most likely to laugh at their own joke first'],
      ['Most likely to reply “lol” to terrible news'],
      ['Most likely to get scammed by an obvious scam'],
      ['Most likely to join a cult by accident'],
      ['Most likely to sleep through ten alarms'],
      ['Most likely to eat dessert first'],
      ['Most likely to ghost the group chat for a week'],
      ['Most likely to be late to their own wedding'],
      ['Most likely to google themselves weekly'],
      ['Most likely to lose a fight with a seagull over chips'],
    ] },
    { kind: 'point', secs: 28, pool: [
      ['Most likely to text their ex tonight'],
      ['Most likely to have a secret admirer RIGHT NOW'],
      ['Most likely to fall in love on this app'],
      ['Most likely to date two people at once'],
      ['Most likely to kiss a stranger tonight'],
      ['Most likely to have the wildest DMs'],
      ['Most likely to flirt with the waiter'],
      ['Most likely to catch feelings within a week'],
      ['Most likely to write poetry about a crush'],
      ['Most likely to stalk a crush’s profile for three hours'],
      ['Most likely to get a celebrity to answer their DM'],
      ['Most likely to break hearts without even noticing'],
      ['Most likely to get proposed to in public'],
      ['Most likely to elope in Vegas'],
      ['Most likely to be in a situationship right now'],
      ['Most likely to blush first'],
      ['Most likely to be someone’s secret crush HERE 👀'],
      ['Most likely to have a 10-page ick list'],
    ] },
    { kind: 'point', secs: 28, pool: [
      ['Most likely to get arrested for something hilarious'],
      ['Most likely to start a bar fight by accident'],
      ['Most likely to wake up in another country'],
      ['Most likely to spend rent money on concert tickets'],
      ['Most likely to become a millionaire then lose it all'],
      ['Most likely to get banned from a casino'],
      ['Most likely to road-trip with no destination'],
      ['Most likely to quit their job in one dramatic exit'],
      ['Most likely to crash a wedding'],
      ['Most likely to win a hot-dog eating contest'],
      ['Most likely to get a tattoo they regret by morning'],
      ['Most likely to tell a celebrity they don’t know who they are'],
      ['Most likely to survive an apocalypse out of pure spite'],
      ['Most likely to fake their own disappearance'],
    ] },
  ]},
];

export const seqByName = (name: string) => SEQ_PACK.find((s) => s.name === name);
