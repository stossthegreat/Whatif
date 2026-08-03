import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../core/haptics.dart';
import '../core/sound.dart';
import '../theme/tokens.dart';

/// Finding — the roulette. Not a fade: a slot-machine reel of flags, faces,
/// games and emojis whips past a center reticle, motion-blurred, decelerating
/// with ticking haptics, and lands on a face — CLICK. "MATCHED." This is the
/// dopamine hit before the drop.
class FindingScreen extends StatefulWidget {
  const FindingScreen({super.key, required this.onDone, this.waitForExternal = false});
  final VoidCallback onDone;

  /// Live mode: keep spinning until the server delivers a match (parent swaps us).
  final bool waitForExternal;

  @override
  State<FindingScreen> createState() => _FindingScreenState();
}

class _FindingScreenState extends State<FindingScreen> with SingleTickerProviderStateMixin {
  static const _itemW = 96.0;
  static const _count = 46;
  static const _winner = 41; // index that lands in the reticle
  final _rng = math.Random();

  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));
  late List<_Item> _items;
  int _lastCenter = -1;
  bool _matched = false;

  @override
  void initState() {
    super.initState();
    _c.addListener(_onTick);
    _spin();
  }

  void _spin() {
    _matched = false;
    // a fresh reel every spin — new faces, new flags, a different landing
    // face each time. The slot machine never repeats itself.
    _items = List.generate(_count, (i) => _Item.build(i, i == _winner, _rng));
    _c.forward(from: 0).whenComplete(() {
      if (!mounted) return;
      if (widget.waitForExternal) {
        _spin(); // keep the reel alive until the server matches us
      } else {
        Buzz.impact();
        Sfx.match();
        setState(() => _matched = true);
        Future<void>.delayed(const Duration(milliseconds: 700), () {
          if (mounted) widget.onDone();
        });
      }
    });
  }

  double get _curve => Curves.easeOutQuart.transform(_c.value);

  void _onTick() {
    // ticking that slows with the reel (only during the satisfying decel)
    final w = context.size?.width ?? 400.0;
    final x = _offsetFor(w);
    final center = ((w / 2 - x) / _itemW).round();
    if (center != _lastCenter) {
      _lastCenter = center;
      if (_c.value > 0.5 && _c.value < 0.99) {
        Buzz.tick();
        Sfx.tick();
      }
    }
    setState(() {});
  }

  double _offsetFor(double width) {
    final endX = width / 2 - (_winner * _itemW + _itemW / 2);
    final spin = 24 * _itemW;
    return endX + spin - spin * _curve;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.black,
      body: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth;
          final x = _offsetFor(w);
          final blur = (1 - _curve) * 22 + 0.01;
          return Stack(
            alignment: Alignment.center,
            children: [
              // soft purple glow behind the reel
              Center(
                child: Container(
                  width: w, height: 180,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [C.sig.withOpacity(0.18), Colors.transparent],
                    ),
                  ),
                ),
              ),
              // the reel
              SizedBox(
                height: 150,
                width: w,
                child: ClipRect(
                  child: ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: 0.4),
                    child: Transform.translate(
                      offset: Offset(x, 0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: _items.map((it) => SizedBox(width: _itemW, height: 150, child: Center(child: it.widget))).toList(),
                      ),
                    ),
                  ),
                ),
              ),
              // edge fades to focus the center
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [C.black, Colors.transparent, Colors.transparent, C.black],
                        stops: const [0.0, 0.22, 0.78, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
              // reticle
              Center(
                child: Container(
                  width: _itemW + 8,
                  height: 128,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: C.sig.withOpacity(0.85), width: 2),
                    boxShadow: [BoxShadow(color: C.sigGlow, blurRadius: 26, spreadRadius: -6)],
                  ),
                ),
              ),
              // label
              Positioned(
                bottom: 120,
                child: _matched
                    ? TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.6, end: 1),
                        duration: const Duration(milliseconds: 360),
                        curve: Curves.easeOutBack,
                        builder: (context, v, _) => Transform.scale(
                          scale: v,
                          child: Text('MATCHED', style: T.display(34).copyWith(letterSpacing: 2, color: C.sig)),
                        ),
                      )
                    : Text('FINDING…', style: T.display(16).copyWith(letterSpacing: 4, color: C.tx2)),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Item {
  _Item(this.widget);
  final Widget widget;

  // All chosen to render on iOS out of the box — no tofu boxes.
  static const _flags = [
    '🇬🇧', '🇺🇸', '🇯🇵', '🇧🇷', '🇮🇹', '🇫🇷', '🇰🇷', '🇪🇸', '🇩🇪', '🇮🇳',
    '🇲🇽', '🇨🇦', '🇳🇬', '🇦🇺', '🇿🇦', '🇦🇷', '🇳🇱', '🇸🇪', '🇵🇹', '🇮🇪',
  ];
  static const _faces = ['😀', '😎', '🥳', '🤩', '😏', '😇', '🤠', '🥸', '😌', '🙃', '😜', '🤪'];
  static const _reacts = ['😂', '🔥', '💀', '❤️', '😳', '👏', '⚡', '👀', '🎉', '✨'];

  static _Item build(int i, bool winner, math.Random r) {
    if (winner) return _Item(_WinnerOrb(face: _faces[r.nextInt(_faces.length)]));
    switch (i % 3) {
      case 0:
        return _Item(Text(_flags[r.nextInt(_flags.length)], style: const TextStyle(fontSize: 46)));
      case 1:
        return _Item(_FaceOrb(face: _faces[r.nextInt(_faces.length)]));
      default:
        return _Item(Text(_reacts[r.nextInt(_reacts.length)], style: const TextStyle(fontSize: 42)));
    }
  }
}

/// A glossy obsidian orb carrying a face — matches the home lobby language, so
/// the reel never shows a flat, "blank" circle.
class _FaceOrb extends StatelessWidget {
  const _FaceOrb({required this.face});
  final String face;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72, height: 72,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-0.45, -0.55), radius: 1.05,
          colors: [Color(0xFF2A2D34), Color(0xFF0C0D10), Color(0xFF000000)],
          stops: [0.0, 0.55, 1.0],
        ),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
        boxShadow: [BoxShadow(color: C.sig.withOpacity(0.14), blurRadius: 14, spreadRadius: -6)],
      ),
      child: Text(face, style: const TextStyle(fontSize: 30)),
    );
  }
}

class _WinnerOrb extends StatelessWidget {
  const _WinnerOrb({required this.face});
  final String face;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84, height: 84,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-0.4, -0.5), radius: 1.05,
          colors: [Color(0xFF3A2A55), Color(0xFF140A22), Color(0xFF000000)],
          stops: [0.0, 0.5, 1.0],
        ),
        border: Border.all(color: C.sig, width: 2.5),
        boxShadow: [BoxShadow(color: C.sigGlow, blurRadius: 26, spreadRadius: -3)],
      ),
      child: Text(face, style: const TextStyle(fontSize: 38)),
    );
  }
}
