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
  static const String googleServerClientId =
      String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID', defaultValue: '');
  static bool get googleEnabled => googleServerClientId.isNotEmpty;
}
