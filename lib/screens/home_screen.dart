import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/haptics.dart';
import '../models/game.dart';
import '../state/session.dart';
import '../theme/tokens.dart';
import '../widgets/glass.dart';
import 'settings_screen.dart';

/// LIVE — the world, not a menu. Very black. Tiny red particles rise; a soft
/// purple glow drifts; obsidian orbs float; activity flickers past. The
/// centerpiece is the living headcount — proof something is happening right
/// now — and the ▶ orb in the tab bar is the only way in.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onSignOut});
  final VoidCallback onSignOut;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _t =
      AnimationController(vsync: this, duration: const Duration(seconds: 30))..repeat();
  final _rng = math.Random();

  late final List<_Particle> _particles =
      List.generate(18, (_) => _Particle.random(_rng));

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    return Scaffold(
      backgroundColor: C.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ambient particle + glow field
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _t,
              builder: (context, _) => CustomPaint(
                painter: _LobbyPainter(_t.value, _particles),
                isComplex: true,
                willChange: true,
              ),
            ),
          ),
          // legibility scrim at the bottom so PLAY + text pop
          const Positioned(
            bottom: 0, left: 0, right: 0, height: 360,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter, end: Alignment.topCenter,
                    colors: [Color(0xF2000000), Color(0x00000000)],
                  ),
                ),
              ),
            ),
          ),
          // foreground UI
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: r.gutter),
              child: Column(
                children: [
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Wordmark(size: 22),
                      const Spacer(),
                      _RoundBtn(
                        icon: Icons.settings_rounded,
                        onTap: () { Buzz.tick(); SettingsScreen.push(context, widget.onSignOut); },
                      ),
                    ],
                  ),
                  const Spacer(flex: 3),
                  const _BigLive(),
                  const SizedBox(height: 26),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _ChaosHour(),
                      SizedBox(width: 8),
                      _TrendChip(),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const _WorldTicker(),
                  const Spacer(flex: 4),
                  Text('you never know who you’ll get',
                      style: T.body.copyWith(color: C.tx3, fontSize: 14)),
                  const SizedBox(height: 10),
                  const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: C.tx3),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The world's heartbeat — a huge living headcount, front and center.
/// Proof that something is happening right now, before you even press play.
class _BigLive extends StatelessWidget {
  const _BigLive();
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppSession.instance,
      builder: (context, _) {
        final n = AppSession.instance.liveCount.toString().replaceAllMapped(
            RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
        final count = AppSession.instance.liveCount;
        return Column(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PulseDot(),
                const SizedBox(width: 8),
                Text('LIVE RIGHT NOW',
                    style: T.eyebrow.copyWith(color: C.tx3, fontSize: 11, letterSpacing: 3.2)),
              ],
            ),
            const SizedBox(height: 12),
            // typography does the work — no glow, no decoration
            Text(
              n,
              style: T.huge(72).copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
                letterSpacing: -2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              count == 1 ? 'stranger on camera' : 'strangers on camera',
              style: T.body.copyWith(color: C.tx2, fontSize: 15),
            ),
          ],
        );
      },
    );
  }
}

class _PulseDot extends StatefulWidget {
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Container(
        width: 8, height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle, color: C.live,
          boxShadow: [BoxShadow(color: C.live.withOpacity(0.4 + 0.6 * _c.value), blurRadius: 8 + 6 * _c.value)],
        ),
      ),
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
        decoration: BoxDecoration(shape: BoxShape.circle, color: C.glass, border: Border.all(color: C.hair)),
        child: Icon(icon, size: 18, color: C.tx2),
      ),
    );
  }
}

/// The hourly ritual — a countdown to CHAOS HOUR (top of every hour), and a hot
/// "LIVE NOW" state for its first minutes. The thing that makes everyone open
/// the app at the same time.
class _ChaosHour extends StatefulWidget {
  const _ChaosHour();
  @override
  State<_ChaosHour> createState() => _ChaosHourState();
}

class _ChaosHourState extends State<_ChaosHour> {
  Timer? _timer;
  Duration _left = Duration.zero;
  bool _live = false;

