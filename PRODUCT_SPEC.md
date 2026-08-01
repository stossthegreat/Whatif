# WhatIf — Product & Design Spec

> **Press one button. Seconds later you're live with people you've never met.
> You never know who, how many, or what happens next.**

This document supersedes the earlier exploration. It defines a **live social
platform**, not a party game — the interaction model first, then the design
system, then the screen-by-screen UX. High-fidelity screens come *after* this is
agreed.

**Locked direction:** live **video** (real faces) · **18+**, age-assured · **pure
stranger discovery** (every session is new people).

---

## 1. Thesis

WhatIf is the "what happens next" machine. It compresses the entire arc of meeting
someone — the anticipation, the awkward hello, the laugh, the moment you'll retell
— into a loop you can start with **one tap** and re-roll forever.

- It is **not** a room, a lobby, a scheduled event, or a game you "join."
- The games exist **only to break the ice**. They last 30–90 seconds and then
  dissolve. The product is *people*.
- The interface's only job is to **disappear** so human moments feel beautiful.
- The feeling on open is not *"what should I do?"* — it's ***"what the hell is
  about to happen?"***

The competitor it most resembles by loop (instant random strangers) is Monkey /
Azar / Omegle — and the entire craft of this product is **being the version of
that idea Apple would ship**: safe, premium, and alive instead of sketchy, cheap,
and static. That gap *is* the product.

---

## 2. The core loop

```
        OPEN
          │
     ┌────▼────┐
     │  PLAY   │   one enormous button, nothing else
     └────┬────┘
          │  ~1–2s of held-breath anticipation (not a spinner)
     ┌────▼─────────────────────────┐
     │  YOU'RE LIVE                  │   dropped onto video with N strangers.
     │  (N is unknown: 1, 2, 4, 6…)  │   no preamble, no "waiting for players"
     └────┬─────────────────────────┘
          │  within ~2s an icebreaker appears (30–90s)
     ┌────▼────┐   laugh · react · quick vote · reveal · tiny celebration
     │  BEATS  │
     └────┬────┘
          │  every 30–90s the world CHANGES on its own:
          │   • a new face drops in      • someone leaves
          │   • the game flips            • the group shrinks to 1:1 or grows
          │   • a twist fires             • a sudden vote
          ▼
     the current carries you through ever-changing configurations of people
     and moments — until you SURFACE (leave) or NEXT (re-roll instantly).
```

### The single biggest idea: **the fluid cell**

Monkey is *skip → new stranger → skip* (1:1, discrete). Jackbox is *one fixed room
all night*. **WhatIf is neither.** You're dropped into a **living cell** that
**continuously recomposes** — membership and activity morph every beat. You don't
"leave a room to find the next"; the next comes to *you*. This is what makes it
feel **alive, not static** — and it's a genuinely new interaction model, not a
reskin of video roulette.

The user controls almost nothing. **The app is a conductor**, deciding the group
size, the games, the twists, the tempo. Unpredictability is the product, and
handing control to the app is what creates it.

### The three verbs the user actually has
1. **PLAY** — start / re-enter the current.
2. **NEXT** — eject the current configuration, get instantly re-rolled. (No dead
   air — never a spinner, never a lobby.)
3. **LEAVE** — surface out. Always one gesture away.

Everything else (reactions, votes, game inputs) is contextual and momentary.
**Report/Block is always a single gesture, on every face, at every moment.**

---

## 3. The unpredictability engine

The magic is manufactured, not random-for-its-own-sake. The conductor draws from:

**Group-size draw** — 1:1, 2, 3, 5, 8. Never announced in advance. Part of the
thrill is not knowing if this is an intimate 1:1 or a chaotic 8.

**Icebreaker deck** (30–90s, video-native, made for strangers, zero skill floor):
- *Point at…* ("…who's clearly the main character") — everyone points at once.
- *Try not to laugh* (video-native tension).
- *Two truths, instant.*
- *Finish the sentence* — first to shout it.
- *Rate the room* — anonymous 1–10, revealed together.
- *Hot seat, 60s.*
- *Caption this moment.*

**Twists** (the "what the hell" beats): a new face drops in · the room silently
shrinks to a 1:1 · one person is secretly the judge · sudden vote: who leaves ·
double-or-nothing · "10 seconds to make them laugh." Fired unpredictably.

