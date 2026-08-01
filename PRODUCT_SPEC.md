# WhatIf — Product Spec

> **What happens tonight?**
> A live multiplayer social *game*. Not a dating app. Not Omegle. Not a feed.
> The most fun place on the internet at 9pm.

This document is the companion to the Flutter app in `/lib`. It captures the
vision, the research that shaped it, the one strategic decision that reshaped the
founder's original idea, the design system, and a screen-by-screen breakdown of
what's built and what comes next.

---

## 0. The one-paragraph thesis

People don't open WhatIf to *meet someone*. They open it to find out **what's
happening tonight**. It's a live table where a rotating pack of short, silly,
role-asymmetric games gets thrown at a small group — and every round ends in a
**public reveal** that the whole room feels at once. Friendship and romance are
*byproducts* of laughing together, never the mechanic. The product is engineered
so that the fun is **with people, not at content** — which is the one thing
TikTok structurally cannot copy.

---

## 1. The strategic decision (challenging the brief)

The founding instinct was a **"spin the bottle"** core mechanic. The brief
explicitly asked us to challenge assumptions if the research supported a stronger
direction. **It does.** Spin-the-bottle should be *one item on the menu, never
the kitchen.* Three research-backed reasons:

1. **It's dating in a costume.** Spin-the-bottle's entire payload is "you two —
   pair off." That's a 1-on-1, romance-coded, "rate this face" frame. It inherits
   every problem that got **Monkey pulled from the App Store (2026)** and **Omegle
   shut down** — and its natural gravity is exactly the positioning we're trying to
   escape. (Azar's random-video loop was so dating-shaped that Match bought it *as a
   dating asset* for $1.725B.)
2. **It has an attractiveness skill-class.** Fall Guys and Jackbox win because
   chaos and comedy *flatten* the skill gap — the shy person gets a story too.
   Spin-the-bottle rewards the confident/attractive and creates a losing class who
   churn. Same failure mode as dating apps.
3. **The moment it produces is un-shareable.** A private awkward pairing is
   *cringe, not content* — and Gen Z's single strongest behavioral constraint is a
   fear of being perceived. Nobody screen-records that. Among Us's emergency
   meeting and Jackbox's public reveal generate *group* moments with a witnessable
   payoff. **The unit of virality is a screen-recordable group reveal.**

### The core loop we build instead

> **A short (sub-10-min), role-asymmetric group mini-game with a public reveal at
> the end** — Among Us's dramatic structure fused with Jackbox's private-input /
> public-reveal comedy — **served nightly on a "it's happening NOW" appointment
> notification** (Houseparty × BeReal × HQ Trivia), **wrapped in a persistent room
> the group drifts back into** (Discord), **protected by group-format + real-time
> moderation + age assurance** (Yubo).

Spin-the-bottle survives as **Truth Roulette** — a spicy, opt-in game mode where
the bottle points at a *dare for the whole table*, not a forced romantic pairing.
Flirty energy stays an emergent byproduct; it's never the reason the table exists.

---

## 2. What the research told us (condensed)

Three parallel research sweeps informed every decision. The load-bearing findings:

| Source | Lesson baked into WhatIf |
|---|---|
| **Houseparty** (died) | Presence + "your friends are in a game NOW" ping is the strongest cold-start weapon — but the activity must **renew nightly** or you become a pandemic novelty. |
| **Among Us** | Short, role-asymmetric, ends in a social reveal. The **emergency-meeting = the shareable moment.** This is our spine. |
| **Jackbox** | **Zero-friction join** (room codes / deep links) + **private input → public reveal** is a comedy generator that works even with strangers, because the content is the person, not their face. |
| **Fall Guys** | **Losing is funny.** Low skill floor + chaos democratizes — never let a "good at it" class win every night. |
| **BeReal** (plateaued) | The appointment/anticipation notification works — but a ping with **no fresh activity behind it decays into a chore.** Don't cap at once-a-day. |
| **Yubo** | Group live > 1-on-1. **Age-verify + real-time moderation is a growth feature, not a tax** — the difference between "App Store featured" and "pulled like Monkey." |
| **Discord** | The endgame isn't a game, it's *a place your people already are.* Game = acquisition loop; **persistent room = retention loop.** |
| **Hook model / variable reward** | Put the mystery on **"what's next"** (game/player), never on the wallet. Earn-first, disclosed-odds cosmetics. No paid loot boxes, ever. |
| **Peak-End rule** | Engineer a **guaranteed peak every session** and **never end on a dead lobby** — close on a highlight reel. |
| **Cringe paradox** | Make the **prompt** funny, never the person. Friend-group-first. This is the cringe shield. |
| **Ethics** | No random 1-on-1 stranger video, ever. Report/block as trust signals. Humane streaks — reward the return, never shame the absence. |

