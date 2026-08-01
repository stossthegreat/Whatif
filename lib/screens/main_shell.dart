import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/haptics.dart';
import '../state/session.dart';
import '../theme/tokens.dart';
import 'home_screen.dart';
import 'sparks_screen.dart';
import 'moments_screen.dart';
import 'me_screen.dart';

/// The app's home base once you're in — a persistent bottom tab bar over four
/// surfaces: Live (the lobby + PLAY), Sparks (your people), Moments (your
/// reveals), and Me. Tabs are kept alive (IndexedStack) so state and the live
/// lobby never reset when you switch.
class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.onPlay, required this.onSignOut});
  final VoidCallback onPlay;
  final VoidCallback onSignOut;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0;

  static const double _barHeight = 62;

  void _go(int i) {
    if (i == _tab) return;
    Buzz.tick();
    setState(() => _tab = i);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final navTotal = _barHeight + mq.padding.bottom;

    final pages = <Widget>[
      HomeScreen(onPlay: widget.onPlay, onSignOut: widget.onSignOut),
      const SparksScreen(embedded: true),
      const MomentsScreen(embedded: true),
      const MeScreen(embedded: true),
    ];

    return Scaffold(
      backgroundColor: C.black,
      body: Stack(
        children: [
          // give every tab enough bottom room to clear the floating bar
          MediaQuery(
            data: mq.copyWith(
              padding: mq.padding.copyWith(bottom: navTotal),
            ),
            child: IndexedStack(index: _tab, children: pages),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _NavBar(
              index: _tab,
              onTap: _go,
              height: _barHeight,
              bottomInset: mq.padding.bottom,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.icon, this.activeIcon, this.label);
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

class _NavBar extends StatelessWidget {
  const _NavBar({
    required this.index,
    required this.onTap,
    required this.height,
    required this.bottomInset,
  });
  final int index;
  final ValueChanged<int> onTap;
  final double height;
  final double bottomInset;

  static const _items = <_NavItem>[
    _NavItem(Icons.sensors_rounded, Icons.sensors_rounded, 'Live'),
    _NavItem(Icons.auto_awesome_outlined, Icons.auto_awesome_rounded, 'Sparks'),
    _NavItem(Icons.auto_awesome_motion_outlined, Icons.auto_awesome_motion_rounded, 'Moments'),
    _NavItem(Icons.person_outline_rounded, Icons.person_rounded, 'Me'),
  ];

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          height: height + bottomInset,
          padding: EdgeInsets.only(bottom: bottomInset),
          decoration: const BoxDecoration(
            color: Color(0xE60A0B0D),
            border: Border(top: BorderSide(color: C.hair)),
          ),
          child: AnimatedBuilder(
            animation: AppSession.instance,
            builder: (context, _) {
              final mutuals = AppSession.instance.mutualCount;
              return Row(
                children: [
                  for (var i = 0; i < _items.length; i++)
                    Expanded(
                      child: _NavCell(
                        item: _items[i],
                        selected: index == i,
                        badge: i == 1 && mutuals > 0 ? mutuals : 0,
                        onTap: () => onTap(i),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NavCell extends StatelessWidget {
  const _NavCell({required this.item, required this.selected, required this.onTap, this.badge = 0});
  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final color = selected ? C.sig : C.tx3;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(selected ? item.activeIcon : item.icon, size: 24, color: color),
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
                        style: const TextStyle(fontSize: 9.5, color: Colors.white, fontWeight: FontWeight.w800)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            item.label,
            style: T.tiny.copyWith(
              fontSize: 10.5,
              color: color,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
