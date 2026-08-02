import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../core/analytics.dart';
import '../core/haptics.dart';
import '../core/sound.dart';
import '../models/game.dart';
import '../models/person.dart';
import '../net/network_client.dart';
import '../net/p2p_service.dart';
import '../net/rtc_service.dart';
import '../state/session.dart';
import '../state/social.dart';
import '../theme/tokens.dart';
import '../widgets/identity_orb.dart';
import '../widgets/countdown_ring.dart';
import '../widgets/glass.dart';
import '../widgets/presence_tile.dart';
import '../widgets/self_view.dart';
import '../widgets/video_view.dart';

enum _Phase { drop, talk, game, reveal, awards, wheel }

/// The room. TikTok-clean, FaceTime-exact.
///
/// Faces fill the screen edge to edge — 1:1 is them full-bleed with you as a
/// floating PiP; groups are perfect 2-column grids. Every room has a name, a
/// running game, and an engine of unpredictability: Chaos Cards strike without
/// warning, 1-in-25 rooms go GOLDEN, someone is secretly the ⭐ Main Character,
/// reactions chain into combos — and every room ends in an awards ceremony the
/// room itself decides, with confetti and one huge NEXT ROOM.
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

class _Award {
  const _Award(this.emoji, this.label, this.winner);
  final String emoji;
  final String label;
  final String winner; // '@name' or 'you'
}

class _LiveScreenState extends State<LiveScreen> with TickerProviderStateMixin {
  final _r = Random();
  late final AnimationController _timer =
      AnimationController(vsync: this)..addListener(_onTick);

  _Phase _phase = _Phase.drop;
  bool _answered = false;
  int _lastSec = -1;

  int? _pointPick;
  bool _pointSelfPick = false; // duo rooms vote with buttons — "me" picked
  final Set<String> _friendReqSent = {}; // uids already friend-requested from this room
  int? _selected;
  int? _winnerIdx;
  String _result = '';
  List<int> _split = const [];
  List<_Award> _awards = const [];
  String? _voteEmoji;

  // the unpredictability engine — server-rolled when available, local otherwise
  late final bool _golden = widget.cell.golden ?? (_r.nextDouble() < 0.04);
  late final int _lucky = _idxOf(widget.cell.luckyId) ?? _r.nextInt(cell.people.length + 1);
  int _reactCount = 0;
  int _combo = 0;
  Timer? _comboReset;

  // server-authoritative mode: a sync-capable server stamps targetId on every
  // round. When present, the server owns timing/results/awards/wheel and the
  // local machinery becomes the fail-soft fallback.
  bool get _serverDriven => widget.live && cell.rounds.first.targetId != null;
  Timer? _resultGrace;
  Timer? _wheelTimeout;
  bool _wheelArming = false;
  DateTime? _roundEndsAt;

  /// Resolve a member conn-id to a tile index ('you' == people.length).
  /// Always resolved at use time — indices shift when someone leaves.
  int? _idxOf(String? id) {
    if (id == null) return null;
    if (id == NetworkClient.instance.myId) return cell.people.length;
    final i = cell.people.indexWhere((p) => p.id == id);
    return i >= 0 ? i : null;
  }

  int _speakingIdx = -1;
  Timer? _idle;
  Timer? _speak;
  Timer? _startTimer;
  Timer? _director;
  StreamSubscription<Map<String, dynamic>>? _netSub;

  // Chaos Cards — the room changes without warning.
  List<String>? _chaos; // [emoji, text]
  static const _chaosCards = [
    ['🤫', 'Everyone WHISPER until the next game'],
    ['🤥', 'Next answer must be a LIE'],
    ['🙃', 'Flip your phone upside down. Now.'],
    ['😐', 'Last to smile wins the room'],
    ['👉', 'Everybody point at someone. NOW.'],
    ['😂', '10 seconds to make the room laugh'],
    ['🎭', 'Swap accents with the person on your left'],
    ['🌀', 'CHAOS — the rules just changed'],
  ];

  // a room is a session — several rounds, then the ceremony, then the wheel
  int _round = 0;
  bool _stamp = true; // the room-name stamp on arrival
  bool _wheelRevive = false; // decided once, when the wheel is armed

  // the {target} engine — every round one random person can be "it". For spin
  // games the animated bottle IS the picker; for others it fills prompt slots.
  int _target = 0;
  bool _bottleDone = true;

  // your PiP in 1:1 — draggable; null = default anchor (bottom-right)
  Offset? _pipPos;

  // talk-first: games played this hang (simulated ceremony every 3rd)
  int _gamesPlayed = 0;

  // blended games — the remaining local beat chain + beat counters for the pill
  final List<RoundDef> _seqQueue = [];
  int _beat = 1;
  int _beats = 1;

  /// roulette rooms: no choices — games auto-chain
  bool get _roulette => (widget.cell.mode ?? 'hang') == 'roulette';
  bool get _isCall => (widget.cell.mode ?? 'hang') == 'call';

  Cell get cell => widget.cell;
  GameDef get game => cell.rounds[_round].game;
  List<String> get _prompt => cell.rounds[_round].prompt;

  String get _targetName =>
      _target >= cell.people.length ? 'you' : '@${cell.people[_target].name}';

