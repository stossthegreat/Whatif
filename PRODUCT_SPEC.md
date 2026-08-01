# WhatIf — Product & Design Spec

> **Press one button. Seconds later you're live with people you've never met.
> You never know who, how many, or what happens next.**

A **live social platform**, not a party game. This document defines the
interaction model, the addiction & fun engine (research-backed), the design
system, and the screen-by-screen UX. High-fidelity screens come *after* this.

**Locked direction:** live **video** (real faces) · **18+**, age-assured · **pure
stranger discovery** (every drop is new people; see §3.7 for the one addition).

---

## 1. Thesis

WhatIf compresses the entire arc of meeting someone — the anticipation, the
awkward hello, the laugh, the moment you'll retell — into a loop you start with
**one tap** and re-roll forever.

- Not a room, a lobby, a scheduled event, or a game you "join."
- The games are **icebreakers only** (30–90s). The product is *people*.
- The interface's only job is to **disappear** so human moments feel beautiful.
- The feeling on open is not *"what should I do?"* — it's ***"what the hell is
  about to happen?"***

It resembles Monkey / Azar / Omegle by *loop* — and the entire craft is being the
version of that idea **Apple would ship**: safe, premium, and alive instead of
sketchy, cheap, and static. **That gap is the product.**

---

## 2. The core loop

```
   OPEN ──► [ PLAY ] ──► held breath (~1.5s) ──► YOU'RE LIVE with N strangers
                             (a reveal,             (N unknown: 1,2,4,6,8…)
                              not a spinner)                │
                                                           │ a game is already running
                                                           ▼
        ┌──────────────── every 30–90s the world CHANGES on its own ───────────┐
        │  new face drops in · someone leaves · group shrinks to 1:1 or grows   │
        │  · the game flips · a twist fires · a sudden vote                      │
        └──────────────────────────────────────────────────────────────────────┘
                                                           │
                              the current carries you until you NEXT or LEAVE
```

**The fluid cell.** Monkey is *skip → new stranger → skip* (1:1, discrete).
Jackbox is one fixed room. **WhatIf is neither** — you're dropped into a **living
cell that continuously recomposes**, membership and activity morphing every beat.
The next comes to *you*. The app is a **conductor** deciding group size, games,
twists, tempo. The user has three verbs: **PLAY · NEXT · LEAVE** — and one always
available: **Report/Block on every face**.

---

## 3. The Addiction & Fun Engine

*Everything here is research-backed (full citations in `/docs/research/`). This
is the heart of the product — the reason it grabs and won't let go.*

### 3.1 The core truth: anticipation is the drug

Dopamine is a **prediction/anticipation** signal, not a pleasure signal. It fires
hardest *before* an **unpredictable** reward and **ramps to a maximum at ~50/50
uncertainty** — then flattens to zero the instant a reward becomes predictable.

**Consequence that reorganizes the whole product:** the addictive surface is not
the stranger — it's the **~1.5 seconds before the stranger appears.** In a study
of **1.7M random-video sessions, 80% lasted under 5 seconds** — people weren't
bingeing on conversations, they were bingeing on **the re-roll**. The *search* is
the drug.

> **Design law: protect the held breath above everything. Design the 1.5s, not
> the person.**

### 3.2 The WhatIf compulsion loop

Each step names the specific dopamine lever it pulls.

| # | Step | What happens | Lever |
|---|---|---|---|
| ① | **Trigger** | One button. Or an *honest* notification ("someone you vibed with is on now"). Zero lobby. | Conditioned cue fires dopamine *before* anything happens. |
| ② | **Anticipation** (300–800ms) | The cell composes: a reveal countdown, silhouettes appearing, "how many?" unknown. **The single most important surface.** | Sustained anticipatory ramp, maximal at max uncertainty. |
| ③ | **The drop** | Instant live cell with a game *already running* — no dead air (the Omegle-killer). Aha must land <30s. | Prediction-error spike, proportional to how good/surprising it is. |
| ④ | **Variable payoff** | The humans. ~1 in 3–4 cells is genuinely great; the rest neutral or "almost." | Variable-ratio reinforcement — the most extinction-resistant schedule known. |
| ⑤ | **Re-roll / recompose** | Every 30–90s, **involuntary and unpredictably timed** — so there's no "this one" to finish and quit on. Exit always one honest tap away. | Removes the *stopping cue* (infinite scroll, for live humans) + re-fires ②. |
| ⑥ | **Investment** | Each great cell offers a low-friction way to store value (save a person, teach the matcher your vibe). | Sunk value → session #2 beats #1. The anti-churn spine (§3.7). |

