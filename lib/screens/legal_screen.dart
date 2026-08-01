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

/// Rivlr legal + info copy.
class LegalCopy {
  LegalCopy._();

  static const privacy = '''PRIVACY POLICY
Rivlr — live social video
Effective date: 1 August 2026 · Version 2.0

This policy explains what Rivlr ("Rivlr", "we", "us", "our") collects, why we collect it, how long we keep it, and the choices you have. We designed Rivlr to need as little of your data as possible: the product is live conversation between people, not their data.

1. WHO WE ARE
Rivlr is a live social video app for adults (18+). Contact for all privacy matters: appsdevelop2025@gmail.com.

2. INFORMATION WE COLLECT

2.1 Information you provide
• A handle you choose (no real name required, and we ask you not to use one)
• Your age (to enforce our 18+ policy), gender, who you want to meet, and the "vibes" you select
• Reports you file about other users

2.2 Camera and microphone
Rivlr is a live video app. When you are in a room, your camera and microphone stream IN REAL TIME to the other people in that room via our video infrastructure provider (LiveKit, Inc.). WE DO NOT RECORD, STORE, OR ANALYSE YOUR VIDEO OR AUDIO. When a room ends, the stream ends. There is no archive, no server-side capture, and no machine analysis of your face or voice.

2.3 Gameplay and session data
While you play: round answers, votes, reactions, the people you save ("sparks"), and blocks/reports are processed in server memory to run the room and keep it safe. Your device stores your own stats (streak, badges, moments text cards) locally.

2.4 Technical data
Connection metadata (such as IP address and connection identifiers) is processed transiently to deliver the service, as with any internet application. We do not build advertising or tracking profiles from it.

3. WHAT WE DO NOT DO
• We do not sell or rent your personal data — to anyone, ever
• We do not serve targeted advertising
• We do not record rooms
• We do not request your contacts, precise location, or real name
• We do not use your video or audio to train AI systems

4. HOW WE USE INFORMATION
• To match you into rooms consistent with your stated preferences
• To run the games (tallies, votes, awards) in real time
• To enforce safety: processing reports and blocks, removing repeatedly-reported accounts, and preventing blocked users from being matched together again
• To operate, debug, and secure the service

5. LEGAL BASES (EEA/UK USERS)
Where GDPR/UK GDPR applies, we process your data on the bases of: performance of a contract (running the service you asked for), legitimate interests (safety, security, abuse prevention), and consent (camera/microphone access, which you may revoke at any time in iOS Settings).

6. SHARING
We share data only with:
• Other users in your room — your live video/audio, handle and gameplay actions (that is the product)
• LiveKit, Inc. — real-time transit of video/audio (not retained)
• Infrastructure providers that host our matchmaking server
We never share with data brokers or advertisers. We may disclose information if required by law or to protect users from imminent harm.

7. RETENTION
• Live video/audio: never retained (real-time transit only)
• Room/session state (answers, votes): held in server memory only; discarded when the room ends or shortly after
• Reports and blocks: retained as long as needed to protect the community
• Profile basics (handle, age, preferences, vibes): stored on your device; the stable identifier is retained server-side while your account exists
• Deleting your account (Settings → Delete account) wipes your device data and abandons your server identity

8. YOUR RIGHTS
Depending on where you live (including GDPR, UK GDPR and CCPA/CPRA), you may have rights to access, correct, delete, or port your data, to object to processing, and to not be discriminated against for exercising rights. Because we hold so little, the fastest path is usually Settings → Delete account. For anything else, email appsdevelop2025@gmail.com — we respond within 30 days. California residents: we do not "sell" or "share" personal information as defined by the CCPA/CPRA.

9. CHILDREN
Rivlr is strictly 18+. We do not knowingly permit anyone under 18 to use the service. If we become aware of an under-18 account we will remove it. To report one: appsdevelop2025@gmail.com.

10. SECURITY
Video and audio travel over encrypted connections. Server-side session state is minimal by design — the best protection for data is not holding it.

11. INTERNATIONAL TRANSFERS
Our infrastructure may process data in other countries. Where required, we rely on appropriate safeguards such as standard contractual clauses.

12. CHANGES
If we make material changes we will present the updated policy in the app before it takes effect.

13. CONTACT
appsdevelop2025@gmail.com''';

