import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import 'glass.dart';

/// The three play presets, lifted out of the old standalone mode screen so
/// they can live on Home. Each card is its own play button — which is why the
/// floating orb is gone: two competing "go" affordances is one too many.
///
/// Written for a bounded box (Home gives them a fixed height); the art layers
/// animate continuously and are cheap (no images, pure paint).

class ModeCard extends StatelessWidget {
  const ModeCard({super.key, required this.title, required this.line, required this.art, required this.onTap});
  final String title;
  final String line;
  final Widget art;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Press(
      haptic: false,
      scale: 0.97,
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF15161B), Color(0xFF07080A)],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: C.hair2),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // the living layer
              Positioned.fill(child: art),
              // legibility grade
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x26000000), Color(0x00000000), Color(0xB3000000)],
                    stops: [0.0, 0.4, 1.0],
                  ),
                ),
              ),
              // copy + the key
              Positioned(
                left: 20,
                right: 20,
                bottom: 14,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: T.huge(27)),
                          const SizedBox(height: 6),
                          Text(line, style: T.sub.copyWith(color: C.tx2, height: 1.3, fontSize: 12.5)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [C.sig, C.purpleDeep],
                        ),
                        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
                        boxShadow: [BoxShadow(color: C.sigGlow, blurRadius: 22, spreadRadius: -6)],
                      ),
                      child: const Icon(Icons.play_arrow_rounded, size: 26, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Roulette's living layer — a big slow-cycling emoji reel with a purple glow.
class RouletteArt extends StatefulWidget {
  const RouletteArt({super.key});
  @override
  State<RouletteArt> createState() => RouletteArtState();
}

class RouletteArtState extends State<RouletteArt> {
  static const _faces = ['🎰', '😜', '🔥', '👀', '🍾', '💀', '😏', '🎭'];
  int _i = 0;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 900), (_) {
      if (mounted) setState(() => _i = (_i + 1) % _faces.length);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
          top: -30,
          right: -20,
          child: Container(
            width: 220, height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [C.sig.withOpacity(0.22), Colors.transparent]),
            ),
          ),
        ),
        Align(
          alignment: const Alignment(0, -0.6),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: ScaleTransition(
                  scale: Tween(begin: 1.3, end: 1.0).animate(anim), child: child),
            ),
            child: Text(_faces[_i], key: ValueKey(_i), style: const TextStyle(fontSize: 52)),
          ),
        ),
      ],
    );
  }
}

/// Groups' living layer — a tight cluster of orbs, your circle in one room.
class GroupsArt extends StatefulWidget {
  const GroupsArt({super.key});
  @override
  State<GroupsArt> createState() => GroupsArtState();
}

class GroupsArtState extends State<GroupsArt> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat(reverse: true);

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
        final t = Curves.easeInOut.transform(_c.value);
        Widget orb(Color a, double size) => Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: const Alignment(-0.4, -0.5),
                  colors: [a.withOpacity(0.9), const Color(0xFF0B0C10)],
                ),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
            );
        return Align(
          alignment: const Alignment(0, -0.6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.translate(
                  offset: Offset(6 - 5 * t, 4 * t), child: orb(const Color(0xFF3A4A66), 38)),
              const SizedBox(width: 8),
              Transform.translate(
                  offset: Offset(0, -5 * t), child: orb(const Color(0xFF66573A), 46 + 5 * t)),
              const SizedBox(width: 8),
              Transform.translate(
                  offset: Offset(-6 + 5 * t, 4 * t), child: orb(const Color(0xFF4A3A66), 38)),
            ],
          ),
        );
      },
    );
  }
}

/// Hang's living layer — two soft orbs breathing toward each other.
class HangArt extends StatefulWidget {
  const HangArt({super.key});
  @override
  State<HangArt> createState() => HangArtState();
}

class HangArtState extends State<HangArt> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat(reverse: true);

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
        final t = Curves.easeInOut.transform(_c.value);
        Widget orb(Color a) => Container(
              width: 46 + 7 * t,
              height: 46 + 7 * t,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: const Alignment(-0.4, -0.5),
                  colors: [a.withOpacity(0.9), const Color(0xFF0B0C10)],
                ),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
            );
        return Align(
          alignment: const Alignment(0, -0.6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.translate(
                  offset: Offset(10 - 16 * t, 6 * math.sin(t * math.pi)), child: orb(const Color(0xFF3A4A66))),
              const SizedBox(width: 12),
              Transform.translate(
                  offset: Offset(-10 + 16 * t, -6 * math.sin(t * math.pi)), child: orb(const Color(0xFF4A3A66))),
            ],
          ),
        );
      },
    );
  }
}
