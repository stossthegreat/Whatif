/// Public legal pages, served at /privacy, /terms, /rules, /delete-account.
/// These URLs go into App Store Connect and Google Play Console. The text
/// MIRRORS lib/screens/legal_screen.dart — change one, change both.

export function page(title: string, body: string): string {
  const esc = body
    .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
    .replace(/\n/g, '<br/>');
  return `<!doctype html><html lang="en"><head><meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<title>${title} · Rivlr</title>
<style>
  body{background:#000;color:#cfcfd4;font:16px/1.65 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif;margin:0}
  main{max-width:720px;margin:0 auto;padding:48px 24px 96px}
  h1{color:#fff;font-size:28px;letter-spacing:-0.5px}
  .mark{color:#fff;font-weight:800;font-size:22px;margin-bottom:32px}
  .mark span{color:#A36BFF}
  a{color:#A36BFF}
</style></head><body><main>
<div class="mark"><span>R</span>ivlr</div>
<h1>${title}</h1>
<p>${esc}</p>
</main></body></html>`;
}

export const privacy = `PRIVACY POLICY
Rivlr — live social video
Effective date: 2 August 2026 · Version 3.0

This policy explains what Rivlr ("Rivlr", "we", "us", "our") collects, why, how long we keep it, who we share it with, and every choice you have. We designed Rivlr to need as little of your data as possible: the product is live conversation between people, not their data. This policy is also available at any time from Settings → Privacy Policy inside the app.

1. WHO WE ARE / DATA CONTROLLER
Rivlr is a live social video app for adults (18+). For the purposes of the UK GDPR and EU GDPR, the data controller is the operator of Rivlr, reachable at appsdevelop2025@gmail.com. That address handles ALL privacy matters: questions, rights requests, complaints, and under-18 reports.

2. INFORMATION WE COLLECT

2.1 Information you provide
• A handle you choose (no real name required — and we ask you NOT to use one)
• Your age (to enforce our 18+ policy), gender, who you want to meet, and the "vibes" you select
• Reports you file about other users, and the people you block or save ("sparks")

2.2 Sign in with Apple (optional)
If you choose Sign in with Apple, we receive and store ONLY the anonymous Apple user identifier — a random string scoped to Rivlr. We do not request, read, or store your name or email address from Apple. The identifier lets your sparks and blocks survive reinstalls. Guest use (no account) is always available.

2.3 Camera and microphone
Rivlr is a live video app. When you are in a room, your camera and microphone stream IN REAL TIME to the other people in that room via our video infrastructure provider (LiveKit, Inc.). WE DO NOT RECORD, STORE, OR ANALYSE YOUR VIDEO OR AUDIO. When a room ends, the stream ends. There is no archive, no server-side capture, no face or voice analysis, and no use of your video or audio to train AI systems. Camera/microphone access is controlled by you in iOS Settings and can be revoked at any time.

2.4 Gameplay and session data
While you play: round answers, votes, and reactions are processed in server memory to run the room, then discarded when the room ends. Your device stores your own stats (streak, badges, moment cards) locally.

2.5 Account data stored on our servers
To make the social layer work across devices and restarts we store server-side, keyed to your identifier: your handle, avatar hue, age-gate confirmation, stated preferences and vibes, your saves/sparks and blocks, report records, and (if you enable notifications) your push token. This is the complete list.

2.6 Analytics
We use Google Firebase Analytics to understand which screens and games people use — events like "game started" or "screen viewed", associated with an app instance, not your handle. We use it to improve the product, never for advertising. We do not use data for cross-app tracking.

2.7 Push notifications (optional)
If you allow notifications, we store a device push token so we can tell you things like a mutual spark coming online. Sending uses Apple Push Notification service and Google Firebase Cloud Messaging. Turn notifications off in your device Settings at any time; the token stops being used.

2.8 Technical data
Connection metadata (such as IP address and connection identifiers) is processed transiently to deliver the service, as with any internet application. We do not build advertising or tracking profiles from it.

3. WHAT WE DO NOT DO
• We do not sell or rent your personal data — to anyone, ever
• We do not serve advertising of any kind
• We do not record rooms — no video, no audio, no transcripts
• We do not request your contacts, precise location, photos, or real name
• We do not use your video or audio to train AI systems
• We do not knowingly permit anyone under 18 to use the service

4. HOW WE USE INFORMATION
• To match you into rooms consistent with your stated preferences
• To run the games (tallies, votes, awards) in real time
• To make sparks, mutuals and blocks work across sessions and devices
• To enforce safety: processing reports and blocks, removing repeatedly-reported accounts, and preventing blocked users from ever being matched together again
• To send notifications you have opted into
• To understand aggregate product usage (analytics) and improve Rivlr
• To operate, debug, and secure the service

5. LEGAL BASES (EEA/UK USERS)
Where GDPR/UK GDPR applies we rely on: performance of a contract (running the service you asked for — matching, games, sparks); legitimate interests (safety, security, abuse prevention, aggregate analytics); and consent (camera/microphone access, push notifications — both revocable at any time in device Settings). We do not use automated decision-making producing legal effects; the only automated action is removal after repeated community reports, which you can contest by email.

6. WHO WE SHARE WITH (PROCESSORS)
We share data only with the parties needed to run Rivlr:
• Other users in your room — your live video/audio, handle and gameplay actions (that is the product)
• LiveKit, Inc. — real-time transit of video/audio (not retained)
• Railway Corp. — hosting for our matchmaking server and database
• Google LLC (Firebase) — analytics events and push message delivery
• Apple Inc. — sign-in (if used) and push delivery
We never share with data brokers or advertisers. We may disclose information if required by law, or where necessary to protect users from imminent harm. If Rivlr is ever acquired, this policy binds the successor, and we will notify you of any material change before it applies.

7. RETENTION
• Live video/audio: never retained (real-time transit only)
• Room/session state (answers, votes): server memory only; discarded when the room ends
• Account data (handle, preferences, sparks, blocks, push token): retained while your account exists; deleted when you delete your account
• Reports: retained up to 24 months for community safety, then deleted
• Analytics events: retained per Firebase's standard 14-month rolling window
• Backups of our database roll off automatically within 30 days

8. DELETING YOUR ACCOUNT
In-app: Settings → Delete account removes your device data AND instructs our servers to delete your account record, sparks, blocks and push token immediately; residual copies leave backups within 30 days. No app access? Email appsdevelop2025@gmail.com from any address with your handle and we will delete within 30 days. Deletion is permanent — sparks cannot be recovered. See /delete-account for the step-by-step guide.

9. YOUR RIGHTS
Depending on where you live you may have the right to access, correct, delete, or receive a copy of your data, to object to or restrict processing, to withdraw consent, and to not be discriminated against for exercising rights. To exercise any of them: appsdevelop2025@gmail.com — we respond within 30 days, and we may ask you to verify control of the account. EEA/UK users may also complain to their supervisory authority (in the UK, the ICO at ico.org.uk).
California residents (CCPA/CPRA): we do not "sell" or "share" personal information as those terms are defined; we collect only the categories described in §2 for the purposes in §4; you have the rights to know, delete, correct, and to non-discrimination.

10. CHILDREN
Rivlr is strictly 18+. We do not knowingly collect data from anyone under 18. Discovery of an under-18 account leads to removal and deletion of its data. Report one: appsdevelop2025@gmail.com.

11. SECURITY
Video and audio travel over encrypted connections (TLS/SRTP). Server data is held in an access-controlled database. Our best protection is architectural: we simply do not hold your video, audio, real name, email, or location. If a breach affecting your data ever occurs we will notify you and regulators as required by law.

12. INTERNATIONAL TRANSFERS
Our infrastructure providers may process data in the United States and other countries. Where required we rely on appropriate safeguards, including standard contractual clauses, with each provider listed in §6.

13. DO NOT TRACK / COOKIES
The app uses no cookies and no cross-site tracking; there is nothing for a "Do Not Track" signal to change.

14. CHANGES
Material changes will be presented in the app before they take effect, with the new effective date above. Continued use after that date means the new version applies.

15. CONTACT
appsdevelop2025@gmail.com — privacy questions, rights requests, complaints, safety.`;

