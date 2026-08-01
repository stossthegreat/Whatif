import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../core/camera_service.dart';
import '../theme/tokens.dart';

/// The user's own camera, rendered as a cover-fit, mirrored preview. Falls back
/// to an elegant cool-light placeholder if the camera isn't available/allowed —
/// so every screen looks intentional either way.
class SelfView extends StatelessWidget {
  const SelfView({super.key, this.label, this.mirror = true, this.grade = false});

  final String? label;
  final bool mirror;

  /// If true, lay a soft dark grade over the preview (used on Home so type reads).
  final bool grade;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: CameraService.instance.ready,
      builder: (context, ready, _) {
        final cam = CameraService.instance.controller;
        Widget inner;
        if (ready && cam != null && cam.value.isInitialized) {
          final size = cam.value.previewSize;
          final w = size?.height ?? 720;
          final h = size?.width ?? 1280;
          Widget preview = ClipRect(
            child: OverflowBox(
              maxWidth: double.infinity,
              maxHeight: double.infinity,
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(width: w, height: h, child: CameraPreview(cam)),
              ),
            ),
          );
          if (mirror) {
            preview = Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()..scale(-1.0, 1.0, 1.0),
              child: preview,
            );
          }
          inner = preview;
        } else {
          inner = const _Placeholder();
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            inner,
            if (grade)
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x73000000), Color(0x26000000), Color(0xBF000000)],
                    stops: [0.0, 0.35, 1.0],
                  ),
                ),
              ),
            if (label != null)
              Positioned(
                left: 10,
                bottom: 8,
                child: Text(label!, style: T.tiny.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
          ],
        );
      },
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();
  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        color: C.char2,
        gradient: RadialGradient(
          center: Alignment(0, -0.2),
          radius: 0.9,
          colors: [Color(0x4D8CB4FF), Color(0x00000000)],
        ),
      ),
    );
  }
}