### The 10 product principles

1. Time-to-first-laugh **< 60 seconds**. The first round *is* the tutorial.
2. Optimize for laughter **with**, not **at**. Reward reactions given and received.
3. Manufacture a **peak every session**; end on a highlight, never a dead lobby.
4. Make the **prompt** funny, never the person (the cringe shield).
5. **Friend-group first**, strangers second (solves cringe, safety, cold-start, invites at once).
6. **Every laugh is a share** — one-tap, ≤15s, watermarked, deep-linked clip.
7. Variable reward on **"what's next,"** never on your wallet.
8. A nightly **prime-time ritual** (habit anchor + concurrency).
9. **Humane streaks** — group streaks, freezes, "welcome back," no guilt.
10. **Safety is the brand, not the tax.**

---

## 3. Visual identity — "Midnight Amusement Park"

The product opens after dark. The whole app lives on **one continuous, breathing
aurora** — a mesh of luminous blobs drifting behind glass — so navigating feels
like moving through a single space, never a slideshow of screens.

- **Canvas:** a violet-tinted near-black (`#080611`). Never a flat black void.
- **The aurora (accents):** magenta `#FF3D9A` · violet `#8A5CFF` · cyan `#22E1FF`.
  These behave like neon — additive glow accumulating on black.
- **Warmth is earned:** amber `#FFC14D` / coral appear *only* on wins, unlocks and
  reveals. Color is a reward; most of the UI is ink and glass.
- **Type:** one family, dramatic weight range. Headlines are loud, tight,
  negative-tracked — posters, not paragraphs. Body stays quiet. Ships on the
  platform's premium default (SF Pro / Roboto) so there are **zero font assets and
  it always renders**; the drama is weight + size + spacing.
- **The wordmark** is the brand thesis: *What* in aurora, *If* in white, a `?` in
  cyan — a question hanging in the air.

Design tokens live in `lib/theme/` (`colors.dart`, `typography.dart`,
`motion.dart`, `app_theme.dart`).

---

## 4. Motion & feel — "springs, not curves"

Everything the finger touches moves on **spring physics**, not fixed easing — a
spring overshoots and settles, which reads as *alive*; a cubic curve reads as
*software*. Craft commandments encoded in the app:

- **Every tappable thing squishes** (`Pressable`) — springs down on touch, a light
  haptic fires on the *same frame*, and it overshoots back on release. Built on a
  raw `SpringSimulation` so it's interruptible and velocity-aware.
- **Staggered reveals** (`Reveal` / `staggered()`) — lists cascade in 60–70ms
  apart, never all at once.
- **One hero material** — the aurora (`AuroraBackground`) is reactive: `energy`
  scales glow + drift speed (calm in the lobby → blown wide open at the reveal),
  and `palette` tints the whole world per game.
- **Reserved big moments** — branded `Confetti` and heavy haptics fire *only* on a
  deserved win, so they stay magic.
- **Emotional haptic vocabulary** (`Buzz`) — `tick / tap / commit / impact /
  heartbeat / celebrate`, so call-sites read like feelings, not API calls.
- **Dramatic countdown** (`CountdownRing`) — a draining ring that shifts cyan →
  amber → hot-red in the final 3 seconds, number pulsing per tick, escalating
  heartbeat haptics.
- **Ambient life** — presence orbs pulse when active; reactions float up the screen
  continuously so a solo tester still feels a crowd.

> **Engineering note:** the app ships with **zero third-party dependencies.** Every
> effect (mesh gradient, confetti, particles, springs, reveals) is hand-built with
> `AnimationController` + `CustomPainter`, which is exactly where "handcrafted"
> lives — and guarantees the app compiles and runs anywhere. Production would layer
> in `rive` (a mascot/host character), a GLSL shader for the mesh, low-latency
> sound, and Core Haptics `.ahap` patterns; the code is structured so those slot in
> behind the existing named seams (`Buzz`, `AuroraBackground`).

---

## 5. Screen-by-screen (what's built)

