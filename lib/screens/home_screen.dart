import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../config.dart';
import '../core/analytics.dart';
import '../core/camera_service.dart';
import '../core/haptics.dart';
import '../core/sound.dart';
import '../models/game.dart';
import '../net/api_client.dart';
import '../net/network_client.dart';
import '../state/session.dart';
import '../state/social.dart';
import '../theme/tokens.dart';
import '../widgets/glass.dart';
import '../widgets/notification_bell.dart';
import '../widgets/self_view.dart';
import 'discover_screen.dart';
import 'plus_screen.dart';
import 'settings_screen.dart';

/// HOME — deliberately NOT a viewfinder.
///
/// Every random-video app on the store is the same screen: your own camera
/// blown up full-bleed with one button floating on it. That silhouette IS
/// the genre, and it made Rivler read as a clone of it at a glance. So the
/// camera is demoted here to a small self-tile — you can still see you're
/// framed and lit, which is the only job it ever actually had — and the
/// screen becomes a composed, dark, editorial surface: who's on right now
/// as real faces, what's playing tonight, and three unmistakably different
/// doors. Content first, camera second.
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
  StreamSubscription<Map<String, dynamic>>? _sub;
  Timer? _poll;
  List<_Face> _faces = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.active) CameraService.instance.ensure();
    _sub = NetworkClient.instance.events.listen(_onNet);
    if (AppConfig.isLive) {
      _refreshFaces();
      _poll = Timer.periodic(const Duration(seconds: 25), (_) => _refreshFaces());
    }
  }

  void _refreshFaces() {
    if (widget.active) NetworkClient.instance.explore();
  }

  void _onNet(Map<String, dynamic> m) {
    if (!mounted) return;
    if (m['t'] == 'explore') {
      final list = ((m['people'] as List?) ?? const [])
          .whereType<Map>()
          .map((p) => _Face.fromMap(p.cast<String, dynamic>()))
          .where((f) => f.online && f.thumbId != null)
          .take(12)
          .toList();
      setState(() => _faces = list);
    } else if (m['t'] == 'faceFresh' || m['t'] == 'profileFresh') {
      _refreshFaces();
    }
  }

  @override
  void didUpdateWidget(HomeScreen old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) {
      CameraService.instance.ensure();
      _refreshFaces();
    }
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
    _sub?.cancel();
    _poll?.cancel();
    // Leaving Home always releases the lens — finding, party and live rooms
    // (LiveKit / WebRTC) open their own capture session.
    CameraService.instance.dispose();
    super.dispose();
  }

  void _roulette() {
    Buzz.pop();
    Sfx.match();
    Track.event('home_start', {'mode': 'roulette'});
    widget.onPlay('roulette');
  }

  void _oneOnOne() {
    Buzz.pop();
    DiscoverScreen.push(context);
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    return Scaffold(
      backgroundColor: C.char,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // a slow violet aurora instead of a camera wallpaper — the screen
          // has depth and life without borrowing the genre's silhouette
          const _Aurora(),
          SafeArea(
            // the screen is a fixed composition, not a feed: it should FILL
            // the phone, not stack at the top and leave a slab of dead black
            // under it. LayoutBuilder + IntrinsicHeight lets the spacers
            // breathe on a big phone while still scrolling on a small one.
            child: LayoutBuilder(
              builder: (context, box) => SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: box.maxHeight),
                  // IntrinsicHeight is load-bearing: Spacer/Expanded inside a
                  // scroll view throws on unbounded height without it
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(r.gutter, 4, r.gutter, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                // ---- header: you, small. Not the wallpaper. ----------------
                Row(
                  children: [
                    const _SelfTile(),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Wordmark(size: 26),
                          const SizedBox(height: 3),
                          AnimatedBuilder(
                            animation: AppSession.instance,
                            builder: (context, _) => Text(
                              '@${AppSession.instance.myHandle}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: T.tiny.copyWith(fontSize: 12, color: C.tx3),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const NotificationBell(size: 36, iconSize: 18),
                    const SizedBox(width: 8),
                    _RoundBtn(
                      icon: Icons.settings_rounded,
                      onTap: () { Buzz.tick(); SettingsScreen.push(context, widget.onSignOut); },
                    ),
                  ],
                ),
                const _StorageBanner(),
                const _FilterChip(),
                _ChaosPill(onTap: _roulette),

                const SizedBox(height: 22),
                // ---- who is actually here, as faces ------------------------
                const _LiveHeadline(),
                if (_faces.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _FaceStrip(faces: _faces, onTap: _oneOnOne),
                ],

                // elastic: on a tall phone this opens up and the composition
                // sits centred instead of hugging the status bar
                const Spacer(flex: 2),
                // ---- the hero: Roulette --------------------------------
                _HeroCard(onTap: _roulette),

                const SizedBox(height: 14),
                // ---- the two other doors ------------------------------
                Row(
                  children: [
                    Expanded(
                      child: _DoorCard(
                        emoji: '🎥',
                        label: '1 on 1',
                        sub: 'browse & pick',
                        onTap: _oneOnOne,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DoorCard(
                        emoji: '👥',
                        label: 'Groups',
                        sub: 'your own room',
                        onTap: () { Buzz.pop(); widget.onPlay('groups'); },
                      ),
                    ),
                  ],
                ),

                const Spacer(flex: 3),
                // ---- tonight's games: the thing they don't have ----------
                Row(
                  children: [
                    Text('PLAYING TONIGHT',
                        style: T.eyebrow.copyWith(color: C.tx3, fontSize: 10.5)),
                    const Spacer(),
                    Text('${SeqDef.ten.length} games',
                        style: T.tiny.copyWith(color: C.tx3, fontSize: 10.5)),
                  ],
                ),
                const SizedBox(height: 10),
                _GameTicker(onTap: _roulette),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---- the stage lighting -----------------------------------------------------

/// Two slow violet blooms drifting behind everything. Replaces the camera as
/// the thing that makes the screen feel alive.
class _Aurora extends StatefulWidget {
  const _Aurora();
  @override
  State<_Aurora> createState() => _AuroraState();
}

class _AuroraState extends State<_Aurora> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 26))..repeat();

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
        final t = _c.value * 2 * math.pi;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: C.char,
            gradient: RadialGradient(
              center: Alignment(0.7 * math.sin(t), -0.75 + 0.25 * math.cos(t * 0.7)),
              radius: 1.25,
              colors: [C.sig.withOpacity(0.20), Colors.transparent],
              stops: const [0.0, 0.75],
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.8 * math.cos(t * 0.6), 0.85 + 0.12 * math.sin(t)),
                radius: 1.1,
                colors: [C.purpleDeep.withOpacity(0.22), Colors.transparent],
                stops: const [0.0, 0.7],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// You, at thumbnail size. Enough to check your framing and lighting — which
/// is the only thing the full-bleed viewfinder was ever really for.
class _SelfTile extends StatelessWidget {
  const _SelfTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: C.hair2),
        boxShadow: [BoxShadow(color: C.sig.withOpacity(0.25), blurRadius: 14, spreadRadius: -6)],
      ),
      child: const SelfView(fit: BoxFit.cover),
    );
  }
}

/// The honest headcount, as a sentence rather than a badge.
class _LiveHeadline extends StatelessWidget {
  const _LiveHeadline();

  String _fmt(int n) =>
      n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppSession.instance,
      builder: (context, _) {
        final s = AppSession.instance;
        // an invented number must never reach a live build
        if (AppConfig.isLive && !s.serverDriven) {
          return Text('Warming up…', style: T.display(30));
        }
        final n = s.liveCount;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 9, height: 9,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: C.acid,
                boxShadow: [BoxShadow(color: C.acidGlow, blurRadius: 8)],
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                n > 0 ? '${_fmt(n)} online now' : 'Quiet right now',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: T.display(27),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Real faces of real people who are on right now. Proof of life the moment
/// the app opens — and the thing a camera wallpaper could never show.
class _FaceStrip extends StatelessWidget {
  const _FaceStrip({required this.faces, required this.onTap});
  final List<_Face> faces;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 62,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: faces.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final f = faces[i];
          return Press(
            haptic: false,
            onTap: onTap,
            child: Container(
              width: 54,
              height: 54,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: C.char3,
                border: Border.all(color: C.acid.withOpacity(0.55), width: 1.5),
              ),
              child: f.thumbId != null && Api.ready
                  ? Image.network(Api.mediaUrl(f.thumbId!), fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink())
                  : const SizedBox.shrink(),
            ),
          );
        },
      ),
    );
  }
}

