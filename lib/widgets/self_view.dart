import 'dart:math' as math;
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

/// A living placeholder — used whenever the camera is unavailable. A soft cool
/// light drifts slowly across near-black so even the camera-less screens breathe
/// (never a dead, static panel).
class _Placeholder extends StatefulWidget {
  const _Placeholder();
  @override
  State<_Placeholder> createState() => _PlaceholderState();
}

class _PlaceholderState extends State<_Placeholder> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 14))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value * 6.28318;
        final dx = 0.32 * math.sin(t);
        final dy = -0.18 + 0.26 * math.cos(t * 0.8);
        return DecoratedBox(
          decoration: BoxDecoration(
            color: C.char2,
            gradient: RadialGradient(
              center: Alignment(dx, dy),
              radius: 0.95,
              colors: const [Color(0x4D8CB4FF), Color(0x00000000)],
              stops: const [0.0, 0.72],
            ),
          ),
        );
      },
    );
  }
}
