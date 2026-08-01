# Enabling live video (LiveKit)

The app ships with a no-op video stub so the default build compiles with zero
native SDKs. When you're ready for real live group video, do these three things.
Nothing else in the app changes — matchmaking, games, reactions and report/block
already run live.

## 1. Add the dependency
In `pubspec.yaml`, uncomment:
```yaml
  livekit_client: ^2.3.0
```
Then `flutter pub get`.

## 2. iOS deployment target 13+
LiveKit/WebRTC needs iOS 13. In `ios/Podfile` set `platform :ios, '13.0'`, set the
Runner **iOS Deployment Target** to 13.0 in Xcode, then `cd ios && pod install`.
(Camera + mic usage strings are already in `Info.plist`.)

## 3. Replace the two seam files

`lib/net/rtc_service.dart`:
```dart
import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

class RtcService {
  RtcService._();
  static final RtcService instance = RtcService._();
  Room? _room;
  final ValueNotifier<int> rev = ValueNotifier<int>(0);

  Future<void> join(String url, String token) async {
    if (url.isEmpty || token.isEmpty) return;
    await leave();
    final room = Room();
    room.addListener(_bump);
    try {
      await room.connect(url, token);
      await room.localParticipant?.setCameraEnabled(true);
      _room = room;
    } catch (_) {
      room.removeListener(_bump);
    }
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
      try { await room.disconnect(); } catch (_) {}
    }
    _bump();
  }
}
```

`lib/widgets/video_view.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

class VideoView extends StatelessWidget {
  const VideoView({super.key, required this.track, this.mirror = false});
  final Object? track;
  final bool mirror;

  @override
  Widget build(BuildContext context) {
    final t = track;
    if (t is! VideoTrack) return const SizedBox.shrink();
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
```

That's it. Build live:
```bash
flutter build ipa --release --dart-define=RIVLR_BACKEND=wss://<your-domain>/ws
```

> If the LiveKit SDK's API differs slightly by version, the only files to touch
> are these two — the rest of the app is decoupled from it.
