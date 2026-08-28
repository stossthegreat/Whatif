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
/// Why the last attempt failed, in the platform's own words, or null when it
/// worked or the user simply closed the sheet.
///
/// This used to be `catch (_)` and the screen said "didn't work — try again",
/// which is indistinguishable between a cancelled sheet, an unregistered
/// signing certificate, and a network blip. The three have completely
/// different fixes, and on Android the common one is silent by design:
///
///   PlatformException(sign_in_failed, ...ApiException: 10)
///       DEVELOPER_ERROR. Google could not match this app to an OAuth client.
///       It compares the package name (com.rivler.app) AND the certificate
///       the installed APK was signed with. A debug-signed build carries a
///       throwaway key that can never be registered, so this fires no matter
///       how many fingerprints are added in Firebase.
///
///   idToken == null after a successful sign-in
///       The account came back but Google would not mint a token for
///       serverClientId — that web client is in a different project from the
///       Android OAuth client, or the id is wrong.
String? lastGoogleError;

Future<bool> googleSignIn() async {
  lastGoogleError = null;
  if (!AppConfig.googleEnabled) {
    lastGoogleError = 'Google sign-in is not configured in this build';
    return false;
  }
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
    if (account == null) return false; // user closed the sheet — not an error
    final auth = await account.authentication;
    final idToken = auth.idToken;
    if (idToken == null || idToken.isEmpty) {
      // Signed in, but Google refused to issue a token for our audience.
      lastGoogleError = 'Signed in, but no ID token was issued for '
          'serverClientId — check that the web client and the Android OAuth '
          'client are in the same Google Cloud project';
      Track.event('google_signin_no_token');
      return false;
    }
    Track.event('google_signin');
    AppSession.instance.setGoogleIdentity(account.id, token: idToken);
    NetworkClient.instance.hello(); // link (or recover) on the server
    return true;
  } catch (e) {
    lastGoogleError = e.toString();
    // Truncated, because a PlatformException prints a paragraph and the
    // useful part — the status code — is at the front.
    Track.event('google_signin_error', {
      'err': lastGoogleError!.substring(0, lastGoogleError!.length.clamp(0, 90)),
    });
    return false;
  }
}
