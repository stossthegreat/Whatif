import 'dart:async';
import 'package:flutter/material.dart';
import '../core/haptics.dart';
import '../models/mock_data.dart';
import '../models/room.dart';
import '../state/app_state.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../widgets/aurora_button.dart';
import '../widgets/glass.dart';
import '../widgets/live_pill.dart';
import '../widgets/presence_orb.dart';
import '../widgets/pressable.dart';
import '../widgets/reveal.dart';
import '../widgets/room_card.dart';
import '../widgets/whatif_scaffold.dart';
import 'live_room_screen.dart';

/// The home lobby — "Tonight". This is the screen that has to feel *alive*: the
/// prime-time countdown ticking, live rooms breathing, friends inside, a crowd
/// already here. The whole design answers one question the moment you open it:
/// "what's happening right now?"
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return WhatIfScaffold(
      energy: 0.5,
      safeBottom: false,
      child: Stack(
        children: [
          IndexedStack(
            index: _tab,
            children: const [
              _TonightTab(),
              _ComingSoonTab(icon: Icons.group_rounded, title: 'Your crew', line: 'Add friends and your group streak lives here.'),
              _ComingSoonTab(icon: Icons.auto_awesome_rounded, title: 'You', line: 'Your orb, unlocks and your funniest moments.'),
            ],
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _NavBar(
              index: _tab,
              onTap: (i) {
                Buzz.tick();
                setState(() => _tab = i);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TonightTab extends StatelessWidget {
  const _TonightTab();

  void _join(BuildContext context, Room room) {
    Buzz.commit();
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 460),
        pageBuilder: (_, __, ___) => LiveRoomScreen(room: room),
        transitionsBuilder: (_, anim, __, child) {
          final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween(begin: 0.94, end: 1.0).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rooms = Mock.tonight();
    final prime = Mock.primeTime();
    return AnimatedBuilder(
      animation: AppState.instance,
      builder: (context, _) {
        final me = AppState.instance.me;
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Row(
                  children: [
                    PresenceOrb(identity: me, size: 44),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('tonight', style: WhatIfType.h1.copyWith(fontSize: 30)),
                          Text('@${me.handle} · the night is young',
                              style: WhatIfType.caption),
                        ],
                      ),
                    ),
                    const _StreakChip(days: 4),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
                child: Reveal(child: _PrimeTimeCard(room: prime, onJoin: () => _join(context, prime))),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('LIVE ROOMS', style: WhatIfType.overline.copyWith(color: WhatIfColors.textMed)),
                    const LivePill(label: 'OPEN NOW'),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList.separated(
                itemCount: rooms.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) => Reveal(
                  delay: Duration(milliseconds: 60 * i),
                  child: RoomCard(room: rooms[i], onJoin: () => _join(context, rooms[i])),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                child: Reveal(
                  delay: const Duration(milliseconds: 260),
                  child: _StartRoomCard(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The nightly appointment. A big, hot card with a live countdown — the habit
/// anchor (HQ Trivia / BeReal energy) that also concentrates concurrency.
class _PrimeTimeCard extends StatefulWidget {
  const _PrimeTimeCard({required this.room, required this.onJoin});
  final Room room;
  final VoidCallback onJoin;

  @override
  State<_PrimeTimeCard> createState() => _PrimeTimeCardState();
}

class _PrimeTimeCardState extends State<_PrimeTimeCard> {
  late int _seconds = widget.room.startingInSeconds ?? 0;
  Timer? _timer;
  bool _reminded = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _seconds = _seconds > 0 ? _seconds - 1 : 0);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _clock {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      glow: WhatIfColors.magenta,
      tint: WhatIfColors.glassStrong,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('🎪', style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Text('PRIME TIME', style: WhatIfType.overline.copyWith(color: WhatIfColors.amber, letterSpacing: 2)),
              const Spacer(),
              Text('everyone. one room.',
                  style: WhatIfType.caption.copyWith(color: WhatIfColors.textLow)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_clock,
                  style: WhatIfType.counter.copyWith(fontSize: 56, height: 1.0)),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('until it\nkicks off',
                    style: WhatIfType.caption.copyWith(color: WhatIfColors.textMed)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: AuroraButton(
                  label: _reminded ? 'You’re in ✓' : 'Notify me',
                  gradient: _reminded ? const [WhatIfColors.mint, WhatIfColors.cyan] : WhatIfColors.ember,
                  onTap: () {
                    Buzz.impact();
                    setState(() => _reminded = true);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Pressable(
                onTap: widget.onJoin,
                child: Container(
                  height: 62,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: WhatIfColors.glass,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: WhatIfColors.hairlineStrong),
                  ),
                  child: Text('Peek in', style: WhatIfType.bodyStrong),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StartRoomCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () {
        Buzz.commit();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: WhatIfColors.inkRaised,
            content: Text('Room builder coming next — invite your crew, pick a pack.'),
          ),
        );
      },
      child: Dottedish(
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: WhatIfColors.auroraSweep,
              ),
              child: const Icon(Icons.add_rounded, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Start your own room', style: WhatIfType.bodyStrong),
                  Text('bring your crew — it’s better with your people',
                      style: WhatIfType.caption),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: WhatIfColors.textLow),
          ],
        ),
      ),
    );
  }
}

/// A dashed-border container for the "create" affordance.
class Dottedish extends StatelessWidget {
  const Dottedish({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: WhatIfColors.glass,
        border: Border.all(color: WhatIfColors.hairlineStrong, width: 1.4),
      ),
      child: child,
    );
  }
}

class _StreakChip extends StatelessWidget {
  const _StreakChip({required this.days});
  final int days;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: WhatIfColors.amber.withOpacity(0.14),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: WhatIfColors.amber.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 15)),
          const SizedBox(width: 6),
          Text('$days',
              style: WhatIfType.label.copyWith(color: WhatIfColors.amber, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({required this.index, required this.onTap});
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.local_fire_department_rounded, 'Tonight'),
      (Icons.group_rounded, 'Crew'),
      (Icons.auto_awesome_rounded, 'You'),
    ];
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        bottom: 12 + MediaQuery.of(context).padding.bottom,
      ),
      child: GlassPanel(
        radius: 26,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        tint: WhatIfColors.glassStrong,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: Pressable(
                  haptic: false,
                  onTap: () => onTap(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 240),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: i == index
                          ? LinearGradient(colors: [
                              WhatIfColors.violet.withOpacity(0.4),
                              WhatIfColors.magenta.withOpacity(0.3),
                            ])
                          : null,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(items[i].$1,
                            color: i == index ? WhatIfColors.textHigh : WhatIfColors.textLow,
                            size: 24),
                        const SizedBox(height: 4),
                        Text(items[i].$2,
                            style: WhatIfType.caption.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: i == index ? WhatIfColors.textHigh : WhatIfColors.textLow,
                            )),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ComingSoonTab extends StatelessWidget {
  const _ComingSoonTab({required this.icon, required this.title, required this.line});
  final IconData icon;
  final String title;
  final String line;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: WhatIfColors.textLow),
            const SizedBox(height: 18),
            Text(title, style: WhatIfType.h2, textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text(line, style: WhatIfType.body, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
