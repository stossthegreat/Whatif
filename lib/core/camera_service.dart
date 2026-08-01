import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

/// Owns the front camera. Deliberately fail-soft: if the camera is unavailable
/// or the user denies permission, [ready] stays false and every screen falls
/// back to an elegant placeholder — the app never crashes or blocks on the
/// camera. Permission is requested in-context (on the onboarding "let's go" tap
/// and again on the first PLAY), so the OS prompt lands at a moment of intent.
class CameraService {
  CameraService._();
  static final CameraService instance = CameraService._();

  CameraController? controller;
  final ValueNotifier<bool> ready = ValueNotifier<bool>(false);
  bool _initTried = false;
  bool _initing = false;

  /// Idempotent. Safe to call from multiple screens.
  Future<void> ensure() async {
    if (ready.value || _initing) return;
    _initing = true;
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) {
        _finish(false);
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
      _finish(true);
    } catch (_) {
      _finish(false);
    }
  }

  void _finish(bool ok) {
    _initTried = true;
    _initing = false;
    ready.value = ok;
  }

  bool get triedAndFailed => _initTried && !ready.value;

  Future<void> dispose() async {
    await controller?.dispose();
    controller = null;
    ready.value = false;
  }
}
