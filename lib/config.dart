/// App configuration.
///
/// [backend] is empty by default, which runs Rivlr in **simulated mode** (the
/// people, matches and games are generated locally — perfect for a solo
/// TestFlight demo, no servers needed). Point it at your deployed Railway server
/// to go **live** with real strangers + LiveKit video:
///
///   flutter run --dart-define=RIVLR_BACKEND=wss://your-app.up.railway.app/ws
class AppConfig {
  AppConfig._();

  static const String backend =
      String.fromEnvironment('RIVLR_BACKEND', defaultValue: '');

  static bool get isLive => backend.isNotEmpty;
}