**Tempo** — beats are short. The peak-end rule governs everything: engineer a
high, then hand off before it sags. When a cell goes flat, the conductor changes
it *before* the user gets bored — the user should never be the one to notice the
lull.

---

## 4. Trust architecture (engineering baseline, not a feature)

An 18+ live-video stranger product only exists if this is load-bearing from frame
one. Non-negotiable, built-in, and designed to feel *premium* rather than
bureaucratic:

- **Age assurance at the door** (privacy-preserving estimation, not ID hoarding).
- **Real-time + AI moderation** on live video; instant auto-cut on violations.
- **One-gesture Report/Block on every face, always** — surfaced as a calm,
  powerful control, not buried. Blocking is instant and silent.
- **Group-default dilutes risk** — most draws are multi-person (witnesses); 1:1 is
  a *sometimes*, and it inherits the same one-tap safety.
- **A public "what we won't do"** — no logging faces, no dark patterns, no
  pay-to-harass. Trust is the brand.

This section is short on purpose: it's a requirement, not a debate. It shapes the
UX (see §6) everywhere a face appears.

---

## 5. Design system — "Black glass"

The north star: **Apple / Arc / Linear / Nothing / Vision Pro.** The UI is a sheet
of black glass that the people glow through. Not Dribbble, not gaming UI, not
neon, not "fun because colours." Fun comes from the *interactions*. The interface
is nearly monochrome so the faces are the only real color on screen.

### Color
| Token | Value | Use |
|---|---|---|
| `--black` | `#000000` | the ground (true black — OLED, faces pop) |
| `--charcoal` | `#0A0B0D` | raised surfaces |
| `--charcoal-2` | `#141619` | cards, sheets |
| `--glass` | `rgba(255,255,255,.06)` + heavy blur | panels, controls |
| `--specular` | `rgba(255,255,255,.5)` hairline | the "gloss" edge that catches light |
| `--text` | `#FFFFFF` / `rgba(255,255,255,.6)` | huge headlines / secondary |
| `--live` | `#FF453A` (Apple system red, used at <5%) | the "you are live/recording" signal only |
| `--signal` | a single cool luminous white-blue glow | interactive light, focus, "matched" |

**Color is light, not hue.** The accent is *luminosity* — glass catching a soft
white-blue glow — with one semantic red reserved exclusively for the live signal.
No purple. No gradients-as-decoration. The faces bring the color.

### Typography
- **One clean grotesque** (SF Pro / system — premium, ships with zero assets).
- **Huge scale contrast**: a headline can be 64–96px, tight tracking, sitting in a
  field of black. Secondary text is small and quiet. Nothing in between competes.
- **Tabular numerals** for the live count, timers, votes.
- Massive whitespace — one idea per screen, everything breathes.

### Materials & light
- **Glass** with a real **specular hairline** on the top edge (the gloss).
- **Liquid lighting** — soft light that *pools* behind the active element and
  shifts slowly; depth comes from blur, shadow, and reflection, never from color.
- Faces are **edge-lit on black**, arranged like objects in space.

### Motion — silence first
> Animation is not decoration. It exists only to increase emotion, and silence is
> what makes it land.

- **The app is mostly still.** No ambient drift, no constant motion.
- Motion fires **only at emotional beats**: a join = a single soft pulse of light;
  a win = a contained particle bloom; an elimination = one sharp camera-shake and
  a darken; a reveal = one crisp card flip; voting-ends = cards flip in unison.
- **Springs** for anything the finger touches (tactile, interruptible).
- Everything else is a slow, expensive fade. Never childish. Never constant.

### Sound & haptics
- A short, expensive **"matched" tone**. Subtle spatial presence audio.
- **Haptics punctuate beats** — a soft tick on match, a firm one on a lock/vote, a
  crisp burst on a win. Precise, never buzzy.

---

## 6. Screen-by-screen UX

Every screen states its purpose in one glance. Faces are the content; chrome is a
whisper.

### 0 · First run (≤ 60 seconds)
Black. One line of huge type at a time, each a held beat:
*"Press one button."* → *"Meet someone new."* → *"You never know what happens."*
Then permissions **as a moment, not a form**: camera + mic requested with a single
elegant self-preview ("this is you — looking good"). Age assurance handled here,
framed as *"a room of real adults, verified."* No sign-up wall before the magic —
they should feel it fast.

