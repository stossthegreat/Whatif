import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_config.dart';

/// One tiny funnel for every signal we care about. Fail-soft everywhere: if
/// Firebase isn't configured (keys not pasted yet) or init fails, every call
/// is a silent no-op — analytics must never crash the product it measures.
///
/// The vocabulary (keep it small, keep it stable — renaming events later
/// destroys history):
///   screens  — every app step: home, mode, party, finding, live, …
///   play_pressed {mode}         — roulette or hang chosen
///   matched {people, mode}      — a room actually formed around you
///   game_started {game, mode}   — a game began in-room
///   game_picked {game}          — what people choose in the picker
///   walk_in                     — someone dropped into a waiting room
///   spark_saved                 — the save-a-person heart
///   awards_shown / wheel_spun {revive} / chaos_card
///   next_room / left_room       — how sessions end
///   party_hosted / party_join_attempt / party_started / party_share
///   trending_tap {game} / chaos_banner_tap
///   onboarding_done / share_card
class Track {
  Track._();
  static FirebaseAnalytics? _fa;

  static Future<void> init() async {
    if (!FirebaseCfg.configured) return;
    try {
      await Firebase.initializeApp(options: FirebaseCfg.ios);
      _fa = FirebaseAnalytics.instance;
    } catch (_) {/* analytics never blocks launch */}
  }

  static void screen(String name) {
    try {
      _fa?.logScreenView(screenName: name);
    } catch (_) {}
  }

  static void event(String name, [Map<String, Object>? params]) {
    try {
      _fa?.logEvent(name: name, parameters: params);
    } catch (_) {}
  }
}