  /// Fill prompt variables — the same prompt lands on a different victim
  /// every single time it's played.
  String _fill(String s) => s.replaceAll('{target}', _targetName);

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable(); // never sleep on a live call
    Buzz.pop();
    Sfx.match();
    // the arrival stamp — the room's name slams across the faces, then clears
    Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _stamp = false);
    });
    _speak = Timer.periodic(const Duration(milliseconds: 1200), (_) {
      if (!mounted || cell.people.isEmpty) return;
      setState(() => _speakingIdx = _r.nextInt(cell.people.length));
    });
    _startTimer = Timer(const Duration(milliseconds: 1300), _toTalk);
    // the Director strikes somewhere in the first stretch — nobody knows when.
    // (In server-driven rooms chaos is pushed by the server so all phones
    // flash the same card at the same moment.)
    if (!_serverDriven) {
      _director = Timer(Duration(milliseconds: 8000 + _r.nextInt(9000)), _dropChaos);
    }
    if (widget.live) {
      _netSub = NetworkClient.instance.events.listen(_onNet);
    }
  }

  // ---- server events (the shared room) --------------------------------------
  void _onNet(Map<String, dynamic> m) {
    if (!mounted) return;
    switch (m['t']) {
      case 'react':
        if (m['e'] is String) {
          _bumpCombo();
          _float(m['e'] as String);
        }
      case 'round':
        _onRoundMsg(m);
      case 'result':
        _onResultMsg(m);
      case 'chaos':
        if (_serverDriven && m['e'] is String && m['x'] is String) {
          Buzz.impact();
          Sfx.slam();
          Track.event('chaos_card');
          setState(() => _chaos = [m['e'] as String, m['x'] as String]);
          Timer(const Duration(milliseconds: 3200), () {
            if (mounted) setState(() => _chaos = null);
          });
        }
      case 'awards':
        _onAwardsMsg(m);
      case 'wheel':
        _onWheelMsg(m);
      case 'talk':
        if (_serverDriven && _phase != _Phase.wheel) _toTalk();
      case 'peerJoined':
        _onPeerJoined(m);
      case 'peerLeft':
        _onPeerLeft(m);
    }
  }

  /// Someone walked into the room — the solo full-screen shrinks to a PiP,
  /// grids reflow, and the moment gets a beat of celebration.
  void _onPeerJoined(Map<String, dynamic> m) {
    final id = m['id'] as String?;
    if (id == null || cell.people.any((p) => p.id == id)) return;
    Buzz.pop();
    Sfx.match();
    Track.event('walk_in');
    final name = (m['name'] as String?) ?? 'someone';
    setState(() {
      cell.people.add(Person(
        id: id,
        uid: m['uid'] as String?,
        name: name,
        hue: ((m['hue'] as num?) ?? 210).toDouble(),
        lx: 0.2 + _r.nextDouble() * 0.5,
        ly: 0.22 + _r.nextDouble() * 0.4,
      ));
      // per-round tile indices can be stale after a reflow — clear them
      _voteCounts = {};
      _pointPick = null;
      _pointSelfPick = false;
      if (_winnerIdx != null && _winnerIdx! >= cell.people.length) _winnerIdx = null;
    });
    _toast('@$name just dropped in 👋');
  }

  void _onPeerLeft(Map<String, dynamic> m) {
    final id = m['id'] as String?;
    if (id == null) return;
    final i = cell.people.indexWhere((p) => p.id == id);
    if (i < 0) return;
    final gone = cell.people[i];
    setState(() {
      cell.people.removeAt(i);
      _voteCounts = {};
      _pointPick = null;
      _pointSelfPick = false;
      _winnerIdx = null;
      if (_target > cell.people.length) _target = cell.people.length;
    });
    _toast('@${gone.name} left the room');
  }

  void _onRoundMsg(Map<String, dynamic> m) {
    if (!_serverDriven || _phase == _Phase.wheel) return;
    final idx = (m['idx'] as num?)?.toInt();
    if (idx == null || idx < 0) return;
    // the round now carries its game — the room picked it live
    if (m['game'] is Map) {
      final wire = _roundFromWire((m['game'] as Map).cast<String, dynamic>());
      while (cell.rounds.length <= idx) {
        cell.rounds.add(wire);
      }
      cell.rounds[idx] = wire;
    }
    if (idx >= cell.rounds.length) return;
    final ends = (m['endsAt'] as num?)?.toInt();
    _roundEndsAt = ends != null ? DateTime.fromMillisecondsSinceEpoch(ends) : null;
    _beat = (m['beat'] as num?)?.toInt() ?? 1;
    _beats = (m['beats'] as num?)?.toInt() ?? 1;
    // hard-sync to the server's clock: cancel every local fallback
    _idle?.cancel();
    _startTimer?.cancel();
    _resultGrace?.cancel();
    _revealTick?.cancel();
    setState(() {
      _revealCount = null;
      _round = idx;
      _answered = false;
      _pointPick = null;
      _pointSelfPick = false;
      _selected = null;
      _winnerIdx = null;
      _split = const [];
      _result = '';
      _voteCounts = {};
    });
    if (_beat == 1) {
      Track.event('game_started', {
        'game': cell.rounds[idx].game.name,
        'mode': cell.mode ?? 'hang',
      });
    }
    _startGame();
  }

  void _onResultMsg(Map<String, dynamic> m) {
    if (!_serverDriven) return;
    final rIdx = (m['round'] as num?)?.toInt();
    if (rIdx != _round || _phase != _Phase.game) return;
    _resultGrace?.cancel();
    _timer.stop();
    _answered = true;

    final winnerIdx = _idxOf(m['winnerId'] as String?);
    final isYou = winnerIdx != null && winnerIdx >= cell.people.length;
    String nameOf(int i) => '@${cell.people[i].name}';

    setState(() {
      switch (game.kind) {
        case GameKind.point:
          final tally = (m['tally'] as Map?) ?? const {};
          _voteCounts = {};
          for (final e in tally.entries) {
            final ti = _idxOf(e.key as String?);
            final c = (e.value as num?)?.toInt() ?? 0;
            if (ti != null && c > 0) _voteCounts[ti] = c;
          }
          if (isYou) {
            _result = 'the room pointed at YOU 😳';
          } else if (winnerIdx != null) {
            _winnerIdx = winnerIdx;
            _result = 'the room pointed at ${nameOf(winnerIdx)}';
          } else {
            _result = 'the room couldn’t decide 🤝';
          }
        case GameKind.spin:
          _result = isYou
              ? 'you took it on the chin 😎'
              : '$_targetName said what they said 💅';
          if (winnerIdx != null && winnerIdx < cell.people.length) _winnerIdx = winnerIdx;
        case GameKind.freeze:
          _result = isYou ? 'you held it 😐 ice cold' : 'you cracked 😂 ${winnerIdx != null ? nameOf(winnerIdx) : 'they'} won';
        case GameKind.rapidFire:
          _result = 'quick hands — the room felt that';
        case GameKind.thumbs:
          final g = (m['guilty'] as num?)?.toInt() ?? 0;
          _result = g == 0 ? 'not one guilty soul 😇 (cap)' : '$g in the room ${g == 1 ? 'is' : 'are'} guilty 👀';
        case GameKind.poll:
        case GameKind.wouldRather:
          final counts = ((m['counts'] as List?) ?? const []).map((e) => (e as num).toInt()).toList();
          final total = counts.fold<int>(0, (a, b) => a + b);
          final a = total > 0 && counts.isNotEmpty ? (counts[0] * 100 / total).round() : 50;
          _split = [a, 100 - a];
          if (_selected != null && _selected! < _split.length) {
            _result = 'the room split ${_split[_selected!]}% your way';
          } else {
            _result = 'the room split $a / ${100 - a}';
          }
        case GameKind.same:
          final counts = ((m['counts'] as List?) ?? const []).map((e) => (e as num).toInt()).toList();
          final matches = _selected != null && _selected! < counts.length
              ? (counts[_selected!] - 1).clamp(0, 99)
              : 0;
          _result = matches > 0 ? '$matches of you said the same thing 🧠' : 'nobody matched you — iconic';
        case GameKind.twoTruths:
          final lie = (m['lieIdx'] as num?)?.toInt() ?? cell.rounds[_round].lieIdx;
          if (_selected == null) {
            _result = 'the lie slipped past everyone 👀';
          } else if (lie != null && _selected == lie) {
            _result = 'you read them 😏 nailed the lie';
          } else {
            _result = 'they fooled you 😵 slippery';
          }
      }
    });
    _toReveal();
  }

  void _onAwardsMsg(Map<String, dynamic> m) {
    if (!_serverDriven || _phase == _Phase.wheel) return;
    final list = (m['list'] as List?) ?? const [];
    final awards = <_Award>[];
    for (final e in list.whereType<Map>()) {
      final idx = _idxOf(e['winnerId'] as String?);
      final winner = idx == null
          ? 'someone'
          : (idx >= cell.people.length ? 'you' : '@${cell.people[idx].name}');
      awards.add(_Award((e['emoji'] as String?) ?? '🏆', (e['label'] as String?) ?? '', winner));
    }
    if (awards.isEmpty) return;
    if (_phase == _Phase.awards) {
      // local fallback fired first — replace with the room's real verdict
      setState(() => _awards = awards);
      return;
    }
    _idle?.cancel();
    _awards = awards;
    var earned = false;
    for (final a in _awards) {
      if (a.winner == 'you') {
        AppSession.instance.earnBadge('${a.emoji} ${a.label}');
        earned = true;
      }
    }
    if (_golden && earned) AppSession.instance.earnBadge('🏆 Golden Room');
    Track.event('awards_shown');
    Buzz.impact();
    Sfx.fanfare();
    setState(() => _phase = _Phase.awards);
    _idle = Timer(const Duration(seconds: 30), () {
      if (mounted && _phase == _Phase.awards) widget.onNext();
    });
  }

  RoundDef _roundFromWire(Map<String, dynamic> g) {
    final kind = gameKindFrom((g['kind'] as String?) ?? 'poll');
    final base = GameDef.byKind(kind);
    final def = GameDef(
      kind: kind,
      name: (g['name'] as String?) ?? base.name,
      hint: (g['hint'] as String?) ?? base.hint,
      minStrangers: base.minStrangers,
      maxStrangers: base.maxStrangers,
      prompts: base.prompts,
    );
    final prompt = ((g['prompt'] as List?) ?? const []).map((e) => e.toString()).toList();
    return RoundDef(
      game: def,
      prompt: prompt.isEmpty ? def.prompts.first : prompt,
      targetId: g['targetId'] as String?,
      lieIdx: (g['lieIdx'] as num?)?.toInt(),
    );
  }

  void _onWheelMsg(Map<String, dynamic> m) {
    if (!_wheelArming) return;
    _wheelTimeout?.cancel();
    _wheelRevive = m['revive'] == true;
    Track.event('wheel_spun', {'revive': _wheelRevive ? 1 : 0});
    final rw = (m['rounds'] as List?) ?? const [];
    if (_wheelRevive && rw.isNotEmpty) {
      cell.rounds = rw
          .whereType<Map>()
          .map((e) => _roundFromWire(e.cast<String, dynamic>()))
          .toList();
    }
    _enterWheel();
  }

  void _enterWheel() {
    _wheelArming = false;
    _idle?.cancel();
    setState(() => _phase = _Phase.wheel);
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _timer.dispose();
    _idle?.cancel();
    _speak?.cancel();
    _startTimer?.cancel();
    _director?.cancel();
    _comboReset?.cancel();
    _resultGrace?.cancel();
    _wheelTimeout?.cancel();
    _revealTick?.cancel();
    _netSub?.cancel();
    super.dispose();
  }

  void _dropChaos() {
    if (!mounted || _phase == _Phase.awards || _phase == _Phase.wheel) return;
    Buzz.impact();
    Sfx.slam();
    setState(() => _chaos = _chaosCards[_r.nextInt(_chaosCards.length)]);
    Timer(const Duration(milliseconds: 3200), () {
      if (mounted) setState(() => _chaos = null);
    });
  }

  // ---- reactions & combos ---------------------------------------------------
  void _bumpCombo() {
    _reactCount++;
    _combo++;
    _comboReset?.cancel();
    _comboReset = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _combo = 0);
    });
    if (_combo == 3 || _combo == 6 || _combo == 10) {
      Buzz.impact();
      Sfx.combo();
    }
    setState(() {});
  }

  void _react() {
    Buzz.tap();
    Sfx.pop();
    _bumpCombo();
    _float('😂');
    if (widget.live) NetworkClient.instance.react('😂');
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
      if (left <= 3 && left > 0) {
        Buzz.tick();
        Sfx.pip();
      }
    }
    setState(() {});
  }

  double get _timerProgress => 1 - _timer.value;

  // ---- phase machine --------------------------------------------------------

  /// The room's resting state: faces + conversation. Games are something the
  /// room chooses to do, not a conveyor belt.
  void _toTalk() {
    if (!mounted || _phase == _Phase.wheel) return;
    _timer.stop();
    _idle?.cancel();
    _resultGrace?.cancel();
    setState(() {
      _phase = _Phase.talk;
      _answered = false;
      _result = '';
      _voteCounts = {};
    });
    // roulette: the wheel of fate rolls the next game on its own
    if (_roulette && !_serverDriven) {
      _idle = Timer(const Duration(seconds: 6), () {
        if (mounted && _phase == _Phase.talk) _requestGame();
      });
    }
  }

  /// Anyone starts one of THE TEN — a chosen game or the dice. Each game is a
  /// blended chain of beats played back to back.
  void _requestGame([String? name]) {
    Buzz.commit();
    Sfx.pop();
    Track.event('game_picked', {'game': name ?? 'random'});
    if (_serverDriven) {
      NetworkClient.instance.pickGame(name);
      return; // the {t:'round'} broadcast starts it for everyone
    }
    // simulated / old server: build the beat chain locally
    final seq = (name != null ? SeqDef.byName(name) : null) ??
        SeqDef.ten[_r.nextInt(SeqDef.ten.length)];
    final beats = seq.beats.map((b) {
      final chosen = [...b.pool[_r.nextInt(b.pool.length)]];
      final head = chosen.removeAt(0);
      chosen.shuffle(_r);
      return RoundDef(
        game: GameDef(
          kind: b.kind, name: seq.name, hint: seq.hint,
          minStrangers: 0, maxStrangers: 8,
          prompts: const [['—']],
        ),
        prompt: [head, ...chosen],
        secs: b.secs,
      );
    }).toList();

    _seqQueue
      ..clear()
      ..addAll(beats.skip(1));
    _beat = 1;
    _beats = beats.length;
    cell.rounds.add(beats.first);
    setState(() {
      _round = cell.rounds.length - 1;
      _pointPick = null;
      _pointSelfPick = false;
      _selected = null;
      _winnerIdx = null;
      _split = const [];
      _voteCounts = {};
    });
    _startGame();
  }

  /// The next beat of the current blended game (simulated chaining).
  void _nextLocalBeat() {
    if (_seqQueue.isEmpty) return;
    final next = _seqQueue.removeAt(0);
    cell.rounds.add(next);
    setState(() {
      _round = cell.rounds.length - 1;
      _beat++;
      _answered = false;
      _pointPick = null;
      _pointSelfPick = false;
      _selected = null;
      _winnerIdx = null;
      _split = const [];
      _result = '';
      _voteCounts = {};
    });
    _startGame();
  }

  /// The game picker — THE TEN, each with a living icon. Warm up top,
  /// spark at the bottom.
  void _openPicker() {
    Buzz.tick();
    const order = ['warm', 'wild', 'spark'];
    final games = [...SeqDef.ten]
      ..sort((a, b) => order.indexOf(a.vibe).compareTo(order.indexOf(b.vibe)));
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(12),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.76),
          decoration: BoxDecoration(
            color: const Color(0xF20B0C10),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: C.hair2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 18),
              Text('PICK A GAME', style: T.eyebrow.copyWith(letterSpacing: 3, fontSize: 11)),
              const SizedBox(height: 4),
              Text('every one is a few rounds back to back', style: T.tiny),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 18),
                  shrinkWrap: true,
                  itemCount: games.length,
                  itemBuilder: (ctx2, i) {
                    final g = games[i];
                    return _GameRow(
                      seq: g,
                      delay: Duration(milliseconds: 40 * i),
                      onTap: () {
                        Navigator.pop(ctx);
                        _requestGame(g.name);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startGame() {
    setState(() {
      _phase = _Phase.game;
      _answered = false;
      // this round's target: the server's pick when synced, else a local roll.
      // The bottle animates the pick for spin games either way.
      _target = _idxOf(cell.rounds[_round].targetId) ?? _r.nextInt(cell.people.length + 1);
      _bottleDone = game.kind != GameKind.spin;
    });
    // mirrors the server's conversation-first table exactly
    var secs = switch (game.kind) {
      GameKind.point => 75, // talk/perform games — they need real time
      GameKind.spin => 45,
      GameKind.freeze => 15,
      GameKind.rapidFire => 20,
      _ => 30, // tap-answer kinds — answer, then chat
    };
    final beatSecs = cell.rounds[_round].secs;
    if (beatSecs != null) secs = beatSecs;
    if (_serverDriven && _roundEndsAt != null) {
      // ride the server's clock so every phone's countdown agrees
      final left = _roundEndsAt!.difference(DateTime.now()).inMilliseconds / 1000;
      secs = left.clamp(3, 90).round();
    }
    // in server-driven rooms the deadline resolution belongs to the server;
    // the grace timer fabricates locally only if the server goes silent.
    _runTimer(secs, _serverDriven ? () {} : _autoResolve);
    if (_serverDriven) {
      _resultGrace?.cancel();
      _resultGrace = Timer(Duration(seconds: secs + 2), () {
        if (mounted && _phase == _Phase.game) {
          _answered = false;
          _autoResolve();
        }
      });
    }
  }

  void _autoResolve() {
    switch (game.kind) {
      case GameKind.point:
        if (cell.people.isEmpty) {
          _resolveFreeze(); // solo warm-up — no one to crown yet
        } else {
          _resolvePoint(_r.nextInt(cell.people.length));
        }
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
      case GameKind.spin:
        _resolveSpin();
    }
  }

  void _resolveSpin() {
    if (_answered) return;
    _answered = true;
    Buzz.commit();
    final lines = [
      '$_targetName took it on the chin 😎',
      'the bottle chose violence 😂',
      '$_targetName will never recover',
      '$_targetName said what they said 💅',
    ];
    setState(() {
      _winnerIdx = _target < cell.people.length ? _target : null;
      _result = lines[_r.nextInt(lines.length)];
    });
    Timer(const Duration(milliseconds: 650), _toReveal);
  }

  // the signature beat: answers stay hidden, then 3…2…1 — everything flips at
  // once. The suspense before the flip is the dopamine.
  int? _revealCount;
  Timer? _revealTick;

  /// point-game vote counts per tile index (people.length == you), shown as
  /// chips on the faces when the reveal flips.
  Map<int, int> _voteCounts = {};

  void _toReveal() {
    if (_revealCount != null) return; // countdown already running
    _timer.stop();
    _revealCount = 3;
    Buzz.tick();
    Sfx.pip();
    setState(() {});
    _revealTick?.cancel();
    _revealTick = Timer.periodic(const Duration(milliseconds: 420), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      final next = (_revealCount ?? 1) - 1;
      if (next <= 0) {
        t.cancel();
        setState(() => _revealCount = null);
        Sfx.match();
        _doReveal();
      } else {
        Buzz.tick();
        Sfx.pip();
        setState(() => _revealCount = next);
      }
    });
  }

  void _doReveal() {
    Buzz.commit();
    AppSession.instance.captureMoment(
      game: game.name,
      result: _result,
      hues: [...cell.people.map((p) => p.hue), AppSession.instance.myHue],
    );
    setState(() => _phase = _Phase.reveal);
    _idle?.cancel();

    // simulated: more beats in this game? quick flip into the next beat.
    if (!_serverDriven && _seqQueue.isNotEmpty) {
      _idle = Timer(const Duration(milliseconds: 4200), () {
        if (mounted && _phase == _Phase.reveal) _nextLocalBeat();
      });
      return;
    }

    _gamesPlayed++;
    // after the reveal breathes, the room goes back to talking. Every 3rd game
    // earns the ceremony. (Server rooms: 'talk'/'awards' messages drive this —
    // the local timers are only the safety net.)
    final ceremonyDue = !_serverDriven && _gamesPlayed % 3 == 0;
    _idle = Timer(Duration(milliseconds: _serverDriven ? 11000 : 6500), () {
      if (!mounted || _phase != _Phase.reveal) return;
      if (ceremonyDue) {
        _toAwards();
      } else {
        _toTalk();
      }
    });
  }

  /// The wheel chose REVIVE — same room, same people, a fresh session.
  void _revive() {
    // server-driven: the shared reroll already arrived with the wheel reply
    if (!_serverDriven) cell.reroll(_r);
    setState(() {
      _round = 0;
      _answered = false;
      _pointPick = null;
      _pointSelfPick = false;
      _selected = null;
      _winnerIdx = null;
      _split = const [];
      _result = '';
      _voteEmoji = null;
      _awards = const [];
      _voteCounts = {};
      _phase = _Phase.drop;
      _stamp = true;
    });
    Buzz.pop();
    Sfx.match();
    Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _stamp = false);
    });
    _startTimer?.cancel();
    _startTimer = Timer(const Duration(milliseconds: 1300), _toTalk);
    if (!_serverDriven) {
      _director?.cancel();
      _director = Timer(Duration(milliseconds: 6000 + _r.nextInt(8000)), _dropChaos);
    }
    _idle?.cancel();
  }

  void _toAwards() {
    _awards = _computeAwards();
    var earned = false;
    for (final a in _awards) {
      if (a.winner == 'you') {
        AppSession.instance.earnBadge('${a.emoji} ${a.label}');
        earned = true;
      }
    }
    if (_golden && earned) AppSession.instance.earnBadge('🏆 Golden Room');
    Buzz.impact();
    Sfx.fanfare();
    setState(() => _phase = _Phase.awards);
    // never a dead end — if you just sit there, the loop pulls you forward.
    _idle?.cancel();
    _idle = Timer(const Duration(seconds: 30), () {
      if (mounted && _phase == _Phase.awards) widget.onNext();
    });
  }

  List<_Award> _computeAwards() {
    final names = [...cell.people.map((p) => '@${p.name}'), 'you']..shuffle(_r);
    final mvp = _winnerIdx != null ? '@${cell.people[_winnerIdx!].name}' : names.first;
    final out = <_Award>[_Award('🏆', 'MVP', mvp)];

    final pool = [
      const ['😂', 'Funniest'],
      const ['😈', 'Chaos Agent'],
      const ['🧠', 'Smartest'],
      const ['👀', 'Weirdest'],
      const ['🔥', 'Main Character'],
    ]..shuffle(_r);
    // your reveal-vote guarantees that award shows up in the ceremony
    if (_voteEmoji != null) {
      final i = pool.indexWhere((p) => p[0] == _voteEmoji);
      if (i > 0) {
        final v = pool.removeAt(i);
        pool.insert(0, v);
      }
    }

    final others = names.where((n) => n != mvp).toList();
    final extra = min(2, pool.length);
    for (var i = 0; i < extra; i++) {
      final winner = others.isEmpty ? mvp : others[i % others.length];
      out.add(_Award(pool[i][0], pool[i][1], winner));
    }
    return out;
  }

  // ---- resolvers ------------------------------------------------------------
  void _resolvePoint(int userPick) {
    if (_answered) return;
    if (_serverDriven) {
      // real vote: tell the server who you tapped, then wait for the tally
      _answered = true;
      Buzz.commit();
      setState(() => _pointPick = userPick);
      final id = cell.people[userPick].id;
      if (id != null) NetworkClient.instance.answer(_round, id);
      return;
    }
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

  /// Duo rooms only: vote for YOURSELF. The server tally accepts any member
  /// id including your own — groups express this by tapping faces, but with
  /// one face on screen it needs a button.
  void _resolvePointSelf() {
    if (_answered) return;
    if (_serverDriven) {
      _answered = true;
      Buzz.commit();
      setState(() => _pointSelfPick = true);
      final me = NetworkClient.instance.myId;
      if (me != null) NetworkClient.instance.answer(_round, me);
      return;
    }
    _answered = true;
    Buzz.commit();
    final winner = cell.people.length == 1 ? 0 : _r.nextInt(cell.people.length);
    setState(() {
      _pointSelfPick = true;
      _winnerIdx = winner;
      _result = 'the room pointed at @${cell.people[winner].name}';
    });
    Timer(const Duration(milliseconds: 850), _toReveal);
  }

  void _resolveSplit(int choice) {
    if (_answered) return;
    if (_serverDriven) {
      _answered = true;
      Buzz.commit();
      setState(() => _selected = choice);
      NetworkClient.instance.answer(_round, choice);
      return;
    }
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
    if (_serverDriven) {
      _answered = true;
      Buzz.commit();
      setState(() => _selected = guilty ? 1 : 0);
      NetworkClient.instance.answer(_round, guilty);
      return;
    }
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
    if (_serverDriven) {
      _answered = true;
      Buzz.commit();
      setState(() => _selected = choice);
      NetworkClient.instance.answer(_round, choice);
      return;
    }
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
    if (_serverDriven) {
      _answered = true;
      Buzz.commit();
      setState(() => _selected = choice);
      NetworkClient.instance.answer(_round, choice);
      return;
    }
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
      _result = survived
          ? 'you held it 😐 ice cold'
          : cell.people.isEmpty
              ? 'you cracked 😂 first'
              : 'you cracked 😂 @${cell.people[0].name} won';
    });
    Buzz.pop();
    _toReveal();
  }

  void _resolveRapid() {
    if (_answered) return;
    if (_serverDriven) {
      _answered = true;
      Buzz.commit();
      NetworkClient.instance.answer(_round, 'done');
      return;
    }
    _answered = true;
    Buzz.commit();
    setState(() {
      _result = cell.people.isEmpty
          ? 'quick hands 👏'
          : 'quick hands — @${cell.people[0].name} liked that';
    });
    Timer(const Duration(milliseconds: 400), _toReveal);
  }

  // ---- save / report / block ------------------------------------------------
  void _save(Person p) {
    Track.event('spark_saved');
    AppSession.instance.spark(p);
    // the server keys saves by the STABLE uid — never the connection id
    final target = p.uid ?? p.id;
    if (widget.live && target != null) NetworkClient.instance.save(target);
    _toast('✨ sparked @${p.name} — they’re in your people now');
    Buzz.commit();
    setState(() {});
  }

  /// The in-room friends sheet — see who you're with, add them as friends.
  /// Requests go out instantly; if they add you back you're friends and
  /// messaging unlocks. No luck, no waiting for the rating prompt.
  void _openAddPeople() {
    Buzz.tick();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final friends = SocialState.instance.friends.map((f) => f.uid).toSet();
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Glass(
              radius: 26,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.group_rounded, size: 20, color: C.sig),
                    const SizedBox(width: 10),
                    Text('in this room', style: T.eyebrow.copyWith(fontSize: 12)),
                  ]),
                  const SizedBox(height: 14),
                  for (final p in cell.people)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          IdentityOrb(hue: p.hue, size: 42),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text('@${p.name}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: T.body.copyWith(
                                    color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15.5)),
                          ),
                          const SizedBox(width: 10),
                          _addState(p, friends, setSheet),
                        ],
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    'Friends can message you and find you again — rooms vanish, people don’t.',
                    style: T.tiny.copyWith(color: C.tx3, fontSize: 12, height: 1.4),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _addState(Person p, Set<String> friendUids, StateSetter setSheet) {
    final uid = p.uid;
    if (uid == null || !widget.live) {
      return Text('—', style: T.tiny.copyWith(color: C.tx3));
    }
    if (friendUids.contains(uid)) {
      return Text('friends ✓',
          style: T.tiny.copyWith(color: C.sig, fontWeight: FontWeight.w800, fontSize: 12.5));
    }
    if (_friendReqSent.contains(uid)) {
      return Text('requested ✓',
          style: T.tiny.copyWith(color: C.tx2, fontWeight: FontWeight.w800, fontSize: 12.5));
    }
    return Press(
      haptic: false,
      onTap: () {
        Buzz.commit();
        NetworkClient.instance.friendRequest(uid);
        _friendReqSent.add(uid);
        setSheet(() {});
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: C.sig,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text('Add friend',
            style: T.tiny.copyWith(
                color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5)),
      ),
    );
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
                // the server keys moderation by the STABLE uid, never conn-id
                final target = p.uid ?? p.id;
                if (widget.live && target != null) NetworkClient.instance.report(target);
                _toast('reported — our team is on it');
              }),
              const Divider(height: 1, color: C.hair),
              _sheetRow(Icons.block_rounded, 'Block @$name', C.live, () {
                Navigator.pop(ctx);
                final target = p.uid ?? p.id;
                if (target != null) {
                  AppSession.instance.noteBlocked(target, p.name);
                  if (widget.live) NetworkClient.instance.block(target);
                }
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
      return AnimatedBuilder(
        animation: Listenable.merge([RtcService.instance.rev, P2PService.instance.rev]),
        builder: (context, _) => _scaffold(context),
      );
    }
    return _scaffold(context);
  }

  Widget _scaffold(BuildContext context) {
    const gold = Color(0xFFFFD54A);
    return Scaffold(
      backgroundColor: C.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1 · the faces — full bleed
          _stage(),
          // 2 · legibility gradients
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
          // 3 · golden room aura
          if (_golden)
            IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: gold.withOpacity(0.85), width: 3),
                  boxShadow: [BoxShadow(color: gold.withOpacity(0.25), blurRadius: 40, spreadRadius: -6)],
                ),
              ),
            ),
          // 4 · floating chrome
          SafeArea(
            child: Stack(
              children: [
                _topBar(),
                if (_phase != _Phase.awards) _rail(),
                if (_phase != _Phase.awards) _caption(),
                if (_combo >= 3)
                  Positioned(
                    right: 12,
                    bottom: 158,
                    child: IgnorePointer(child: _ComboPill(count: _combo)),
                  ),
              ],
            ),
          ),
          // 4.4 · the flip — 3…2…1, everything reveals at once
          if (_revealCount != null)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: const Color(0x59000000),
                  alignment: Alignment.center,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: ScaleTransition(
                          scale: Tween(begin: 1.6, end: 1.0).animate(anim), child: child),
                    ),
                    child: Text(
                      '$_revealCount',
                      key: ValueKey(_revealCount),
                      style: T.huge(120).copyWith(
                        color: Colors.white,
                        shadows: const [Shadow(color: Color(0xCC000000), blurRadius: 24)],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          // 4.5 · the bottle — spins over the faces, picks its victim
          if (_phase == _Phase.game && game.kind == GameKind.spin && !_bottleDone)
            _BottleOverlay(
              key: ValueKey('bottle$_round'),
              targetName: _targetName,
              onDone: () {
                if (!mounted) return;
                Buzz.impact();
                Sfx.land();
                setState(() => _bottleDone = true);
              },
            ),
          // 5 · Chaos Card — full-screen interruption
          if (_chaos != null) _ChaosOverlay(emoji: _chaos![0], text: _chaos![1]),
          // 6 · the ceremony
          if (_phase == _Phase.awards) _awardsOverlay(),
          // 7 · the wheel — revive or next, the wheel decides
          if (_phase == _Phase.wheel)
            _ReviveWheel(
              revive: _wheelRevive,
              onDone: (revive) {
                if (!mounted) return;
                if (revive) {
                  _revive();
                } else {
                  widget.onNext();
                }
              },
            ),
          // 8 · arrival stamp — the room's name slams over the faces
          if (_stamp) _RoomStamp(name: cell.roomName, golden: _golden),
        ],
      ),
    );
  }

  // ---- the face wall (FaceTime-exact) ---------------------------------------
  Widget _stage() {
    final n = cell.people.length;

    // solo (waiting) — no fake tiles, ever. You, full bleed, and the truth.
    if (n == 0) {
      return Stack(
        fit: StackFit.expand,
        children: [
          _selfFace(),
          Positioned(
            left: 0,
            right: 0,
            top: MediaQuery.of(context).padding.top + 64,
            child: IgnorePointer(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  decoration: BoxDecoration(
                    color: const Color(0x8C000000),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: C.hair2),
                  ),
                  child: Text('you’re live — waiting for someone real to drop in…',
                      style: T.tiny.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ),
        ],
      );
    }

    // 1:1 — them full screen, you as a draggable PiP (default bottom-right).
    if (n == 1) {
      return LayoutBuilder(builder: (context, box) {
        const pw = 128.0, ph = 184.0;
        final pad = MediaQuery.of(context).padding;
        final def = Offset(box.maxWidth - pw - 12, box.maxHeight - ph - 220);
        var pos = _pipPos ?? def;
        pos = Offset(
          pos.dx.clamp(8.0, box.maxWidth - pw - 8.0),
          pos.dy.clamp(pad.top + 56.0, box.maxHeight - ph - 12.0),
        );
        return Stack(
          fit: StackFit.expand,
          children: [
            _face(0, radius: 0),
            Positioned(
              left: pos.dx,
              top: pos.dy,
              child: GestureDetector(
                onPanUpdate: (d) => setState(() => _pipPos = pos + d.delta),
                child: _pip(),
              ),
            ),
          ],
        );
      });
    }

    // groups — perfect 2-column grid, you are one of the tiles.
    final tiles = <Widget>[...List.generate(n, (i) => _face(i)), _selfFace()];
    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i += 2) {
      final end = min(i + 2, tiles.length);
      final kids = <Widget>[];
      for (var j = i; j < end; j++) {
        if (j > i) kids.add(const SizedBox(width: 2));
        kids.add(Expanded(child: tiles[j]));
      }
      rows.add(Expanded(child: Row(children: kids)));
      if (end < tiles.length) rows.add(const SizedBox(height: 2));
    }
    return Column(children: rows);
  }

  Widget _pip() {
    return Container(
      width: 128,
      height: 184,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
        boxShadow: const [BoxShadow(color: Color(0xB3000000), blurRadius: 22, offset: Offset(0, 8))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            widget.live ? _selfVideo() : const SelfView(),
            if (_lucky == cell.people.length)
              const Positioned(left: 6, top: 6, child: _StarChip()),
          ],
        ),
      ),
    );
  }

  Widget _face(int i, {double radius = 0}) {
    final p = cell.people[i];
    final canPoint = _phase == _Phase.game && game.kind == GameKind.point && !_answered;
    final tile = PresenceTile(
      person: p,
      radius: radius,
      popDelay: Duration(milliseconds: 60 * i),
      speaking: _speakingIdx == i && _phase != _Phase.drop,
      picked: _pointPick == i || _winnerIdx == i,
      win: _winnerIdx == i && _phase == _Phase.reveal,
      dimmed: _phase == _Phase.reveal && _winnerIdx != null && _winnerIdx != i && game.kind == GameKind.point,
      saved: AppSession.instance.isSaved(p.sparkKey),
      // P2P carries the (single) remote face when active; LiveKit otherwise.
      // Remote P2P is NEVER mirrored (see the doctrine in video_view.dart).
      videoChild: !widget.live
          ? null
          : P2PService.instance.active
              ? P2PVideoView(renderer: P2PService.instance.remoteRenderer)
              : VideoView(track: RtcService.instance.trackFor(p.id)),
      connecting: widget.live &&
          (P2PService.instance.active || P2PService.instance.attempting
              ? !P2PService.instance.remoteReady
              : RtcService.instance.trackFor(p.id) == null),
      onTap: canPoint ? () => _resolvePoint(i) : null,
      onReport: () => _openReport(p),
      onSave: () => _save(p),
    );
    final votes = _voteCounts[i] ?? 0;
    if (_lucky != i && votes == 0) return tile;
    // full-bleed tiles reach under the status bar — keep chips clear of it
    final chipTop = radius == 0 ? MediaQuery.of(context).padding.top + 56.0 : 10.0;
    return Stack(
      fit: StackFit.expand,
      children: [
        tile,
        if (_lucky == i) Positioned(left: 10, top: chipTop, child: const _StarChip()),
        if (votes > 0) Positioned(right: 10, top: chipTop, child: _VoteChip(count: votes)),
      ],
    );
  }

  /// Local video. P2P first (mirror:true is MANDATORY there — raw
  /// getUserMedia has no auto-mirror layer, see video_view.dart); LiveKit
  /// otherwise. The fade holds back the camera's first frames, which can
  /// carry stale rotation metadata (sideways) on both pipelines.
  Widget _selfVideo() {
    final p2p = P2PService.instance;
    if (p2p.attempting || p2p.active) {
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 950),
        curve: const Interval(0.38, 1.0, curve: Curves.easeOut),
        builder: (context, v, child) => Opacity(opacity: v, child: child),
        child: P2PVideoView(renderer: p2p.localRenderer, mirror: true),
      );
    }
    final t = RtcService.instance.localTrack;
    if (t == null) return const ColoredBox(color: C.char2);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 950),
      curve: const Interval(0.38, 1.0, curve: Curves.easeOut),
      builder: (context, v, child) => Opacity(opacity: v, child: child),
      child: VideoView(track: t),
    );
  }

  Widget _selfFace() {
    return DecoratedBox(
      decoration: const BoxDecoration(color: C.char2),
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.live ? _selfVideo() : const SelfView(),
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
          if (_lucky == cell.people.length)
            const Positioned(left: 10, top: 10, child: _StarChip()),
          if ((_voteCounts[cell.people.length] ?? 0) > 0)
            Positioned(
                right: 10, top: 10, child: _VoteChip(count: _voteCounts[cell.people.length]!)),
        ],
      ),
    );
  }

  // ---- top bar --------------------------------------------------------------
  Widget _topBar() {
    const gold = Color(0xFFFFD54A);
    return Positioned(
      top: 6,
      left: 12,
      right: 12,
      child: Row(
        children: [
          Press(
            onTap: widget.onLeave,
            child: Container(
              width: 40, height: 40,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x4D000000)),
              child: const Icon(Icons.close_rounded, size: 20, color: Colors.white),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0x59000000),
              borderRadius: BorderRadius.circular(100),
              border: _golden ? Border.all(color: gold.withOpacity(0.9)) : null,
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (_golden) ...[
                const Text('🏆', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 6),
              ] else ...[
                Container(
                  width: 7, height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle, color: C.live,
                    boxShadow: [BoxShadow(color: C.live.withOpacity(0.7), blurRadius: 8)],
                  ),
                ),
                const SizedBox(width: 7),
              ],
              Text(
                _isCall
                    ? '🔒 private call'
                    : _golden
                        ? 'GOLDEN · ${cell.roomName}'
                        : '${cell.roomName} · ${cell.people.length + 1}',
                style: T.tiny.copyWith(
                  color: _golden ? gold : Colors.white,
                  letterSpacing: 0.4,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ]),
          ),
          const Spacer(),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  // ---- right action rail ----------------------------------------------------
  Widget _rail() {
    return Positioned(
      right: 10,
      bottom: 210,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.live) ...[
            _RailAction(
              icon: RtcService.instance.micOn ? Icons.mic_rounded : Icons.mic_off_rounded,
              iconColor: RtcService.instance.micOn ? Colors.white : C.live,
              label: RtcService.instance.micOn ? 'mic' : 'muted',
              onTap: () {
                final on = !RtcService.instance.micOn;
                Track.event('mic_toggled', {'on': on ? 1 : 0});
                Buzz.tick();
                RtcService.instance.setMic(on);
              },
            ),
            const SizedBox(height: 18),
          ],
          if (widget.live && _isCall) ...[
            _RailAction(
              icon: RtcService.instance.camOn
                  ? Icons.videocam_rounded
                  : Icons.videocam_off_rounded,
              iconColor: RtcService.instance.camOn ? Colors.white : C.live,
              label: RtcService.instance.camOn ? 'camera' : 'cam off',
              onTap: () {
                Buzz.tick();
                RtcService.instance.setCam(!RtcService.instance.camOn);
              },
            ),
            const SizedBox(height: 18),
          ],
          if (!_isCall) ...[
            // WhatsApp-style people button — add whoever you're with as a
            // friend right here, without waiting for the rating prompt.
            _RailAction(
              icon: Icons.person_add_alt_1_rounded,
              iconColor: Colors.white,
              label: 'add',
              onTap: _openAddPeople,
            ),
            const SizedBox(height: 18),
          ],
          _RailAction(
            icon: Icons.favorite_rounded,
            iconColor: C.live,
            label: _reactCount > 0 ? '$_reactCount' : 'react',
            onTap: _react,
          ),
          const SizedBox(height: 18),
          _RailAction(
            icon: Icons.ios_share_rounded,
            iconColor: Colors.white,
            label: 'share',
            onTap: () {
              Buzz.commit();
              _toast('✨ moment saved — share it from your profile');
            },
          ),
        ],
      ),
    );
  }

  // ---- bottom caption -------------------------------------------------------
  Widget _caption() {
    if (_phase == _Phase.drop) return const SizedBox.shrink();
    if (_phase == _Phase.talk) {
      if (_roulette) {
        // roulette rooms don't take requests — build the suspense instead
        return Positioned(
          left: 16,
          right: 16,
          bottom: 18,
          child: Row(
            children: [
              const Text('🎰', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Text('next game rolling in…',
                  style: T.sub.copyWith(color: Colors.white70, fontWeight: FontWeight.w700)),
            ],
          ),
        );
      }
      return Positioned(
        left: 16,
        right: 16,
        bottom: 14,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('just talk — or play something',
                style: T.sub.copyWith(color: Colors.white70, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(right: 52),
              child: Row(
                children: [
                  Expanded(
                    child: Press(
                      haptic: false,
                      onTap: () => _requestGame(),
                      child: Container(
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text('🎲  Random game',
                            style: T.body.copyWith(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 15)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Press(
                      haptic: false,
                      onTap: _openPicker,
                      child: Container(
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0x59000000),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0x40FFFFFF)),
                        ),
                        child: Text('Pick a game',
                            style: T.body.copyWith(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: C.sig.withOpacity(0.22),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: C.sig.withOpacity(0.5)),
                  ),
                  child: Text(_beats > 1 ? 'BEAT $_beat/$_beats' : 'GAME ${_gamesPlayed + 1}',
                      style: T.eyebrow.copyWith(color: Colors.white, letterSpacing: 1.2, fontSize: 9.5)),
                ),
                const SizedBox(width: 10),
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
            AnimatedSwitcher(
              duration: M.quick,
              child: Text(
                // spin games keep the prompt hidden until the bottle lands
                game.kind == GameKind.spin && !_bottleDone ? 'Spin the Bottle 🍾' : _fill(_prompt.first),
                key: ValueKey('$_round·$_bottleDone'),
                style: T.big.copyWith(fontSize: 24, height: 1.12, shadows: const [
                  Shadow(color: Color(0xCC000000), blurRadius: 12),
                ]),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.only(right: 52),
              child: _answered && _serverDriven
                  ? Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.lock_rounded, size: 15, color: C.sig),
                      const SizedBox(width: 8),
                      Text('locked in — waiting for the room…',
                          style: T.sub.copyWith(color: Colors.white70, fontWeight: FontWeight.w600)),
                    ])
                  : Column(
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
        // 1:1 rooms have exactly one face on screen — "tap a face" is
        // meaningless, so the vote becomes two buttons: them or you.
        if (cell.people.length == 1) {
          return [
            _pointBtn('@${cell.people.first.name}', _pointPick == 0, () => _resolvePoint(0)),
            const SizedBox(height: 8),
            _pointBtn('me 🙋', _pointSelfPick, _resolvePointSelf),
          ];
        }
        return [
          Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.touch_app_rounded, size: 16, color: C.sig),
            const SizedBox(width: 8),
            Text('tap a face to vote', style: T.sub.copyWith(color: Colors.white)),
          ]),
        ];
      case GameKind.poll:
      case GameKind.wouldRather:
        return [
          _optBtn(_prompt[1], 0),
          const SizedBox(height: 8),
          _optBtn(_prompt[2], 1),
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
          for (var i = 1; i < _prompt.length; i++) ...[
            _optBtn(_prompt[i], i - 1),
            if (i < _prompt.length - 1) const SizedBox(height: 8),
          ],
        ];
      case GameKind.freeze:
        return [Text('hold it… 😐', style: T.sub.copyWith(color: Colors.white))];
      case GameKind.rapidFire:
        return [_optBtn('Done', 0)];
      case GameKind.spin:
        return [
          Row(mainAxisSize: MainAxisSize.min, children: [
            const Text('🍾', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Text(
              _bottleDone ? '$_targetName is on the spot' : 'the bottle is deciding…',
              style: T.sub.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ]),
        ];
    }
  }

  /// Vote button for duo point rounds — same glass style as _optBtn but with
  /// an explicit tap handler instead of the shared game-kind switch.
  Widget _pointBtn(String label, bool sel, VoidCallback onVote) {
    return Press(
      onTap: _answered ? null : onVote,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: sel ? C.sig.withOpacity(0.9) : const Color(0x59000000),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: sel ? C.sig : const Color(0x40FFFFFF)),
        ),
        child: Text(label,
            style: T.body.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    );
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

  // ---- reveal: the beat + the room's instant vote ---------------------------
  Widget _revealBody() {
    const voteEmoji = ['😂', '😈', '🧠', '👀', '🔥'];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_result,
            style: T.big.copyWith(fontSize: 23, height: 1.16, shadows: const [
              Shadow(color: Color(0xCC000000), blurRadius: 12),
            ])),
        const SizedBox(height: 6),
        Text('rate the room —', style: T.tiny.copyWith(color: Colors.white70)),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final e in voteEmoji)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Press(
                  onTap: () {
                    Buzz.commit();
                    setState(() => _voteEmoji = e);
                    _float(e);
                    if (widget.live) {
                      NetworkClient.instance.react(e);
                      NetworkClient.instance.vote(e); // a real award vote
                    }
                  },
                  child: AnimatedContainer(
                    duration: M.quick,
                    width: 46, height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _voteEmoji == e ? C.sig.withOpacity(0.85) : const Color(0x59000000),
                      border: Border.all(color: _voteEmoji == e ? C.sig : const Color(0x33FFFFFF)),
                    ),
                    child: Text(e, style: const TextStyle(fontSize: 20)),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  // ---- the ceremony ---------------------------------------------------------
  Widget _awardsOverlay() {
    const gold = Color(0xFFFFD54A);
    final mvp = _awards.isEmpty ? 'you' : _awards.first.winner;
    final mvpIsYou = mvp == 'you';
    Person? mvpPerson;
    if (!mvpIsYou) {
      for (final p in cell.people) {
        if ('@${p.name}' == mvp) mvpPerson = p;
      }
    }

    return Positioned.fill(
      child: Stack(
        children: [
          Container(color: const Color(0xF0000000)),
          const Positioned.fill(child: IgnorePointer(child: _Confetti())),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _golden ? '🏆 GOLDEN ROOM 🏆' : 'THE ROOM HAS DECIDED',
                      style: T.eyebrow.copyWith(
                        color: _golden ? gold : C.sig,
                        letterSpacing: 3,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 26),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.5, end: 1),
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOutBack,
                      builder: (context, v, child) => Transform.scale(scale: v, child: child),
                      child: Column(
                        children: [
                          const Text('🏆', style: TextStyle(fontSize: 56)),
                          const SizedBox(height: 10),
                          Text(mvp, style: T.huge(38)),
                          const SizedBox(height: 6),
                          Text('MVP', style: T.eyebrow.copyWith(color: gold, letterSpacing: 4, fontSize: 13)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    for (var i = 1; i < _awards.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: Duration(milliseconds: 400 + i * 180),
                          curve: Curves.easeOut,
                          builder: (context, v, child) => Opacity(
                            opacity: v,
                            child: Transform.translate(offset: Offset(0, 14 * (1 - v)), child: child),
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                            decoration: BoxDecoration(
                              color: C.glass,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: _awards[i].winner == 'you' ? C.sig.withOpacity(0.7) : C.hair),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(_awards[i].emoji, style: const TextStyle(fontSize: 20)),
                                const SizedBox(width: 12),
                                Text(_awards[i].label,
                                    style: T.body.copyWith(color: C.tx2, fontWeight: FontWeight.w600)),
                                const SizedBox(width: 12),
                                Text(_awards[i].winner,
                                    style: T.body.copyWith(
                                        color: _awards[i].winner == 'you' ? C.sig : Colors.white,
                                        fontWeight: FontWeight.w800)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 34),
                    Press(
                      haptic: false,
                      onTap: () {
                        Buzz.impact();
                        Sfx.pop();
                        if (_serverDriven) {
                          // the server's wheel decides — ask, with a fast local
                          // fallback so the button never feels dead
                          if (_wheelArming) return;
                          setState(() => _wheelArming = true);
                          NetworkClient.instance.spinWheel();
                          _wheelTimeout?.cancel();
                          _wheelTimeout = Timer(const Duration(milliseconds: 900), () {
                            if (mounted && _wheelArming) {
                              _wheelRevive = _r.nextDouble() < 0.35;
                              _enterWheel();
                            }
                          });
                        } else {
                          _wheelRevive = _r.nextDouble() < 0.35;
                          _enterWheel();
                        }
                      },
                      child: Container(
                        height: 60,
                        width: double.infinity,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [BoxShadow(color: C.sigGlow, blurRadius: 34, spreadRadius: -8)],
                        ),
                        child: Text('SPIN THE WHEEL  ›', style: T.h3.copyWith(color: Colors.black, fontSize: 18)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (mvpPerson != null && !AppSession.instance.isSaved(mvpPerson.sparkKey)) ...[
                          Press(
                            onTap: () => _save(mvpPerson!),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                              decoration: BoxDecoration(
                                color: C.glass,
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(color: C.sig.withOpacity(0.6)),
                              ),
                              child: Text('✨ spark $mvp',
                                  style: T.tiny.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Press(
                          onTap: () {
                            Buzz.tick();
                            _toTalk();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(color: C.hair2),
                            ),
                            child: Text('keep hanging',
                                style: T.tiny.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Press(
                          onTap: widget.onLeave,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text('leave', style: T.tiny.copyWith(color: C.tx3)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
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

// ---- chrome pieces ----------------------------------------------------------

/// The ⭐ seat — one random person each room is the Main Character.
class _StarChip extends StatelessWidget {
  const _StarChip();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xCC1A1205),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: const Color(0xFFFFD54A)),
      ),
      child: const Text('⭐ main character',
          style: TextStyle(fontSize: 10.5, color: Color(0xFFFFD54A), fontWeight: FontWeight.w800)),
    );
  }
}

/// Real vote count on a face after the flip — "👉 3".
class _VoteChip extends StatelessWidget {
  const _VoteChip({required this.count});
  final int count;
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1.4, end: 1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      builder: (context, v, child) => Transform.scale(scale: v, child: child),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text('👉 $count',
            style: const TextStyle(fontSize: 12, color: Colors.black, fontWeight: FontWeight.w900)),
      ),
    );
  }
}

/// Reaction chain — "🔥 x5 COMBO". People chase these.
class _ComboPill extends StatelessWidget {
  const _ComboPill({required this.count});
  final int count;
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(count),
      tween: Tween(begin: 1.25, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutBack,
      builder: (context, v, child) => Transform.scale(scale: v, child: child),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [C.live.withOpacity(0.9), C.sig.withOpacity(0.9)]),
          borderRadius: BorderRadius.circular(100),
          boxShadow: [BoxShadow(color: C.sigGlow, blurRadius: 18, spreadRadius: -4)],
        ),
        child: Text('🔥 x$count COMBO',
            style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w900)),
      ),
    );
  }
}

/// A Chaos Card strikes — full-screen, impossible to miss, gone in 3 seconds.
class _ChaosOverlay extends StatelessWidget {
  const _ChaosOverlay({required this.emoji, required this.text});
  final String emoji;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          color: const Color(0xB3000000),
          alignment: Alignment.center,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.7, end: 1),
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutBack,
            builder: (context, v, child) =>
                Opacity(opacity: v.clamp(0, 1), child: Transform.scale(scale: v, child: child)),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 34),
              padding: const EdgeInsets.fromLTRB(26, 30, 26, 30),
              decoration: BoxDecoration(
                color: const Color(0xF2140A1E),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: C.sig, width: 1.5),
                boxShadow: [BoxShadow(color: C.sigGlow, blurRadius: 60, spreadRadius: -10)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('⚠️ CHAOS CARD',
                      style: T.eyebrow.copyWith(color: C.live, letterSpacing: 3, fontSize: 12)),
                  const SizedBox(height: 18),
                  Text(emoji, style: const TextStyle(fontSize: 58)),
                  const SizedBox(height: 16),
                  Text(text, textAlign: TextAlign.center, style: T.big.copyWith(fontSize: 24, height: 1.15)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One of THE TEN in the picker — a living emoji tile, the name, the recipe,
/// and a beat count. Slides in with a tiny stagger.
class _GameRow extends StatefulWidget {
  const _GameRow({required this.seq, required this.onTap, this.delay = Duration.zero});
  final SeqDef seq;
  final VoidCallback onTap;
  final Duration delay;

  @override
  State<_GameRow> createState() => _GameRowState();
}

class _GameRowState extends State<_GameRow> with SingleTickerProviderStateMixin {
  late final AnimationController _in =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
  late final AnimationController _bob =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))
        ..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(widget.delay, () {
      if (mounted) _in.forward();
    });
  }

  @override
  void dispose() {
    _in.dispose();
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.seq;
    return AnimatedBuilder(
      animation: _in,
      builder: (context, child) {
        final v = Curves.easeOutCubic.transform(_in.value);
        return Opacity(
          opacity: v,
          child: Transform.translate(offset: Offset(0, 16 * (1 - v)), child: child),
        );
      },
      child: Press(
        haptic: false,
        scale: 0.97,
        onTap: widget.onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: C.hair),
          ),
          child: Row(
            children: [
              // the living icon
              AnimatedBuilder(
                animation: _bob,
                builder: (context, _) {
                  final t = Curves.easeInOut.transform(_bob.value);
                  return Transform.translate(
                    offset: Offset(0, -2 + 4 * t),
                    child: Transform.rotate(
                      angle: -0.06 + 0.12 * t,
                      child: Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF1B1D23), Color(0xFF0A0B0E)],
                          ),
                          border: Border.all(color: C.hair2),
                        ),
                        child: Text(g.icon, style: const TextStyle(fontSize: 24)),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(g.name,
                            style: T.body.copyWith(
                                color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                        if (g.vibe == 'spark') ...[
                          const SizedBox(width: 8),
                          Text('SPARK',
                              style: T.eyebrow.copyWith(color: C.sig, fontSize: 8.5, letterSpacing: 1.6)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(g.hint, style: T.tiny),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text('${g.beats.length} rounds',
                  style: T.tiny.copyWith(color: C.tx3, fontSize: 10.5)),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded, size: 18, color: C.tx3),
            ],
          ),
        ),
      ),
    );
  }
}

/// One item in the right-side action rail.
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
            child: Transform.scale(
                scale: 0.7 + 0.5 * (t * 3).clamp(0, 1),
                child: Text(widget.emoji, style: const TextStyle(fontSize: 34))),
          ),
        );
      },
    );
  }
}

/// The bottle. Spins over the faces with ticking suspense, decelerates, lands —
/// and someone is on the spot. Straight from the spin-the-bottle playbook:
/// the two seconds where nobody knows WHO is the whole game.
class _BottleOverlay extends StatefulWidget {
  const _BottleOverlay({super.key, required this.targetName, required this.onDone});
  final String targetName;
  final VoidCallback onDone;

  @override
  State<_BottleOverlay> createState() => _BottleOverlayState();
}

class _BottleOverlayState extends State<_BottleOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2300));
  late final double _finalR;
  int _lastTick = -1;

  @override
  void initState() {
    super.initState();
    final r = Random();
    _finalR = (4 + r.nextInt(3)) * 2 * pi + r.nextDouble() * 2 * pi;
    _c.addListener(_tick);
    _c.forward().whenComplete(() {
      if (mounted) {
        Timer(const Duration(milliseconds: 500), widget.onDone);
      }
    });
  }

  void _tick() {
    final rot = Curves.easeOutQuart.transform(_c.value) * _finalR;
    final t = (rot / (pi / 3)).floor();
    if (t != _lastTick) {
      _lastTick = t;
      if (_c.value > 0.08 && _c.value < 0.96) {
        Buzz.tick();
        Sfx.tick();
      }
    }
    setState(() {});
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rot = Curves.easeOutQuart.transform(_c.value) * _finalR;
    final done = _c.isCompleted;
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          color: const Color(0x8C000000),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('THE BOTTLE DECIDES', style: T.eyebrow.copyWith(color: C.sig, letterSpacing: 3, fontSize: 11)),
              const SizedBox(height: 24),
              Container(
                width: 150,
                height: 150,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0x40140A1E),
                  border: Border.all(color: C.sig.withOpacity(0.4)),
                  boxShadow: [BoxShadow(color: C.sigGlow, blurRadius: 44, spreadRadius: -10)],
                ),
                child: Transform.rotate(
                  angle: rot,
                  child: const Text('🍾', style: TextStyle(fontSize: 64)),
                ),
              ),
              const SizedBox(height: 24),
              AnimatedSwitcher(
                duration: M.quick,
                child: done
                    ? Container(
                        key: const ValueKey('picked'),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(
                          color: C.sig,
                          borderRadius: BorderRadius.circular(100),
                          boxShadow: [BoxShadow(color: C.sigGlow, blurRadius: 26, spreadRadius: -4)],
                        ),
                        child: Text('${widget.targetName} 👀',
                            style: T.h3.copyWith(color: Colors.white, fontSize: 17)),
                      )
                    : Text('who’s it landing on…',
                        key: const ValueKey('spinning'), style: T.sub.copyWith(color: Colors.white70)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The arrival stamp — the room's name slams across the faces for a beat.
/// This is the "where the hell am I" moment that makes rooms memorable.
class _RoomStamp extends StatelessWidget {
  const _RoomStamp({required this.name, required this.golden});
  final String name;
  final bool golden;

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFFFD54A);
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          color: const Color(0x66000000),
          alignment: Alignment.center,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutBack,
            builder: (context, v, child) => Opacity(
              opacity: v.clamp(0, 1),
              child: Transform.scale(scale: 1.6 - 0.6 * v, child: child),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  golden ? '🏆 GOLDEN ROOM' : 'YOU\'VE ENTERED',
                  style: T.eyebrow.copyWith(
                      color: golden ? gold : C.tx2, letterSpacing: 3.5, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Text(
                    name,
                    textAlign: TextAlign.center,
                    style: T.huge(40).copyWith(
                      shadows: [
                        Shadow(color: golden ? gold.withOpacity(0.5) : C.sigGlow, blurRadius: 40),
                        const Shadow(color: Color(0xCC000000), blurRadius: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The wheel. You don't choose what happens next — it does. Lands on
/// 🔁 REVIVE (same room, fresh games) or ➡️ NEXT (new strangers).
class _ReviveWheel extends StatefulWidget {
  const _ReviveWheel({required this.revive, required this.onDone});
  final bool revive;
  final ValueChanged<bool> onDone;

  @override
  State<_ReviveWheel> createState() => _ReviveWheelState();
}

class _ReviveWheelState extends State<_ReviveWheel> with SingleTickerProviderStateMixin {
  static const _slices = 8;
  static const _a = 2 * pi / _slices;

  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 3300));
  late final double _finalR;
  int _lastTop = -1;
  bool _landed = false;

  @override
  void initState() {
    super.initState();
    final r = Random();
    // odd slices are REVIVE, even are NEXT — pick a target of the chosen kind
    final candidates = [for (var i = 0; i < _slices; i++) if ((i.isOdd) == widget.revive) i];
    final target = candidates[r.nextInt(candidates.length)];
    final jitter = (r.nextDouble() - 0.5) * _a * 0.5;
    _finalR = 5 * 2 * pi + (2 * pi - target * _a) + jitter;
    _c.addListener(_tick);
    _c.forward().whenComplete(() {
      if (!mounted) return;
      Buzz.impact();
      Sfx.land();
      setState(() => _landed = true);
      Timer(const Duration(milliseconds: 1100), () {
        if (mounted) widget.onDone(widget.revive);
      });
    });
  }

  void _tick() {
    final rot = Curves.easeOutQuart.transform(_c.value) * _finalR;
    final top = ((2 * pi - (rot % (2 * pi))) / _a).round() % _slices;
    if (top != _lastTop) {
      _lastTop = top;
      if (_c.value > 0.1 && _c.value < 0.97) {
        Buzz.tick();
        Sfx.tick();
      }
    }
    setState(() {});
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rot = Curves.easeOutQuart.transform(_c.value) * _finalR;
    return Positioned.fill(
      child: Container(
        color: const Color(0xF2000000),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('THE WHEEL DECIDES', style: T.eyebrow.copyWith(color: C.sig, letterSpacing: 3, fontSize: 12)),
              const SizedBox(height: 30),
              SizedBox(
                width: 300,
                height: 300,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    Transform.rotate(
                      angle: rot,
                      child: CustomPaint(size: const Size(300, 300), painter: _WheelPainter()),
                    ),
                    // hub
                    Container(
                      width: 62,
                      height: 62,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF0A0B0D),
                        border: Border.all(color: Colors.white.withOpacity(0.25), width: 1.5),
                        boxShadow: [BoxShadow(color: C.sigGlow, blurRadius: 24, spreadRadius: -6)],
                      ),
                      child: const Text('🎰', style: TextStyle(fontSize: 26)),
                    ),
                    // pointer
                    Positioned(
                      top: -6,
                      child: Container(
                        width: 0,
                        height: 0,
                        decoration: const BoxDecoration(
                          border: Border(
                            left: BorderSide(color: Colors.transparent, width: 13),
                            right: BorderSide(color: Colors.transparent, width: 13),
                            top: BorderSide(color: Colors.white, width: 22),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 34),
              AnimatedSwitcher(
                duration: M.quick,
                child: _landed
                    ? Column(
                        key: const ValueKey('landed'),
                        children: [
                          Text(
                            widget.revive ? '🔁 REVIVED' : '➡️ NEXT ROOM',
                            style: T.huge(34).copyWith(color: widget.revive ? C.sig : Colors.white),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.revive ? 'same room — run it back' : 'fresh strangers incoming',
                            style: T.body.copyWith(color: C.tx2),
                          ),
                        ],
                      )
                    : Text('revive the room… or roll new strangers?',
                        key: const ValueKey('spinning'), style: T.body.copyWith(color: C.tx2)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  static const _slices = 8;
  static const _a = 2 * pi / _slices;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final rect = Rect.fromCircle(center: c, radius: radius);
    final fill = Paint()..style = PaintingStyle.fill;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFF000000);

    for (var i = 0; i < _slices; i++) {
      // slice i centered at top when rotation is zero
      final start = -pi / 2 - _a / 2 + i * _a;
      final revive = i.isOdd;
      fill.color = revive ? const Color(0xFF6D28D9) : const Color(0xFF17181C);
      canvas.drawArc(rect, start, _a, true, fill);
      canvas.drawArc(rect, start, _a, true, line);

      // label along the slice
      final tp = TextPainter(
        text: TextSpan(
          text: revive ? 'REVIVE' : 'NEXT',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
            color: revive ? Colors.white : const Color(0x99FFFFFF),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(start + _a / 2 + pi / 2);
      tp.paint(canvas, Offset(-tp.width / 2, -radius + 16));
      canvas.restore();
    }

    // outer ring
    canvas.drawCircle(
      c,
      radius - 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = const Color(0x40FFFFFF),
    );
  }

  @override
  bool shouldRepaint(_WheelPainter old) => false;
}

/// Purple / white / gold confetti raining through the ceremony.
class _Confetti extends StatefulWidget {
  const _Confetti();
  @override
  State<_Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<_Confetti> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  late final List<_Flake> _flakes;

  @override
  void initState() {
    super.initState();
    final r = Random();
    _flakes = List.generate(56, (_) => _Flake.random(r));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => CustomPaint(painter: _ConfettiPainter(_c.value, _flakes)),
    );
  }
}

class _Flake {
  _Flake(this.x, this.off, this.speed, this.size, this.spin, this.color);
  final double x, off, speed, size, spin;
  final Color color;
  static _Flake random(Random r) => _Flake(
        r.nextDouble(),
        r.nextDouble(),
        0.55 + r.nextDouble() * 0.8,
        3.5 + r.nextDouble() * 4.5,
        r.nextDouble() * 6.28,
        const <Color>[C.sig, Colors.white, Color(0xFFFFD54A), C.live][r.nextInt(4)],
      );
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.t, this.flakes);
  final double t;
  final List<_Flake> flakes;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint();
    for (final f in flakes) {
      final y = ((t * f.speed + f.off) % 1.15) - 0.075;
      final x = f.x + 0.03 * sin((t * 6.28 * 2) + f.spin);
      p.color = f.color.withOpacity(0.9);
      canvas.save();
      canvas.translate(x * size.width, y * size.height);
      canvas.rotate(f.spin + t * 6.28);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: f.size, height: f.size * 0.6), const Radius.circular(1.5)),
        p,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
