import 'dart:math';
import 'package:flutter/material.dart';
import 'models/game.dart';
import 'state/session.dart';
import 'theme/tokens.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';
import 'screens/finding_screen.dart';
import 'screens/live_screen.dart';

class WhatIfApp extends StatelessWidget {
  const WhatIfApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WhatIf',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: C.black,
        colorScheme: const ColorScheme.dark(
          primary: C.sig,
          surface: C.char2,
        ),
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
      ),
      home: const _Root(),
    );
  }
}

enum _Step { onboarding, home, finding, live }

class _Root extends StatefulWidget {
  const _Root();
  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  final _rng = Random();
  _Step _step = _Step.onboarding;
  Cell? _cell;
  int _drop = 0; // reset live-screen state per drop

  void _to(_Step s) => setState(() => _step = s);

  void _dropIntoCell() {
    final s = AppSession.instance;
    final cell = Cell.random(_rng, avoidKind: s.lastKind, recentHeads: s.recentHeads);
    s.noteCell(cell);
    setState(() {
      _cell = cell;
      _drop++;
      _step = _Step.live;
    });
  }

  @override
  Widget build(BuildContext context) {
    final Widget screen = switch (_step) {
      _Step.onboarding => OnboardingScreen(onDone: () => _to(_Step.home)),
      _Step.home => HomeScreen(onPlay: () => _to(_Step.finding)),
      _Step.finding => FindingScreen(onDone: _dropIntoCell),
      _Step.live => LiveScreen(
          key: ValueKey(_drop),
          cell: _cell!,
          onNext: () => _to(_Step.finding),
          onLeave: () => _to(_Step.home),
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
