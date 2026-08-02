import 'dart:async';
import 'dart:math';
import 'package:app_links/app_links.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter/material.dart';
import 'config.dart';
import 'core/analytics.dart';
import 'core/push.dart';
import 'models/game.dart';
import 'models/person.dart';
import 'net/network_client.dart';
import 'net/p2p_service.dart';
import 'net/rtc_service.dart';
import 'state/chat.dart';
import 'state/session.dart';
import 'state/social.dart';
import 'theme/tokens.dart';
import 'widgets/incoming_call_overlay.dart';
import 'widgets/match_overlay.dart';
import 'widgets/rating_overlay.dart';
import 'screens/chat_screen.dart';
import 'screens/friends_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/signin_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/main_shell.dart';
import 'screens/party_screen.dart';
import 'screens/rules_screen.dart';
import 'screens/mode_screen.dart';
import 'screens/finding_screen.dart';
import 'screens/live_screen.dart';

class RivlrApp extends StatelessWidget {
  const RivlrApp({super.key});

  /// Global navigator — deep links and push taps route through it.
  static final navKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navKey,
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

enum _Step { boot, welcome, signin, profile, rules, permission, home, mode, party, finding, live }

class _Root extends StatefulWidget {
  const _Root();
  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  final _rng = Random();
  _Step _step = _Step.boot;
  String _mode = 'hang'; // how the next room should run
  Cell? _cell;
  int _drop = 0;
  StreamSubscription<Map<String, dynamic>>? _netSub;
  StreamSubscription<Uri>? _linkSub;
  String? _partyCode; // arrived via rivlr://join/CODE
  String? _partyInviteUid; // host a room and DM this friend the code
  bool _pendingCallVideo = true; // camera state for the next call cell

