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

/// The live canvas — the reason the app exists. Faces on black; the layout
/// reflows to the (unpredictable) group size; a game is already running so there
/// is never dead air; every round builds to one reveal beat; NEXT re-rolls, and
/// an idle cell recomposes on its own so you feel the pull.
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

  int? _pointPick; // tile the user pointed at
  int? _selected; // generic selected option
  int? _winnerIdx; // tile to spotlight on reveal
  int? _saveIdx; // tile that shows the reconnect "save"
  String _result = '';
  List<int> _split = const [];

  int _speakingIdx = -1;
  Timer? _idle;
  Timer? _speak;
  Timer? _startTimer;
  StreamSubscription<Map<String, dynamic>>? _netSub;

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
    // relay peers' reactions in live mode
    if (widget.live) {
      _netSub = NetworkClient.instance.events.listen((m) {
        if (!mounted) return;
        if (m['t'] == 'react' && m['e'] is String) _float(m['e'] as String);
      });
    }
  }

  @override
  void dispose() {
    _timer.dispose();
    _idle?.cancel();
    _speak?.cancel();
    _startTimer?.cancel();
    _netSub?.cancel();
    super.dispose();
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
    // timed out — resolve with a sensible default so the beat still lands
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
    setState(() => _phase = _Phase.reveal);
    // involuntary recompose if the user just sits there — the loop pulls.
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
      _saveIdx = winner;
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
      _saveIdx = _r.nextInt(cell.people.length);
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
      _saveIdx = _r.nextInt(cell.people.length);
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
      _saveIdx = _r.nextInt(cell.people.length);
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
      _saveIdx = 0;
      _result = correct ? 'you read them 😏 nailed the lie' : 'they fooled you 😵 slippery';
    });
    Timer(const Duration(milliseconds: 650), _toReveal);
  }

  void _resolveFreeze() {
    if (_answered) return;
    _answered = true;
    final survived = _r.nextBool();
    setState(() {
      _saveIdx = _r.nextInt(cell.people.length);
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
      _saveIdx = 0;
      _result = 'quick hands — @${cell.people[0].name} liked that';
    });
    Timer(const Duration(milliseconds: 400), _toReveal);
  }

  // ---- report / block -------------------------------------------------------
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
      // rebuild when LiveKit tracks change so video tiles fill in
      return ValueListenableBuilder<int>(
        valueListenable: RtcService.instance.rev,
        builder: (context, _, __) => _scaffold(context),
      );
    }
    return _scaffold(context);
  }

  Widget _scaffold(BuildContext context) {
    final r = Responsive.of(context);
    return Scaffold(
      backgroundColor: C.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // stage
          Padding(
            padding: EdgeInsets.fromLTRB(12, MediaQuery.of(context).padding.top + 62, 12, 0),
            child: _buildGrid(),
          ),
          // cinematic legibility scrims (top for the bar, bottom for the card)
          Positioned(
            top: 0, left: 0, right: 0, height: 150,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Colors.black.withOpacity(0.65), Colors.transparent],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0, left: 0, right: 0, height: 260,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter, end: Alignment.topCenter,
                    colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                  ),
                ),
              ),
            ),
          ),
          // top bar
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  Press(
                    onTap: widget.onLeave,
                    child: Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: C.glass, border: Border.all(color: C.hair)),
                      child: const Icon(Icons.close_rounded, size: 20, color: C.tx2),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0x59000000),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: C.hair),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(width: 6, height: 6, decoration: BoxDecoration(
                        shape: BoxShape.circle, color: C.live,
                        boxShadow: [BoxShadow(color: C.live.withOpacity(0.6), blurRadius: 8)])),
                      const SizedBox(width: 7),
                      Text(cell.isOneToOne ? 'LIVE · 1:1' : 'LIVE · ${cell.people.length + 1} people',
                          style: T.tiny.copyWith(color: C.tx2, letterSpacing: 1, fontWeight: FontWeight.w800)),
                    ]),
                  ),
                  const Spacer(),
                  const SizedBox(width: 38),
                ],
              ),
            ),
          ),
          // game / reveal card
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(r.gutter * 0.6, 0, r.gutter * 0.6, 12),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: r.stageMaxWidth),
                  child: _phase == _Phase.drop ? const SizedBox.shrink() : _buildCard(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The camera IS the interface. 1:1 stacks them over you; groups are an equal
  /// FaceTime grid with you as one of the tiles (never a floating box).
  Widget _buildGrid() {
    final n = cell.people.length; // strangers
    final personTiles = List.generate(n, (i) => _tile(i));

    if (n == 1) {
      return Column(children: [
        Expanded(child: personTiles[0]),
        const SizedBox(height: 8),
        Expanded(child: _selfTile()),
      ]);
    }

    final tiles = <Widget>[...personTiles, _selfTile()];
    final cols = tiles.length <= 4 ? 2 : 3;
    return _facetime(tiles, cols);
  }

  Widget _facetime(List<Widget> tiles, int cols) {
    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i += cols) {
      final rowKids = <Widget>[];
      for (var j = 0; j < cols; j++) {
        if (j > 0) rowKids.add(const SizedBox(width: 8));
        final idx = i + j;
        rowKids.add(Expanded(child: idx < tiles.length ? tiles[idx] : const SizedBox()));
      }
      rows.add(Expanded(child: Row(children: rowKids)));
      if (i + cols < tiles.length) rows.add(const SizedBox(height: 8));
    }
    return Column(children: rows);
  }

  Widget _selfTile() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: C.char2,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0x1FFFFFFF)),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            widget.live
                ? VideoView(track: RtcService.instance.localTrack, mirror: true)
                : const SelfView(),
            Positioned(
              top: 0, left: 12, right: 12,
              child: Container(height: 1, decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0x00FFFFFF), C.spec, Color(0x00FFFFFF)]))),
            ),
            const Positioned(
              left: 12, bottom: 11,
              child: Text('you', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(int i) {
    final p = cell.people[i];
    final canPoint = _phase == _Phase.game && game.kind == GameKind.point && !_answered;
    return PresenceTile(
      person: p,
      popDelay: Duration(milliseconds: 70 * i),
      speaking: _speakingIdx == i && _phase != _Phase.drop,
      picked: _pointPick == i || _winnerIdx == i,
      win: _winnerIdx == i && _phase == _Phase.reveal,
      dimmed: _phase == _Phase.reveal && _winnerIdx != null && _winnerIdx != i && game.kind == GameKind.point,
      showSave: _phase == _Phase.reveal && _saveIdx == i,
      saved: AppSession.instance.isSaved(p.name),
      videoChild: widget.live ? VideoView(track: RtcService.instance.trackFor(p.id)) : null,
      onTap: canPoint ? () => _resolvePoint(i) : null,
      onReport: () => _openReport(p),
      onSave: () {
        AppSession.instance.save(p.name);
        _toast('saved @${p.name} — you’ll know when they’re live');
        Buzz.commit();
      },
    );
  }

  Widget _buildCard() {
    return Glass(
      radius: 26,
      padding: const EdgeInsets.all(20),
      tint: const Color(0x99101113),
      child: _phase == _Phase.reveal ? _revealBody() : _gameBody(),
    );
  }

  Widget _gameBody() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(game.name.toUpperCase(),
                style: T.eyebrow.copyWith(color: C.sig, letterSpacing: 1.8, fontSize: 11)),
            const Spacer(),
            AnimatedBuilder(
              animation: _timer,
              builder: (context, _) => RingPaint(progress: _timerProgress, size: 22, stroke: 2),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(cell.prompt.first, style: T.big.copyWith(fontSize: 22, height: 1.14)),
        const SizedBox(height: 6),
        Text(game.hint, style: T.tiny),
        const SizedBox(height: 16),
        ..._inputs(),
      ],
    );
  }

  List<Widget> _inputs() {
    switch (game.kind) {
      case GameKind.point:
        return [Text('tap someone’s tile', style: T.sub.copyWith(color: C.tx2))];
      case GameKind.poll:
      case GameKind.wouldRather:
        return [
          _optBtn(cell.prompt[1], 0),
          const SizedBox(height: 9),
          _optBtn(cell.prompt[2], 1),
        ];
      case GameKind.thumbs:
        return [
          Row(children: [
            Expanded(child: _thumb('👍', true)),
            const SizedBox(width: 10),
            Expanded(child: _thumb('👎', false)),
          ]),
        ];
      case GameKind.same:
        return [
          for (var i = 1; i < cell.prompt.length; i++) ...[
            _optBtn(cell.prompt[i], i - 1),
            if (i < cell.prompt.length - 1) const SizedBox(height: 9),
          ],
        ];
      case GameKind.twoTruths:
        return [
          for (var i = 1; i < cell.prompt.length; i++) ...[
            _optBtn(cell.prompt[i], i - 1),
            if (i < cell.prompt.length - 1) const SizedBox(height: 9),
          ],
        ];
      case GameKind.freeze:
        return [Text('hold it… 😐', style: T.sub.copyWith(color: C.tx2))];
      case GameKind.rapidFire:
        return [
          _optBtn('Done', 0),
        ];
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: sel ? C.glass2 : C.glass,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: sel ? C.sig : C.hair),
        ),
        child: Row(
          children: [
            Expanded(child: Text(label, style: T.body.copyWith(color: Colors.white, fontWeight: FontWeight.w600))),
            if (pct != null) Text('$pct%', style: T.sub.copyWith(color: C.tx3, fontWeight: FontWeight.w700)),
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
        padding: const EdgeInsets.symmetric(vertical: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: sel ? C.glass2 : C.glass,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: sel ? C.sig : C.hair),
        ),
        child: Text(glyph, style: const TextStyle(fontSize: 26)),
      ),
    );
  }

  Widget _revealBody() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_result, style: T.big.copyWith(fontSize: 21, height: 1.2)),
        const SizedBox(height: 16),
        Row(
          children: [
            Press(
              onTap: () {
                Buzz.tap();
                _float('😂');
                if (widget.live) NetworkClient.instance.react('😂');
              },
              child: Container(
                width: 54, height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: C.glass, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.hair)),
                child: const Text('😂', style: TextStyle(fontSize: 22)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Press(
                haptic: false,
                onTap: () {
                  Buzz.commit();
                  widget.onNext();
                },
                child: Container(
                  height: 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                  child: Text('Next  ›', style: T.h3.copyWith(color: Colors.black, fontSize: 16)),
                ),
              ),
            ),
          ],
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
        startX: size.width * (0.4 + _r.nextDouble() * 0.2),
        startY: size.height * 0.7,
        onDone: () => entry.remove(),
      ),
    );
    overlay.insert(entry);
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
          left: widget.startX,
          top: widget.startY - 220 * t,
          child: Opacity(
            opacity: opacity.clamp(0, 1),
            child: Transform.scale(scale: 0.7 + 0.5 * (t * 3).clamp(0, 1), child: Text(widget.emoji, style: const TextStyle(fontSize: 34))),
          ),
        );
      },
    );
  }
}
