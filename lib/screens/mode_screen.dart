import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/haptics.dart';
import '../core/sound.dart';
import '../theme/tokens.dart';
import '../widgets/glass.dart';

/// Press play → choose your poison. Two cards, nothing else:
///
///   ROULETTE — no choices. Games hit you back to back. Want out? Go home.
///   HANG     — person to person. Just talk. Start a game when you want one.
///
/// Full-height obsidian cards, one living animation each, a purple play key.
class ModeScreen extends StatelessWidget {
  const ModeScreen({super.key, required this.onPick, required this.onBack});
  final ValueChanged<String> onPick;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    return Scaffold(
      backgroundColor: C.black,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: r.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 6),
              Row(
                children: [
                  Press(
                    onTap: onBack,
                    child: Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle, color: C.glass, border: Border.all(color: C.hair)),
                      child: const Icon(Icons.arrow_back_rounded, size: 20, color: C.tx2),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text('How do you want it?', style: T.big.copyWith(fontSize: 24)),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _ModeCard(
                  title: 'Roulette',
                  line: 'No choices. Games hit you, back to back.\nSurvive the wheel.',
                  art: const _RouletteArt(),
                  onTap: () {
                    Buzz.pop();
                    Sfx.match();
                    onPick('roulette');
                  },
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _ModeCard(
                  title: 'Hang',
                  line: 'Person to person. Just talk.\nStart a game whenever you feel it.',
                  art: const _HangArt(),
                  onTap: () {
                    Buzz.pop();
                    Sfx.pop();
                    onPick('hang');
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({required this.title, required this.line, required this.art, required this.onTap});
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
                left: 22,
                right: 22,
                bottom: 20,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: T.huge(34)),
                          const SizedBox(height: 6),
                          Text(line, style: T.sub.copyWith(color: C.tx2, height: 1.35, fontSize: 14)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Container(
                      width: 56,
                      height: 56,
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
                      child: const Icon(Icons.play_arrow_rounded, size: 30, color: Colors.white),
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
class _RouletteArt extends StatefulWidget {
  const _RouletteArt();
  @override
  State<_RouletteArt> createState() => _RouletteArtState();
}

class _RouletteArtState extends State<_RouletteArt> {
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
          alignment: const Alignment(0, -0.45),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: ScaleTransition(
                  scale: Tween(begin: 1.3, end: 1.0).animate(anim), child: child),
            ),
            child: Text(_faces[_i], key: ValueKey(_i), style: const TextStyle(fontSize: 74)),
          ),
        ),
      ],
    );
  }
}

/// Hang's living layer — two soft orbs breathing toward each other.
class _HangArt extends StatefulWidget {
  const _HangArt();
  @override
  State<_HangArt> createState() => _HangArtState();
}

class _HangArtState extends State<_HangArt> with SingleTickerProviderStateMixin {
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
              width: 64 + 8 * t,
              height: 64 + 8 * t,
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
          alignment: const Alignment(0, -0.45),
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
