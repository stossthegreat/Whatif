import 'package:firebase_core/firebase_core.dart';

/// Firebase project keys. Everything ships wired but DORMANT until the real
/// keys land here — no crashes, no fake data, analytics simply no-ops.
///
/// TO GO LIVE: create the iOS app (bundle id com.rivlr.app) in the Firebase
/// console, download GoogleService-Info.plist, and copy these five values out
/// of it, then flip [configured] to true:
///   API_KEY            -> apiKey
///   GOOGLE_APP_ID      -> appId
///   GCM_SENDER_ID      -> messagingSenderId
///   PROJECT_ID         -> projectId
///   BUNDLE_ID          -> iosBundleId (must be com.rivlr.app)
/// (We initialize from Dart, so the plist itself never needs to be added to
/// the Xcode project.)
class FirebaseCfg {
  static const bool configured = false;

  static FirebaseOptions get ios => const FirebaseOptions(
        apiKey: 'PASTE_API_KEY',
        appId: 'PASTE_GOOGLE_APP_ID',
        messagingSenderId: 'PASTE_GCM_SENDER_ID',
        projectId: 'PASTE_PROJECT_ID',
        iosBundleId: 'com.rivlr.app',
      );
}
