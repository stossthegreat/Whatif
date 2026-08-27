# Rivler — App Store listing copy

Rewritten after the 26 Aug 2026 rejection under **Guideline 1.1 — Objectionable
Content**, which cited the *description* and *promotional text* fields.

Apple's warning was explicit: *"Resubmitting this app without making the
appropriate changes, or submitting a new app with similar marketing and
concept, will result in the same or additional App Review Guideline
violations."* So this is not a light edit — the flirt/dating framing is gone
entirely and the positioning is now a party-games app.

## What triggered it, and what changed

The old copy is preserved here so the same words don't creep back in.

| Old wording | Why it tripped 1.1 | Now |
|---|---|---|
| "Truth or Dare — a truth, a dare, and **a spicy finale**" | "spicy" is the standard euphemism for sexual content | "a truth, a dare, and a final round" |
| "**Kiss** Marry Ghost" | names a sexual/romantic act in marketing | cut from the listing entirely |
| "**Rizz Off** — best line, worst line, **shoot your shot**" | pick-up/seduction framing | "Best Line — the funniest opener wins" |
| "Spin the Bottle — the bottle picks, **no escape**" | coercion framing on a UGC app is the worst possible pairing | "the bottle picks who answers next" |
| "**Roast** Circle" | reads as sanctioned harassment | "Compliment Circle" |
| "Meet **one on one**… land face to face with someone new" | stranger-video-chat positioning invites 1.2 scrutiny | led with games; meeting is the mechanism, not the pitch |

**In-app names still say `Kiss Marry Ghost`, `Rizz Off` and `Roast Circle`.**
Apple cited metadata only, so this listing is compliant as it stands — but a
reviewer who opens the games list will see them. Renaming them in
`server/src/games.ts` is the safer move before the next submission and is a
separate change; it is not done here.

---

## App name

```
Rivler — Party Games Live
```

## Subtitle (30 char max)

```
Play party games on camera
```

## Promotional text (170 char max)

```
Seventeen party games, played live on camera with real people. Spin the Bottle, Would You Rather, Never Have I Ever. 18+, moderated, and nothing is ever recorded.
```

## Description

```
Rivler is a live video app built around party games.

Press one button, land in a room, and play. Spin the Bottle. Would You Rather.
Never Have I Ever. Real games, played out loud, with real people — not another
feed to scroll.

THE GAMES
Over a thousand rounds across 17 games, and it remembers what you have played,
so you get a new one next time instead of the same question on a loop.

• Spin the Bottle — the bottle picks who answers next
• Truth or Dare — a truth, a dare, and a final round
• Never Have I Ever — thumbs up means guilty
• Would You Rather — three impossible choices
• Face Off — pull it, hold it, funniest face wins
• Best Line — the funniest opener wins the round
• 21 Questions, This or That, Mind Reader, Impressions, Compliment Circle,
  Storytime, Hot Takes, Eye Contact, Dare Machine, Most Likely To

NO TYPING, EVER
Every game is talk, tap, or pull a face. Nothing to write, nothing to read out.
You are on camera — that is the whole point.

BRING YOUR OWN PEOPLE
Get a room code that is yours forever. Share it, your friends drop in, and the
games run for the whole room.

PLAY WITH SOMEONE NEW
Browse who is online, pick who you want to play with, and invite them. They
choose whether to accept. Nobody appears on camera without agreeing first.

THE PEOPLE YOU LIKE DON'T DISAPPEAR
Follow someone after a room and they stay. Message them, send voice notes and
photos, invite them back. Rooms end. People don't.

NEVER RECORDED
We do not record or store your video or audio. When a room ends, the stream
ends. There is no archive, no replay, nothing kept for anyone to see later.

BUILT TO BE SAFE
• 18+ only, verified date of birth, account required — no anonymous drop-ins
• Report and block are one tap from every room, chat and profile
• Photos, names, bios and messages are screened automatically before they post
• Live video is checked continuously; a camera that breaks the rules is covered
  on everyone else's screen within seconds
• Every report reaches a human and is acted on within 24 hours
• Zero tolerance for abusive users or objectionable content — accounts are
  removed for it

RIVLER PRO
Playing one on one is free and always will be. Pro unlocks the full party game
catalogue, Roulette, your own group room, and choosing who you meet.
£4.99/week or £14.99/month. Auto-renews until cancelled; cancel any time in
your App Store settings.

Terms: https://rivler.up.railway.app/terms
Privacy: https://rivler.up.railway.app/privacy
```

## Keywords (100 char max)

```
party games,truth or dare,never have i ever,spin bottle,live video,group video,friends,would you
```

Deliberately excluded, because each invites 1.1 or a dating-category review:
`flirt`, `rizz`, `kiss`, `spicy`, `dating`, `meet strangers`, `random chat`,
`omegle`, `monkey`, `azar`.

## Age rating

Must be set to **18+** in App Store Connect — Apple named it as the first
required item under 1.2. In the questionnaire, answer honestly for:
unrestricted web access (no), user-generated content (yes), and frequent/intense
mature themes as they apply. The app already enforces this with a hard
date-of-birth gate that remembers a rejection, so the rating matches behaviour.

## Review notes (App Review Information → Notes)

```
Rivler is an 18+ live party-games app. Users play structured games (Spin the
Bottle, Would You Rather, Never Have I Ever) on camera, either in a private
room with friends via a room code, or with someone who accepts their invite.

Guideline 1.2 measures in this build:
• Age: hard date-of-birth gate at sign-up, 18+ enforced, rejection remembered
  across reinstalls. No guest access — Sign in with Apple or Google required.
• Terms: accepted at sign-up before any access. Section 5 states a zero-
  tolerance policy for objectionable content and abusive users.
• Automated filtering: profile photos, chat photos, handles, bios and messages
  are screened before they are shown to anyone. Live video frames are sampled
  continuously and a camera breaking the rules is blurred on other users'
  screens within seconds.
• Flagging: Report is one tap from every room, chat and profile, and asks for
  a category (child safety, nudity, harassment, violence, impersonation).
• Blocking: instant and permanent; a blocked user can never be matched again.
• Removing your own content: Settings → Edit profile → Remove photo takes a
  profile photo down immediately. Settings → Show me in Explore removes you
  from discovery instantly. Settings → Delete account removes everything.
• 24-hour action: every report enters a severity-ordered human queue; child
  safety and nudity are handled first. Automatic temporary suspension applies
  on strong independent-report signal pending human review.
• Contact: Settings → Contact opens email to m2mb@info.com for reporting
  inappropriate activity.

Nothing is recorded. Video and audio are peer-to-peer for two-person rooms and
relayed for group rooms; no stream is stored at any point.

Test account: <fill in a sandbox account before submitting>
```
