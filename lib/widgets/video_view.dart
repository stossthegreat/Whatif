import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:livekit_client/livekit_client.dart';

/// Renders a LiveKit [VideoTrack] cover-fit. Accepts an opaque [track] so
/// call-sites don't depend on LiveKit types; returns nothing when there's no
/// track yet, so the tile's placeholder shows through until video arrives.
///
/// MIRRORING — DO NOT ADD A MANUAL FLIP HERE. LiveKit's renderer defaults to
/// VideoViewMirrorMode.auto, which already mirrors YOUR OWN front camera
/// (bathroom-mirror selfie view) and leaves remote people unmirrored — both
/// correct. A manual Transform on top cancels the mirror and produces the
/// dreaded "lean left, image goes right". This happened. Never again.
///
/// NOTE: livekit_client is pinned to 2.3.1+hotfix.1, where the renderer's fit
/// type is flutter_webrtc's RTCVideoViewObjectFit (the VideoViewFit enum only
/// exists in later SDK versions). If the pin is ever bumped past 2.4, revisit.
class VideoView extends StatelessWidget {
  const VideoView({super.key, required this.track});
  final Object? track;

  @override
  Widget build(BuildContext context) {
    final t = track;
    if (t is! VideoTrack) return const SizedBox.shrink();
    return VideoTrackRenderer(
      t,
      fit: rtc.RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
    );
  }
}
