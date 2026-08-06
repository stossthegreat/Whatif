import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/haptics.dart';
import '../net/network_client.dart';
import '../state/chat.dart';
import '../state/social.dart';
import '../theme/tokens.dart';
import 'chats_screen.dart';
import 'explore_screen.dart';
import 'home_screen.dart';
import 'me_screen.dart';

/// Four tabs, and three of them still work when the queue is empty — which was
/// the whole problem with the old two-tab shell: no one online meant an app
/// with nothing in it.
///
///   HOME     —  your live camera + TAP TO START, mode chips at the bottom
///   EXPLORE  —  who's on right now, tap to say hello
///   MESSAGES —  conversations and your friends
///   PROFILE  —  you: record, people, moments, settings
class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.onPlay, required this.onParty, required this.onSignOut});

  /// Mode string: 'roulette' | 'hang' | 'groups'.
  final ValueChanged<String> onPlay;
  final VoidCallback onParty;
  final VoidCallback onSignOut;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0; // 0 Home · 1 Explore · 2 Messages · 3 Profile

  static const double _barHeight = 64;

  void _go(int i) {
    if (i == _tab) return;
    Buzz.tick();
    setState(() => _tab = i);
    // The tabs live in an IndexedStack, so each one's initState runs ONCE, at
    // app start — possibly before the socket is even up. Explore's buttons and
    // the Friends lane both read the friend graph, so without this they show
    // whatever was true when the app launched: the "sometimes it knows my
    // friends, sometimes it doesn't" bug.
    if (i == 1 || i == 2) NetworkClient.instance.friendsSnapshot();
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
                HomeScreen(
                    onSignOut: widget.onSignOut,
                    onParty: widget.onParty,
                    onPlay: widget.onPlay,
                    // the camera stage runs only while Home is the visible tab
                    active: _tab == 0),
                ExploreScreen(onPlay: widget.onPlay),
                const ChatsScreen(embedded: true),
                MeScreen(embedded: true, onSignOut: widget.onSignOut),
              ],
            ),
          ),
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
                    color: Color(0xE60A0714),
                    border: Border(top: BorderSide(color: C.hair)),
                  ),
                  child: AnimatedBuilder(
                    animation: Listenable.merge(
                        [SocialState.instance, ChatStore.instance]),
                    builder: (context, _) => Row(
                      children: [
                        Expanded(
                          child: _NavCell(
                            icon: _tab == 0 ? Icons.home_rounded : Icons.home_outlined,
                            label: 'Home',
                            selected: _tab == 0,
                            onTap: () => _go(0),
                          ),
                        ),
                        Expanded(
                          child: _NavCell(
                            icon: _tab == 1 ? Icons.explore_rounded : Icons.explore_outlined,
                            label: 'Explore',
                            selected: _tab == 1,
                            onTap: () => _go(1),
                          ),
                        ),
                        Expanded(
                          child: _NavCell(
                            icon: _tab == 2
                                ? Icons.chat_bubble_rounded
                                : Icons.chat_bubble_outline_rounded,
                            label: 'Messages',
                            selected: _tab == 2,
                            badge: ChatStore.instance.unreadTotal,
                            onTap: () => _go(2),
                          ),
                        ),
                        Expanded(
                          child: _NavCell(
                            icon: _tab == 3 ? Icons.person_rounded : Icons.person_outline_rounded,
                            label: 'Profile',
                            selected: _tab == 3,
                            badge: SocialState.instance.reqCount,
                            onTap: () => _go(3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
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
          // active-tab indicator — a small purple bar sliding in above the icon
          AnimatedContainer(
            duration: M.quick,
            curve: M.ease,
            margin: const EdgeInsets.only(bottom: 4),
            width: selected ? 18 : 0,
            height: 3,
            decoration: BoxDecoration(
              color: C.sig,
              borderRadius: BorderRadius.circular(100),
              boxShadow: selected
                  ? [BoxShadow(color: C.sigGlow, blurRadius: 8, spreadRadius: -1)]
                  : null,
            ),
          ),
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
                    decoration: const BoxDecoration(
                      color: C.acid,
                      borderRadius: BorderRadius.all(Radius.circular(100)),
                      boxShadow: [BoxShadow(color: C.acidGlow, blurRadius: 8, spreadRadius: -2)],
                    ),
                    child: Text('$badge',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 9.5, color: Colors.black, fontWeight: FontWeight.w800)),
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
