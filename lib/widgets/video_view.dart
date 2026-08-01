import 'package:flutter/material.dart';

/// Live-video renderer seam. In this default build it's a no-op (returns nothing,
/// so the tile's animated placeholder shows through). Replaced with the real
/// LiveKit `VideoTrackRenderer` version when video is enabled — see
/// `docs/ENABLE_VIDEO.md`. Accepts an opaque [track] so call-sites don't change.
class VideoView extends StatelessWidget {
  const VideoView({super.key, required this.track, this.mirror = false});
  final Object? track;
  final bool mirror;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