### 1 · Home — the PLAY screen
Near-empty black. One **enormous PLAY** control, center. Above it, tiny and quiet:
`live now · 42,318` (tabular, faintly breathing). Nothing else — no feed, no nav,
no rooms. The whole screen is a dare. A soft white-blue glow pools under PLAY and
tracks the finger. This screen answers "what do I do?" before the question forms.

### 2 · Finding (≈1–2s)
Not a spinner. Your own camera fills the screen, edge-lit; the specular light
sweeps once; a soft tone; the count of "searching…" ticks. A held breath, then —

### 3 · The Live canvas *(the core)*
Faces on black. The **layout system reflows to N** without ever feeling like a
grid app:
- **1:1** — two large panes, intimate, generous black margin.
- **2–3** — a considered arrangement, not a spreadsheet.
- **4–8** — faces as edge-lit tiles that breathe and reflow as membership changes.
When someone **joins**, their tile *arrives* with a single pulse of light. When
someone **leaves**, the layout re-settles with a soft spring. The canvas is always
alive and always recomposing — that's the point.

**Chrome:** almost none. A tiny `LIVE` dot. Your NEXT and LEAVE gestures at the
edges. Every face carries an invisible long-press → **Report/Block**.

### 4 · Icebreaker overlay
A single line of huge type slides up from the bottom over the faces — the prompt —
with a slim timer ring. Inputs are momentary (point, tap, shout, a 1–10 dial).
Then it **dissolves**. It never takes over the screen; the faces stay the star.

### 5 · The beats (motion reserved for these)
- **Vote** — tiles get a subtle selectable state; you tap a face.
- **Reveal** — cards/results flip in unison, one crisp motion.
- **Win** — a contained particle bloom on the winner's tile + a warm haptic.
- **Eliminate** — one sharp camera-shake, their tile darkens and exits.
- **Twist** — a single card cuts in ("a stranger just walked in") then gone.
- **Celebrate** — brief, shared, then immediately the next beat. Never lingers.

### 6 · Controls (gesture-first, minimal)
- **NEXT** — swipe / edge button: instantly re-rolled into a new cell. No lobby.
- **LEAVE** — surface out, always available, one gesture.
- **React** — a small, tasteful reaction rail (not emoji spam) — light-based
  reactions that flash over your own tile.
- **Report/Block** — long-press any face → a calm, powerful sheet. Instant.

### 7 · No dead ends
There is **no empty state**. If matching is thin, you're dropped into a warmer,
smaller draw or a live "moment" already in progress — never a spinner, never
"no one's here." The current never stops.

### 8 · Minimal profile
Barely a profile. A verified 18+ badge, a first name, a light history of "moments"
you chose to keep. No feed, no followers, no vanity metrics. The product is the
live moment, not a profile to maintain.

### 9 · Edge states (designed, premium)
Reconnecting = the canvas holds, dims, and a quiet line reassures; it recovers
without dumping you. Camera-off, poor-connection, and "you were reported" all have
calm, first-class, on-brand treatments. Nothing generic ever shows.

---

## 7. Monetization (premium, never dark)
- **Priority matching** / skip-the-line.
- **Taste filters** (region, language, vibe) as a paid nicety — never a wall.
- **Signature light** — tasteful, luminous frame/lighting treatments for your own
  video (light, not cartoon stickers).
- **Super-reactions** and generous "NEXT+".
No loot boxes. No pay-to-harass. No guilt. No selling reach over other humans.

---

## 8. Why it's a new category
- **Instant** like Monkey, but **group-fluid** and **conductor-driven** instead of
  1:1 skip — alive, not static.
- **Premium** like Apple, where every rival is cheap and sketchy — the interface
  disappears and the people become the content.
- **Unpredictable** by design — the app, not the user, decides what happens next,
  so every open is *"what the hell is about to happen?"*

That combination doesn't exist yet. That's the opening.

---

## 9. What's next (build order)
1. **This spec, agreed.** ← we are here
2. High-fidelity, interactive **key screens**, in order of importance:
   **Home (PLAY)** → **Finding** → **The Live canvas (1:1, and group)** →
   **an icebreaker beat + a reveal/celebrate**. Black-glass system, real motion.
3. Then: onboarding, safety flows, profile, edge states.
4. Then: the real-time / video / moderation architecture.

> Note: the earlier `lib/` Flutter build and `docs/preview.html` are the retired
> party-game exploration. They stay in history but do not reflect this direction;
> the new screens will be built fresh against this spec.
