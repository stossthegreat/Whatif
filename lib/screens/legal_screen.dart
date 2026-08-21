import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../widgets/glass.dart';

/// A pushed page for Privacy, Terms, House Rules and About — title + body.
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.title, required this.body});
  final String title;
  final String body;

  static void push(BuildContext context, String title, String body) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => LegalScreen(title: title, body: body),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 6),
              Row(
                children: [
                  Press(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: C.glass, border: Border.all(color: C.hair)),
                      child: const Icon(Icons.arrow_back_rounded, size: 20, color: C.tx2),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Text(title, style: T.big.copyWith(fontSize: 24))),
                ],
              ),
              const SizedBox(height: 18),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(body, style: T.body.copyWith(height: 1.55, color: C.tx2)),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rivler legal + info copy. The SAME text is served publicly by the server at
/// /privacy, /terms, /rules and /delete-account (server/src/legal.ts) — if you
/// change one, change both.
class LegalCopy {
  LegalCopy._();

  static const privacy = '''PRIVACY POLICY
Rivler — live social video
Effective date: 11 August 2026 · Version 4.1

This Privacy Policy explains what Rivler ("Rivler", "we", "us", "our") collects, why we collect it, how long we keep it, who we share it with, and every choice you have. Please read it carefully — by using Rivler you agree to the practices described here. Capitalised terms not defined here have the meanings given in our Terms of Service. This policy is also available at any time from Settings → Privacy Policy in the app, and on the web.

1. WHO WE ARE AND WHAT THIS POLICY COVERS
Rivler is the data controller for the personal information described in this policy. Contact: m2mb@info.com. This policy covers our handling of information collected through the Rivler app and service. It does not cover the practices of third parties we do not own or control — including other users, the app stores you install Rivler from, or external services you reach through Rivler — and we encourage you to review their policies separately.

2. THE SERVICE, IN ONE LINE
Rivler pairs people into live video rooms with games, lets you browse who is online and ask them to meet, and lets people who chose each other stay connected: friends, messaging, and calls. This policy is written around exactly that — nothing more is collected than the product needs.

3. INFORMATION YOU PROVIDE
• A handle you choose (no real name required — and we ask you NOT to use one)
• Your date of birth (to enforce our 18+ policy and to match you with people near your age — never shown to anyone) and your gender
• Your primary language and your interests — these are what the matching actually runs on
• Profile details you CHOOSE to add, all optional: a bio, city, pronouns, what you're looking for, and a profile photo. Your COUNTRY is taken from your phone's region setting (a country, never GPS or a precise location) purely to nudge matching
• Reports you file about other users, and the people you block, save, or add as friends
• Anything you include when you contact us at m2mb@info.com

4. SIGNING IN — APPLE OR GOOGLE, REQUIRED
Rivler requires an account: Sign in with Apple on iOS, Sign in with Google on Android. There is no guest mode — a real, verifiable identity is what makes suspensions actually stick, and it is why your friends, messages and profile survive a reinstall. Whichever you use, we receive and store ONLY the anonymous user identifier that provider issues for Rivler — a random string. We do not request, read, or store your name or email address from Apple or from Google.

5. CAMERA AND MICROPHONE — NEVER RECORDED
WE DO NOT RECORD, STORE, OR ANALYSE YOUR VIDEO OR AUDIO. When a room ends, the stream ends. There is no archive, no server-side capture, no face or voice analysis, and no use of your video or audio to train AI systems. In most one-to-one rooms your video travels directly between the two phones and never touches our servers at all; in group rooms and when a direct connection isn't possible, it is relayed in real time by our video provider without being recorded. This is the foundation of Rivler and it does not change.

6. MESSAGES AND MEDIA YOU SEND
When you and another person become friends, you can message each other. To deliver messages across devices and sessions, we store on our servers:
• Your messages — text, voice notes, photos, GIF links, game invites, and call records (who called whom, when, missed/answered) — with timestamps
• Reactions to messages and how far each side has read (read receipts)
• The media bytes themselves for photos, voice notes and profile photos (up to 1MB per item)
Photos and voice notes sent in chats are automatically deleted from our servers 90 days after sending. Profile photos are kept while your account exists (replacing your photo deletes the old one). GIFs are links served by Tenor (a Google service) — when you search GIFs, your search text is sent to Tenor; we never send Tenor your identity.
Remember: the people you message can screenshot, save, or copy what you send, on their own devices, outside our control. Do not send anything you would not want kept.

7. YOUR SOCIAL GRAPH AND GAME RECORD
To make "the people you liked never disappear" work, we store:
• Friendships and friend requests (including who asked, when you matched, and the tier/pin settings you choose)
• An encounter log: who you met in rooms, when, roughly how long you talked, and the countries involved — this powers "Recently met", stops you being rematched with the same stranger immediately, and counts your countries-met stat
• Post-room answers to "Would you meet this person again?" and personality-trait votes you cast and receive (profiles show aggregated tallies; individual votes are never shown to anyone)
• Your persistent record: rooms, streaks, laughs, wins, badges and titles
• Internal quality signals derived from reports, blocks and ratings, used ONLY to improve matchmaking. They are never displayed, never shared, and never sold.

8. IN-ROOM GAMEPLAY
While you play: round answers, votes, and reactions are processed in server memory to run the room, then discarded when the room ends. Moment cards (the shareable game-verdict graphics) are generated and stored on your device only.

9. ANALYTICS
We use Firebase Analytics to understand which screens and games people use, in aggregate (e.g. "how many rooms started today"). We answer "no" to tracking under Apple's App Tracking Transparency because we do not track you across other companies' apps or websites, and we do not use analytics data to identify you.

10. PUSH NOTIFICATIONS
If you allow notifications, we store a device push token so we can tell you things like a friend coming online, a new message, or a friend request. Sending uses Apple Push Notification service and Google Firebase Cloud Messaging. Turn notifications off in your device Settings at any time; the token stops being used.

11. TECHNICAL DATA AND YOUR DEVICE IDENTIFIER
Like every online service, our servers momentarily see your IP address and connection metadata when your device connects. We use it transiently for delivery, rate limiting, and abuse prevention (for example, limiting how many simultaneous connections one address can open). We do not build profiles from it.

We also generate a random identifier for your device and store it in your phone's secure keychain. It is a random string — it contains nothing about you, is not your advertising identifier, and is never shared with anyone. Its only job is safety: it is what stops someone who has been suspended from deleting the app, reinstalling it, and walking straight back in. It is linked to the accounts that have signed in on this device, and to any suspension applied to it.

12. WHAT WE DO NOT DO
• We do not record rooms — no video, no audio, no transcripts of live rooms
• We do not request your contacts or address book
• We do not collect GPS or precise location
• We do not use cookies, web tracking, or advertising identifiers
• We do not show ads, and we do not sell or rent personal data to anyone
• We do not use your content or your conversations to train AI systems

To be precise about the one thing people care most about: "never recorded"
means LIVE ROOM video and audio. It does not mean we hold nothing at all —
the things we do hold are listed in sections 3, 6 and 7; the automated
screen every upload passes through is in section 12a, and the places a
human may look at your content are listed in section 12b.
12a. AUTOMATED SCREENING, BEFORE ANYTHING IS EVEN POSTED
On top of report + block, Rivler runs an automated content-safety filter over
photos and text at the moment you submit them — profile photos, chat photos,
your handle, your bio, and messages — and blocks the worst of it outright,
before it is ever stored or shown to anyone. This is automated pattern
matching, not a person, and it runs on every relevant upload, not only after
a complaint. See section 15 for the processor that performs this scan.

12b. WHEN A HUMAN MAY SEE SOMETHING
We would rather over-explain this than let "never recorded" be read as more
than it is:
• If someone reports your profile photo or a photo/voice note you sent, a
  moderator may open that specific item to decide whether it breaks the rules,
  and may remove it. Reported items are only ever viewed in response to a
  report, never browsed.
• Crash and error diagnostics sent to Firebase include the technical error
  text from the failure. They do not contain your messages or media.
• Report records contain who reported whom, the category, the time, and which
  room it happened in.
Live room video and audio are never in any of this, because they are never
captured in the first place.

12c. DISCOVERY — WHO CAN SEE YOU
Rivler has an Explore tab: a grid of people who are online right now, so the
app still works when the matching queue is quiet.
• While you are online and signed in, other signed-in adults may see a CARD:
  your handle, your avatar, your title if you have one, your country, and any
  interests you and they share. Nothing else.
• Your date of birth is NEVER shown — only a derived age on the profile you
  choose to open.
• Only people who have completed sign-in appear in Explore or can ask
  someone to meet — there is no way to browse or be browsed without an
  account.
• Tapping your card does not connect anyone to you. It sends a request that
  rings, exactly like a call, and nothing happens unless you accept.
• You can switch this off completely: Settings → Discovery → "Show me in
  Explore". With it off you disappear from the grid entirely and can still
  play, message, and use every other part of Rivler.
People you have blocked, and people either of you answered "never again"
about, never see each other in Explore.

13. HOW WE USE INFORMATION
To run the service you asked for (matching, rooms, games, friends, messaging, calls); to keep the community safe (report handling, blocks, abuse prevention, under-18 removal); to maintain and improve Rivler using aggregate statistics; and to communicate service messages. We do not use your information for marketing to third parties.

14. LEGAL BASES (EEA / UK)
Where GDPR / UK GDPR applies we rely on: performance of a contract (running the service — matching, games, friends, messaging); legitimate interests (safety, security, abuse prevention, aggregate analytics); and consent (camera/microphone access, push notifications, optional profile details — each revocable at any time in device Settings or by removing the details). We do not use automated decision-making producing legal effects; the only automated action is removal after repeated community reports, which you can contest at m2mb@info.com. California residents: we do not "sell" or "share" personal information as defined by the CCPA/CPRA, and we honour access and deletion requests as described below.

15. WHO WE SHARE WITH
We share personal data only with the processors that make the service run, each bound to process it solely on our instructions:
• LiveKit — real-time video relay for group rooms and fallback connections (no recording)
• Railway — server hosting
• Supabase — our database host
• OpenAI — automated content-safety screening of photos and text at the moment you submit them (section 12a); used for moderation only, on that single request, never to train any model
• Google Firebase — analytics and push delivery
• Apple — Sign in with Apple and push delivery
• Google — Sign in with Google
• Tenor (Google) — GIF search results (receives your search text only)
We may also disclose information: with your consent; to comply with law or valid legal process; to enforce our Terms or protect the rights, property, or safety of Rivler, our users, or the public; and as aggregate, anonymised statistics that identify no one. If Rivler is involved in a merger, acquisition, or sale of assets, user information may be part of the transferred assets — we will notify you (in-app and/or on this page) of any change in ownership or in how your information is handled.

16. GOVERNMENT AND LAW-ENFORCEMENT REQUESTS
We review every government or law-enforcement request individually and require valid legal process that states its legal basis and identifies the account concerned. We may narrow or reject requests that are overbroad. Where permitted, we may notify affected users. If we receive information giving us a good-faith belief of an emergency involving danger of death or serious physical injury, we may disclose the limited information necessary to prevent that harm — remember that we hold no video or audio of anyone.

17. HOW LONG WE KEEP THINGS
• Account and profile data (handle, profile details, photo): while your account exists
• Friendships, encounter log, ratings, votes, stats and badges: while your account exists
• Messages: until you delete your account (your sent messages are then deleted)
• Chat photos and voice notes: 90 days from sending, then deleted automatically
• Push token: until you disable notifications or delete your account
• Reports (including the category and the media item reported, if any): up to
  24 months, for community safety, even after account deletion
• Rolling database backups: purged within 30 days
There is no video or audio retention because none is ever captured.

18. DELETING YOUR ACCOUNT
In-app: Settings → Delete account removes your device data AND instructs our servers to delete your account record, profile and photo, friendships and requests, the messages and media you sent, your encounter log, ratings and votes you cast, stats, badges and push token immediately; residual copies leave backups within 30 days. No app access? Email m2mb@info.com from any address with your handle and we will delete within 30 days. Three honest caveats: messages and media already delivered to other people's devices may persist on their side; report records about behaviour may be retained for community safety; and if your account or device is under an active suspension, the record of that suspension is retained so deletion cannot be used to escape it. Deletion is permanent — friendships and messages cannot be recovered.

19. YOUR RIGHTS
Depending on where you live, you may have the right to access, correct, export, restrict, object to processing of, or delete your personal data, and to withdraw consent at any time. Exercise any of them by emailing m2mb@info.com — we answer within 30 days and may ask you to verify control of the account first (a safeguard, not an obstacle). If you are in the EEA or UK you may also complain to your data-protection authority (in the UK, the ICO at ico.org.uk).

20. CHILDREN
Rivler is strictly 18+. We do not knowingly collect data from anyone under 18. Discovery of an under-18 account leads to removal and deletion of its data. Report one: m2mb@info.com.

21. SECURITY
All traffic is encrypted in transit (TLS). Media access is token-protected. Access to production systems is restricted and logged. In most one-to-one rooms your video never touches a server at all. No internet service can promise absolute security, but our best protection is structural: we simply do not hold your video, audio, real name, email, or precise location.

22. INTERNATIONAL TRANSFERS
Our processors operate in the United States and Europe. Where data leaves the UK/EEA it is protected by appropriate safeguards (standard contractual clauses or an adequacy decision). By using the service you acknowledge this transfer.

23. CHANGES TO THIS POLICY
If we make material changes we will post the new version here and flag it in the app at least 7 days before it takes effect, so you can review it (or delete your account) first. Continued use after the effective date means you accept the new version.

24. CONTACT
Questions, requests, complaints: m2mb@info.com. We read everything.''';

