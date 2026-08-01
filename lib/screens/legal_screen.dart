import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../widgets/glass.dart';

/// A simple pushed page for Privacy, Terms and About — a title + scrollable body.
/// The copy here is a clear placeholder; replace with your real legal text before
/// launch.
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
Effective date: 1 August 2026

This policy explains what Rivlr ("we", "us") collects, why, and what we never do with it. We built Rivlr to need as little of your data as possible — the product is the people, not their data.

1 · WHAT WE COLLECT

Identity you give us. A handle you choose (no real name required), your age, gender, who you want to meet, and the vibes you pick. These are stored on your device and sent to our servers only to run matchmaking.

Camera and microphone. Rivlr is a live video app: your camera and mic stream to the people in your room, in real time, through our video infrastructure (LiveKit). WE DO NOT RECORD, STORE, OR ANALYSE YOUR VIDEO OR AUDIO. When a room ends, the stream is gone.

Gameplay. Round results, votes, reactions, sparks (people you save) and reports exist in server memory while you play and are used to run the game and keep people safe.

Technical basics. Connection data (such as IP address) is processed transiently to deliver the service, as with any internet app.

2 · WHAT WE NEVER DO

We do not sell your personal data. We do not show you ads based on your data. We do not record your rooms. We do not ask for your contacts, location, or real name.

3 · SAFETY PROCESSING

When you report or block someone, we process that report — including the reporter and reported handles — to protect the community. Repeatedly reported accounts are removed. Blocks are permanent: we use your block list to make sure you are never matched with that person again.

4 · WHERE DATA LIVES

Profile basics live on your device. Live session state lives in server memory and is not written to long-term storage. Video flows through LiveKit's real-time infrastructure and is not retained.

5 · YOUR CONTROLS

Delete your data any time: Settings → Delete account wipes your identity and preferences from the device and abandons your server identity. You can also revoke camera/microphone access in iOS Settings at any point.

6 · AGE

Rivlr is strictly for adults (18+). If we become aware of an under-18 account we will remove it.

7 · CHANGES & CONTACT

If this policy changes materially we will show you the new version in the app.

Questions or requests: appsdevelop2025@gmail.com''';

  static const terms = '''TERMS OF SERVICE
Effective date: 1 August 2026

Welcome to Rivlr. These terms are a deal between you and us — short version: be an adult, be decent on camera, and don't ruin the room.

1 · WHO CAN USE RIVLR

You must be 18 or older. By creating an account you confirm you are. No exceptions.

2 · THE SERVICE

Rivlr connects you by live video with other people — sometimes one, sometimes a group — and runs short games in the room. Rooms are live and unmoderated in real time: you will meet real strangers, and what they do is their responsibility, not ours. Use Report and Block (long-press any face) whenever someone crosses a line.

3 · THE RULES OF THE ROOM

You agree not to:
• be nude, sexually explicit, or sexually solicit anyone;
• harass, threaten, bully, or hate on anyone — including for who they are;
• show violence, self-harm, weapons, drugs, or illegal activity;
• record, screenshot, or redistribute other people's video without their consent;
• impersonate others, spam, advertise, or scam;
• attempt to identify, stalk, or contact people against their wishes;
• use Rivlr if you are under 18.

Breaking these rules can mean instant removal and a permanent ban. Community reports trigger automatic removal at a threshold — the room protects itself.

4 · YOUR CONTENT

Your live video belongs to you. You grant us only the technical licence needed to transmit it to the people in your room in real time. We do not record it.

5 · EARLY ACCESS

Rivlr is in active development and is provided "as is" and "as available", without warranties of any kind. Features may change, break, or disappear. We may suspend or terminate the service, or any account, at any time to protect the community.

6 · LIABILITY

To the maximum extent permitted by law, we are not liable for indirect, incidental, or consequential damages arising from your use of Rivlr, including the conduct of other users. Nothing in these terms limits liability that cannot be limited by law.

7 · CONTACT

appsdevelop2025@gmail.com''';

  static const about = '''Rivlr — you never know who you'll get.

A live social platform. Press one button and, seconds later, you're face-to-face with people you've never met — sometimes one, sometimes a room. Games break the ice, the room votes, the wheel decides what happens next.

Not a dating app. Not a lobby. The most unpredictable place on the internet.

Made with care. This is an early build — thank you for being here first.''';
}
