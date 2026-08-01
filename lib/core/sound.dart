import 'package:audioplayers/audioplayers.dart';
import '../state/session.dart';

/// The sound layer — eight tiny generated cues that make the app feel alive:
/// reel ticks, the match thunk, countdown pips, the chaos slam, award fanfare,
/// combo pips, the wheel landing. Every call is fail-soft (a broken audio
/// session can never crash a live room) and respects the sound setting.
class Sfx {
  Sfx._();

  static final List<AudioPlayer> _pool =
      List.generate(4, (_) => AudioPlayer()..setPlayerMode(PlayerMode.lowLatency));
  static int _i = 0;

  static Future<void> _play(String name, double vol) async {
    if (!AppSession.instance.soundOn) return;
    try {
      final p = _pool[_i = (_i + 1) % _pool.length];
      await p.stop();
      await p.play(AssetSource('sfx/$name.wav'), volume: vol);
    } catch (_) {/* audio must never break the room */}
  }

  static void tick() => _play('tick', 0.45);
  static void pip() => _play('pip', 0.6);
  static void pop() => _play('pop', 0.7);
  static void match() => _play('match', 1.0);
  static void slam() => _play('slam', 1.0);
  static void land() => _play('land', 1.0);
  static void combo() => _play('combo', 0.8);
  static void fanfare() => _play('fanfare', 0.9);
}
