import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'config.dart';
import 'models/game.dart';
import 'models/person.dart';
import 'net/network_client.dart';
import 'net/rtc_service.dart';
import 'state/session.dart';
import 'theme/tokens.dart';
import 'screens/welcome_screen.dart';
import 'screens/signin_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/main_shell.dart';
import 'screens/party_screen.dart';
import 'screens/rules_screen.dart';
import 'screens/finding_screen.dart';
import 'screens/live_screen.dart';

class RivlrApp extends StatelessWidget {
  const RivlrApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rivlr',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: C.black,
        colorScheme: const ColorScheme.dark(primary: C.sig, surface: C.char2),
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
      ),
      home: const _Root(),
    );
  }
}

enum _Step { boot, welcome, signin, profile, rules, permission, home, party, finding, live }

class _Root extends StatefulWidget {
  const _Root();
  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  final _rng = Random();
  _Step _step = _Step.boot;
  Cell? _cell;
  int _drop = 0;
  StreamSubscription<Map<String, dynamic>>? _netSub;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    // load saved identity BEFORE the network hello, so the backend sees a
    // stable uid and we can skip onboarding for returning users.
    await AppSession.instance.load();
    if (AppConfig.isLive) {
      NetworkClient.instance.connect();
      _netSub = NetworkClient.instance.events.listen(_onNet);
    }
    if (!mounted) return;
    _to(AppSession.instance.onboarded ? _Step.home : _Step.welcome);
  }

  @override
  void dispose() {
    _netSub?.cancel();
    super.dispose();
  }

  void _to(_Step s) => setState(() => _step = s);

  // ---- live mode (server-driven) -------------------------------------------
  void _onNet(Map<String, dynamic> m) {
    switch (m['t']) {
      case 'presence':
        final n = (m['live'] as num?)?.toInt();
        if (n != null) AppSession.instance.setLiveCount(n);
      case 'cell':
        _onCell(m);
      case 'ended':
        RtcService.instance.leave();
        if (mounted && _step == _Step.live) _to(_Step.finding); // server re-queued us
      case 'sparkMutual':
        if (m['name'] is String) {
          AppSession.instance.markMutual(m['name'] as String, uid: m['uid'] as String?);
        }
      case 'sparkLive':
        if (m['name'] is String) AppSession.instance.setSparkLive(m['name'] as String, true);
    }
  }

  void _onCell(Map<String, dynamic> m) {
    final cell = _cellFromServer(m);
    AppSession.instance.noteCell(cell);
    final url = (m['url'] as String?) ?? '';
    final token = (m['token'] as String?) ?? '';
    RtcService.instance.join(url, token); // fire-and-forget; tiles fill on rev
    setState(() {
      _cell = cell;
      _drop++;
      _step = _Step.live;
    });
  }

  RoundDef _roundFromServer(Map<String, dynamic> g) {
    final kind = gameKindFrom((g['kind'] as String?) ?? 'poll');
    final base = GameDef.byKind(kind);
    // honour the server's game name/hint (it owns the wild variants like
    // "Survival" / "Red Flag"), falling back to the local pack's defaults.
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

  Cell _cellFromServer(Map<String, dynamic> m) {
    var people = ((m['people'] as List?) ?? const [])
        .map((e) => Person.fromServer((e as Map).cast<String, dynamic>(), _rng))
        .toList();

    // prefer the server's full session (everyone plays the same rounds); an
    // older server sends a single game — fill the session out locally.
    var rounds = ((m['rounds'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => _roundFromServer(e.cast<String, dynamic>()))
        .toList();
    if (rounds.isEmpty && m['game'] is Map) {
      rounds = [_roundFromServer((m['game'] as Map).cast<String, dynamic>())];
    }
    if (rounds.isEmpty) {
      rounds = Cell.rollRounds(_rng, people.length);
    } else if (rounds.length < 5) {
      rounds = [
        ...rounds,
        ...Cell.rollRounds(_rng, people.length,
            count: 5 - rounds.length, avoidKind: rounds.last.game.kind),
      ];
    }
    return Cell(
      people: people,
      rounds: rounds,
      golden: m['golden'] as bool?,
      luckyId: m['luckyId'] as String?,
    );
  }

  // ---- simulated mode -------------------------------------------------------
  void _dropSimulated() {
    final s = AppSession.instance;
    final cell = Cell.random(_rng, avoidKind: s.lastKind, recentHeads: s.recentHeads);
    s.noteCell(cell);
    setState(() {
      _cell = cell;
      _drop++;
      _step = _Step.live;
    });
  }

  // ---- verbs ----------------------------------------------------------------
  void _play() {
    if (AppConfig.isLive) NetworkClient.instance.play();
    _to(_Step.finding);
  }

  void _next() {
    if (AppConfig.isLive) {
      NetworkClient.instance.next();
      RtcService.instance.leave();
      _to(_Step.finding);
    } else {
      _to(_Step.finding);
    }
  }

  void _leave() {
    if (AppConfig.isLive) {
      NetworkClient.instance.leaveCell();
      RtcService.instance.leave();
    }
    _to(_Step.home);
  }

  @override
  Widget build(BuildContext context) {
    final live = AppConfig.isLive;
    final Widget screen = switch (_step) {
      _Step.boot => const ColoredBox(color: C.black),
      _Step.welcome => WelcomeScreen(onNext: () => _to(_Step.signin)),
      _Step.signin => SignInScreen(onContinue: () => _to(_Step.profile)),
      _Step.profile => ProfileScreen(onDone: () => _to(_Step.rules)),
      _Step.rules => RulesScreen(onAgree: () => _to(_Step.permission)),
      _Step.permission => OnboardingScreen(onDone: () {
          AppSession.instance.completeOnboarding();
          _to(_Step.home);
        }),
      _Step.home => MainShell(
          onPlay: _play,
          onParty: () => _to(_Step.party),
          onSignOut: () => _to(_Step.welcome)),
      _Step.party => PartyScreen(onBack: () => _to(_Step.home)),
      _Step.finding => FindingScreen(onDone: _dropSimulated, waitForExternal: live),
      _Step.live => LiveScreen(
          key: ValueKey(_drop),
          cell: _cell!,
          onNext: _next,
          onLeave: _leave,
          live: live,
        ),
    };

    return AnimatedSwitcher(
      duration: M.base,
      switchInCurve: M.ease,
      switchOutCurve: M.ease,
      transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
      child: KeyedSubtree(key: ValueKey('${_step.name}$_drop'), child: screen),
    );
  }
}
