import 'package:google_sign_in/google_sign_in.dart';
import '../config.dart';
import '../net/network_client.dart';
import '../state/session.dart';
import 'analytics.dart';

/// One Sign-in-with-Google flow — the Android mirror of apple_auth.dart,
/// same shape on purpose. Scopes deliberately EMPTY: we take only the
/// anonymous identifier, exactly as with Apple.
///
/// The identity model is identical: your uid never changes; Google links to
/// it as a recovery key. If this Google account already belongs to a Rivler
/// account (reinstall / new phone), the server's welcome hands back the
/// canonical uid and the whole graph returns.
///
/// We send the ID TOKEN, not just the id string — the id alone is a claim
/// anyone could make; the token is signed by Google and verified server-side
/// against Google's published keys.
Future<bool> googleSignIn() async {
  if (!AppConfig.googleEnabled) return false;
  try {
    final g = GoogleSignIn(
      scopes: const [],
      // the WEB client id — Google mints the idToken's audience for this,
      // which is what the server's GOOGLE_CLIENT_ID verifies against
      serverClientId: AppConfig.googleServerClientId,
      // iOS needs its OWN client id as well. Passing it here keeps the Dart
      // define authoritative instead of depending on a GIDClientID in
      // Info.plist being kept in sync by hand. (Android ignores this — it
      // identifies the app by package name + SHA-1 instead.)
      clientId: AppConfig.googleIosClientId.isEmpty
          ? null
          : AppConfig.googleIosClientId,
    );
    final account = await g.signIn();
    if (account == null) return false; // user closed the sheet
    final auth = await account.authentication;
    final idToken = auth.idToken;
    if (idToken == null || idToken.isEmpty) return false;
    Track.event('google_signin');
    AppSession.instance.setGoogleIdentity(account.id, token: idToken);
    NetworkClient.instance.hello(); // link (or recover) on the server
    return true;
  } catch (_) {
    return false;
  }
}
