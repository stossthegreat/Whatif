# WhatIf

**Press one button. Seconds later you're live with people you've never met.**

A live social video platform (18+) built in Flutter for iOS & Android. One PLAY
button drops you into a live cell of random strangers — sometimes 1:1, sometimes a
crowd — with a short game already running to break the ice. Every 30–90s the world
recomposes: new faces, new game, a twist. The interface disappears; the people are
the content.

> 📄 **[`PRODUCT_SPEC.md`](./PRODUCT_SPEC.md)** — the full product, the research-backed
> Addiction & Fun Engine (§3), and the "Black glass" design system.
> 🛠 **[`docs/BUILD_TESTFLIGHT.md`](./docs/BUILD_TESTFLIGHT.md)** — get it on TestFlight.

## What's here (buildable today)

The full loop runs on a device with **no backend** — matching, the other people,
and the games are simulated locally; the camera powers your real self-view (with
a graceful fallback if denied):

**Onboarding → Home (PLAY, already alive) → Finding (the reveal countdown) →
Live (unpredictable games, the reveal, NEXT re-roll, opt-in reconnect,
one-gesture Report/Block).**

## Run it
```bash
flutter pub get
flutter run          # a real device is best (camera)
```

## Design system — "Black glass"
True black, one cool sliver of signal light, huge type, massive whitespace.
Motion stays silent until it matters — it fires only on the press, the countdown,
the pop, and the reveal.

## File map
```
lib/
  main.dart · app.dart              entry + root flow (onboarding→home→finding→live)
  theme/tokens.dart                 Black-glass colors, type, motion, Responsive
  core/haptics.dart                 the beat vocabulary
  core/camera_service.dart          fail-soft front camera
  models/person.dart · game.dart    presence + the rotating game pack (group + 1:1)
  state/session.dart                saved (reconnect) set + live count
  widgets/                          glass, play button, countdown ring,
                                    presence tile, self view
  screens/                          onboarding · home · finding · live
```

## Status
First buildable version of the live-video product, on simulated data. Next:
real-time matching + WebRTC video + moderation (see `PRODUCT_SPEC.md §9`).
