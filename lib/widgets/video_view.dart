import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

/// Renders a LiveKit [VideoTrack] cover-fit. Returns null-sized when there's no
/// track yet, so the caller's placeholder shows through until video arrives.
class VideoView extends StatelessWidget {
  const VideoView({super.key, required this.track, this.mirror = false});
  final VideoTrack? track;
  final bool mirror;

  @override
  Widget build(BuildContext context) {
    final t = track;
    if (t == null) return const SizedBox.shrink();
    Widget r = VideoTrackRenderer(t, fit: VideoViewFit.cover);
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