**The near-miss.** When a cell recomposes *just* as it was getting good, that
"almost" recruits the same win-circuitry as a real win and *increases* the pull to
continue. Surface a subtle, honest **"cut short? → reconnect"** — turn the loss
into fuel, never frustration.

### 3.3 The Grab — the first 8 seconds (PLAY → first live face)

The window is <3s (TikTok decides distribution at ~1.5s; 3-second retention drives
~2.2× downstream engagement). Every unavoidable step (permission, age gate) is
**costumed as an anticipation beat**.

| Time | What the user feels | Sensory design |
|---|---|---|
| **0.0s** | *"I look good. I'm ready."* | Home opens **already alive**: a big, **mirrored, softly-lit** self-view + a pulsing PLAY. Never a menu. Live "3.2k playing now." |
| **0.0s** | *Commitment.* | Press PLAY → deep, confident haptic *thunk*; button collapses inward. |
| **0.2s** | *"Something's coming."* | Self-view shrinks toward a "portal"; frame narrows/darkens; audio riser **begins**. |
| **0.2–1.4s** | *Held breath.* (peak dopamine) | A **reveal countdown** — filling ring, "connecting… 2… 1" — a finish line, **never a spinner**. Haptic ramp climbs. |
| **1.5s** | *The jolt.* "Someone is looking back at me." | The stranger **POPS in** — sharp cut, **no fade** — live motion + audio at frame one. Riser **resolves** on a chord; bright haptic snap. |
| **1.5–2s** | *Co-presence.* | Self-view shrinks to a small corner PiP; full attention on the other face (eyes near center). |
| **2–6s** | *"A real human, right now."* | Chrome disappears — faces only. First double-take / laugh. |
| **6s+** | *"Who's next?"* | **NEXT** is a satisfying physical *throw* (not a panic tap) whose momentum carries straight into the next countdown → back to 0.2s. |

**Two-phase self-view** (high-leverage): *before* live — big, **mirrored**,
auto-flattered (soft key light, warm grade, gentle smoothing) so the first thing
you see is "oh, I look good" (kills the #1 fear of going live). *Live* — shrink it
away so you watch *them*, not yourself (self-surveillance is what makes camera
anxiety and Zoom-fatigue).

### 3.4 Triple-random composition

WhatIf randomizes **three independent variables at once**, re-rolled every
recompose — where TikTok randomizes one (content). Compound uncertainty makes
prediction *impossible*, so the anticipation ramp stays pinned near maximum and
novelty decays far slower.

- **WHO** you get (the FYP-for-humans variable).
- **HOW MANY** — cell size is a live loot-box: a duo? a chaotic 6? Unknown until
  the reveal.
- **WHAT GAME / TWIST** the conductor drops.

### 3.5 The game engine (the fun)

Games exist to **guarantee the <30s aha and kill dead air** — not to be the point.
The unfair advantage: **on live video, laughter is involuntary and contagious** —
one genuine crack infects the whole grid (facial mimicry → emotional contagion).
So every game **points cameras at faces under pressure**, never at text.

**Three reusable loop skeletons** (rotate the *type*, not just the prompt, so the
rhythm never goes samey):
1. **Submit → Reveal → React** — private input, simultaneous public reveal (the workhorse).
2. **Simultaneous Action → Verdict** — everyone acts at once; the grid renders a live verdict (fastest, most video-native).
3. **Pattern → Break** — rhythm/standoff; the break is the joke (zero content needed).

**The 6 rules of a WhatIf game:** ① one sentence to play · ② point the camera at
faces, not text · ③ everyone risks at once (reciprocal vulnerability — no one
cornered alone) · ④ build one peak, then get out (setup → anticipation →
simultaneous reveal → hand-off; cut it the instant the laugh lands) · ⑤ **no
losers, only champions** (the one who cracked first is celebrated; spice lives in
the *content*, never in humiliating a person) · ⑥ thin frame, fat deck (each game
is a template + a versioned prompt pool; the recomposing group is procedural
content, so it never feels the same twice).

**The launch portfolio (18 games):**

| Skeleton | Games |
|---|---|
| **Simultaneous → Verdict** | **Point Party** (spicy prompt → everyone points at once), **Most Likely To** (+ 5s defense), **Freeze Face** (hold an expression, last to crack wins), **Reaction Roulette** (word flashes → last to react loses), **Hot Take Poll** (either/or → minority defends), **Confession Cam** (Never-Have-I-Ever, thumbs on 3) |
| **Submit → Reveal → React** | **Blank Detonation** (CAH-style fill-in), **Two Truths — Face Read** (guess the lie by their face), **Same Brain** (match answers, no losers), **Guess My Face** (secret emotion, act it silently) |
| **Pattern → Break** | **Don't Laugh Club** (a chosen jester vs the grid's straight faces), **Zap** (Zip-Zap-Zop reflex chain), **Mirror Master** (mirror the leader; desyncs are comedy) |
| **Performance (opt-in)** | **Accent Chaos**, **Dramatic Reading** (read a shampoo label like a tragedy), **Yes-And Story**, **Charades Blitz**, **Vibe Check** (one secret weird instruction; spot the impostor) |