export const terms = `TERMS OF SERVICE & END USER LICENCE AGREEMENT
Rivlr — live social video
Effective date: 2 August 2026 · Version 3.0

These terms are a binding agreement between you and Rivlr ("we", "us"). By ticking the agreement boxes, creating an account, or using Rivlr you accept them, together with the Privacy Policy and House Rules, which are part of this agreement. Short version: be an adult, be decent on camera, never record anyone, be careful about what you share with strangers, and the room can remove you.

1. ELIGIBILITY
You must be at least 18 years old and legally able to enter this agreement. By using Rivlr you represent that both are true. Accounts belonging to under-18s are removed on discovery, without notice, and their data deleted. We may implement additional age-assurance measures and you agree to cooperate with them.

2. THE SERVICE
Rivlr connects you by live video with other people — sometimes one person, sometimes a group — and offers short games inside the room. Rooms are LIVE: you will meet real strangers whose behaviour we do not control in real time. Rivlr provides safety tools (report, block, instant leave, mute) and automated removal driven by community reports; use them. We may add, change, or remove features at any time.

3. HOUSE RULES — ZERO TOLERANCE FOR OBJECTIONABLE CONTENT
You agree that you will NOT:
(a) appear nude, engage in sexual activity, or sexually solicit anyone;
(b) harass, bully, threaten, or demean anyone, including on the basis of race, ethnicity, national origin, religion, disability, sex, gender identity, or sexual orientation;
(c) display or promote violence, self-harm, weapons, drugs, or any illegal activity;
(d) record, screenshot, screen-capture, or redistribute other people's video, audio, or likeness — with or without intent to share;
(e) impersonate any person, spam, advertise, solicit money, or scam;
(f) attempt to identify, locate, stalk, or contact people against their wishes;
(g) share content that infringes anyone's intellectual property or privacy;
(h) circumvent bans, age controls, or safety systems, or access the service by automated means.

There is NO TOLERANCE for objectionable content or abusive users. Violations may result in immediate, permanent removal without warning. Community reports trigger automatic removal at a threshold, and we review reports and act on them — including ejecting offenders and removing content — within 24 hours. To appeal a removal, email appsdevelop2025@gmail.com.

4. MEETING PEOPLE; YOUR SAFETY
Rivlr introduces you to people you do not know. Use judgement: do not share your real name, address, workplace, financial details, or social handles with strangers; be cautious about anything you show on camera; and if you ever choose to meet someone offline, that choice and its consequences are yours alone. WE DO NOT CONDUCT BACKGROUND CHECKS ON USERS. Rivlr is not an emergency service — if you believe someone is in danger, contact local emergency services first, then report the room to us.

5. YOUR CONTENT AND LICENCE
Your live video and audio belong to you. You grant us only the limited, technical, non-exclusive licence required to transmit them in real time to the members of your room. We do not record them, so no further licence is needed or taken. If you send us feedback or ideas, we may use them without obligation to you.

6. APP LICENCE
We grant you a personal, non-exclusive, non-transferable, revocable licence to use the Rivlr app on devices you own or control, subject to these terms and the applicable app store's usage rules. You may not copy, modify, reverse engineer, or redistribute the app except where law permits it despite this clause.

7. INTELLECTUAL PROPERTY
Rivlr, the Rivlr wordmark, and the app's design and content (excluding your content) are ours or our licensors' and are protected by law. No rights are granted except the licence in §6.

8. APPLE-SPECIFIC TERMS
These terms are between you and Rivlr, not Apple. Apple has no obligation to provide maintenance or support, and no warranty obligations — any warranty claims are our responsibility. Apple is not responsible for addressing claims relating to the app (including product liability, regulatory non-compliance, or third-party IP claims). Apple and its subsidiaries are third-party beneficiaries of these terms and may enforce them against you. You represent that you are not located in an embargoed country and are not on any restricted-parties list.

9. GOOGLE PLAY-SPECIFIC TERMS
If you obtained Rivlr from Google Play, Google is not a party to these terms, provides no warranty or support for the app, and has no liability for claims relating to it. Nothing in these terms limits any rights you have under Google Play's terms of service.

10. SUSPENSION AND TERMINATION
We may suspend or terminate the service, or your access to it, at any time — including to protect the community, comply with law, or discontinue the product. You may stop using Rivlr and delete your account at any time in Settings → Delete account (see the Privacy Policy for exactly what deletion removes). Sections 5, 7, and 11–16 survive termination.

11. EARLY ACCESS; DISCLAIMER
Rivlr is under active development and is provided "AS IS" and "AS AVAILABLE", without warranties of any kind, express or implied, including fitness for a particular purpose and non-infringement. We do not warrant that the service will be uninterrupted or error-free, or that any particular person you meet will behave lawfully or decently.

12. LIMITATION OF LIABILITY
To the maximum extent permitted by law: we are not liable for indirect, incidental, special, consequential, or punitive damages, loss of data, or loss of goodwill, nor for the conduct of any user, whether online or offline. Our total liability for any claim will not exceed the greater of the amount you paid us in the last 12 months (currently zero) or £50. Nothing in these terms limits liability that cannot lawfully be limited (including for fraud, or death or personal injury caused by negligence).

13. INDEMNITY
You will indemnify us against third-party claims arising from your breach of these terms or your conduct on the service, except to the extent we caused the loss.

14. CHANGES
We may update these terms; material changes will be presented in the app before they take effect. Continuing to use Rivlr after changes take effect means you accept them.

15. GENERAL
If any provision of these terms is found unenforceable, the rest remain in effect. Our not enforcing a provision is not a waiver. You may not assign this agreement; we may assign it to a successor of the service. These terms plus the Privacy Policy and House Rules are the entire agreement between us about Rivlr.

16. GOVERNING LAW
These terms are governed by the laws of England and Wales, and disputes are subject to the exclusive jurisdiction of its courts — except where the law of your country of residence grants you mandatory consumer protections and venue, which remain yours.

17. CONTACT
appsdevelop2025@gmail.com`;