class _Face {
  _Face({required this.uid, this.thumbId, this.online = true});
  factory _Face.fromMap(Map<String, dynamic> m) => _Face(
        uid: (m['uid'] as String?) ?? '',
        thumbId: (m['thumbId'] as num?)?.toInt(),
        online: m['online'] != false,
      );
  final String uid;
  final int? thumbId;
  final bool online;
}

// ---- the doors --------------------------------------------------------------

/// Roulette, as a proper piece of art rather than a floating button on a
/// camera feed. Big, gradient, alive — and unmistakably a card, not a lens.
class _HeroCard extends StatefulWidget {
  const _HeroCard({required this.onTap});
  final VoidCallback onTap;
  @override
  State<_HeroCard> createState() => _HeroCardState();
}

class _HeroCardState extends State<_HeroCard> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Press(
      scale: 0.985,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Container(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
          decoration: BoxDecoration(
            gradient: C.gradSigHot,
            borderRadius: BorderRadius.circular(R.card),
            boxShadow: [
              BoxShadow(
                color: C.sigGlow,
                blurRadius: 26 + 10 * _c.value,
                spreadRadius: -8,
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('ROULETTE',
                        style: T.eyebrow.copyWith(
                            color: Colors.white.withOpacity(0.75), fontSize: 10.5)),
                    const SizedBox(height: 6),
                    Text('Spin me\nsomeone', style: T.display(30).copyWith(height: 1.05)),
                    const SizedBox(height: 8),
                    Text('no choosing · games hit back to back',
                        style: T.tiny.copyWith(
                            color: Colors.white.withOpacity(0.85), fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // the dial, small and spinning — a nod to the old portal without
              // being a full-screen button
              Transform.rotate(
                angle: _c.value * 0.6,
                child: Container(
                  width: 58, height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.14),
                    border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
                  ),
                  child: const Icon(Icons.bolt_rounded, size: 30, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A deliberate destination. Visually a card, never a filter chip.
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
        padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
        decoration: BoxDecoration(
          color: C.char2,
          borderRadius: BorderRadius.circular(R.card),
          border: Border.all(color: C.hair2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 12),
            Row(
              children: [
                Flexible(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: T.display(17).copyWith(letterSpacing: 0.3)),
                ),
                // a quiet crown, not a padlock — an upsell, not a denial
                if (tagged) ...[
                  const SizedBox(width: 5),
                  const Text('👑', style: TextStyle(fontSize: 11)),
                ],
              ],
            ),
            const SizedBox(height: 3),
            Text(sub,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: T.tiny.copyWith(color: C.tx2, fontSize: 11.5, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ---- header pieces ---------------------------------------------------------

/// Shown ONLY when the server admits it cannot persist (no database, or a
/// deploy older than the social layer). Silence here cost days of "why does
/// nothing save" — never again.
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
          margin: const EdgeInsets.only(top: 12),
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

class _RoundBtn extends StatelessWidget {
  const _RoundBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Press(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: C.glass2,
            border: Border.all(color: C.hair2)),
        child: Icon(icon, size: 18, color: Colors.white),
      ),
    );
  }
}

// ---- chaos pill ------------------------------------------------------------

/// The hourly ritual — a slim pill that exists ONLY while it's on: the first
/// five minutes of every hour, or a live seasonal event.
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
      padding: const EdgeInsets.only(top: 12),
      child: Press(
        onTap: () { Buzz.tick(); Track.event('chaos_banner_tap'); widget.onTap(); },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
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
              Text(clock, style: T.mono.copyWith(color: Colors.black, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

// ---- game ticker -----------------------------------------------------------

/// A slim, endless marquee of tonight's games — the one-line billboard for
/// the thing the camera-only apps don't have.
class _GameTicker extends StatefulWidget {
  const _GameTicker({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_GameTicker> createState() => _GameTickerState();
}

class _GameTickerState extends State<_GameTicker> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 26))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _cell(String emoji, String name) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: C.char2,
          borderRadius: BorderRadius.circular(R.chip),
          border: Border.all(color: C.hair),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 6),
            Text(name,
                style: T.display(12).copyWith(color: C.tx2, letterSpacing: 0.9)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // one strip, drawn twice — translating by exactly half loops seamlessly
    final strip = Row(
      mainAxisSize: MainAxisSize.min,
      children: [for (final d in SeqDef.ten) _cell(d.icon, d.name.toLowerCase())],
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: SizedBox(
        height: 38,
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
          padding: const EdgeInsets.only(top: 12),
          child: Align(
            alignment: Alignment.centerLeft,
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
          ),
        );
      },
    );
  }
}
