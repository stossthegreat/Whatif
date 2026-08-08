// The rotating game pack — server-authoritative so every client in a cell gets
// the same game + prompt. Mirrors the Flutter client's kinds. Prompts are deep
// and the matchmaker avoids repeating the last kind, so cells never feel samey.

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

export const PACK: GameDef[] = [
  // Most Likely To — real prompts from published "most likely to" lists,
  // roast-y and wholesome interleaved so the room never stays on one note.
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
    ] },
  { kind: 'poll', name: 'Hot Take', vibe: 'warm', hint: 'pick a side',
    minStrangers: 1, maxStrangers: 8, prompts: [
      ['Pineapple on pizza?', 'crime', 'genius'], ['Socks in bed?', 'yes', 'never'],
      ['Text or call?', 'text', 'call'], ['Cereal then milk?', 'right', 'chaos'],
      ['Front camera or back?', 'front', 'back'], ['TP over or under?', 'over', 'under'],
      ['Beach or mountains?', 'beach', 'mountains'], ['Morning person?', 'yes', 'absolutely not'],
      ['Cats or dogs?', 'cats', 'dogs'], ['Is a hotdog a sandwich?', 'yes', 'how dare you'],
    ] },
  // Never Have I Ever — real prompts from published NHIE lists, tiered clean
  // → funny → spicy. Session position gates which tier surfaces first
  // (rollSession's warm/wild/spark arc naturally does this): round 1 never
  // opens on the spicy end.
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
      // spicy
      ['Never have I ever kissed someone whose name I never knew'], ['Never have I ever had a one-night stand'],
      ['Never have I ever used a dating app'], ['Never have I ever ghosted someone I was dating'],
      ['Never have I ever lied to get out of a date'], ['Never have I ever gone through a partner’s phone'],
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
      // thought-provoking
      ['Say every thought out loud, or…', 'say everything', 'never speak again'],
      ['Be a legendary storyteller from embarrassing moments, or…', 'great stories', 'never embarrass yourself'],
      ['Be the star player on a losing team, or…', 'star, losing team', 'bench, championship team'],
      ['Know all the mysteries of the universe but lose your memories, or…', 'cosmic secrets', 'keep your memories'],
      // spicy
      ['Be talked dirty to in person, or…', 'in person', 'over text'],
      ['Wake up next to a stranger, or…', 'a stranger', 'a room of everyone you’ve dated'],
      ['Watch your partner flirt with someone you don’t know, or…', 'flirt, stranger', 'flirt, someone you know'],
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
      ['Texts back “k” when they’re mad instead of saying why', 'green flag', 'red flag'],
      ['Sends full sentences instead of just “k”', 'green flag', 'red flag'],
      ['Says “I feel…” instead of assuming what you’re thinking', 'green flag', 'red flag'],
      ['Double-texts without shame', 'green flag', 'red flag'],
      ['Says “you always…” or “you never…” mid-argument', 'green flag', 'red flag'],
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
    { kind: 'freeze', secs: 11, pool: [
      ['Gurning: UGLIEST face contest. 3…2…1 GO'],
      ['Fish face 🐟 — but make it seductive. HOLD IT'],
      ['Double chin championship. Every chin you own. Commit.'],
      ['Your face when the text says “we need to talk”. HOLD IT'],
    ] },
    { kind: 'freeze', secs: 11, pool: [
      ['Villain smirk — you just stole their fries. Freeze.'],
      ['The face you make reading your own texts from 3am. HOLD'],
      ['Your “I just saw my ex thriving” face. HOLD IT'],
      ['Sexy stare and fish lips AT THE SAME TIME. Do not laugh.'],
    ] },
    { kind: 'point', secs: 13, pool: [['Crown the funniest face 👑']] },
  ]},
  { name: 'Eye Contact', icon: '👀', hint: 'hold it · smile · don’t crack', vibe: 'spark', duo: true, beats: [
    { kind: 'freeze', secs: 11, pool: [
      ['Dead-eye contact. No laughing. The first blink is a confession.'],
      ['Stare into their soul. Whoever laughs first loses.'],
    ] },
    { kind: 'freeze', secs: 11, pool: [
      ['Now a SLOW smile. Do not crack.'],
      ['Now wink like a movie star. Hold it.'],
      ['Mouth “I know your secret” in total silence. HOLD.'],
    ] },
    { kind: 'point', secs: 13, pool: [['Who broke first?']] },
  ]},
  { name: 'Hot Takes', icon: '🔥', hint: 'three takes · pick sides · argue', vibe: 'warm', duo: true, beats: [
    { kind: 'poll', pool: [
      ['Pineapple on pizza?', 'elite — fight me', 'a crime against Italy'],
      ['Cereal or milk first?', 'milk first, like a menace', 'cereal first, like a person'],
      ['Is a hotdog a sandwich?', 'legally, yes', 'take that back'],
      ['Toilet paper: over or under?', 'over — civilised', 'under — feral'],
      ['Night shower or morning shower?', 'night — superior being', 'morning — you sleep dirty??'],
    ] },
    { kind: 'poll', pool: [
      ['Voice notes over a minute long?', 'a love language', 'straight to jail'],
      ['Texting “lol” with a dead face?', 'we all do it', 'psychotic behaviour'],
      ['Gym at 6am?', 'built different', 'built LYING'],
      ['Splitting the bill on a first date?', 'fair is fair', 'the date is over'],
      ['Texting your ex at 2am?', 'human nature', 'throw the phone in the sea'],
    ] },
    { kind: 'poll', pool: [
      ['They clap when the plane lands', 'green flag — pure joy', 'red flag — arrest them'],
      ['They still follow all their exes', 'green — secure', 'red — runs an ex museum'],
      ['All their exes are “crazy”', 'green — just unlucky', 'red — THEY are the crazy ex'],
      ['They baby-talk their dog', 'green — marry them', 'red — the dog is embarrassed'],
      ['Phone permanently on Do Not Disturb', 'green — inner peace', 'red — hiding something'],
    ] },
  ]},
  // Perform-then-crown games need real time to breathe — Charades/Heads Up!
  // research converges on 60-90s as the sweet spot; the old flat ~23s
  // (secsFor's point default) cut people off before the funny part landed.
  { name: 'Storytime', icon: '🎤', hint: 'real stories · best one wins', vibe: 'wild', duo: false, beats: [
    { kind: 'point', secs: 40, pool: [
      ['Most embarrassing moment of your LIFE. Full story. GO'],
      ['Your most unhinged 3am decision — and why it made sense at the time'],
      ['The biggest public L you’ve ever taken. Spare NO detail'],
      ['The time you flirted and it went catastrophically wrong'],
    ] },
    { kind: 'point', secs: 40, pool: [
      ['Worst date you’ve ever been on. Build the scene.'],
      ['A lie you told that spiralled completely out of control'],
      ['The dumbest thing you fully believed as a kid'],
      ['A story that starts: “so security was NOT happy with me”'],
    ] },
  ]},
  { name: 'Rizz Off', icon: '😏', hint: 'best line · worst line · shoot your shot', vibe: 'spark', duo: false, beats: [
    { kind: 'point', secs: 22, pool: [
      ['Cheesiest pickup line you know. Full eye contact. GO'],
      ['“Are you a parking ticket? Because you’ve got FINE written all over you.” Now beat it.'],
    ] },
    { kind: 'point', secs: 22, pool: [
      ['WORST pickup line on purpose. Make it foul.'],
      ['A pickup line so bad it loops back around to smooth. GO'],
    ] },
    { kind: 'point', secs: 22, pool: [
      ['Shoot your shot at the camera like your crush is watching'],
      ['Flirt with the camera in a whisper. Fully commit 😳'],
    ] },
  ]},
  { name: 'Spin the Bottle', icon: '🍾', hint: 'the bottle picks · no escape', vibe: 'spark', duo: false, beats: [
    { kind: 'spin', pool: [
      ['{target} — what’s your actual type? Be brutally honest'],
      ['{target} — rate your own rizz out of 10. Now prove it.'],
      ['{target} — who in this room would you take on a date? 👀'],
      ['{target} — most scandalous first-date story. Spill.'],
    ] },
    { kind: 'spin', pool: [
      ['{target} — blow a kiss in extreme slow motion. Commit.'],
      ['{target} — describe your dream date in 10 seconds. GO'],
      ['{target} — say “hey you” to the camera like it’s 2am 😳'],
      ['{target} — your most romantic move ever. Details.'],
    ] },
  ]},
  { name: 'Confessions', icon: '🙊', hint: 'never have I ever · thumbs up = guilty', vibe: 'wild', duo: true, beats: [
    { kind: 'thumbs', pool: [
      ['Never have I ever ghosted someone mid-conversation'],
      ['Never have I ever texted the WRONG person something unforgivable'],
      ['Never have I ever stalked an ex online this week'],
      ['Never have I ever pretended to be busy to dodge plans'],
    ] },
    { kind: 'thumbs', pool: [
      ['Never have I ever pretended not to see someone I know in public'],
      ['Never have I ever flirted my way out of trouble'],
      ['Never have I ever lied about my age'],
      ['Never have I ever faked an entire personality on a first date'],
    ] },
    { kind: 'thumbs', pool: [
      ['Never have I ever kissed someone whose name I never knew'],
      ['Never have I ever had a one-night stand'],
      ['Never have I ever gone through a partner’s phone'],
      ['Never have I ever had a crush on a friend’s partner'],
    ] },
  ]},
  { name: 'Would You Rather', icon: '🤔', hint: 'three impossible choices', vibe: 'warm', duo: true, beats: [
    { kind: 'wouldRather', pool: [
      ['Fight 100 duck-sized horses, or…', '100 tiny horses', '1 giant duck'],
      ['Read minds, or…', 'read minds', 'be invisible'],
      ['Always hiccup when you talk, or…', 'hiccup talking', 'sneeze laughing'],
    ] },
    { kind: 'wouldRather', pool: [
      ['Your search history goes public, or…', 'search history public', 'texts read out loud'],
      ['Know how you die, or…', 'know when', 'know how'],
      ['Be famous, or…', 'famous', 'filthy rich'],
    ] },
    { kind: 'wouldRather', pool: [
      ['Date someone hotter than you, or…', 'hotter — live in fear', 'less hot — live in peace'],
      ['Be talked dirty to in person, or…', 'in person 😳', 'over text'],
      ['Always say what you think, or…', 'brutal honesty', 'never speak again'],
    ] },
  ]},
  { name: 'Impressions', icon: '🎭', hint: 'do it badly · funniest wins', vibe: 'wild', duo: false, beats: [
    { kind: 'point', secs: 35, pool: [
      ['Your worst BATMAN'],
      ['Your worst British accent'],
      ['Your worst influencer apology video'],
      ['Order a pizza like a movie VILLAIN 😈'],
    ] },
    { kind: 'point', secs: 35, pool: [
      ['Your GRANDMA describing your love life 👵'],
      ['A CEO on a podcast explaining why you’re single 💼'],
      ['A flight attendant calmly announcing the plane IS going down'],
      ['A BABY negotiating a business deal 👶'],
    ] },
    { kind: 'point', secs: 22, pool: [['Best EVIL LAUGH — commit or lose. Crown the winner']] },
  ]},
  { name: 'Roast Circle', icon: '💀', hint: 'roast · get roasted · make up', vibe: 'wild', duo: false, beats: [
    { kind: 'point', secs: 35, pool: [
      ['Roast the person on your left (with love)'],
      ['Roast this app to its face. Go.'],
      ['Roast each other’s camera angle. NOW.'],
    ] },
    { kind: 'point', secs: 35, pool: [
      ['Roast your OWN haircut before someone else does'],
      ['Roast your own dating history in one sentence'],
      ['Confess your pettiest move ever — pettiest wins'],
    ] },
    { kind: 'point', secs: 22, pool: [['Now the best COMPLIMENT — make someone blush to make up']] },
  ]},
];

export const seqByName = (name: string) => SEQ_PACK.find((s) => s.name === name);
