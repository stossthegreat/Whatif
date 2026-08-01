import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../core/haptics.dart';
import '../models/game.dart';
import '../models/person.dart';
import '../net/network_client.dart';
import '../net/rtc_service.dart';
import '../state/session.dart';
import '../theme/tokens.dart';
import '../widgets/countdown_ring.dart';
import '../widgets/glass.dart';
import '../widgets/presence_tile.dart';
import '../widgets/self_view.dart';
import '../widgets/video_view.dart';

enum _Phase { drop, game, reveal }

/// The live canvas — TikTok-clean. Faces fill the screen edge to edge; every
/// control floats *over* the video (a right-side action rail, a bottom caption),
/// never an opaque panel that eats the frame. A game is always running so there
/// is no dead air; each round builds to one reveal beat.
class LiveScreen extends StatefulWidget {
  const LiveScreen({
    super.key,
    required this.cell,
    required this.onNext,
    required this.onLeave,
    this.live = false,
  });
  final Cell cell;
  final VoidCallback onNext;
  final VoidCallback onLeave;

  /// True when driven by the real backend (LiveKit video + relayed reactions).
  final bool live;

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> with TickerProviderStateMixin {
  final _r = Random();
  late final AnimationController _timer =
      AnimationController(vsync: this)..addListener(_onTick);

  _Phase _phase = _Phase.drop;
  bool _answered = false;
  int _lastSec = -1;

  int? _pointPick;
  int? _selected;
  int? _winnerIdx;
  String _result = '';
  List<int> _split = const [];
  int _reactCount = 0;

  int _speakingIdx = -1;
  Timer? _idle;
  Timer? _speak;
  Timer? _startTimer;
  Timer? _director;
  StreamSubscription<Map<String, dynamic>>? _netSub;

  String? _twist;
  static const _twists = [
    '⚡  Everyone point at the funniest person',
    '🔥  Next answer has to be a lie',
    '😂  10 seconds to make the room laugh',
    '❤️  Two of you — 30 seconds, go',
    '👀  Everyone freeze. Hold it.',
    '🌀  CHAOS — the rules just changed',
  ];

  Cell get cell => widget.cell;
  GameDef get game => cell.game;

  @override
  void initState() {
    super.initState();
    Buzz.pop();
    _speak = Timer.periodic(const Duration(milliseconds: 1200), (_) {
      if (!mounted || cell.people.isEmpty) return;
      setState(() => _speakingIdx = _r.nextInt(cell.people.length));
    });
    _startTimer = Timer(const Duration(milliseconds: 700), _startGame);
    _director = Timer(Duration(milliseconds: 9000 + _r.nextInt(7000)), _injectTwist);
    if (widget.live) {
      _netSub = NetworkClient.instance.events.listen((m) {
        if (!mounted) return;
        if (m['t'] == 'react' && m['e'] is String) {
          setState(() => _reactCount++);
          _float(m['e'] as String);
        }
      });
    }
  }

  @override
  void dispose() {
    _timer.dispose();
    _idle?.cancel();
    _speak?.cancel();
    _startTimer?.cancel();
    _director?.cancel();
    _netSub?.cancel();
    super.dispose();
  }

  void _injectTwist() {
    if (!mounted) return;
    Buzz.impact();
    setState(() => _twist = _twists[_r.nextInt(_twists.length)]);
    Timer(const Duration(milliseconds: 3800), () {
      if (mounted) setState(() => _twist = null);
    });
  }

  // ---- game timer plumbing --------------------------------------------------
  void _runTimer(int seconds, VoidCallback onDone) {
    _lastSec = seconds;
    _timer
      ..duration = Duration(seconds: seconds)
      ..reset()
      ..forward().whenComplete(() {
        if (mounted && !_answered) onDone();
      });
  }

  void _onTick() {
    if (!_timer.isAnimating) return;
    final total = _timer.duration?.inSeconds ?? 1;
    final left = (total * (1 - _timer.value)).ceil();
    if (left != _lastSec) {
      _lastSec = left;
      if (left <= 3 && left > 0) Buzz.tick();
    }
    setState(() {});
  }

  double get _timerProgress => 1 - _timer.value;

  // ---- phase machine --------------------------------------------------------
  void _startGame() {
    setState(() {
      _phase = _Phase.game;
      _answered = false;
    });
    final secs = switch (game.kind) {
      GameKind.freeze => 5,
      GameKind.rapidFire => 10,
      _ => 9,
    };
    _runTimer(secs, _autoResolve);
  }

  void _autoResolve() {
    switch (game.kind) {
      case GameKind.point:
        _resolvePoint(_r.nextInt(cell.people.length));
      case GameKind.poll:
      case GameKind.wouldRather:
        _resolveSplit(0);
      case GameKind.thumbs:
        _resolveThumbs(true);
      case GameKind.same:
        _resolveSame(0);
      case GameKind.twoTruths:
        _resolveTwoTruths(0);
      case GameKind.freeze:
        _resolveFreeze();
      case GameKind.rapidFire:
        _resolveRapid();
    }
  }

  void _toReveal() {
    _timer.stop();
    Buzz.commit();
    AppSession.instance.captureMoment(
      game: game.name,
      result: _result,
      hues: [...cell.people.map((p) => p.hue), AppSession.instance.myHue],
    );
    setState(() => _phase = _Phase.reveal);
    _idle?.cancel();
    _idle = Timer(const Duration(seconds: 7), () {
      if (mounted && _phase == _Phase.reveal) widget.onNext();
    });
  }

  // ---- resolvers ------------------------------------------------------------
  void _resolvePoint(int userPick) {
    if (_answered) return;
    _answered = true;
    Buzz.commit();
    final winner = cell.people.length == 1 ? 0 : _r.nextInt(cell.people.length);
    setState(() {
      _pointPick = userPick;
      _winnerIdx = winner;
      _result = 'the room pointed at @${cell.people[winner].name}';
    });
    Timer(const Duration(milliseconds: 850), _toReveal);
  }

  void _resolveSplit(int choice) {
    if (_answered) return;
    _answered = true;
    Buzz.commit();
    final a = 40 + _r.nextInt(30);
    setState(() {
      _selected = choice;
      _split = [a, 100 - a];
      _result = 'the room split ${choice == 0 ? a : 100 - a}% your way';
    });
    Timer(const Duration(milliseconds: 650), _toReveal);
  }

  void _resolveThumbs(bool guilty) {
    if (_answered) return;
    _answered = true;
    Buzz.commit();
    final n = 1 + _r.nextInt(cell.people.length + 1);
    setState(() {
      _selected = guilty ? 1 : 0;
      _result = '$n in the room are guilty 👀';
    });
    Timer(const Duration(milliseconds: 650), _toReveal);
  }

  void _resolveSame(int choice) {
    if (_answered) return;
    _answered = true;
    Buzz.commit();
    final m = _r.nextInt(cell.people.length + 1);
    setState(() {
      _selected = choice;
      _result = m > 0 ? '$m of you said the same thing 🧠' : 'nobody matched you — iconic';
    });
    Timer(const Duration(milliseconds: 650), _toReveal);
  }

  void _resolveTwoTruths(int choice) {
    if (_answered) return;
    _answered = true;
    Buzz.commit();
    final correct = _r.nextBool();
    setState(() {
      _selected = choice;
      _result = correct ? 'you read them 😏 nailed the lie' : 'they fooled you 😵 slippery';
    });
    Timer(const Duration(milliseconds: 650), _toReveal);
  }

  void _resolveFreeze() {
    if (_answered) return;
    _answered = true;
    final survived = _r.nextBool();
    setState(() {
      _result = survived ? 'you held it 😐 ice cold' : 'you cracked 😂 @${cell.people[0].name} won';
    });
    Buzz.pop();
    _toReveal();
  }

  void _resolveRapid() {
    if (_answered) return;
    _answered = true;
    Buzz.commit();
    setState(() {
      _result = 'quick hands — @${cell.people[0].name} liked that';
    });
    Timer(const Duration(milliseconds: 400), _toReveal);
  }

  // ---- actions --------------------------------------------------------------
  void _react() {
    Buzz.tap();
    setState(() => _reactCount++);
    _float('😂');
    if (widget.live) NetworkClient.instance.react('😂');
  }

  void _share() {
    Buzz.commit();
    _toast('✨ moment saved — share it from your Moments tab');
  }

  void _save(Person p) {
    AppSession.instance.spark(p);
    if (widget.live && p.id != null) NetworkClient.instance.save(p.id!);
    _toast('✨ sparked @${p.name} — added to your people');
    Buzz.commit();
    setState(() {});
  }

  void _openReport(Person p) {
    Buzz.commit();
    final name = p.name;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(12),
        child: Glass(
          radius: 26,
          padding: const EdgeInsets.all(6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _sheetRow(Icons.flag_outlined, 'Report @$name', C.tx, () {
                Navigator.pop(ctx);
                if (widget.live && p.id != null) NetworkClient.instance.report(p.id!);
                _toast('reported — our team is on it');
              }),
              const Divider(height: 1, color: C.hair),
              _sheetRow(Icons.block_rounded, 'Block @$name', C.live, () {
                Navigator.pop(ctx);
                if (widget.live && p.id != null) NetworkClient.instance.block(p.id!);
                _toast('blocked — you won’t see them again');
                widget.onNext();
              }),
              const Divider(height: 1, color: C.hair),
              _sheetRow(null, 'Cancel', C.tx2, () => Navigator.pop(ctx), center: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetRow(IconData? icon, String label, Color color, VoidCallback onTap, {bool center = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
        child: Row(
          mainAxisAlignment: center ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            if (icon != null) ...[Icon(icon, size: 20, color: color), const SizedBox(width: 12)],
            Text(label, style: T.body.copyWith(color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: C.char3,
        content: Text(msg, style: T.sub.copyWith(color: Colors.white)),
        duration: const Duration(milliseconds: 2200),
      ));
  }

  // ---- build ---------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    if (widget.live) {
      return ValueListenableBuilder<int>(
        valueListenable: RtcService.instance.rev,
        builder: (context, _, __) => _scaffold(context),
      );
    }
    return _scaffold(context);
  }

  Widget _scaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: C.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. faces — full bleed, edge to edge
          _grid(),
          // 2. legibility gradients (subtle, so faces still read through)
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x99000000), Color(0x00000000), Color(0x00000000), Color(0xCC000000)],
                  stops: [0.0, 0.16, 0.55, 1.0],
                ),
              ),
            ),
          ),
          // 3. floating chrome
          SafeArea(
            child: Stack(
              children: [
                _topBar(),
                _rail(),
                _caption(),
                Positioned(
                  top: 8,
                  left: 20,
                  right: 20,
                  child: IgnorePointer(
                    child: AnimatedSwitcher(
                      duration: M.quick,
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: ScaleTransition(scale: Tween(begin: 0.92, end: 1.0).animate(anim), child: child),
                      ),
                      child: _twist == null
                          ? const SizedBox.shrink()
                          : _TwistBanner(key: ValueKey<String>(_twist!), text: _twist!),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---- the face wall --------------------------------------------------------
  Widget _grid() {
    final n = cell.people.length;
    final personTiles = List.generate(n, (i) => _face(i));

    if (n == 1) {
      return Column(children: [
        Expanded(child: personTiles[0]),
        const SizedBox(height: 2),
        Expanded(child: _selfFace()),
      ]);
    }

    final tiles = <Widget>[...personTiles, _selfFace()];
    final cols = tiles.length <= 4 ? 2 : 3;
    return _wall(tiles, cols);
  }

  Widget _wall(List<Widget> tiles, int cols) {
    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i += cols) {
      final end = min(i + cols, tiles.length);
      final rowKids = <Widget>[];
      for (var j = i; j < end; j++) {
        if (j > i) rowKids.add(const SizedBox(width: 2));
        rowKids.add(Expanded(child: tiles[j]));
      }
      rows.add(Expanded(child: Row(children: rowKids)));
      if (end < tiles.length) rows.add(const SizedBox(height: 2));
    }
    return Column(children: rows);
  }

  Widget _face(int i) {
    final p = cell.people[i];
    final canPoint = _phase == _Phase.game && game.kind == GameKind.point && !_answered;
    return PresenceTile(
      person: p,
      radius: 0,
      popDelay: Duration(milliseconds: 60 * i),
      speaking: _speakingIdx == i && _phase != _Phase.drop,
      picked: _pointPick == i || _winnerIdx == i,
      win: _winnerIdx == i && _phase == _Phase.reveal,
      dimmed: _phase == _Phase.reveal && _winnerIdx != null && _winnerIdx != i && game.kind == GameKind.point,
      saved: AppSession.instance.isSaved(p.name),
      videoChild: widget.live ? VideoView(track: RtcService.instance.trackFor(p.id)) : null,
      onTap: canPoint ? () => _resolvePoint(i) : null,
      onReport: () => _openReport(p),
      onSave: () => _save(p),
    );
  }

  Widget _selfFace() {
    return DecoratedBox(
      decoration: const BoxDecoration(color: C.char2),
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.live
              ? VideoView(track: RtcService.instance.localTrack, mirror: true)
              : const SelfView(),
          const Positioned(
            left: 0, right: 0, bottom: 0, height: 54,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter, end: Alignment.topCenter,
                    colors: [Color(0x99000000), Color(0x00000000)],
                  ),
                ),
              ),
            ),
          ),
          const Positioned(
            left: 12, bottom: 10,
            child: Text('you', style: TextStyle(fontSize: 12.5, color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  // ---- top bar (floating) ---------------------------------------------------
  Widget _topBar() {
    return Positioned(
      top: 6,
      left: 12,
      right: 12,
      child: Row(
        children: [
          _iconBtn(Icons.close_rounded, widget.onLeave, size: 40),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0x4D000000),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 7, height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle, color: C.live,
                  boxShadow: [BoxShadow(color: C.live.withOpacity(0.7), blurRadius: 8)],
                ),
              ),
              const SizedBox(width: 7),
              Text(cell.isOneToOne ? 'LIVE · 1:1' : 'LIVE · ${cell.people.length + 1}',
                  style: T.tiny.copyWith(color: Colors.white, letterSpacing: 0.8, fontWeight: FontWeight.w800)),
            ]),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap, {double size = 44}) {
    return Press(
      onTap: onTap,
      child: Container(
        width: size, height: size,
        decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x4D000000)),
        child: Icon(icon, size: size * 0.5, color: Colors.white),
      ),
    );
  }

  // ---- right action rail (TikTok signature) ---------------------------------
  Widget _rail() {
    return Positioned(
      right: 10,
      bottom: 200,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RailAction(
            icon: Icons.favorite_rounded,
            iconColor: C.live,
            label: _reactCount > 0 ? '$_reactCount' : 'react',
            onTap: _react,
          ),
          const SizedBox(height: 20),
          _RailAction(
            icon: Icons.ios_share_rounded,
            iconColor: Colors.white,
            label: 'share',
            onTap: _share,
          ),
        ],
      ),
    );
  }

  // ---- bottom caption (prompt / result / inputs) ----------------------------
  Widget _caption() {
    if (_phase == _Phase.drop) return const SizedBox.shrink();
    return Positioned(
      left: 16,
      right: 16,
      bottom: 14,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_phase == _Phase.reveal)
            _revealBody()
          else ...[
            Row(
              children: [
                Text(game.name.toUpperCase(),
                    style: T.eyebrow.copyWith(color: C.sig, letterSpacing: 1.8, fontSize: 11)),
                const SizedBox(width: 10),
                AnimatedBuilder(
                  animation: _timer,
                  builder: (context, _) => RingPaint(progress: _timerProgress, size: 18, stroke: 2),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(cell.prompt.first,
                style: T.big.copyWith(fontSize: 24, height: 1.12, shadows: const [
                  Shadow(color: Color(0xCC000000), blurRadius: 12),
                ])),
            const SizedBox(height: 14),
            // right rail sits over the answers, so leave its lane clear
            Padding(
              padding: const EdgeInsets.only(right: 52),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: _inputs(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _inputs() {
    switch (game.kind) {
      case GameKind.point:
        return [
          Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.touch_app_rounded, size: 16, color: C.sig),
            const SizedBox(width: 8),
            Text('tap a face', style: T.sub.copyWith(color: Colors.white)),
          ]),
        ];
      case GameKind.poll:
      case GameKind.wouldRather:
        return [
          _optBtn(cell.prompt[1], 0),
          const SizedBox(height: 8),
          _optBtn(cell.prompt[2], 1),
        ];
      case GameKind.thumbs:
        return [
          Row(children: [
            _thumb('👍', true),
            const SizedBox(width: 10),
            _thumb('👎', false),
          ]),
        ];
      case GameKind.same:
      case GameKind.twoTruths:
        return [
          for (var i = 1; i < cell.prompt.length; i++) ...[
            _optBtn(cell.prompt[i], i - 1),
            if (i < cell.prompt.length - 1) const SizedBox(height: 8),
          ],
        ];
      case GameKind.freeze:
        return [Text('hold it… 😐', style: T.sub.copyWith(color: Colors.white))];
      case GameKind.rapidFire:
        return [_optBtn('Done', 0)];
    }
  }

  Widget _optBtn(String label, int index) {
    final sel = _selected == index;
    final pct = _split.isNotEmpty && index < _split.length ? _split[index] : null;
    return Press(
      onTap: _answered
          ? null
          : () {
              switch (game.kind) {
                case GameKind.poll:
                case GameKind.wouldRather:
                  _resolveSplit(index);
                case GameKind.same:
                  _resolveSame(index);
                case GameKind.twoTruths:
                  _resolveTwoTruths(index);
                case GameKind.rapidFire:
                  _resolveRapid();
                default:
                  break;
              }
            },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: sel ? C.sig.withOpacity(0.9) : const Color(0x59000000),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: sel ? C.sig : const Color(0x40FFFFFF)),
        ),
        child: Row(
          children: [
            Expanded(child: Text(label, style: T.body.copyWith(color: Colors.white, fontWeight: FontWeight.w700))),
            if (pct != null) Text('$pct%', style: T.sub.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  Widget _thumb(String glyph, bool guilty) {
    final sel = _selected == (guilty ? 1 : 0);
    return Press(
      onTap: _answered ? null : () => _resolveThumbs(guilty),
      child: Container(
        width: 62,
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: sel ? C.sig.withOpacity(0.9) : const Color(0x59000000),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: sel ? C.sig : const Color(0x40FFFFFF)),
        ),
        child: Text(glyph, style: const TextStyle(fontSize: 24)),
      ),
    );
  }

  Widget _revealBody() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_result,
            style: T.big.copyWith(fontSize: 23, height: 1.16, shadows: const [
              Shadow(color: Color(0xCC000000), blurRadius: 12),
            ])),
        const SizedBox(height: 14),
        Press(
          haptic: false,
          onTap: () {
            Buzz.commit();
            widget.onNext();
          },
          child: Container(
            height: 54,
            width: double.infinity,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Text('Next  ›', style: T.h3.copyWith(color: Colors.black, fontSize: 17)),
          ),
        ),
      ],
    );
  }

  void _float(String emoji) {
    final overlay = Overlay.of(context);
    final size = MediaQuery.of(context).size;
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _FloatingEmoji(
        emoji: emoji,
        startX: size.width * (0.78 + _r.nextDouble() * 0.08),
        startY: size.height * 0.62,
        onDone: () => entry.remove(),
      ),
    );
    overlay.insert(entry);
  }
}