The full first-run journey is playable end to end: **Splash → Onboarding → Auth →
Identity → Home lobby → Live room** (with a self-driving, replayable round).

### Splash (`splash_screen.dart`)
The aurora is *already breathing* before you touch anything. The wordmark blooms
up on an overshooting spring; the tagline breathes; glyphs drift up like embers.
Auto-advances (tap to skip). Says "something is already happening here" in the
first second.

### Onboarding (`onboarding_screen.dart`)
Three pages that **teach by showing, not telling** — each is a live demo of the
soul: (1) a room of orbs gathering around *you*, (2) a fanned deck of game cards,
(3) the winner reveal with a confetti burst. No forms, no tutorial. Ends on a
hook — "Get me in" — not a checklist.

### Auth (`auth_screen.dart`)
No form. No password. Three one-tap doors (Apple / Google / phone). The hero line
is **social proof** — a *live, ticking* count of who's already inside — because
the reason to join is "your people are here," not "make an account." Safety is
stated up front as a value: *age-checked, groups not strangers, report anyone.*

### Identity (`avatar_screen.dart`)
The whole thing fits on one screen, ~15 seconds. A big **live orb** reacts
instantly to every choice — face (glyph), aura (gradient), handle, vibe — with a
"🎲 surprise me" for the indecisive. **No photo, ever:** you're a luminous
character, not a face to be rated. The orb carries across every screen.

### Home lobby — "Tonight" (`home_screen.dart`)
The screen that must feel *alive*. It answers "what's happening right now?" the
instant it opens:
- **Prime Time card** — a live countdown to the nightly headliner (the habit
  anchor + concurrency engine), with *Notify me* / *Peek in*.
- **Live rooms** — each `RoomCard` reads as a warm, occupied place: the game's
  color bleeds in, a stack of player orbs shows the crowd, a "2 friends inside"
  badge does the FOMO work, fill count, LIVE pulse.
- **Start your own room**, a group-streak flame, and a glass nav shell
  (Tonight / Crew / You).

### Live room — the payoff (`live_room_screen.dart`)
The reason the app exists. A self-driving round choreographs the full arc, with
the aurora, haptics, reactions and confetti all peaking on the reveal:

`gathering` (orbs arrive around you) → `reveal` ("NEXT UP: ???" → the game card
blooms in with its one-sentence rule) → `prompt` (the question; you lock one of
four answers while others' "locked-in" ticks appear) → `answering` (the dramatic
countdown ring) → `voting` (tap your suspect from a grid of orbs) → `results`
(the impostor is revealed; **confetti + celebrate-haptics if you nailed it**; an
MVP banner). Then **Next round** rotates to a different game, or **Wrap up**.
Throughout: a reaction bar spams floating emoji, and the room reacts back.

---

## 6. Roadmap — what comes next

**This pass** delivered the front-end masterpiece on simulated data (the chosen
scope). The path to a real product, in order:

1. **Real-time backend** — matchmaking, room state, presence. (WebSockets /
   a realtime DB; authoritative round state server-side.)
2. **Auth** — real Apple/Google/phone + privacy-preserving **age assurance**.
3. **Group live audio** (not 1-on-1 video) with **real-time + AI moderation** and
   prominent one-tap report/block — the Yubo safety architecture.
4. **The clip engine** — auto-edited ≤15s, watermarked, deep-linked highlight of
   each reveal. The retention peak *and* the acquisition loop in one artifact.
5. **The rotating game pack** as content: a live-ops cadence of new game types &
   prompt decks, plus **user-generated prompt packs** (the investment hook).
6. **Persistent rooms** — convert a fun session into a Discord-style room the crew
   drifts back into (the retention loop).
7. **Ethical cosmetics economy** — earn-first, disclosed-odds unlocks; a mascot/
   host character (Rive); Core Haptics + a branded SFX kit.
8. **Cold-start GTM** — saturate one hyper-connected vertical (a few college /
   creator friend-networks) before any broad launch.

**Never on the roadmap:** random 1-on-1 stranger video, paid loot boxes, guilt/
shame notifications, or anything that makes romance the mechanic.

---

## 7. Running it

```bash
flutter pub get
flutter run     # iOS simulator, Android emulator, or a physical device
```

Portrait, dark, after dark. Zero dependencies beyond the Flutter SDK, so
`pub get` is instant and it builds anywhere. See `README.md` for the file map.
