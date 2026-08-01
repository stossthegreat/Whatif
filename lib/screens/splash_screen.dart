import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../widgets/aurora_background.dart';
import '../widgets/gradient_text.dart';

/// First frame the user ever sees. The aurora is already breathing; the wordmark
/// blooms up from nothing on a spring, a hairline of light sweeps under it, the
/// tagline fades in, and a few glyphs drift up like embers. Auto-advances — no
/// button, no wait screen. The whole thing says "something is already happening
/// here" before the user has done a single thing.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _mark; // wordmark bloom (spring)
  late final AnimationController _ambient; // tagline + embers
  bool _left = false;

  @override
  void initState() {
    super.initState();
    _mark = AnimationController.unbounded(vsync: this, value: 0);
    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();

    // Bloom the wordmark in with an overshooting spring.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mark.animateWith(SpringSimulation(
        const SpringDescription(mass: 1, stiffness: 180, damping: 12),
        0,
        1,
        0,
      ));
    });

    Future<void>.delayed(const Duration(milliseconds: 2600), _advance);
  }

  void _advance() {
    if (_left) return;
    _left = true;
    widget.onDone();
  }

  @override
  void dispose() {
    _mark.dispose();
    _ambient.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _advance, // tap to skip
      child: Scaffold(
        backgroundColor: WhatIfColors.ink,
        body: AuroraBackground(
          energy: 0.8,
          child: Stack(
            children: [
              _Embers(controller: _ambient),
              Center(
                child: AnimatedBuilder(
                  animation: _mark,
                  builder: (context, child) {
                    final v = _mark.value.clamp(0.0, 1.4);
                    return Opacity(
                      opacity: v.clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: 0.7 + 0.3 * v,
                        child: child,
                      ),
                    );
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Wordmark(fontSize: 56),
                      const SizedBox(height: 18),
                      AnimatedBuilder(
                        animation: _ambient,
                        builder: (context, _) {
                          // Tagline breathes gently in opacity.
                          final o = 0.55 + 0.45 * (0.5 + 0.5 * math.sin(_ambient.value * math.pi * 2));
                          return Opacity(
                            opacity: o,
                            child: Text(
                              'what happens tonight?',
                              style: WhatIfType.body.copyWith(
                                color: WhatIfColors.textMed,
                                letterSpacing: 0.2,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A few glyphs drifting upward like slow embers behind the wordmark.
class _Embers extends StatelessWidget {
  const _Embers({required this.controller});
  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return CustomPaint(
          size: Size.infinite,
          painter: _EmberPainter(controller.value),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _EmberPainter extends CustomPainter {
  _EmberPainter(this.t);
  final double t;
  static const _glyphs = ['🎭', '🌶️', '💬', '🍾', '⚡️', '👾', '🦊', '💫'];

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < _glyphs.length; i++) {
      final seed = i / _glyphs.length;
      final phase = (t + seed) % 1.0;
      final x = size.width * (0.1 + 0.8 * ((math.sin(seed * 12.9) + 1) / 2)) +
          math.sin((phase + seed) * math.pi * 2) * 16;
      final y = size.height * (1.05 - 1.15 * phase);
      final opacity = (math.sin(phase * math.pi)).clamp(0.0, 1.0) * 0.5;
      final tp = TextPainter(
        text: TextSpan(
          text: _glyphs[i],
          style: TextStyle(fontSize: 24 + 10 * seed, color: Colors.white.withOpacity(opacity)),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, y));
    }
  }

  @override
  bool shouldRepaint(_EmberPainter old) => old.t != t;
}
