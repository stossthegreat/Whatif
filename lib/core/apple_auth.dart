import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../net/network_client.dart';
import '../state/session.dart';
import 'analytics.dart';

/// One Sign-in-with-Apple flow, used everywhere: onboarding, the settings
/// upsell, and the after-a-match nudge. Scopes deliberately EMPTY — we take
/// only the anonymous identifier, exactly as the privacy policy promises.
///
/// The identity model: your uid never changes; Apple links to it as a
/// recovery key. If this Apple id already belongs to an account (reinstall),
/// the server's welcome hands back the canonical uid and the session adopts
/// it — the whole graph returns.
Future<bool> appleSignIn() async {
  try {
    final cred = await SignInWithApple.getAppleIDCredential(scopes: const []);
    final auid = cred.userIdentifier;
    if (auid == null || auid.isEmpty) return false;
    Track.event('apple_signin');
    AppSession.instance.setAppleIdentity(auid);
    NetworkClient.instance.hello(); // link (or recover) on the server
    return true;
  } catch (_) {
    return false;
  }
}
