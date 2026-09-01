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

Every claim below was checked against the build before being written down. Do
not send it until `OPENAI_API_KEY` is set on the server — the filtering
paragraph is false without it, and a claim App Review can disprove is worse
than no claim.

```
Rivler is an 18+ live party-games app. Users play structured games (Spin the
Bottle, Would You Rather, Never Have I Ever) on camera, either in a private
room with friends via a room code, or with someone who accepts their invite.

On the previous rejection: Rivler does not allow anonymous posting. There is
no guest path of any kind. Sign in with Apple or Google is required before any
content can be created or seen, and the server rejects unauthenticated
sessions. Every piece of content is attached to a verified account, which is
what makes a ban meaningful.

Guideline 1.2 measures in this build:
• Age: hard date-of-birth gate at sign-up, 18+ enforced, and a rejection is
  remembered across reinstalls.
• Terms: three checkboxes at sign-up — 18 or older, agree to the Terms, follow
  the House Rules — all required before either sign-in button does anything.
  Terms section 5 is titled "HOUSE RULES — ZERO TOLERANCE FOR OBJECTIONABLE
  CONTENT" and states there is no tolerance for objectionable content or
  abusive users.
• Automated filtering: profile photos, chat photos, handles, bios and messages
  are screened before they are shown to anyone. Live video is sampled
  continuously and a camera breaking the rules is blurred on the other
  person's screen within seconds.
• Flagging: a report control is visible on every live video tile (flag icon,
  top-left of each face), in every chat via the ⋯ menu, and on every profile.
  It asks for a category — child safety, nudity, harassment, violence,
  impersonation, or other.
• Blocking: instant and permanent, from the same menus. A blocked person can
  never be matched with you again.
• Removing your own content: Profile → Edit profile → Remove photo takes a
  profile photo down immediately, everywhere. Settings → Show me in Explore
  removes you from discovery instantly. Settings → Delete account removes the
  account and its content.
• 24-hour action: every report enters a severity-ordered human queue; child
  safety and nudity sort above everything else. A strong independent-report
  signal applies an automatic temporary suspension pending human review;
  permanent removal is always a human decision.
• Contact: Settings → "Report a problem · m2mb@info.com". Tapping it copies
  the address and confirms reports are answered within 24 hours.

Nothing is recorded. Video and audio are peer-to-peer for two-person rooms and
relayed for group rooms; no stream is stored at any point.

No demo account is needed — Sign in with Apple works with the reviewer's own
Apple ID. The date-of-birth screen that follows requires an 18+ date.
```
