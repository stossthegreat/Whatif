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
/// NOTE: livekit_client is pinned to 2.11.0, where the renderer's fit type is
/// the SDK's own VideoViewFit enum. Up to 2.4.x it was flutter_webrtc's
/// RTCVideoViewObjectFit — the P2P renderer below still takes that one, so both
/// types are in scope here and they are NOT interchangeable. If the pin moves,
/// re-read VideoTrackRenderer's constructor before assuming this still compiles.
///
/// RENDER MODE — MUST STAY texture. On iOS the SDK's default ("auto") uses a
/// native platform view that applies frame rotation by rotating the whole
/// layer: a full-screen portrait view rotated 90° collapses into a horizontal
/// band one screen-width tall (the "letterboxed zoomed face"), it ignores our
/// cover fit, and its 270° branch literally divides by zero. The texture path
/// bakes rotation into the pixels natively and computes cover-fit in Flutter
/// from the rotation-aware aspect ratio — verified against flutter_webrtc
/// 0.12.12+hotfix.1 source. LiveKit 2.11's `auto` happens to resolve to
/// texture by default at this pin, but that is a default and defaults move,
/// so this stays explicit. Do not remove renderMode.
class VideoView extends StatelessWidget {
  const VideoView({super.key, required this.track});
  final Object? track;

  @override
  Widget build(BuildContext context) {
    final t = track;
    if (t is! VideoTrack) return const SizedBox.shrink();
    return VideoTrackRenderer(
      t,
      fit: VideoViewFit.cover,
      renderMode: VideoRenderMode.texture,
    );
  }
}

/// Direct P2P rendering (raw flutter_webrtc renderer, texture path — the same
/// pipeline the LiveKit fix uses, so rotation is baked into the pixels).
///
/// MIRRORING DOCTRINE for P2P (read the saga above before touching):
/// raw getUserMedia has NO auto-mirror layer — unlike LiveKit's renderer.
/// Therefore the LOCAL front camera MUST pass mirror: true here, and REMOTE
/// views MUST pass mirror: false. Getting this backwards recreates the
/// "lean left, image goes right" bug.
class P2PVideoView extends StatelessWidget {
  const P2PVideoView({super.key, required this.renderer, this.mirror = false});
  final rtc.RTCVideoRenderer renderer;
  final bool mirror;

  @override
  Widget build(BuildContext context) {
    // The renderer initializes ASYNC after `attempting` flips true — building
    // the platform view before its texture exists can throw (release paints
    // that as the full-screen GREY box). Black until the texture is real.
    if (renderer.textureId == null) return const ColoredBox(color: Color(0xFF060709));
    return rtc.RTCVideoView(
      renderer,
      mirror: mirror,
      objectFit: rtc.RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
      filterQuality: FilterQuality.medium,
    );
  }
}
