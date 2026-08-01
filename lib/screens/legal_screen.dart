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

/// Placeholder legal + info copy. Replace before launch.
class LegalCopy {
  LegalCopy._();

  static const privacy = '''PLACEHOLDER — replace with your real Privacy Policy.

WhatIf is a live social app for adults (18+). This is a summary of how we intend to handle your data:

• Camera & microphone are used only to connect you live with other people. We do not record or store your video or audio.

• We use age assurance to keep the community 18+. Reports and blocks are reviewed to keep people safe.

• We collect the minimum needed to run matchmaking and keep the service safe. We do not sell your personal data.

• You can delete your account and associated data at any time from Settings.

Contact: privacy@whatif.example

Last updated: replace-me.''';

  static const terms = '''PLACEHOLDER — replace with your real Terms of Service.

By using WhatIf you agree to:

• You are 18 years or older.

• Be kind. Harassment, nudity, hate, threats and illegal content are not allowed and may result in a permanent ban.

• You are responsible for your own conduct on live calls. Use Report/Block if someone crosses the line — it’s always one tap away.

• The service is provided “as is” while in early access.

Contact: support@whatif.example

Last updated: replace-me.''';

  static const about = '''WhatIf — what happens tonight?

A live social platform. Press one button and, seconds later, you’re face-to-face with people you’ve never met — sometimes one, sometimes a room. A quick game breaks the ice, then the moment moves on. You never know who’s next.

Not a dating app. Not a lobby. Just the most fun place on the internet after dark.

Made with care. This is an early build — thank you for being here first.''';
}