  @override
  void initState() {
    super.initState();
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final now = DateTime.now();
    if (now.minute < 5) {
      _live = true;
      final endsAt = DateTime(now.year, now.month, now.day, now.hour, 5);
      _left = endsAt.difference(now);
    } else {
      _live = false;
      final next = DateTime(now.year, now.month, now.day, now.hour + 1);
      _left = next.difference(now);
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = _left.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = _left.inSeconds.remainder(60).toString().padLeft(2, '0');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _live ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: _live ? Colors.white : C.hair2),
      ),
      child: Text(
        _live ? 'CHAOS HOUR · $m:$s' : 'Chaos hour in $m:$s',
        style: T.tiny.copyWith(
          color: _live ? Colors.black : C.tx2,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// The trending game — a clean glass chip beside the chaos-hour countdown.
/// Rotates slowly; never overlaps anything.
class _TrendChip extends StatefulWidget {
  const _TrendChip();
  @override
  State<_TrendChip> createState() => _TrendChipState();
}

class _TrendChipState extends State<_TrendChip> {
  static const _games = ['Roast Me', 'Red Flag', 'Face Battle', 'Spin the Bottle', 'Caption This', 'Rizz Battle'];
  final _rng = math.Random();
  Timer? _t;
  late String _game = _games[_rng.nextInt(_games.length)];

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted) setState(() => _game = _games[_rng.nextInt(_games.length)]);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: C.hair2),
      ),
      child: AnimatedSwitcher(
        duration: M.base,
        child: Text(
          'Trending · $_game',
          key: ValueKey(_game),
          style: T.tiny.copyWith(color: C.tx2, fontWeight: FontWeight.w700, letterSpacing: 0.2),
        ),
      ),
    );
  }
}

/// The world, breathing — one line at a time. Rooms filling, laughs counting,
/// friends going live, a trending game. Nothing on this screen is static.
class _WorldTicker extends StatefulWidget {
  const _WorldTicker();
  @override
  State<_WorldTicker> createState() => _WorldTickerState();
}

class _WorldTickerState extends State<_WorldTicker> {
  final _rng = math.Random();
  Timer? _t;
  late String _line = _next();

  String _next() {
    switch (_rng.nextInt(4)) {
      case 0:
        final room = Cell.roomNames[_rng.nextInt(Cell.roomNames.length)];
        return '$room filling · ${2 + _rng.nextInt(4)}/6';
      case 1:
        return '${180 + _rng.nextInt(600)} laughs this minute';
      case 2:
        return '${2 + _rng.nextInt(7)} of your people online';
      default:
        return '${3 + _rng.nextInt(9)} rooms started just now';
    }
  }

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 2700), (_) {
      if (mounted) setState(() => _line = _next());
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      child: AnimatedSwitcher(
        duration: M.base,
        switchInCurve: M.ease,
        switchOutCurve: M.ease,
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.5), end: Offset.zero).animate(anim),
            child: child,
          ),
        ),
        // one quiet line of type — no pill, no border. The words are enough.
        child: Text(
          _line,
          key: ValueKey(_line),
          style: T.tiny.copyWith(color: C.tx3, fontWeight: FontWeight.w600, letterSpacing: 0.2),
        ),
      ),
    );
  }
}

// ---- particle / glow field ------------------------------------------------
class _Particle {
  _Particle(this.x, this.baseY, this.speed, this.size, this.red);
  double x, baseY, speed, size;
  bool red;
  static _Particle random(math.Random r) => _Particle(
        r.nextDouble(), r.nextDouble(), 0.02 + r.nextDouble() * 0.06,
        0.8 + r.nextDouble() * 1.8, r.nextDouble() > 0.35,
      );
}

class _LobbyPainter extends CustomPainter {
  _LobbyPainter(this.t, this.particles);
  final double t;
  final List<_Particle> particles;

  @override
  void paint(Canvas canvas, Size size) {
    final tau = math.pi * 2;
    // two soft glow blobs
    void blob(Color c, double cx, double cy, double rad, double op) {
      final paint = Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(colors: [c.withOpacity(op), c.withOpacity(0)])
            .createShader(Rect.fromCircle(center: Offset(cx * size.width, cy * size.height), radius: rad));
      canvas.drawCircle(Offset(cx * size.width, cy * size.height), rad, paint);
    }
    blob(C.purpleDeep, 0.28 + 0.1 * math.sin(t * tau), 0.30 + 0.06 * math.cos(t * tau), size.width * 0.7, 0.10);
    blob(C.blue, 0.78 + 0.08 * math.cos(t * tau * 0.8), 0.22 + 0.05 * math.sin(t * tau), size.width * 0.5, 0.04);

    // rising particles
    final p = Paint();
    for (final part in particles) {
      final y = (part.baseY - t * part.speed * 8) % 1.0;
      final yy = y < 0 ? y + 1 : y;
      final x = (part.x + 0.02 * math.sin((t * 6 + part.baseY) * tau)) % 1.0;
      final op = (math.sin(yy * math.pi)).clamp(0.0, 1.0) * 0.6;
      p.color = (part.red ? C.live : C.sig).withOpacity(op * (part.red ? 0.35 : 0.22));
      canvas.drawCircle(Offset(x * size.width, yy * size.height), part.size, p);
    }
  }

  @override
  bool shouldRepaint(_LobbyPainter old) => old.t != t;
}

// ---- floating avatars -----------------------------------------------------



