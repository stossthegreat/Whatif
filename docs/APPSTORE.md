# Rivlr — App Store submission pack

Everything App Store Connect will ask for, pre-answered. Work through top to
bottom when submitting.

## 1 · Basics

| Field | Value |
|---|---|
| Name | Rivlr |
| Subtitle (30 chars) | Live video. Real strangers. |
| Bundle ID | com.rivlr.app |
| Category | Social Networking |
| Age rating | **17+** (see §3) |
| Price | Free |

Promotional text (170 chars):
> Press play and you're live with someone new — talk, play ten unhinged
> games, spark with people you click with. Never recorded. You never know
> who you'll get.

Keywords (100 chars):
`live,video chat,random,strangers,games,social,meet people,omegle,party,chaos`

## 2 · Privacy nutrition labels (App Privacy section)

Data types to declare — everything else: "not collected".

**Contact info → Email**: NOT collected (Apple sign-in may share a private
relay email but we never read or store it — declare nothing).

**User content → Audio/Video**: collected? **No** — live streams are
transient, never recorded or stored (say exactly this in the notes field if
asked). Do NOT declare photos/videos.

**Identifiers → User ID**: YES — linked to user, used for App Functionality
(stable anonymous id / Apple user id for sparks, blocks, moderation).

**Usage data → Product interaction**: YES — NOT linked to identity, used for
Analytics (Firebase: screens, game picks, matches). We do not use it for
tracking; answer **"No"** to "Do you use data to track users?" (no ads, no
data brokers, no cross-app tracking).

**Diagnostics**: none collected.

## 3 · Age rating questionnaire

Answer honestly to land on 17+:
- Unrestricted web access: NO
- User-generated content: **YES** (live video chat)
- Frequent/intense mature or suggestive themes: **Infrequent/Mild**
- Everything else (violence, gambling, drugs …): None
- The 18+ House Rules gate + report/block/kick pipeline is our UGC
  safety story (Guideline 1.2): report → auto-kick at 3 reports, block,
  no recording, moderation contact in-app.

## 4 · Review notes (paste into "Notes" for the reviewer)

> Rivlr is live 1:1/group video chat with party games. Key review info:
> 1. Sign-in is optional — tap "Continue as guest" to use the app without
>    an account. Sign in with Apple is the only account system.
> 2. Video rooms need a second participant: run the app on two devices, or
>    press Play on both to be matched together (the server matches queued
>    users; with only the review device online you'll see the solo waiting
>    room, which is expected).
> 3. Rooms are never recorded — video is transient WebRTC (LiveKit).
> 4. UGC safety (Guideline 1.2): users must accept House Rules during
>    onboarding; every room has Report and Block on each participant
>    (long-press ⋯); 3 reports auto-remove a user; blocked users are
>    never matched again and can be managed in Settings → Safety.
> 5. Account deletion: Settings → Delete account (Guideline 5.1.1(v)).
> 6. Contact: appsdevelop2025@gmail.com

## 5 · Screenshots (6.9" iPhone required set)

Shoot on iPhone 16 Pro Max sim/device, dark content:
1. Home — "Connect to a random person" + trending rail
2. Mode choice — Roulette vs Hang cards
3. Live 1:1 — faces + a game caption (use two test devices)
4. Game picker — the ten living game tiles
5. Awards ceremony — "the room voted"
6. Room with friends — the big code screen

No device frames needed; Apple composites plain screenshots fine. Avoid
showing real strangers' faces — use your own two devices.

## 6 · Pre-submission checklist

- [ ] Railway: Postgres attached, `DATABASE_URL` referenced on the service
- [ ] Railway: `FIREBASE_SERVICE_ACCOUNT` env set (for pushes)
- [ ] Firebase console: APNs auth key (.p8) uploaded under Cloud Messaging
- [ ] Apple Developer portal: App ID has Sign in with Apple + Push enabled
      (done), and the App Store provisioning profile was REGENERATED after
      enabling them (Codemagic fetches the fresh profile automatically)
- [ ] TestFlight build passes on 2 devices: match, voice both ways, camera
      upright, party code join, deep link, mute, block → never rematch
- [ ] Privacy policy URL — the server hosts it, paste into App Store
      Connect / Play Console:
      https://whatif-production-051b.up.railway.app/privacy
      Also live: /terms · /rules · /delete-account (the delete-account URL
      is REQUIRED by Google Play's data-deletion policy for Android)
- [ ] Demo video ready in case review asks (screen-record a 2-device match)
