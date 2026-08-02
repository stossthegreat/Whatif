import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

/// All LiveKit usage is isolated here (and in widgets/video_view.dart). Connects
/// to a LiveKit room, publishes the local camera AND microphone, and exposes
/// each participant's video track. [rev] bumps whenever tracks change so the UI
/// rebuilds. Only invoked in live mode; in simulated builds nothing calls join().
class RtcService {
  RtcService._();
  static final RtcService instance = RtcService._();

  Room? _room;
  final ValueNotifier<int> rev = ValueNotifier<int>(0);

  /// Whether the local mic is live. Always back on when a new room starts —
  /// nobody wants to join their next room silently muted from the last one.
  bool micOn = true;

  Future<void> setMic(bool on) async {
    micOn = on;
    try {
      await _room?.localParticipant?.setMicrophoneEnabled(on);
    } catch (_) {}
    _bump();
  }

  Future<void> join(String url, String token) async {
    if (url.isEmpty || token.isEmpty) return; // video disabled — placeholders show
    await leave();
    micOn = true;
    // speakerOn: a face-to-face video app plays through the loudspeaker, not
    // the earpiece — without this iOS can route voices somewhere inaudible.
    final room = Room(
      roomOptions: const RoomOptions(
        defaultAudioOutputOptions: AudioOutputOptions(speakerOn: true),
      ),
    );
    room.addListener(_bump);
    try {
      await room.connect(url, token);
      _room = room; // set immediately so leave() can always disconnect
    } catch (_) {
      room.removeListener(_bump);
      _bump();
      return;
    }
    // publish each track independently — a denied camera must not kill voice,
    // and a denied mic must not kill video.
    try {
      await room.localParticipant?.setMicrophoneEnabled(true);
    } catch (_) {}
    try {
      await room.localParticipant?.setCameraEnabled(true);
    } catch (_) {}
    _bump();
  }

  void _bump() => rev.value++;

  VideoTrack? get localTrack => _firstVideo(_room?.localParticipant);

  VideoTrack? trackFor(String? identity) {
    if (identity == null || _room == null) return null;
    for (final p in _room!.remoteParticipants.values) {
      if (p.identity == identity) return _firstVideo(p);
    }
    return null;
  }

  VideoTrack? _firstVideo(Participant? p) {
    if (p == null) return null;
    for (final pub in p.videoTrackPublications) {
      final t = pub.track;
      if (t is VideoTrack) return t;
    }
    return null;
  }

  Future<void> leave() async {
    final room = _room;
    _room = null;
    if (room != null) {
      room.removeListener(_bump);
      try {
        await room.disconnect();
      } catch (_) {}
    }
    _bump();
  }
}
