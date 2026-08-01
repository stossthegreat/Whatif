import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/haptics.dart';
import '../state/session.dart';
import '../theme/tokens.dart';
import 'home_screen.dart';
import 'me_screen.dart';

/// Three tabs. That's the whole philosophy:
///
///   LIVE  —  the world. Everything moving, rooms filling, chaos hour ticking.
///    ▶    —  drop in. The button IS the company. It dominates the bar.
///   YOU   —  profile, badges, sparks, moments, settings. One page.
///
/// People don't open Rivlr to browse — they open it to get dropped into chaos.
class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.onPlay, required this.onSignOut});
  final VoidCallback onPlay;
  final VoidCallback onSignOut;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0; // 0 = LIVE, 1 = YOU

  static const double _barHeight = 64;

  void _go(int i) {
    if (i == _tab) return;
    Buzz.tick();
    setState(() => _tab = i);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final navTotal = _barHeight + mq.padding.bottom;

    return Scaffold(
      backgroundColor: C.black,
      body: Stack(
        children: [
          MediaQuery(
            data: mq.copyWith(padding: mq.padding.copyWith(bottom: navTotal)),
            child: IndexedStack(
              index: _tab,
              children: [
                HomeScreen(onPlay: widget.onPlay, onSignOut: widget.onSignOut),
                MeScreen(embedded: true, onSignOut: widget.onSignOut),
              ],
            ),
          ),
          // the bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  height: _barHeight + mq.padding.bottom,
                  padding: EdgeInsets.only(bottom: mq.padding.bottom),
                  decoration: const BoxDecoration(
                    color: Color(0xE6060709),
                    border: Border(top: BorderSide(color: C.hair)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _NavCell(
                          icon: Icons.sensors_rounded,
                          label: 'Live',
                          selected: _tab == 0,
                          onTap: () => _go(0),
                        ),
                      ),
                      const Expanded(child: SizedBox()), // lane for the orb
                      Expanded(
                        child: AnimatedBuilder(
                          animation: AppSession.instance,
                          builder: (context, _) => _NavCell(
                            icon: _tab == 1 ? Icons.person_rounded : Icons.person_outline_rounded,
                            label: 'You',
                            selected: _tab == 1,
                            badge: AppSession.instance.mutualCount,
                            onTap: () => _go(1),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // the orb — floats above the bar, dominates it
          Positioned(
            left: 0,
            right: 0,
            bottom: mq.padding.bottom + 14,
            child: Center(child: _PlayOrb(onTap: widget.onPlay)),
          ),
        ],
      ),
    );
  }
}

class _NavCell extends StatelessWidget {
  const _NavCell({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge = 0,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : C.tx3;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon, size: 25, color: color),
              if (badge > 0)
                Positioned(
                  right: -7,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    constraints: const BoxConstraints(minWidth: 15),
                    decoration: BoxDecoration(
                      color: C.sig,
                      borderRadius: BorderRadius.circular(100),
                      boxShadow: [BoxShadow(color: C.sigGlow, blurRadius: 8, spreadRadius: -2)],
                    ),
                    child: Text('$badge',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 9.5, color: Colors.white, fontWeight: FontWeight.w800)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(label,
              style: T.tiny.copyWith(
                fontSize: 10.5,
                color: color,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              )),
        ],
      ),
    );
  }
}

/// The drop-in orb. Breathing purple glow — the single most important pixel in
/// the app. One tap from anywhere and you're in a room.
class _PlayOrb extends StatefulWidget {
  const _PlayOrb({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_PlayOrb> createState() => _PlayOrbState();
}

class _PlayOrbState extends State<_PlayOrb> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))
        ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Buzz.pop();
        widget.onTap();
      },
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final glow = 0.45 + 0.35 * _c.value;
          return Container(
            width: 62,
            height: 62,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [C.sig, C.purpleDeep],
              ),
              border: Border.all(color: Colors.white.withOpacity(0.22), width: 1.5),
              boxShadow: [
                BoxShadow(color: C.sig.withOpacity(glow), blurRadius: 26, spreadRadius: -2),
                const BoxShadow(color: Color(0x99000000), blurRadius: 18, offset: Offset(0, 8)),
              ],
            ),
            child: const Icon(Icons.play_arrow_rounded, size: 34, color: Colors.white),
          );
        },
      ),
    );
  }
}
