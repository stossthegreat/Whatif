import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

/// Owns the front camera for the Home stage. Deliberately fail-soft: if the
/// camera is unavailable or the user denies permission, [ready] stays false
/// and every screen falls back to an elegant placeholder — the app never
/// crashes or blocks on the camera.
///
/// Live rooms do NOT use this service (LiveKit / WebRTC open their own
/// capture session), so Home must fully [dispose] before a room starts —
/// iOS will not run two capture sessions at once.
class CameraService {
  CameraService._();
  static final CameraService instance = CameraService._();

  CameraController? controller;
  final ValueNotifier<bool> ready = ValueNotifier<bool>(false);
  bool _initTried = false;

  /// Every open/close runs through one queue: a dispose can never interleave
  /// with an init still in flight (fast tab flips, accept-call-from-home).
  Future<void> _queue = Future.value();
  Future<void> _serial(Future<void> Function() op) {
    final next = _queue.then((_) => op());
    _queue = next.catchError((_) {});
    return _queue;
  }

  /// Idempotent. Safe to call from multiple screens.
  Future<void> ensure() => _serial(() async {
        if (ready.value) return;
        try {
          final cams = await availableCameras();
          if (cams.isEmpty) {
            _initTried = true;
            return;
          }
          final front = cams.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.front,
            orElse: () => cams.first,
          );
          final c = CameraController(
            front,
            ResolutionPreset.high,
            enableAudio: false,
          );
          await c.initialize();
          controller = c;
          _initTried = true;
          ready.value = true;
        } catch (_) {
          _initTried = true;
        }
      });

  bool get triedAndFailed => _initTried && !ready.value;

  Future<void> dispose() => _serial(() async {
        // Detach every view FIRST — during the await below the old
        // controller is dead, and a build against it would crash.
        final c = controller;
        controller = null;
        ready.value = false;
        await c?.dispose();
      });
}
