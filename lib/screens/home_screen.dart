import 'dart:async';
import 'package:flutter/material.dart';
import '../config.dart';
import '../core/analytics.dart';
import '../core/camera_service.dart';
import '../core/haptics.dart';
import '../core/sound.dart';
import '../models/game.dart';
import '../state/session.dart';
import '../state/social.dart';
import '../theme/tokens.dart';
import '../widgets/glass.dart';
import '../widgets/notification_bell.dart';
import '../widgets/portal_ring.dart';
import '../widgets/self_view.dart';
import 'discover_screen.dart';
import 'plus_screen.dart';
import 'settings_screen.dart';

/// HOME — you, live, full bleed. The app is already on before you press
/// anything: your own camera is the stage, the world's headcount is at the
/// top, and one huge TAP TO START floats in the middle — it always means
/// Roulette, the free instant-chaos lane. 1-on-1 (Rivlr+) and Groups are
/// two clear doors below it, not lanes to pick then press a separate button
/// for — tapping either one goes straight there.
///
/// A low number is never shown; a shown number is never invented.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.onSignOut,
    required this.onParty,
    required this.onPlay,
    this.active = true,
  });
  final VoidCallback onSignOut;
  final VoidCallback onParty;

  /// Mode string: 'roulette' | 'hang' | 'groups'.
  final ValueChanged<String> onPlay;

  /// True while Home is the visible tab. The camera runs only then — other
  /// tabs must not burn battery, and live rooms need the lens free.
  final bool active;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.active) CameraService.instance.ensure();
  }

  @override
  void didUpdateWidget(HomeScreen old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) CameraService.instance.ensure();
    if (!widget.active && old.active) CameraService.instance.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused) {
      CameraService.instance.dispose();
    } else if (s == AppLifecycleState.resumed && widget.active) {
      CameraService.instance.ensure();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Leaving Home always releases the lens — finding, party and live rooms
    // (LiveKit / WebRTC) open their own capture session.
    CameraService.instance.dispose();
    super.dispose();
  }

  /// The dial always means Roulette now — 1-on-1 moved to its own door
  /// (Discover) since it's a browse-and-choose flow, not a press-and-wait one.
  void _start() {
    Buzz.pop();
    Sfx.match();
    Track.event('home_start', {'mode': 'roulette'});
    widget.onPlay('roulette');
  }

  void _openOneOnOne() {
    if (!AppSession.instance.plus) {
      Buzz.tick();
      PlusScreen.push(context,
          reason: '1-on-1 rooms are part of Rivlr+ — Roulette and Groups are always free.');
      return;
    }
    Buzz.pop();
    DiscoverScreen.push(context);
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    return Scaffold(
      backgroundColor: C.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // the living stage — you, mirrored, width-fit for the full field of
          // view (elegant placeholder when the camera is off or denied)
          const SelfView(grade: true, fit: BoxFit.fitWidth),
          // the whole stage is the start button
          Positioned.fill(
            child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: _start),
          ),
          // legibility scrim behind the chips + nav bar
          const Positioned(
            bottom: 0, left: 0, right: 0, height: 240,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter, end: Alignment.topCenter,
                    colors: [Color(0xE6000000), Color(0x00000000)],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 6),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: r.gutter),
                  child: Row(
                    children: [
                      const Wordmark(size: 32),
                      const Spacer(),
                      const _LivePill(),
                      const SizedBox(width: 8),
                      const NotificationBell(size: 34, iconSize: 17),
                      const SizedBox(width: 8),
                      _RoundBtn(
                        icon: Icons.settings_rounded,
                        onTap: () { Buzz.tick(); SettingsScreen.push(context, widget.onSignOut); },
                      ),
                    ],
                  ),
                ),
                const _StorageBanner(),
                const _FilterChip(),
                _ChaosPill(onTap: () => widget.onPlay('roulette')),
                const Spacer(),
                // the Portal — Rivlr's living mark; taps fall through to the
                // stage. Always Roulette now: the one thing pressing the
                // stage does, with 1-on-1 and Groups as their own doors below.
                IgnorePointer(
                  child: PortalRing(
                    title: 'Tap to\nroll',
                    line: 'no choices — games hit back to back',
                    size: 246 * r.scale,
                  ),
                ),
                const Spacer(),
                // tonight's games — the billboard for what they don't have
                _GameTicker(onTap: _start),
                const SizedBox(height: 14),
                // the two doors — deliberate destinations, never confused
                // with the dial above. 1-on-1 carries its Rivlr+ tag right
                // on the card, so the value is visible before anyone taps.
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: r.gutter),
                  child: AnimatedBuilder(
                    animation: AppSession.instance,
                    builder: (context, _) => Row(
                      children: [
                        Expanded(
                          child: _DoorCard(
                            emoji: '🎥',
                            label: '1 on 1',
                            sub: AppSession.instance.plus ? 'choose who you meet' : 'Rivlr+',
                            tagged: !AppSession.instance.plus,
                            onTap: _openOneOnOne,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _DoorCard(
                            emoji: '👥',
                            label: 'Groups',
                            sub: 'with your people',
                            onTap: () { Buzz.pop(); widget.onPlay('groups'); },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---- doors -----------------------------------------------------------------

/// A deliberate destination, not a filter — visually distinct from the dial
/// above it on purpose. Two equal cards, icon over label over one line of
/// truth about what's behind it.
class _DoorCard extends StatelessWidget {
  const _DoorCard({
    required this.emoji,
    required this.label,
    required this.sub,
    required this.onTap,
    this.tagged = false,
  });
  final String emoji;
  final String label;
  final String sub;
  final bool tagged;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Press(
      haptic: false,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0x59000000),
          borderRadius: BorderRadius.circular(R.card),
          border: Border.all(color: C.hair2, width: 1),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(label, style: T.display(15).copyWith(letterSpacing: 0.4)),
                      // a quiet crown, not a scary padlock — an upsell, not
                      // a denial. Only shown while signed out of Rivlr+.
                      if (tagged) ...[
                        const SizedBox(width: 5),
                        Text('👑', style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.9))),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: T.tiny.copyWith(color: C.tx2, fontSize: 11.5, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---- header pieces ---------------------------------------------------------

/// Shown ONLY when the server admits it cannot persist (no database, or a
/// deploy older than the social layer). Silence here cost days of "why does
/// nothing save" — never again: if friends/messages/photos can't save, the
/// app says so on the front page.
class _StorageBanner extends StatelessWidget {
  const _StorageBanner();

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.isLive) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: SocialState.instance,
      builder: (context, _) {
        final s = SocialState.instance;
        if (!s.welcomed || s.serverStorage) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: const Color(0x33FF3B5C),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: C.live.withOpacity(0.6)),
          ),
          child: Row(
            children: [
              const Text('⚠️', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Server storage is offline — friends, messages and photos can’t save. '
                  'Redeploy the backend with DATABASE_URL set.',
                  style: T.tiny.copyWith(color: Colors.white, fontSize: 12, height: 1.35),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The live headcount — acid dot + the actual number of people, owner's
/// call. Nothing at all until the server has actually spoken (an invented
/// number must never leak into a live build).
class _LivePill extends StatelessWidget {
  const _LivePill();

  String _fmt(int n) =>
      n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppSession.instance,
      builder: (context, _) {
        final s = AppSession.instance;
        if (AppConfig.isLive && !s.serverDriven) return const SizedBox.shrink();
        return Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0x66000000),
            borderRadius: BorderRadius.circular(R.chip),
            border: Border.all(color: C.hair2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7, height: 7,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: C.acid,
                  boxShadow: [BoxShadow(color: C.acidGlow, blurRadius: 6)],
                ),
              ),
              const SizedBox(width: 7),
              Text(
                '${_fmt(s.liveCount)} ONLINE',
                style: T.tiny.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RoundBtn extends StatelessWidget {
  const _RoundBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Press(
      onTap: onTap,
      child: Container(
        width: 34, height: 34,
        decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0x66000000),
            border: Border.all(color: C.hair2)),
        child: Icon(icon, size: 18, color: Colors.white),
      ),
    );
  }
}

// ---- chaos pill ------------------------------------------------------------

/// The hourly ritual, now a slim pill that exists ONLY while it's on — the
/// first five minutes of every hour, or a live seasonal event. The rest of
/// the time Home stays pure camera.
class _ChaosPill extends StatefulWidget {
  const _ChaosPill({required this.onTap});
  final VoidCallback onTap;
  @override
  State<_ChaosPill> createState() => _ChaosPillState();
}

class _ChaosPillState extends State<_ChaosPill> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final social = SocialState.instance;
    final ev = social.eventEndsAt;
    final eventLive = social.eventName != null && ev != null && ev.isAfter(now);
    final chaosLive = now.minute < 5;
    if (!eventLive && !chaosLive) return const SizedBox.shrink();

    final String label;
    final String clock;
    if (eventLive) {
      final left = ev.difference(now);
      label = '⚡ ${social.eventName!.toUpperCase()}';
      clock = left.inDays >= 1
          ? '${left.inDays}d ${left.inHours.remainder(24)}h'
          : '${left.inHours}:${left.inMinutes.remainder(60).toString().padLeft(2, '0')}';
    } else {
      final end = DateTime(now.year, now.month, now.day, now.hour, 5);
      final leftC = end.difference(now);
      final m = leftC.inMinutes.remainder(60).toString().padLeft(2, '0');
      final s = leftC.inSeconds.remainder(60).toString().padLeft(2, '0');
      label = '⚡ CHAOS HOUR — LIVE';
      clock = '$m:$s';
    }
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Press(
        onTap: () { Buzz.tick(); Track.event('chaos_banner_tap'); widget.onTap(); },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(R.chip),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: T.tiny.copyWith(
                      color: Colors.black, fontWeight: FontWeight.w800, fontSize: 12)),
              const SizedBox(width: 8),
              Text(clock,
                  style: T.mono.copyWith(color: Colors.black, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

// ---- game ticker -----------------------------------------------------------

/// A slim, endless marquee of tonight's games above the mode chips — the
/// one-line billboard for the thing the camera-only apps don't have.
/// Tapping it starts the selected mode.
class _GameTicker extends StatefulWidget {
  const _GameTicker({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_GameTicker> createState() => _GameTickerState();
}

class _GameTickerState extends State<_GameTicker> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 22))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _cell(String emoji, String name, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 11.5)),
          const SizedBox(width: 5),
          Text(name,
              style: T.display(11.5).copyWith(
                  color: color ?? Colors.white.withOpacity(0.55), letterSpacing: 1.4)),
          const SizedBox(width: 8),
          Text('·', style: TextStyle(color: Colors.white.withOpacity(0.22), fontSize: 12)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // one strip, drawn twice — translating by exactly half loops seamlessly
    final strip = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _cell('⚡', 'tonight', color: C.acid),
        for (final d in SeqDef.ten) _cell(d.icon, d.name.toLowerCase()),
      ],
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: SizedBox(
        height: 24,
        width: double.infinity,
        child: ClipRect(
          child: OverflowBox(
            alignment: Alignment.centerLeft,
            maxWidth: double.infinity,
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, child) => FractionalTranslation(
                translation: Offset(-_c.value * 0.5, 0),
                child: child,
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [strip, strip]),
            ),
          ),
        ),
      ),
    );
  }
}

// ---- active filter ---------------------------------------------------------

/// Shows only when a paid filter is switched on, so you always know what
/// you're searching inside. Tapping goes straight to changing it.
class _FilterChip extends StatelessWidget {
  const _FilterChip();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppSession.instance,
      builder: (context, _) {
        final meet = AppSession.instance.meetPref;
        if (meet == 'Everyone') return const SizedBox.shrink();
        final word = meet == 'Women' ? 'women only' : 'men only';
        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Press(
            onTap: () {
              Buzz.tick();
              SettingsScreen.push(context, () {});
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
              decoration: BoxDecoration(
                gradient: C.gradSig,
                borderRadius: BorderRadius.circular(R.chip),
                boxShadow: C.glowSig(blur: 14, spread: -5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.tune_rounded, size: 13, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(word,
                      style: T.tiny.copyWith(
                          color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