export const rules = `THE HOUSE RULES

Four rules. They keep this place good.

1. 18+ ONLY
Everyone here is an adult. No exceptions, no "almost".

2. BE DECENT ON CAMERA
No nudity. No harassment, hate, or threats. No violence, weapons, or drugs. Instant, permanent ban.

3. NEVER RECORD ANYONE
We never record rooms — that's a promise. You don't record them either. No screenshots, no screen-capture, no sharing anyone's face without consent.

4. THE ROOM PROTECTS ITSELF
Long-press any face to report or block — one tap, instant. Community reports remove people automatically. Blocked people can never be matched with you again.

Breaking these gets you removed. The room decides fast.`;

export const deleteAccount = `DELETE YOUR RIVLR ACCOUNT
This page exists so you can always find out how to delete your account and data — with or without the app installed. (Required by Google Play's account-deletion policy; applies equally to iOS.)

WHAT DELETION REMOVES
• Your account record: handle, avatar colour, age confirmation, preferences and vibes
• Your sparks (saves) and mutual connections — both directions
• Your blocks and your push notification token
• All data on your device (stats, badges, moment cards)
Report records may be retained up to 24 months for community safety (they identify the reported behaviour, not your live media — remember: rooms are never recorded, so there is no video or audio of you anywhere to delete). Residual copies leave rolling database backups within 30 days.

OPTION 1 — IN THE APP (INSTANT)
1. Open Rivlr
2. Tap the settings gear (top right of Home)
3. Scroll to ACCOUNT → Delete account
4. Confirm. Your device data is wiped and our servers delete your account immediately.

OPTION 2 — BY EMAIL (NO APP NEEDED)
Email appsdevelop2025@gmail.com with the subject "Delete my account" and the handle you used. We delete within 30 days and confirm by reply. If you signed in with Apple you can also revoke Rivlr under Settings → Apple ID → Sign-In & Security → Sign in with Apple on your device.

Deletion is permanent. Sparks and mutuals cannot be recovered.`;