/// One item in the right-side action rail — a circular translucent button with
/// a white icon and a bold label below, TikTok-style.
class _RailAction extends StatelessWidget {
  const _RailAction({required this.icon, required this.label, required this.onTap, this.iconColor = Colors.white});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Press(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48, height: 48,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x40000000)),
            child: Icon(icon, size: 27, color: iconColor),
          ),
          const SizedBox(height: 5),
          Text(label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.w700,
                shadows: [Shadow(color: Color(0xCC000000), blurRadius: 6)],
              )),
        ],
      ),
    );
  }
}

class _FloatingEmoji extends StatefulWidget {
  const _FloatingEmoji({required this.emoji, required this.startX, required this.startY, required this.onDone});
  final String emoji;
  final double startX;
  final double startY;
  final VoidCallback onDone;

  @override
  State<_FloatingEmoji> createState() => _FloatingEmojiState();
}

class _FloatingEmojiState extends State<_FloatingEmoji> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
        ..forward().whenComplete(widget.onDone);
  final _r = Random();
  late final double _drift = (_r.nextDouble() - 0.5) * 60;

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
        final t = _c.value;
        final opacity = t < 0.2 ? t / 0.2 : (t > 0.7 ? (1 - (t - 0.7) / 0.3) : 1.0);
        return Positioned(
          left: widget.startX + _drift * t,
          top: widget.startY - 240 * t,
          child: Opacity(
            opacity: opacity.clamp(0, 1),
            child: Transform.scale(scale: 0.7 + 0.5 * (t * 3).clamp(0, 1), child: Text(widget.emoji, style: const TextStyle(fontSize: 34))),
          ),
        );
      },
    );
  }
}

/// The Director's twist banner — a glass pill with a purple glow that drops in,
/// tells the room what just changed, then fades. The room never goes awkward.
class _TwistBanner extends StatelessWidget {
  const _TwistBanner({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        decoration: BoxDecoration(
          color: const Color(0xE6141018),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: C.sig.withOpacity(0.6)),
          boxShadow: [BoxShadow(color: C.sigGlow, blurRadius: 30, spreadRadius: -8)],
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: T.body.copyWith(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
        ),
      ),
    );
  }
}
