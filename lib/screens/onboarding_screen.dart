import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/haptics.dart';
import '../models/game.dart';
import '../models/identity.dart';
import '../models/mock_data.dart';
import '../theme/colors.dart';
import '../theme/motion.dart';
import '../theme/typography.dart';
import '../widgets/aurora_button.dart';
import '../widgets/confetti.dart';
import '../widgets/gradient_text.dart';
import '../widgets/presence_orb.dart';
import '../widgets/reveal.dart';
import '../widgets/whatif_scaffold.dart';

/// Onboarding teaches by *showing*, not telling. Three pages, each a tiny live
/// demo of the product's soul: a room gathering, the game rotating, and the
/// shareable reveal. No forms, no tutorial. Ends on a hook, not a checklist.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onFinish});
  final VoidCallback onFinish;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pc = PageController();
  final _confetti = ConfettiController();
  int _page = 0;

  static const _pages = [
    _PageData(
      eyebrow: 'IT’S NOT A FEED',
      title: 'It’s a room.',
      body: 'No scrolling. No performing. You drop in with a handful of people and something starts happening.',
    ),
    _PageData(
      eyebrow: 'NEVER THE SAME TWICE',
      title: 'A new game\nevery night.',
      body: 'One sentence of rules. Impossible to be bad at. The game does the talking — you just react.',
    ),
    _PageData(
      eyebrow: 'YOU’LL WANT TO RECORD IT',
      title: 'Then the\nreveal.',
      body: 'Every round ends with a moment the whole room feels at once. That’s the part that ends up on your story.',
    ),
  ];

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _pages.length - 1) {
      _pc.nextPage(duration: Motion.base, curve: Motion.entrance);
    } else {
      widget.onFinish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final last = _page == _pages.length - 1;
    return WhatIfScaffold(
      energy: 0.4 + _page * 0.2,
      palette: _page == 2 ? WhatIfColors.celebration.take(3).toList() : WhatIfColors.aurora,
      child: Stack(
        children: [
          Column(
            children: [
              // Top bar: skip.
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Wordmark(fontSize: 24),
                    if (!last)
                      TextButton(
                        onPressed: widget.onFinish,
                        child: Text('Skip',
                            style: WhatIfType.label.copyWith(color: WhatIfColors.textLow)),
                      )
                    else
                      const SizedBox(height: 48),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pc,
                  itemCount: _pages.length,
                  onPageChanged: (i) {
                    Buzz.tick();
                    setState(() => _page = i);
                    if (i == 2) {
                      Future<void>.delayed(const Duration(milliseconds: 500),
                          () => _confetti.fire(origin: const Offset(0.5, 0.42)));
                    }
                  },
                  itemBuilder: (context, i) => _OnboardPage(
                    data: _pages[i],
                    index: i,
                    active: _page == i,
                  ),
                ),
              ),
              // Dots + CTA.
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: Column(
                  children: [
                    _Dots(count: _pages.length, index: _page),
                    const SizedBox(height: 22),
                    AuroraButton(
                      label: last ? 'Get me in' : 'Next',
                      icon: last ? Icons.bolt_rounded : Icons.arrow_forward_rounded,
                      onTap: _next,
                    ),
                  ],
                ),
              ),
            ],
          ),
          ConfettiOverlay(controller: _confetti),
        ],
      ),
    );
  }
}

class _PageData {
  const _PageData({required this.eyebrow, required this.title, required this.body});
  final String eyebrow;
  final String title;
  final String body;
}

class _OnboardPage extends StatelessWidget {
  const _OnboardPage({required this.data, required this.index, required this.active});
  final _PageData data;
  final int index;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          // The live demo for this page.
          Expanded(
            child: Center(
              child: switch (index) {
                0 => const _DemoRoom(),
                1 => const _DemoGames(),
                _ => const _DemoReveal(),
              },
            ),
          ),
          const SizedBox(height: 8),
          Text(data.eyebrow,
              style: WhatIfType.overline.copyWith(color: WhatIfColors.cyan)),
          const SizedBox(height: 12),
          GradientText(
            data.title,
            style: WhatIfType.h1.copyWith(fontSize: 40, height: 1.02),
            gradient: const LinearGradient(colors: [Colors.white, Colors.white]),
          ),
          const SizedBox(height: 14),
          Text(data.body, style: WhatIfType.body.copyWith(fontSize: 17, height: 1.45)),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

/// Page 1 demo: a cluster of orbs, one of them pulsing (you're not alone here).
class _DemoRoom extends StatelessWidget {
  const _DemoRoom();
  @override
  Widget build(BuildContext context) {
    final crowd = Mock.group(6, from: 3);
    return SizedBox(
      height: 240,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (var i = 0; i < crowd.length; i++)
            Transform.translate(
              offset: Offset(
                math.cos(i / crowd.length * math.pi * 2) * 92,
                math.sin(i / crowd.length * math.pi * 2) * 92,
              ),
              child: Reveal(
                delay: Duration(milliseconds: 120 * i),
                child: PresenceOrb(identity: crowd[i], size: 46, active: i == 0),
              ),
            ),
          Reveal(
            delay: const Duration(milliseconds: 400),
            child: PresenceOrb(identity: Identity.guest, size: 72, active: true),
          ),
        ],
      ),
    );
  }
}

/// Page 2 demo: a fanned stack of game cards.
class _DemoGames extends StatelessWidget {
  const _DemoGames();
  @override
  Widget build(BuildContext context) {
    final games = GameType.pack.take(4).toList();
    return SizedBox(
      height: 240,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (var i = games.length - 1; i >= 0; i--)
            Transform.translate(
              offset: Offset((i - 1.5) * 28, (i - 1.5).abs() * 10),
              child: Transform.rotate(
                angle: (i - 1.5) * 0.09,
                child: Reveal(
                  delay: Duration(milliseconds: 100 * (games.length - i)),
                  child: _MiniGameCard(games[i]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MiniGameCard extends StatelessWidget {
  const _MiniGameCard(this.game);
  final GameType game;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 128,
      height: 172,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: game.gradient,
        boxShadow: [
          BoxShadow(color: game.colors.first.withOpacity(0.4), blurRadius: 30, spreadRadius: -6),
        ],
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(game.glyph, style: const TextStyle(fontSize: 40)),
          Text(game.name,
              style: WhatIfType.h3.copyWith(color: Colors.white, fontSize: 18)),
        ],
      ),
    );
  }
}

/// Page 3 demo: a "winner" orb rising with a crown.
class _DemoReveal extends StatelessWidget {
  const _DemoReveal();
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 240,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('👑', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 8),
            Reveal(
              delay: const Duration(milliseconds: 200),
              dy: 40,
              child: PresenceOrb(identity: Mock.roster[0], size: 108, active: true, showLabel: true),
            ),
            const SizedBox(height: 12),
            Reveal(
              delay: const Duration(milliseconds: 500),
              child: Text('funniest in the room',
                  style: WhatIfType.label.copyWith(color: WhatIfColors.amber)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});
  final int count;
  final int index;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: Motion.quick,
            curve: Motion.entrance,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == index ? 26 : 8,
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(100),
              gradient: i == index ? WhatIfColors.auroraSweep : null,
              color: i == index ? null : WhatIfColors.hairlineStrong,
            ),
          ),
      ],
    );
  }
}
