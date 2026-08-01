import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/haptics.dart';
import '../models/game.dart';
import '../models/identity.dart';
import '../models/room.dart';
import '../state/app_state.dart';
import '../theme/colors.dart';
import '../theme/motion.dart';
import '../theme/typography.dart';
import '../widgets/aurora_background.dart';
import '../widgets/confetti.dart';
import '../widgets/countdown_ring.dart';
import '../widgets/floating_reactions.dart';
import '../widgets/live_pill.dart';
import '../widgets/presence_orb.dart';
import '../widgets/pressable.dart';
import '../widgets/reveal.dart';

/// The live room — the whole reason the app exists. A self-driving round moves
/// through gather → reveal → prompt → countdown → vote → the payoff, with the
/// aurora, haptics, reactions and confetti all choreographed to peak on the
/// reveal (peak-end rule). Everything is interactive where it matters: you lock
/// an answer, you cast a vote, you spam reactions — and the room reacts back.
class LiveRoomScreen extends StatefulWidget {
  const LiveRoomScreen({super.key, required this.room});
  final Room room;

  @override
  State<LiveRoomScreen> createState() => _LiveRoomScreenState();
}

class _LiveRoomScreenState extends State<LiveRoomScreen>
    with TickerProviderStateMixin {
  final _confetti = ConfettiController();
  final _reactions = ReactionController();
  final _rng = math.Random();

  late final AnimationController _countdown;
  Timer? _phaseTimer;
  Timer? _ambientReactions;
  int _lastSecond = -1;

  RoundPhase _phase = RoundPhase.gathering;
  GameType _game = GameType.pack[0];
  int _round = 1;

  int? _lockedAnswer;
  int? _vote;
  late int _impostor;
  bool _resultsShown = false;
  final Set<int> _lockedPlayers = {};

  // Round content (mock).
  final List<String> _answers = const [
    'emotionally unavailable but consistent',
    'i reply “haha” to end conversations',
    'i’m always 7 minutes late, on purpose',
    'i give unsolicited advice, brilliantly',
  ];
  String get _prompt => switch (_game.name) {
        'Impostor' => 'Your toxic trait — but make it a flex.',
        'Hot Takes' => 'Drop your spiciest take. Anonymously.',
        'Would You Rather' => 'Fight 100 duck-sized horses, or one horse-sized duck?',
        'Most Likely To' => 'Most likely to start a cult (a fun one).',
        'Caption This' => 'Caption the cursed image. Best one wins.',
        _ => 'The wheel has chosen. Truth or dare?',
      };

  @override
  void initState() {
    super.initState();
    _game = widget.room.game;
    _impostor = _rng.nextInt(widget.room.players.length);
    _countdown = AnimationController(vsync: this)
      ..addListener(_onCountdownTick);
    _startAmbientReactions();
    _enter(RoundPhase.gathering);
  }

  @override
  void dispose() {
    _phaseTimer?.cancel();
    _ambientReactions?.cancel();
    _countdown.dispose();
    super.dispose();
  }

  // ---- Ambient life ---------------------------------------------------------
  void _startAmbientReactions() {
    const emojis = ['😂', '💀', '🔥', '😳', '👏'];
    _ambientReactions = Timer.periodic(const Duration(milliseconds: 1600), (_) {
      if (!mounted) return;
      if (_phase == RoundPhase.prompt || _phase == RoundPhase.results || _phase == RoundPhase.voting) {
        _reactions.emit(emojis[_rng.nextInt(emojis.length)], x: 0.2 + _rng.nextDouble() * 0.6);
      }
    });
  }

  // ---- Countdown plumbing ---------------------------------------------------
  void _runCountdown(int seconds, VoidCallback onDone) {
    _lastSecond = seconds;
    _countdown
      ..duration = Duration(seconds: seconds)
      ..reset()
      ..forward().whenComplete(onDone);
  }

  void _onCountdownTick() {
    if (!_countdown.isAnimating) return;
    final total = _countdown.duration!.inSeconds;
    final left = (total * (1 - _countdown.value)).ceil();
    if (left != _lastSecond) {
      _lastSecond = left;
      if (left <= 3 && left > 0) Buzz.heartbeat();
      setState(() {});
    }
  }

  double get _ringProgress => 1 - _countdown.value;
  int get _secondsLeft {
    if (_countdown.duration == null) return 0;
    return (_countdown.duration!.inSeconds * (1 - _countdown.value)).ceil().clamp(0, 99);
  }

  // ---- Phase machine --------------------------------------------------------
  void _enter(RoundPhase p) {
    _phaseTimer?.cancel();
    setState(() => _phase = p);
    switch (p) {
      case RoundPhase.gathering:
        _phaseTimer = Timer(const Duration(milliseconds: 2400), () => _enter(RoundPhase.reveal));
        break;
      case RoundPhase.reveal:
        Buzz.commit();
        _phaseTimer = Timer(const Duration(milliseconds: 2400), () => _enter(RoundPhase.prompt));
        break;
      case RoundPhase.prompt:
        _lockedPlayers.clear();
        _simulateLocking();
        break;
      case RoundPhase.answering:
        _runCountdown(5, () => _enter(RoundPhase.voting));
        break;
      case RoundPhase.voting:
        _runCountdown(8, _revealResults);
        break;
      case RoundPhase.results:
        break;
    }
  }

  /// Other players "lock in" their answers over a few seconds — the little ticks
  /// appearing is what makes the room feel live while you decide.
  void _simulateLocking() {
    for (var i = 0; i < widget.room.players.length; i++) {
      Timer(Duration(milliseconds: 700 + _rng.nextInt(2600)), () {
        if (!mounted || _phase != RoundPhase.prompt) return;
        setState(() => _lockedPlayers.add(i));
      });
    }
  }

  void _lockAnswer(int i) {
    if (_lockedAnswer != null) return;
    Buzz.commit();
    setState(() => _lockedAnswer = i);
    _enter(RoundPhase.answering);
  }

  void _castVote(int i) {
    if (_vote != null) return;
    Buzz.commit();
    setState(() => _vote = i);
    // A beat to let it land, then reveal.
    _phaseTimer?.cancel();
    _phaseTimer = Timer(const Duration(milliseconds: 900), _revealResults);
  }

  void _revealResults() {
    if (_resultsShown) return; // guard against double-fire (early vote + timer)
    _resultsShown = true;
    _phaseTimer?.cancel();
    _countdown.stop();
    final correct = _vote == _impostor;
    setState(() => _phase = RoundPhase.results);
    if (correct) {
      Buzz.celebrate();
      _confetti.fire(origin: const Offset(0.5, 0.42));
    } else {
      Buzz.impact();
    }
    // A cascade of reactions on the reveal.
    for (var i = 0; i < 6; i++) {
      Timer(Duration(milliseconds: 120 * i), () {
        if (mounted) _reactions.emit(correct ? '🎉' : '💀', x: 0.3 + _rng.nextDouble() * 0.4);
      });
    }
  }

  void _nextRound() {
    Buzz.commit();
    setState(() {
      _round++;
      _game = GameType.pack[_round % GameType.pack.length];
      _impostor = _rng.nextInt(widget.room.players.length);
      _lockedAnswer = null;
      _vote = null;
      _resultsShown = false;
      _lockedPlayers.clear();
    });
    _enter(RoundPhase.reveal);
  }

  // ---- UI -------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final energy = switch (_phase) {
      RoundPhase.gathering => 0.4,
      RoundPhase.reveal => 0.7,
      RoundPhase.prompt => 0.55,
      RoundPhase.answering => 0.8,
      RoundPhase.voting => 0.85,
      RoundPhase.results => 1.0,
    };
    return Scaffold(
      backgroundColor: WhatIfColors.ink,
      body: AuroraBackground(
        energy: energy,
        palette: _game.colors.length >= 2
            ? [_game.colors[0], _game.colors[1], WhatIfColors.cyan]
            : WhatIfColors.aurora,
        child: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  _TopBar(room: widget.room, phase: _phase, round: _round, onLeave: () => Navigator.of(context).maybePop()),
                  Expanded(child: _buildStage()),
                  _buildActionZone(),
                ],
              ),
            ),
            ReactionLayer(controller: _reactions),
            ConfettiOverlay(controller: _confetti),
          ],
        ),
      ),
    );
  }

  Widget _buildStage() {
    return AnimatedSwitcher(
      duration: Motion.base,
      switchInCurve: Motion.entrance,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(scale: Tween(begin: 0.94, end: 1.0).animate(anim), child: child),
      ),
      child: KeyedSubtree(
        key: ValueKey(_phase),
        child: switch (_phase) {
          RoundPhase.gathering => _GatheringStage(room: widget.room),
          RoundPhase.reveal => _RevealStage(game: _game, round: _round),
          RoundPhase.prompt => _promptStage(),
          RoundPhase.answering => _answeringStage(),
          RoundPhase.voting => _votingStage(),
          RoundPhase.results => _resultsStage(),
        },
      ),
    );
  }

  Widget _promptStage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 8),
          _PhaseLabel(game: _game),
          const SizedBox(height: 18),
          Reveal(
            child: Text(_prompt,
                textAlign: TextAlign.center,
                style: WhatIfType.h1.copyWith(fontSize: 30, height: 1.12)),
          ),
          const SizedBox(height: 10),
          Text('${_lockedPlayers.length}/${widget.room.players.length} locked in',
              style: WhatIfType.caption.copyWith(color: WhatIfColors.mint)),
          const Spacer(),
          ...staggered([
            for (var i = 0; i < _answers.length; i++)
              _AnswerChip(
                text: _answers[i],
                locked: _lockedAnswer == i,
                dimmed: _lockedAnswer != null && _lockedAnswer != i,
                onTap: () => _lockAnswer(i),
              ),
          ], step: const Duration(milliseconds: 60)),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _answeringStage() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _PhaseLabel(game: _game),
        const SizedBox(height: 28),
        AnimatedBuilder(
          animation: _countdown,
          builder: (context, _) =>
              CountdownRing(progress: _ringProgress, secondsLeft: _secondsLeft, size: 180),
        ),
        const SizedBox(height: 28),
        Text('answers locking in…',
            style: WhatIfType.body.copyWith(color: WhatIfColors.textMed)),
        const SizedBox(height: 8),
        Text('who gave themselves away?',
            style: WhatIfType.caption.copyWith(color: WhatIfColors.textLow)),
      ],
    );
  }

  Widget _votingStage() {
    final players = widget.room.players;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Text('WHO GOT THE ODD PROMPT?',
              style: WhatIfType.overline.copyWith(color: WhatIfColors.live)),
          const SizedBox(height: 6),
          Text('tap your suspect', style: WhatIfType.caption),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.timer_rounded, size: 14, color: WhatIfColors.amber),
                const SizedBox(width: 5),
                Text('$_secondsLeft',
                    style: WhatIfType.label.copyWith(color: WhatIfColors.amber, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.only(bottom: 8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.82,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: players.length,
              itemBuilder: (context, i) => _VoteTarget(
                identity: players[i],
                selected: _vote == i,
                dimmed: _vote != null && _vote != i,
                onTap: () => _castVote(i),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultsStage() {
    final impostor = widget.room.players[_impostor];
    final correct = _vote == _impostor;
    // MVP of the round — for the demo, if you nailed it, you're MVP; else the impostor is.
    final mvp = correct ? AppState.instance.me : impostor;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Reveal(
            child: Text(correct ? 'NAILED IT' : 'GOT AWAY WITH IT',
                style: WhatIfType.overline.copyWith(
                  color: correct ? WhatIfColors.mint : WhatIfColors.live,
                  fontSize: 13,
                  letterSpacing: 2,
                )),
          ),
          const SizedBox(height: 20),
          Reveal(
            delay: const Duration(milliseconds: 150),
            dy: 40,
            child: Column(
              children: [
                const Text('🎭', style: TextStyle(fontSize: 34)),
                const SizedBox(height: 8),
                PresenceOrb(identity: impostor, size: 120, active: true, showLabel: true),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Reveal(
            delay: const Duration(milliseconds: 350),
            child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: WhatIfType.body.copyWith(color: WhatIfColors.textMed, fontSize: 17),
                children: [
                  const TextSpan(text: 'the impostor was '),
                  TextSpan(
                    text: '@${impostor.handle}',
                    style: WhatIfType.bodyStrong.copyWith(color: WhatIfColors.textHigh),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 26),
          Reveal(
            delay: const Duration(milliseconds: 520),
            child: _MvpBanner(identity: mvp, correct: correct),
          ),
        ],
      ),
    );
  }

  Widget _buildActionZone() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_phase == RoundPhase.results) ...[
            Reveal(
              delay: const Duration(milliseconds: 650),
              child: Row(
                children: [
                  Expanded(
                    child: Pressable(
                      onTap: () => Navigator.of(context).maybePop(),
                      child: Container(
                        height: 58,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: WhatIfColors.glass,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: WhatIfColors.hairlineStrong),
                        ),
                        child: Text('Wrap up', style: WhatIfType.bodyStrong),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: _NextRoundButton(onTap: _nextRound),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          ReactionBar(controller: _reactions),
        ],
      ),
    );
  }
}

// ---- Stage widgets ----------------------------------------------------------

class _TopBar extends StatelessWidget {
  const _TopBar({required this.room, required this.phase, required this.round, required this.onLeave});
  final Room room;
  final RoundPhase phase;
  final int round;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Pressable(
            onTap: onLeave,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: WhatIfColors.glass,
                border: Border.all(color: WhatIfColors.hairline),
              ),
              child: const Icon(Icons.close_rounded, size: 20, color: WhatIfColors.textMed),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(room.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: WhatIfType.bodyStrong.copyWith(fontSize: 15)),
                Text('round $round · ${phase.label}',
                    style: WhatIfType.caption.copyWith(fontSize: 11)),
              ],
            ),
          ),
          const LivePill(),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: WhatIfColors.glass,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: WhatIfColors.hairline),
            ),
            child: Row(
              children: [
                const Icon(Icons.person_rounded, size: 13, color: WhatIfColors.textMed),
                const SizedBox(width: 4),
                Text('${room.count}',
                    style: WhatIfType.caption.copyWith(fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GatheringStage extends StatelessWidget {
  const _GatheringStage({required this.room});
  final Room room;
  @override
  Widget build(BuildContext context) {
    final players = room.players;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 260,
            height: 260,
            child: Stack(
              alignment: Alignment.center,
              children: [
                for (var i = 0; i < players.length; i++)
                  Transform.translate(
                    offset: Offset(
                      math.cos(i / players.length * math.pi * 2 - math.pi / 2) * 100,
                      math.sin(i / players.length * math.pi * 2 - math.pi / 2) * 100,
                    ),
                    child: Reveal(
                      delay: Duration(milliseconds: 120 * i),
                      child: PresenceOrb(identity: players[i], size: 44),
                    ),
                  ),
                PresenceOrb(identity: AppState.instance.me, size: 66, active: true),
              ],
            ),
          ),
          const SizedBox(height: 30),
          Text('the room is filling…',
              style: WhatIfType.h3.copyWith(color: WhatIfColors.textMed)),
          const SizedBox(height: 6),
          Text('${room.count} inside · get ready',
              style: WhatIfType.caption),
        ],
      ),
    );
  }
}

class _RevealStage extends StatelessWidget {
  const _RevealStage({required this.game, required this.round});
  final GameType game;
  final int round;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('NEXT UP', style: WhatIfType.overline.copyWith(color: WhatIfColors.textLow, letterSpacing: 3)),
          const SizedBox(height: 20),
          // The game card blooms in.
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.6, end: 1.0),
            duration: Motion.slow,
            curve: Motion.emphatic,
            builder: (context, v, child) => Transform.scale(scale: v, child: Opacity(opacity: v.clamp(0, 1), child: child)),
            child: Container(
              width: 220,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                gradient: game.gradient,
                boxShadow: [BoxShadow(color: game.colors.first.withOpacity(0.55), blurRadius: 50, spreadRadius: -6)],
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  Text(game.glyph, style: const TextStyle(fontSize: 72)),
                  const SizedBox(height: 12),
                  Text(game.name,
                      textAlign: TextAlign.center,
                      style: WhatIfType.h1.copyWith(color: Colors.white, fontSize: 28)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Reveal(
            delay: const Duration(milliseconds: 350),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(game.rule,
                  textAlign: TextAlign.center,
                  style: WhatIfType.body.copyWith(fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhaseLabel extends StatelessWidget {
  const _PhaseLabel({required this.game});
  final GameType game;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(game.glyph, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 8),
        Text(game.name.toUpperCase(),
            style: WhatIfType.overline.copyWith(color: WhatIfColors.textMed, letterSpacing: 2)),
      ],
    );
  }
}

class _AnswerChip extends StatelessWidget {
  const _AnswerChip({required this.text, required this.locked, required this.dimmed, required this.onTap});
  final String text;
  final bool locked;
  final bool dimmed;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Pressable(
        onTap: onTap,
        child: AnimatedOpacity(
          duration: Motion.quick,
          opacity: dimmed ? 0.4 : 1.0,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: locked ? WhatIfColors.glassStrong : WhatIfColors.glass,
              border: Border.all(
                color: locked ? WhatIfColors.mint : WhatIfColors.hairline,
                width: locked ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(text,
                      style: WhatIfType.bodyStrong.copyWith(
                        fontWeight: FontWeight.w600,
                        color: WhatIfColors.textHigh,
                      )),
                ),
                if (locked) ...[
                  const SizedBox(width: 10),
                  const Icon(Icons.lock_rounded, size: 18, color: WhatIfColors.mint),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VoteTarget extends StatelessWidget {
  const _VoteTarget({required this.identity, required this.selected, required this.dimmed, required this.onTap});
  final Identity identity;
  final bool selected;
  final bool dimmed;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: Motion.quick,
        opacity: dimmed ? 0.35 : 1.0,
        child: AnimatedContainer(
          duration: Motion.quick,
          curve: Motion.entrance,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: selected ? WhatIfColors.glassStrong : WhatIfColors.glass,
            border: Border.all(
              color: selected ? WhatIfColors.live : WhatIfColors.hairline,
              width: selected ? 2.5 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PresenceOrb(identity: identity, size: 48, active: selected),
              const SizedBox(height: 6),
              Text('@${identity.handle}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: WhatIfType.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: selected ? WhatIfColors.textHigh : WhatIfColors.textMed,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

class _MvpBanner extends StatelessWidget {
  const _MvpBanner({required this.identity, required this.correct});
  final Identity identity;
  final bool correct;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(colors: [
          WhatIfColors.amber.withOpacity(0.22),
          WhatIfColors.magenta.withOpacity(0.14),
        ]),
        border: Border.all(color: WhatIfColors.amber.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PresenceOrb(identity: identity, size: 44),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('👑 MVP of the round',
                  style: WhatIfType.caption.copyWith(color: WhatIfColors.amber, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text('@${identity.handle}',
                  style: WhatIfType.bodyStrong.copyWith(color: WhatIfColors.textHigh)),
            ],
          ),
        ],
      ),
    );
  }
}

class _NextRoundButton extends StatelessWidget {
  const _NextRoundButton({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Pressable(
      haptic: false,
      onTap: onTap,
      child: Container(
        height: 58,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: WhatIfColors.emberSweep,
          boxShadow: [BoxShadow(color: WhatIfColors.magenta.withOpacity(0.5), blurRadius: 28, spreadRadius: -4)],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Next round', style: WhatIfType.bodyStrong.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
            const SizedBox(width: 8),
            const Icon(Icons.bolt_rounded, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }
}
