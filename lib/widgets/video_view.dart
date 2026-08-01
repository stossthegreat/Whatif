import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:livekit_client/livekit_client.dart';

/// Renders a LiveKit [VideoTrack] cover-fit. Accepts an opaque [track] so
/// call-sites don't depend on LiveKit types; returns nothing when there's no
/// track yet, so the tile's placeholder shows through until video arrives.
///
/// NOTE: livekit_client is pinned to 2.3.1+hotfix.1, where the renderer's fit
/// type is flutter_webrtc's RTCVideoViewObjectFit (the VideoViewFit enum only
/// exists in later SDK versions). If the pin is ever bumped past 2.4, revisit.
class VideoView extends StatelessWidget {
  const VideoView({super.key, required this.track, this.mirror = false});
  final Object? track;
  final bool mirror;

  @override
  Widget build(BuildContext context) {
    final t = track;
    if (t is! VideoTrack) return const SizedBox.shrink();
    Widget r = VideoTrackRenderer(
      t,
      fit: rtc.RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
    );
    if (mirror) {
      r = Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()..scale(-1.0, 1.0, 1.0),
        child: r,
      );
    }
    return r;
  }
}