  @override
  void initState() {
    super.initState();
    // deep surfaces (chat threads, invite bubbles) drive the play flow
    // through these hooks instead of owning the step machine
    AppNav.joinPartyCode = (code) {
      if (!mounted) return;
      _partyInviteUid = null;
      _partyCode = code;
      _to(_Step.party);
    };
    AppNav.hostPartyFor = (uid) {
      if (!mounted) return;
      _partyCode = null;
      _partyInviteUid = uid;
      _to(_Step.party);
    };
    AppNav.startCall = (uid, video) {
      if (!mounted) return;
      _pendingCallVideo = video;
      Track.event('call_invite', {'video': video ? 1 : 0});
      NetworkClient.instance.callInvite(uid, video: video);
      final ctx = RivlrApp.navKey.currentContext;
      if (ctx != null) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: C.char2,
          content: Text('📞 ringing…', style: T.body.copyWith(color: Colors.white)),
        ));
      }
    };
    _boot();
  }

  Future<void> _boot() async {
    // load saved identity BEFORE the network hello, so the backend sees a
    // stable uid and we can skip onboarding for returning users.
    await AppSession.instance.load();
    if (AppConfig.isLive) {
      SocialState.instance.attach(); // before connect so they see the welcome
      ChatStore.instance.attach(AppSession.instance.myUid);
      NetworkClient.instance.connect();
      _netSub = NetworkClient.instance.events.listen(_onNet);
    }
    if (!mounted) return;
    _to(AppSession.instance.onboarded ? _Step.home : _Step.welcome);
    // returning users: register for pushes once home settles (first-run users
    // are asked right after onboarding instead — see the permission step)
    if (AppSession.instance.onboarded) {
      Timer(const Duration(seconds: 3), Push.init);
    }
    // deep links AFTER the first screen is decided, so a cold-start link can
    // override it (fail-soft: links just don't work if the plugin balks)
    try {
      final links = AppLinks();
      final initial = await links.getInitialLink();
      if (initial != null) _onLink(initial);
      _linkSub = links.uriLinkStream.listen(_onLink);
    } catch (_) {}
  }

  /// rivlr://join/CODE — jump straight into the friends-room screen with the
  /// code prefilled and auto-joined (once onboarded; brand-new users finish
  /// onboarding first and the code keeps waiting for them).
  void _onLink(Uri u) {
    if (u.scheme != 'rivlr') return;
    final segs = [u.host, ...u.pathSegments].where((s) => s.isNotEmpty).toList();
    if (segs.isNotEmpty && segs.first.toLowerCase() == 'join' && segs.length >= 2) {
      final code = segs[1].toUpperCase();
      if (code.length < 4) return;
      Track.event('deep_link_join');
      _partyCode = code;
      if (AppSession.instance.onboarded && mounted) _to(_Step.party);
    }
    // rivlr://chat/<uid> — from a message push
    if (segs.isNotEmpty && segs.first.toLowerCase() == 'chat' && segs.length >= 2) {
      final uid = segs[1];
      final friend = SocialState.instance.friends
          .where((f) => f.uid == uid)
          .toList();
      if (friend.isEmpty || !AppSession.instance.onboarded) return;
      final ctx = RivlrApp.navKey.currentContext;
      if (ctx != null) {
        ChatScreen.push(ctx, uid: friend.first.uid, name: friend.first.name, hue: friend.first.hue);
      }
    }
  }

  @override
  void dispose() {
    _netSub?.cancel();
    _linkSub?.cancel();
    super.dispose();
  }

  void _to(_Step s) {
    Track.screen(s.name);
    setState(() => _step = s);
    _wakelock(s);
  }

  /// Screen sleep is managed HERE and only here. The per-screen
  /// enable/disable pairs raced across transitions (both are async platform
  /// calls, so finding's dispose-disable could land AFTER live's
  /// init-enable) — leaving a live room free to dim and sleep mid-call.
  void _wakelock(_Step s) {
    final awake = s == _Step.finding || s == _Step.live || s == _Step.party;
    WakelockPlus.toggle(enable: awake);
  }

  // ---- live mode (server-driven) -------------------------------------------
  void _onNet(Map<String, dynamic> m) {
    switch (m['t']) {
      case 'welcome':
        // after a reconnect: if we're not in (or looking for) a room, make
        // sure the server doesn't think we still hold a seat from before the
        // drop — otherwise resume would yank us back into a room we left.
        if (_step != _Step.live && _step != _Step.finding) {
          NetworkClient.instance.leaveCell();
        }
        Push.resend(); // fresh connection never saw our push token
      case 'presence':
        final n = (m['live'] as num?)?.toInt();
        if (n != null) {
          AppSession.instance.setLiveCount(n,
              rooms: (m['rooms'] as num?)?.toInt(),
              matches: (m['matches'] as num?)?.toInt());
        }
      case 'cell':
        _onCell(m);
      case 'ended':
        RtcService.instance.leave();
        if (mounted && _step == _Step.live) {
          // calls end back at home; stranger rooms recompose into a new match
          _to((_cell?.mode ?? '') == 'call' ? _Step.home : _Step.finding);
        }
      case 'call':
        // ringing — but never interrupt a live room: auto-decline as busy
        if (_step == _Step.live) {
          final id = (m['callId'] as String?) ?? '';
          if (id.isNotEmpty) NetworkClient.instance.callDecline(id);
          SocialState.instance.clearIncomingCall();
        }
      case 'badge':
        final label = m['label'] as String?;
        final ctx = RivlrApp.navKey.currentContext;
        if (label != null && ctx != null) {
          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: C.char2,
            content: Text('🏅 Badge earned — $label',
                style: T.body.copyWith(color: Colors.white)),
          ));
        }
      case 'callState':
        final st = m['state'] as String?;
        final ctx2 = RivlrApp.navKey.currentContext;
        if (ctx2 != null && (st == 'declined' || st == 'timeout' || st == 'busy')) {
          ScaffoldMessenger.of(ctx2).showSnackBar(SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: C.char2,
            content: Text(
                st == 'busy' ? 'they’re in a room right now' : 'no answer — try later',
                style: T.body.copyWith(color: Colors.white)),
          ));
        }
      case 'sparkMutual':
        if (m['name'] is String) {
          AppSession.instance.markMutual(m['name'] as String, uid: m['uid'] as String?);
        }
      case 'sparkLive':
        if (m['name'] is String) AppSession.instance.setSparkLive(m['name'] as String, true);
      case 'rtc':
        final from = m['from'] as String?;
        final d = (m['d'] as Map?)?.cast<String, dynamic>();
        if (from != null && d != null) P2PService.instance.onSignal(from, d);
    }
  }

  void _onCell(Map<String, dynamic> m) {
    final isCall = m['mode'] == 'call';
    // rooms are only expected while matching, in a party lobby, already live
    // (resume/re-roll), or when a CALL was just accepted. Anywhere else —
    // e.g. a stale resume racing a leave we sent after reconnecting at
    // home — release the seat and stay.
    if (!isCall && _step != _Step.party && _step != _Step.finding && _step != _Step.live) {
      NetworkClient.instance.leaveCell();
      return;
    }
    final cell = _cellFromServer(m);
    AppSession.instance.noteCell(cell);
    Track.event('matched', {
      'people': cell.people.length,
      'mode': cell.mode ?? 'hang',
    });
    final url = (m['url'] as String?) ?? '';
    final token = (m['token'] as String?) ?? '';
    // P2P: exactly-two stranger rooms go phone-to-phone; LiveKit is the
    // automatic fallback (and still carries groups + calls). Worst case is
    // exactly the pre-P2P app.
    final wantP2p = m['p2p'] == true && cell.people.length == 1 &&
        cell.people.first.id != null && NetworkClient.instance.myId != null;
    if (wantP2p) {
      final peerId = cell.people.first.id!;
      final myId = NetworkClient.instance.myId!;
      P2PService.instance.onFailed = () {
        RtcService.instance.join(url, token); // the room continues on LiveKit
      };
      P2PService.instance.attempt(
        peerId: peerId,
        offerer: myId.compareTo(peerId) < 0, // exactly one side offers
      );
    } else {
      P2PService.instance.leave();
      // voice calls start camera-off; toggling upgrades to video mid-call
      RtcService.instance.join(url, token, camera: !isCall || _pendingCallVideo);
    }
    setState(() {
      _cell = cell;
      _drop++;
      _step = _Step.live;
    });
    _wakelock(_Step.live);
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
      mode: m['mode'] as String?,
    );
  }

  // ---- simulated mode -------------------------------------------------------
  void _dropSimulated() {
    final s = AppSession.instance;
    final cell = Cell.random(_rng, avoidKind: s.lastKind, recentHeads: s.recentHeads, mode: _mode);
    s.noteCell(cell);
    setState(() {
      _cell = cell;
      _drop++;
      _step = _Step.live;
    });
    _wakelock(_Step.live);
  }

  // ---- verbs ----------------------------------------------------------------
  void _play(String mode) {
    _mode = mode;
    Track.event('play_pressed', {'mode': mode});
    if (AppConfig.isLive) NetworkClient.instance.play(mode);
    _to(_Step.finding);
  }

  void _next() {
    Track.event('next_room');
    if (AppConfig.isLive) {
      NetworkClient.instance.next();
      RtcService.instance.leave();
      _to(_Step.finding);
    } else {
      _to(_Step.finding);
    }
  }

  void _leave() {
    Track.event('left_room');
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
          Track.event('onboarding_done');
          _to(_Step.home);
          Timer(const Duration(seconds: 2), Push.init);
        }),
      _Step.home => MainShell(
          onPlay: () => _to(_Step.mode),
          onParty: () => _to(_Step.party),
          onSignOut: () => _to(_Step.welcome)),
      _Step.mode => ModeScreen(onPick: _play, onBack: () => _to(_Step.home)),
      _Step.party => PartyScreen(
          key: ValueKey('party${_partyCode ?? ''}${_partyInviteUid ?? ''}'),
          initialCode: _partyCode,
          inviteUid: _partyInviteUid,
          onBack: () {
            _partyCode = null;
            _partyInviteUid = null;
            _to(_Step.home);
          }),
      _Step.finding => FindingScreen(onDone: _dropSimulated, waitForExternal: live),
      _Step.live => LiveScreen(
          key: ValueKey(_drop),
          cell: _cell!,
          onNext: _next,
          onLeave: _leave,
          live: live,
        ),
    };

    return Stack(
      children: [
        AnimatedSwitcher(
          duration: M.base,
          switchInCurve: M.ease,
          switchOutCurve: M.ease,
          transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
          child: KeyedSubtree(key: ValueKey('${_step.name}$_drop'), child: screen),
        ),
        // ---- social overlays: never a blocking step, always floating -------
        AnimatedBuilder(
          animation: SocialState.instance,
          builder: (context, _) {
            final s = SocialState.instance;
            // a ringing call outranks everything (rooms auto-decline earlier)
            final call = s.incomingCall;
            if (call != null && _step != _Step.live) {
              return IncomingCallOverlay(
                key: ValueKey('call${call.callId}'),
                call: call,
                onAccept: () {
                  _pendingCallVideo = call.video;
                  NetworkClient.instance.callAccept(call.callId);
                  SocialState.instance.clearIncomingCall();
                },
              );
            }
            // the meet-again question — over finding/home only, never mid-room
            if (s.pendingRates.isNotEmpty &&
                (_step == _Step.finding || _step == _Step.home)) {
              return RatingOverlay(
                key: ValueKey('rate${s.pendingRates.first.cellId}${s.pendingRates.first.uid}'),
                item: s.pendingRates.first,
              );
            }
            // 🎉 the match celebration — anywhere except live rooms
            if (s.celebrations.isNotEmpty && _step != _Step.live) {
              return MatchOverlay(
                key: ValueKey('match${s.celebrations.first.uid}'),
                friend: s.celebrations.first,
                onSeePeople: () => FriendsScreen.push(context),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }
}