  static const terms = '''TERMS OF SERVICE & END USER LICENCE AGREEMENT
Rivlr — live social video
Effective date: 1 August 2026 · Version 2.0

These terms are a binding agreement between you and Rivlr ("we", "us"). By creating an account or using Rivlr you accept them. Short version: be an adult, be decent on camera, never record anyone, and the room can remove you.

1. ELIGIBILITY
You must be at least 18 years old. By using Rivlr you represent that you are. Accounts belonging to under-18s are removed on discovery, without notice.

2. THE SERVICE
Rivlr connects you by live video with other people — sometimes one person, sometimes a group — and offers short games inside the room. Rooms are live: you will meet real strangers whose behaviour we do not control in real time. Rivlr provides safety tools (report, block, instant leave) and automated removal driven by community reports; use them.

3. HOUSE RULES (ZERO TOLERANCE)
You agree that you will NOT:
(a) appear nude, engage in sexual activity, or sexually solicit anyone;
(b) harass, bully, threaten, or demean anyone, including on the basis of race, ethnicity, religion, disability, sex, gender identity, or sexual orientation;
(c) display or promote violence, self-harm, weapons, drugs, or any illegal activity;
(d) record, screenshot, screen-capture, or redistribute other people's video, audio, or likeness — with or without intent to share;
(e) impersonate any person, spam, advertise, solicit money, or scam;
(f) attempt to identify, locate, stalk, or contact people against their wishes;
(g) circumvent bans, age controls, or safety systems.

There is NO TOLERANCE for objectionable content or abusive users. Violations may result in immediate, permanent removal without warning. Community reports trigger automatic removal at a threshold. We may review reported conduct and act on it at our sole discretion.

4. YOUR CONTENT AND LICENCE
Your live video and audio belong to you. You grant us only the limited, technical licence required to transmit them in real time to the members of your room. We do not record them, so no further licence is needed or taken.

5. APP LICENCE
We grant you a personal, non-exclusive, non-transferable, revocable licence to use the Rivlr app on Apple-branded devices you own or control, subject to these terms and Apple's usage rules.

6. APPLE-SPECIFIC TERMS
These terms are between you and Rivlr, not Apple. Apple has no obligation to provide maintenance or support, and no warranty obligations — any warranty claims are our responsibility. Apple is not responsible for addressing claims relating to the app (including product liability, regulatory non-compliance, or IP claims by third parties). Apple and its subsidiaries are third-party beneficiaries of these terms and may enforce them against you. You represent that you are not located in an embargoed country and are not on any restricted-parties list.

7. SUSPENSION AND TERMINATION
We may suspend or terminate the service, or your access to it, at any time — including to protect the community, comply with law, or discontinue the product. You may stop using Rivlr and delete your account at any time in Settings.

8. EARLY ACCESS; DISCLAIMER
Rivlr is under active development and is provided "AS IS" and "AS AVAILABLE", without warranties of any kind, express or implied, including fitness for a particular purpose and non-infringement. We do not warrant that the service will be uninterrupted or error-free, or that any particular person you meet will behave lawfully or decently.

9. LIMITATION OF LIABILITY
To the maximum extent permitted by law: we are not liable for indirect, incidental, special, consequential, or punitive damages, or for the conduct of any user, whether online or offline. Our total liability for any claim will not exceed the greater of the amount you paid us in the last 12 months (currently zero) or £50. Nothing in these terms limits liability that cannot lawfully be limited.

10. INDEMNITY
You will indemnify us against claims arising from your breach of these terms or your conduct on the service.

11. CHANGES
We may update these terms; material changes will be presented in the app. Continuing to use Rivlr after changes take effect means you accept them.

12. GOVERNING LAW
These terms are governed by the laws of England and Wales, and disputes are subject to the exclusive jurisdiction of its courts, except where the law of your country of residence grants you mandatory protections and venue.

13. CONTACT
appsdevelop2025@gmail.com''';

  static const rules = '''THE HOUSE RULES

Four rules. They keep this place good.

1. 18+ ONLY
Everyone here is an adult. No exceptions, no "almost".

2. BE DECENT ON CAMERA
No nudity. No harassment, hate, or threats. No violence, weapons, or drugs. Instant, permanent ban.

3. NEVER RECORD ANYONE
We never record rooms — that's a promise. You don't record them either. No screenshots, no screen-capture, no sharing anyone's face without consent.

4. THE ROOM PROTECTS ITSELF
Long-press any face to report or block — one tap, instant. Community reports remove people automatically. Blocked people can never be matched with you again.

Breaking these gets you removed. The room decides fast.''';

  static const about = '''Rivlr — you never know who you'll get.

A live social platform. Press one button and, seconds later, you're face-to-face with people you've never met — sometimes one, sometimes a room. Talk as long as you like; play a game whenever the vibe calls for it; the room votes, and the wheel decides what happens next.

Never recorded. Ever. That's why people are actually themselves here.

Not a dating app. Not a lobby. The most unpredictable place on the internet.

Made with care. This is an early build — thank you for being here first.''';
}
