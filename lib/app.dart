import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';
import 'theme/motion.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/avatar_screen.dart';
import 'screens/home_screen.dart';

/// The onboarding-to-home journey, as one continuous space. Each step cross-
/// fades into the next over the same living aurora, so the app never feels like
/// a stack of separate screens.
enum _Step { splash, onboarding, auth, avatar, home }

class WhatIfApp extends StatelessWidget {
  const WhatIfApp({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(WhatIfTheme.systemOverlay);
    return MaterialApp(
      title: 'WhatIf',
      debugShowCheckedModeBanner: false,
      theme: WhatIfTheme.dark,
      home: const _RootFlow(),
    );
  }
}

class _RootFlow extends StatefulWidget {
  const _RootFlow();

  @override
  State<_RootFlow> createState() => _RootFlowState();
}

class _RootFlowState extends State<_RootFlow> {
  _Step _step = _Step.splash;

  void _go(_Step s) => setState(() => _step = s);

  @override
  Widget build(BuildContext context) {
    final Widget screen = switch (_step) {
      _Step.splash => SplashScreen(onDone: () => _go(_Step.onboarding)),
      _Step.onboarding => OnboardingScreen(onFinish: () => _go(_Step.auth)),
      _Step.auth => AuthScreen(onAuthed: () => _go(_Step.avatar)),
      _Step.avatar => AvatarScreen(onDone: () => _go(_Step.home)),
      _Step.home => const HomeScreen(),
    };

    return AnimatedSwitcher(
      duration: Motion.slow,
      switchInCurve: Motion.entrance,
      switchOutCurve: Motion.exit,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      child: KeyedSubtree(key: ValueKey(_step), child: screen),
    );
  }
}
