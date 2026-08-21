import 'dart:io' show Platform;

/// App configuration.
///
/// [backend] is empty by default, which runs Rivler in **simulated mode** (the
/// people, matches and games are generated locally — perfect for a solo
/// TestFlight demo, no servers needed). Point it at your deployed Railway server
/// to go **live** with real strangers + LiveKit video:
///
///   flutter run --dart-define=RIVLR_BACKEND=wss://your-app.up.railway.app/ws
class AppConfig {
  AppConfig._();

  // Defaults to the live Railway backend, so every build is live with no
  // Codemagic changes. Override for a simulated build with:
  //   --dart-define=RIVLR_BACKEND=
  static const String backend = String.fromEnvironment(
    'RIVLR_BACKEND',
    defaultValue: 'wss://whatif-production-051b.up.railway.app/ws',
  );

  static bool get isLive => backend.isNotEmpty;

  /// Google Sign-In. This is the WEB application OAuth client id from Google
  /// Cloud — the same value the server holds as GOOGLE_CLIENT_ID, because
  /// it's the audience Google mints the idToken for. Empty (the default)
  /// hides the Google button entirely, so an unconfigured build can never
  /// show a dead button. Set in Codemagic with:
  ///   --dart-define=GOOGLE_SERVER_CLIENT_ID=xxxx.apps.googleusercontent.com
  /// Defaults to the real WEB client id from the rivler-3064b project. This
  /// is NOT a secret — it ships inside google-services.json in every Android
  /// build by design — and defaulting it means one less thing to get wrong in
  /// CI. The dart-define still overrides it for a different environment.
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '245988086284-hpdj8nk9pt5as7hpquetrd39bdsarss5.apps.googleusercontent.com',
  );

  /// The iOS OAuth client id. Google Sign-In on iOS ALSO needs native config
  /// the Dart layer can't supply — a GIDClientID and a matching reversed-id
  /// URL scheme in Info.plist. Without those the sheet opens and dies, which
  /// is a dead button in front of a reviewer. So the iOS Google button only
  /// appears once this is set, and setting it is the same moment you add the
  /// plist entries. Android needs none of this.
  ///   --dart-define=GOOGLE_IOS_CLIENT_ID=xxxx.apps.googleusercontent.com
  static const String googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
    defaultValue: '245988086284-1118vejf3c4igo4idrg43olfqtet1p6h.apps.googleusercontent.com',
  );

  /// Google sign-in is offerable at all: the server can verify the token
  /// (server client id) AND, on iOS only, the native side is configured too.
  static bool get googleEnabled =>
      googleServerClientId.isNotEmpty &&
      (!Platform.isIOS || googleIosClientId.isNotEmpty);
}