  static const terms = '''TERMS OF SERVICE & END USER LICENCE AGREEMENT
Rivler — live social video
Effective date: 11 August 2026 · Version 4.1

These Terms are a binding contract between you and Rivler ("Rivler", "we", "us"). They incorporate our Privacy Policy and House Rules by reference. By creating an account, ticking the boxes at sign-in, or using Rivler in any way, you agree to all of them; if you do not agree, do not use the service. If we publish additional rules for specific features ("Additional Terms"), those apply too.

1. ELIGIBILITY
You must be at least 18 years old and legally able to enter this agreement. By using Rivler you warrant that you are. We cannot independently verify every user's age, and we accept no liability where information you provide is untruthful — but discovery of an under-18 user leads to immediate, permanent removal. IF YOU ARE UNDER 18, DO NOT ATTEMPT TO REGISTER OR USE THE SERVICE. You may hold one account, for your own personal, non-commercial use only.

2. THE SERVICE
Rivler connects you into live video rooms with people you don't know (always one-to-one for strangers), lets you browse people who are online and invite them to meet (they choose whether to accept), supports rooms you create with friends, and — when two people choose each other — friendships with messaging and calls. Games run inside rooms. We may add, change, or remove features at any time as the service evolves.

3. YOUR ACCOUNT AND SECURITY
Rivler requires an account — Sign in with Apple on iOS, Sign in with Google on Android. There is no guest mode: a real, verifiable identity is what lets suspensions actually stick, and it is why the graph of friends and messages survives a reinstall. Your account is yours alone: do not sell, transfer, or share it, and do not let anyone else use it. You may not choose a handle you have no right to use or one intended to impersonate another person. You are responsible for activity on your account. If we must resolve a dispute over who owns an account, our determination (which may include suspension or termination) is final. Tell us immediately at m2mb@info.com about any unauthorised use.

4. FREE SERVICE AND RIVLR+ SUBSCRIPTIONS
Rivler is free to use. Meeting strangers, messaging, rooms and games cost nothing and always will — every way into a room is open to every account.

Rivler+ is an optional paid subscription that unlocks: choosing which gender of people you are matched with; seeing the list of people who said they would meet you again; and priority position in the matching queue. Nothing about safety, moderation, friends you have already made, or your ability to talk to people you have already met is ever placed behind payment.

Subscriptions are sold through the app store you installed Rivler from — the App Store on iOS, Google Play on Android. The exact price and billing period are shown to you inside the app before you buy, in your own currency, and payment is charged to your Apple ID or Google Play account on confirmation. A subscription renews automatically for the same period at the same price unless you cancel at least 24 hours before the current period ends. Cancel any time in your Apple ID or Google Play subscription settings; cancelling stops future renewals and you keep access until the paid period runs out. We do not charge you separately and we never store your card details — your app store handles all billing.

Refunds are handled by Apple or Google under their own policies, not by us; we cannot issue or refuse them, though we will help you contact them. Except where the law requires otherwise, part-used periods are not refunded. If your subscription lapses or is refunded, paid features switch off — any filter you had set returns to meeting everyone — and everything free about your account, including your friends and messages, is unaffected.

We may change what Rivler+ includes or what it costs. Price rises and material reductions take effect only for periods beginning after we have told you, and your app store will ask you to agree to a price increase before it is charged. If a paid feature depends on other people being online — the matching filter especially — we cannot promise anyone will be available at a given moment; the app shows you honest live numbers so you can judge for yourself.

5. HOUSE RULES — ZERO TOLERANCE FOR OBJECTIONABLE CONTENT
You agree that you will NOT, in any room, message, profile, or other content:
(a) display nudity or sexual content, or behave sexually toward anyone
(b) harass, bully, threaten, defame, or abuse anyone, or promote hatred against any person or group
(c) display or promote violence, weapons, self-harm, drugs, or illegal acts, or content depicting cruelty
(d) be, solicit, or in any way sexualise anyone under 18 — this results in an immediate permanent ban and a report to authorities
(e) impersonate any person or entity, or misrepresent your affiliation with anyone
(f) record, screenshot, screen-capture, or redistribute ANY portion of a room or anyone's face, voice, or messages without the express consent of everyone involved
(g) share anything another user asked to keep private, on Rivler or anywhere else
(h) spam, advertise, solicit for commercial purposes, or promote pyramid schemes, gambling, or "get rich" ventures
(i) harvest, scrape, or collect other users' information, or solicit personal information from anyone
(j) upload malware or any code designed to disrupt the service, probe or overload our systems, or access anything not intentionally made available to you
(k) copy the service's features to build a competing product, or solicit our users for one
(l) break any applicable law or regulation.
We may investigate any of the above and take any action we consider appropriate, including removing content, suspending or permanently terminating accounts, and reporting to law enforcement.

6. MODERATION
Before anything is even shown to anyone, an automated filter screens photos and text you submit — profile photos, chat photos, your handle and bio, and messages — for content that breaks these Terms, and blocks the worst of it outright at the moment you try to send it.

Reporting is also one tap away in every room, chat and profile, and asks what kind of problem it is — child safety, nudity or sexual content, harassment or hate, violence or threats, impersonation, or something else. Blocks are instant and permanent: a blocked person can never be matched with you again.

Every report reaches a human review queue, ordered by severity, and we act within 24 hours — child-safety and nudity reports are handled ahead of everything else. Outcomes include removing a profile photo or other content, temporarily suspending an account, and permanently removing it.

Reports are a signal, not an automatic verdict: we weigh how many independent people reported you, their standing, how recent it is, and how serious the category, and only a strong combination triggers an automatic temporary suspension pending review. Permanent removal is a decision made by a person. Suspensions may be applied to an account and to the device it used, so deleting and reinstalling the app does not undo them.

We may remove any content or user at our discretion to keep the community safe, and we report illegal material to the appropriate authorities.

7. YOUR CONTENT AND LICENCES
Live video and audio: they belong to you, and WE DO NOT RECORD THEM. You grant us only the limited, technical, non-exclusive licence required to transmit them in real time to the members of your room. No recording exists, so no further licence is needed or taken.
Stored content: things you deliberately create and send — messages, photos, voice notes, GIF selections, your profile (handle, bio, photo, details) — remain yours. You grant us a limited, non-exclusive, royalty-free, worldwide licence to host, store, reproduce, technically adapt (e.g. compressing a photo for phones), and transmit that content SOLELY to operate the service and deliver your content to the people you sent it to. This licence is not for advertising, is not sublicensable for any other purpose, does not permit sale of your content, and does not permit AI training on it. It ends when your content is deleted under the retention schedule in the Privacy Policy — except that copies already delivered to recipients may remain with them, exactly as an SMS you sent remains on your friend's phone.
Feedback: if you send us ideas or suggestions, we may use them without obligation to you.
You represent that you have all rights needed to share whatever you share, and that it complies with these Terms. Be aware that recipients of your messages can save or copy them outside the app; share accordingly.

8. MEETING PEOPLE; YOUR SAFETY
Rivler connects strangers by design. We do not run background checks and cannot verify the identity, intentions, honesty, or age of any user. Exercise the same judgement you would meeting anyone new: never share your address, financial details, or identifying documents; be cautious about arranging in-person meetings; and use report and block freely — they exist for you. Any interaction, exchange, or in-person meeting between you and another user is solely between the two of you. Rivler is not an emergency service; if you are in danger, contact local emergency services.

9. USER DISPUTES
If you have a dispute with another user, we are under no obligation to become involved, though we may act on reports under Section 6. To the maximum extent permitted by law, you release Rivler and its personnel from claims, demands, and damages of every kind arising out of or connected with such disputes.

10. THIRD-PARTY SERVICES
The service uses third-party providers (video relay, hosting, database, analytics, push delivery, GIF search, automated content moderation) and may contain links or content from services we do not control. We are not responsible for third-party services, their content, or their privacy practices, and your dealings with any third party are between you and them. GIFs are provided by Tenor and subject to its terms.

11. APP LICENCE
We grant you a personal, revocable, non-exclusive, non-transferable licence to install and use the Rivler app on devices you own or control, for your personal use, subject to these Terms and the app store's rules. You may not copy, modify, distribute, sell, lease, reverse-engineer, or create derivative works from the app or service except where the law expressly permits.

12. INTELLECTUAL PROPERTY
The service — including its code, design, graphics, sounds, game formats, and trademarks — is owned by Rivler or its licensors and protected by intellectual-property law. Apart from the licences expressly granted here, no rights are transferred to you. You agree not to use, reproduce, or exploit any part of the service or any content that is not yours without permission.

13. APPLE-SPECIFIC TERMS
These Terms are between you and Rivler, not Apple. Apple has no obligation to furnish maintenance or support, and no warranty obligation beyond refunding any purchase price, if any. Apple is not responsible for claims relating to the app (product liability, legal compliance, consumer protection, IP). Apple and its subsidiaries are third-party beneficiaries of these Terms and may enforce them against you. You warrant you are not in an embargoed country or on any restricted-parties list, and you will comply with applicable third-party agreements (e.g. your data plan).

14. GOOGLE PLAY-SPECIFIC TERMS
Where you obtained the app from Google Play, Google is not a party to these Terms, provides no warranty or support for the app, and has no liability for it; your use also complies with the Google Play Terms of Service.

15. SUSPENSION AND TERMINATION
You may stop using Rivler and delete your account at any time (Settings → Delete account, or /delete-account). We may suspend or terminate your access at any time, with or without notice, if we reasonably believe you have broken these Terms or the House Rules, or to protect the service or its users. On termination your licences end and your data is handled as described in the Privacy Policy. Sections that by their nature survive termination (content licences already exercised, disclaimers, liability limits, indemnity, disputes) survive.

16. EARLY ACCESS; DISCLAIMER OF WARRANTIES
Rivler is a young, evolving service. THE SERVICE AND ALL CONTENT ARE PROVIDED "AS IS" AND "AS AVAILABLE", WITHOUT WARRANTIES OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, NON-INFRINGEMENT, OR THAT THE SERVICE WILL BE UNINTERRUPTED, SECURE, OR ERROR-FREE. WE MAKE NO WARRANTY ABOUT ANY CONTENT, USER, OR IDENTITY, AND YOU ACCESS ALL OF IT AT YOUR OWN RISK. Nothing in these Terms limits rights that consumer law grants you that cannot be limited.

17. LIMITATION OF LIABILITY
TO THE FULLEST EXTENT PERMITTED BY LAW, RIVLR AND ITS PERSONNEL SHALL NOT BE LIABLE FOR ANY INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, PUNITIVE, OR EXEMPLARY DAMAGES — INCLUDING LOST PROFITS, LOST DATA, LOSS OF GOODWILL, OR THE CONDUCT OF OTHER USERS OR THIRD PARTIES — ARISING FROM OR RELATING TO THE SERVICE, EVEN IF ADVISED OF THE POSSIBILITY. OUR TOTAL LIABILITY FOR ALL CLAIMS WILL NOT EXCEED THE GREATER OF THE AMOUNT YOU PAID US IN THE LAST 12 MONTHS OR £50. Nothing here excludes liability that cannot lawfully be excluded (including for death or personal injury caused by negligence, or fraud).

18. INDEMNITY
You agree to indemnify and hold Rivler and its personnel harmless from claims, liabilities, damages, losses, and expenses (including reasonable legal fees) arising from your content, your use of the service, your violation of these Terms, or your violation of any law or third-party right, including actions taken through your account.

19. DISPUTE RESOLUTION AND GOVERNING LAW
Talk to us first: before bringing any formal claim, email m2mb@info.com with a description of the dispute, and both sides will attempt in good faith to resolve it within 30 days — most things get fixed this way. These Terms are governed by the laws of England and Wales, and disputes are subject to the exclusive jurisdiction of its courts — except where the law of your country of residence grants you mandatory consumer protections and venue, which remain yours. To the extent permitted by applicable law, claims must be brought in your individual capacity, not as a claimant or class member in any class, consolidated, or representative proceeding; where such a limit is unenforceable in your jurisdiction, it does not apply to you.

20. ASSIGNMENT
You may not assign or transfer these Terms or your account. We may assign these Terms (for example, in a merger or sale) — your rights under them are unaffected.

21. SEVERABILITY; NO WAIVER; ENTIRE AGREEMENT
If any provision of these Terms is found unenforceable, it will be limited to the minimum extent necessary and the rest remain in full force. Our failure to enforce any provision is not a waiver of it. These Terms, the Privacy Policy, the House Rules, and any Additional Terms are the entire agreement between you and us about the service, and supersede prior understandings. Nothing in these Terms creates any employment, agency, or partnership relationship, and you may not bind Rivler in any way.

22. CHANGES TO THESE TERMS
We may update these Terms as the service evolves. Material changes are posted here and flagged in the app at least 7 days before taking effect; continued use after that means you accept them. If you do not accept a change, stop using the service and delete your account before the change takes effect.

23. CONTACT
Questions about these Terms: m2mb@info.com.''';

  static const rules = '''THE HOUSE RULES

Four rules. They keep this place good.

1. 18+ ONLY
Everyone here is an adult. No exceptions, no "almost".

2. BE DECENT ON CAMERA
No nudity. No harassment, hate, or threats. No violence, weapons, or drugs. Instant, permanent ban.

3. NEVER RECORD ANYONE
We never record rooms — that's a promise. You don't record them either. No screenshots, no screen-capture, no sharing anyone's face without consent.

4. THE ROOM PROTECTS ITSELF
Long-press any face to report or block — one tap, instant. Photos and messages are also auto-screened before they ever post. Community reports remove people automatically. Blocked people can never be matched with you again.

Breaking these gets you removed. The room decides fast.''';

  static const about = '''Rivler — you never know who you'll get.

A live social platform. Press one button and, seconds later, you're face-to-face with people you've never met — sometimes one, sometimes a room. Talk as long as you like; play a game whenever the vibe calls for it; the room votes, and the wheel decides what happens next.

Never recorded. Ever. That's why people are actually themselves here.

Not a dating app. Not a lobby. The most unpredictable place on the internet.

Made with care. This is an early build — thank you for being here first.''';
}