Each ships as a template + a spice-tagged, group-size-tagged, versioned prompt
deck (weekly seasonal packs). One "Most Likely To" engine + 500 prompts = 500
games; a fresh cast every recompose refreshes even repeats.

### 3.6 The Liveness Director — never an empty room

The existential risk of any live app: PLAY returns "nobody." **The user must never
see the empty room.** A matching layer cascades, in order of preference:

`exact-filter 1:1 → relaxed filter → widened geo → small group cell (3–5 faces, forgiving of thin supply) → "warming up… 12s" countdown (anticipation, not failure)`

Plus: **concentrate supply into prime-time appointment windows** (density beats
headcount — 15 active people feel alive where 200 silent ones don't), a **warm
pool** (users idle in an alive self-view lobby, already "in the pool" before they
press), and honest **social proof at the door** ("busiest at 9pm").

### 3.7 Anti-churn: the memory layer *(recommendation)*

**The one honest tension with "pure roulette":** novelty is a decaying asset, and
**"no memory" is exactly what killed Omegle and Houseparty.** Every dead
random-video app lacked a way to *run into someone again*.

**Recommendation (keeps roulette intact):** the core loop stays 100% pure — every
drop is new strangers, you never *pick* your next match. But add:
1. **Opt-in reconnect** — you can *save* someone great; they become findable when
   they're live again. A stranger is novelty; a maybe-recurring stranger is a
   relationship-in-progress — the single biggest day-7 retention lever.
2. **Vibe-learning matcher** — quietly raise hit-rate across sessions (FYP for
   humans) while *preserving* the 50/50 uncertainty. Keep the unpredictability,
   climb the quality; session #2 measurably better than #1.
3. **Honest appointment spikes** — occasional scheduled/surprise mass events
   ("something happens at 9pm, no one knows what") layered *on top of* the always-on
   loop — never the only draw (HQ Trivia's fatal mistake).

> Founder call needed: ship the opt-in reconnect (recommended), or stay 100% pure
> roulette? I'd ship it — it's the difference between a novelty spike and a
> platform.

### 3.8 Ethical guardrails (non-negotiable, written into the product)

- **North-star metric = great human moments per session, NOT minutes-on-app.** If
  engagement rises while satisfaction falls (the "compulsion without enjoyment"
  signature), the mechanic is a trap — kill it.
- **Moderation & matching quality ARE the retention engine, not overhead.**
  Chatroulette and Omegle died from low signal-to-noise and safety liability, not
  boredom. The day the median re-roll becomes "another creep," the retention curve
  dies. The app-conducted group cell is the structural defense (witnesses, scripts,
  app-controlled frame).
- **Refuse (prohibited by design):** fake presence/scarcity ("5 people are
  waiting!" when they're not) · guilt-trip / sad-owl loss framing · streaks that
  punish absence · asymmetric friction (frictionless *continue*, hidden *exit*) ·
  any compulsion-without-enjoyment mechanic. These cross from addictive into evil —
  and, for a live 18+ product, into the legal exposure that actually killed Omegle.

---

## 4. Trust architecture (engineering baseline)

An 18+ live-video stranger product only exists if this is load-bearing from frame
one, and designed to feel **premium**, not bureaucratic:

- **Age assurance at the door** (privacy-preserving estimation, not ID hoarding),
  costumed as the "getting camera-ready" beat (§3.3).
- **Real-time + AI moderation** on live video; instant auto-cut on violations.
- **One-gesture Report/Block on every face, always** — a calm, powerful control,
  instant and silent.
- **Group-default dilutes risk** — most draws are multi-person (witnesses); 1:1 is
  a *sometimes*, inheriting the same one-tap safety.
- **A public "what we won't do."** Trust is the brand, and it *is* the retention
  engine (§3.8).

---

## 5. Design system — "Black glass"

North star: **Apple / Arc / Linear / Nothing / Vision Pro.** The UI is a sheet of
black glass the people glow through. Not Dribbble, not gaming UI, not neon, not
"fun because colours." Fun comes from *interactions*. Nearly monochrome so the
**faces are the only real color on screen.**

### Color
| Token | Value | Use |
|---|---|---|
| `--black` | `#000000` | the ground (true black — OLED, faces pop) |
| `--charcoal` | `#0A0B0D` | raised surfaces |
| `--charcoal-2` | `#141619` | cards, sheets |
| `--glass` | `rgba(255,255,255,.06)` + heavy blur | panels, controls |
| `--specular` | `rgba(255,255,255,.5)` hairline | the "gloss" edge that catches light |
| `--text` | `#FFFFFF` / `rgba(255,255,255,.6)` | huge headlines / secondary |
| `--live` | `#FF453A` (used at <5%) | the "you are live" signal ONLY |
| `--signal` | a single cool white-blue glow | interactive light, focus, "matched" |

**Color is light, not hue.** The accent is *luminosity* — glass catching a soft
white-blue glow — with one semantic red reserved for the live signal. No purple.
No gradients-as-decoration. The faces bring the color.

### Type
One clean grotesque (SF Pro / system — premium, zero assets). **Huge scale
contrast**: a 64–96px headline in a field of black; secondary text small and quiet;
nothing in between competes. Tabular numerals for the live count, timers, votes.
Massive whitespace — one idea per screen.

### Materials, motion, sound
- **Glass** with a real **specular hairline** (the gloss); **liquid lighting**
  that pools behind the active element; depth from blur/shadow/reflection, never
  color. Faces **edge-lit on black**.
- **Motion — silence first.** The app is mostly still. Motion fires **only at
  emotional beats**: a join = one pulse of light; a win = a contained particle
  bloom; an elimination = one sharp camera-shake + darken; a reveal = one crisp
  flip. Springs for anything the finger touches. Never childish, never constant.
- **Sound & haptics** — an expensive "matched" tone; the **riser-that-resolves**
  on connect (§3.3); haptics punctuate beats (soft tick on match, firm on
  lock/vote, crisp burst on a win). Precise, never buzzy.

---

## 6. Screen-by-screen UX

Every screen states its purpose in one glance. Faces are the content; chrome is a
whisper.

### 0 · First run (≤ 60s to first live face)
Open on a **value moment, not a form**: a beautiful mirrored self-view already
running + one glowing PLAY. Tap PLAY → camera/mic permission fires **at the moment
of intent** ("to meet someone, WhatIf needs to see you"). 18+ age assurance runs
**inside** the flattering "getting ready" self-view, so the legal gate *is* the
anticipation beat. Defer everything else — no username/bio before the first
electric reveal. **The first match is rigged** to a warm, high-quality partner so
the aha is guaranteed.

### 1 · Home — the PLAY screen
Near-empty black, **already alive**: your mirrored, softly-lit self-view breathing,
one **enormous PLAY** pulsing, and tiny/quiet `live now · 42,318` (tabular). No
feed, no nav, no rooms. The whole screen is a dare. A soft white-blue glow pools
under PLAY and tracks the finger.

### 2 · Finding (≈1–2s) — the held breath
**Not a spinner — a reveal countdown.** Self-view narrows toward a portal, a ring
fills to a finish line ("connecting… 2… 1"), an audio riser and haptic ramp climb
together. This 1.5s is the most important surface in the product (§3.1). It must
read as *"something's coming,"* never *"something's wrong."*

### 3 · The Live canvas *(the core)*
The stranger **pops in hard** (no fade), live + audio at frame one, eyes near
center. Your self-view shrinks to a small corner PiP. The **layout reflows to N**
without ever feeling like a grid app: 1:1 = two intimate panes; 2–3 = a considered
arrangement; 4–8 = edge-lit tiles that breathe. **Join** = a tile arrives on a
pulse of light; **leave** = the layout re-settles on a soft spring. Always
recomposing. Chrome: a tiny `LIVE` dot, NEXT and LEAVE at the edges, and an
invisible long-press → **Report/Block** on every face.

### 4 · Icebreaker overlay
A single line of huge type slides up over the faces (the prompt) with a slim timer
ring. Inputs are momentary (point, tap, shout, a 1–10 dial). Then it **dissolves**.
It never takes over — the faces stay the star.

### 5 · The beats (motion reserved for these)
Vote (tiles selectable) · Reveal (results flip in unison) · Win (contained bloom +
warm haptic) · Eliminate (one camera-shake, tile darkens & exits) · Twist (one card
cuts in — "a stranger just walked in" — then gone) · Celebrate (brief, shared, then
the next beat). Never lingers.

### 6 · Controls (gesture-first)
**NEXT** — a momentum-carrying *throw* that flows into the next countdown (the
reload lever — make it feel *great*). **LEAVE** — one gesture, always available,
honest. **React** — a small tasteful light-based reaction rail (not emoji spam).
**Report/Block** — long-press any face → a calm, powerful, instant sheet.

### 7 · No dead ends
There is **no empty state** (§3.6). Thin supply degrades gracefully into a warmer
small cell or a "warming up… 12s" countdown — never a spinner, never "no one's
here." The current never stops.

### 8 · Minimal profile + the memory layer
Barely a profile: a verified 18+ badge, a first name, and your **saved people**
(opt-in reconnect, §3.7) — who you can see are live now. No feed, no followers, no
vanity metrics.

### 9 · Edge states (designed, premium)
Reconnecting = the canvas holds and dims with a quiet reassurance, recovers without
dumping you. Camera-off, poor-connection, "you were reported" — all calm,
first-class, on-brand. Nothing generic ever shows.

---

## 7. Monetization (premium, never dark)
Priority matching / skip-the-line · **taste filters** (region, language, vibe) as a
paid nicety framed as "who you're in the mood to meet," never a transactional
gender toggle · **signature light** (tasteful luminous framing for your own video,
light not stickers) · super-reactions & generous "NEXT+". No loot boxes, no
pay-to-harass, no guilt, no selling reach over other humans.

---

## 8. Why it's a new category
- **Instant** like Monkey, but **group-fluid** and **conductor-driven** — alive,
  not 1:1 skip.
- **Premium** like Apple, where every rival is cheap and sketchy — the interface
  disappears, the people become the content.
- **Unpredictable on three axes at once** (who × how many × what game) — so every
  open is *"what the hell is about to happen?"*

That combination doesn't exist yet. That's the opening.

---

## 9. Build order
1. **This spec, agreed.** ← we are here
2. High-fidelity, interactive **key screens**, in priority order:
   **Home (PLAY, already alive)** → **Finding (the reveal countdown)** → **the Live
   canvas (1:1 and group, with a running game + a reveal beat)**. Black-glass
   system, real motion, engineered around §3.
3. Then: first-run/onboarding, the game deck, safety flows, the memory layer,
   edge states.
4. Then: real-time / WebRTC video / moderation / matching architecture.

> The earlier `lib/` Flutter build and `docs/preview.html` are the retired
> party-game exploration — kept in history, not reflective of this direction. New
> screens are built fresh against this spec.
