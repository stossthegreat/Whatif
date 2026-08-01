import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/haptics.dart';
import '../theme/colors.dart';

/// A live stream of reaction emoji floating up the screen — the ambient "the
/// room is laughing" signal. Tapping the bar spawns your reaction; the demo also
/// auto-emits others' reactions so a solo tester still feels a crowd.
class ReactionLayer extends StatefulWidget {
  const ReactionLayer({super.key, required this.controller});
  final ReactionController controller;

  @override
  State<ReactionLayer> createState() => _ReactionLayerState();
}

class ReactionController extends ChangeNotifier {
  final List<_Emit> _pending = [];
  void emit(String emoji, {double x = 0.5}) {
    _pending.add(_Emit(emoji, x));
    notifyListeners();
  }
}

class _Emit {
  _Emit(this.emoji, this.x);
  final String emoji;
  final double x;
}

class _ReactionLayerState extends State<ReactionLayer>
    with TickerProviderStateMixin {
  final List<_Floater> _floaters = [];
  final math.Random _rng = math.Random();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_drain);
  }

  void _drain() {
    for (final e in widget.controller._pending) {
      _spawn(e.emoji, e.x);
    }
    widget.controller._pending.clear();
  }

  void _spawn(String emoji, double x) {
    late final _Floater f;
    final ctl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1800 + _rng.nextInt(900)),
    );
    f = _Floater(
      emoji: emoji,
      x: x + (_rng.nextDouble() - 0.5) * 0.08,
      drift: (_rng.nextDouble() - 0.5) * 0.12,
      size: 24.0 + _rng.nextInt(16),
      controller: ctl,
    );
    setState(() => _floaters.add(f));
    ctl.forward().whenComplete(() {
      // If the layer was disposed mid-flight, dispose() already tore down this
      // controller — don't double-dispose.
      if (!mounted) return;
      setState(() => _floaters.remove(f));
      ctl.dispose();
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_drain);
    for (final f in _floaters) {
      f.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, c) {
          return Stack(
            children: [
              for (final f in _floaters)
                AnimatedBuilder(
                  animation: f.controller,
                  builder: (context, _) {
                    final t = f.controller.value;
                    final y = c.maxHeight * (0.85 - 0.7 * t);
                    final x = c.maxWidth * (f.x + f.drift * math.sin(t * math.pi * 2));
                    final opacity = t < 0.15 ? t / 0.15 : (t > 0.7 ? (1 - (t - 0.7) / 0.3) : 1.0);
                    return Positioned(
                      left: x - f.size / 2,
                      top: y,
                      child: Opacity(
                        opacity: opacity.clamp(0.0, 1.0),
                        child: Transform.scale(
                          scale: 0.6 + 0.6 * math.min(1, t * 3),
                          child: Text(f.emoji, style: TextStyle(fontSize: f.size)),
                        ),
                      ),
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Floater {
  _Floater({
    required this.emoji,
    required this.x,
    required this.drift,
    required this.size,
    required this.controller,
  });
  final String emoji;
  final double x;
  final double drift;
  final double size;
  final AnimationController controller;
}

/// The tappable reaction bar.
class ReactionBar extends StatelessWidget {
  const ReactionBar({super.key, required this.controller});
  final ReactionController controller;

  static const _emojis = ['😂', '💀', '🔥', '😳', '👏', '❤️'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: WhatIfColors.glass,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: WhatIfColors.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final e in _emojis)
            GestureDetector(
              onTap: () {
                Buzz.tick();
                controller.emit(e, x: 0.5 + (_emojis.indexOf(e) - 2.5) * 0.02);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(e, style: const TextStyle(fontSize: 24)),
              ),
            ),
        ],
      ),
    );
  }
}
