# WhatIf

**What happens tonight?**

A live multiplayer social *game* for iOS & Android, built in Flutter. Not a
dating app, not Omegle, not a feed — a live table where a rotating pack of short,
silly, role-asymmetric games gets thrown at a small group, and every round ends
in a **public reveal** the whole room feels at once. Friendship and romance are
byproducts of laughing together, never the mechanic.

> 📄 The vision, the research, and the strategic core-loop decision live in
> **[`PRODUCT_SPEC.md`](./PRODUCT_SPEC.md)**. Read that first.

## What's here

A fully playable first-run experience on simulated data (no backend required):

**Splash → Onboarding → Sign-in → Identity → Home lobby → Live room**, with a
self-driving, replayable game round complete with a dramatic countdown, voting,
the reveal, confetti, floating reactions and haptics.

Everything is hand-built with `AnimationController` + `CustomPainter` — **zero
third-party dependencies**, so it compiles and runs anywhere.

## Run it

```bash
flutter pub get
flutter run
```

Portrait, dark, after dark.

## File map

```
lib/
  main.dart                     app entry (portrait, dark chrome)
  app.dart                      root flow: splash → onboarding → auth → avatar → home

  theme/
    colors.dart                 "Midnight Amusement Park" palette + gradients
    typography.dart             poster-scale type system (zero font assets)
    motion.dart                 durations, house curves, spring specs
    app_theme.dart              the single dark theme + system chrome
  core/
    haptics.dart                Buzz — the emotional haptic vocabulary

  widgets/
    aurora_background.dart      the reactive mesh-gradient hero material
    whatif_scaffold.dart        every screen sits on the same living aurora
    glass.dart                  frosted glass panels
    pressable.dart              spring-squish + haptic on everything tappable
    reveal.dart                 staggered entrance reveals
    gradient_text.dart          aurora wordmark + gradient headlines
    aurora_button.dart          primary CTA (shimmer + glow) + ghost button
    presence_orb.dart           players as luminous, pulsing orbs
    live_pill.dart              LIVE chip + frosted tag chips
    countdown_ring.dart         the dramatic draining countdown
    confetti.dart               branded particle burst (deserved wins only)
    floating_reactions.dart     emoji that float up — "the room is laughing"
    room_card.dart              a live room on the Tonight board

  models/
    identity.dart               the orb identity (glyph + gradient + handle)
    game.dart                   the rotating game pack + round phases
    room.dart                   a live room
    mock_data.dart              a hand-built cast so every screen feels alive
  state/
    app_state.dart              minimal app-wide state (the user's identity)

  screens/
    splash_screen.dart
    onboarding_screen.dart
    auth_screen.dart
    avatar_screen.dart
    home_screen.dart            the "Tonight" lobby
    live_room_screen.dart       the live game round — the payoff
```

## Status

First-version front-end masterpiece on simulated data. The roadmap to a real
live product (realtime backend, age assurance, group audio + moderation, the clip
engine, persistent rooms) is in `PRODUCT_SPEC.md §6`.
