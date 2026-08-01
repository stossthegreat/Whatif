import 'package:flutter/foundation.dart';

/// Live-video seam. This default build ships a **no-op stub** (no native SDK) so
/// the app compiles cleanly everywhere and your first TestFlight/Codemagic build
/// is bulletproof. Matchmaking, presence, games and reactions are all real in
/// live mode — only the video rendering is deferred.
///
/// To turn on real LiveKit group video, follow `docs/ENABLE_VIDEO.md` (add the
/// `livekit_client` dependency and replace this file + `widgets/video_view.dart`
/// with the versions provided there). Nothing else in the app changes.
class RtcService {
  RtcService._();
  static final RtcService instance = RtcService._();

  /// Bumps when video state changes (no-op in the stub).
  final ValueNotifier<int> rev = ValueNotifier<int>(0);

  Future<void> join(String url, String token) async {/* enabled in ENABLE_VIDEO.md */}
  Future<void> leave() async {}

  /// Returns a video track when LiveKit is enabled; null here (placeholder shows).
  Object? get localTrack => null;
  Object? trackFor(String? identity) => null;
}
