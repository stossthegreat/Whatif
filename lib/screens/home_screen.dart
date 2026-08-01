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
      List.generate(34, (_) => _Particle.random(_rng));
  late final List<_Avatar> _avatars = List.generate(6, (i) => _Avatar.random(_rng, i));

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
          // drifting avatars (upper two-thirds)
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _t,
              builder: (context, _) => _AvatarLayer(t: _t.value, avatars: _avatars),
            ),
          ),
          // ephemeral activity
          const _ActivityLayer(),
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
                  const SizedBox(height: 18),
                  const _ChaosHour(),
                  const SizedBox(height: 10),
                  const _WorldTicker(),
                  const Spacer(flex: 4),
                  Text('you never know who you’ll get',
                      style: T.body.copyWith(color: C.tx2, fontSize: 15)),
                  const SizedBox(height: 8),
                  Icon(Icons.keyboard_arrow_down_rounded, size: 22, color: C.sig.withOpacity(0.9)),
                  const SizedBox(height: 4),
                  Text('DROP IN', style: T.eyebrow.copyWith(color: C.sig, letterSpacing: 3, fontSize: 11)),
                  const SizedBox(height: 10),
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
        return Column(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PulseDot(),
                const SizedBox(width: 8),
                Text('LIVE RIGHT NOW',
                    style: T.eyebrow.copyWith(color: C.live, fontSize: 11, letterSpacing: 3)),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              n,
              style: T.huge(64).copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
                shadows: [Shadow(color: C.sigGlow, blurRadius: 40)],
              ),
            ),
            const SizedBox(height: 6),
            Text('strangers on camera', style: T.body.copyWith(color: C.tx2, fontSize: 15)),
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
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        gradient: _live
            ? LinearGradient(colors: [C.live.withOpacity(0.28), C.sig.withOpacity(0.22)])
            : null,
        color: _live ? null : C.glass,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: _live ? C.sig.withOpacity(0.6) : C.hair),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 13)),
          const SizedBox(width: 7),
          Text(
            _live ? 'CHAOS HOUR · LIVE  $m:$s' : 'chaos hour in  $m:$s',
            style: T.tiny.copyWith(
              color: _live ? Colors.white : C.tx2,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ],
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

  static const _games = ['Red Flag', 'Caption This', 'Roast Me', 'Freeze Face', 'Odd One Out', 'Sell It'];

  String _next() {
    switch (_rng.nextInt(5)) {
      case 0:
        final room = Cell.roomNames[_rng.nextInt(Cell.roomNames.length)];
        return '$room filling · ${2 + _rng.nextInt(4)}/6';
      case 1:
        return '😂 ${180 + _rng.nextInt(600)} laughs this minute';
      case 2:
        return '👀 ${2 + _rng.nextInt(7)} of your people online';
      case 3:
        return '📈 trending · ${_games[_rng.nextInt(_games.length)]}';
      default:
        return '⚡ ${3 + _rng.nextInt(9)} rooms started just now';
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
        child: Container(
          key: ValueKey(_line),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0x59000000),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: C.hair),
          ),
          child: Text(_line,
              style: T.tiny.copyWith(color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.w700)),
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
    blob(C.purpleDeep, 0.28 + 0.1 * math.sin(t * tau), 0.30 + 0.06 * math.cos(t * tau), size.width * 0.7, 0.22);
    blob(C.blue, 0.78 + 0.08 * math.cos(t * tau * 0.8), 0.22 + 0.05 * math.sin(t * tau), size.width * 0.5, 0.10);

    // rising particles
    final p = Paint();
    for (final part in particles) {
      final y = (part.baseY - t * part.speed * 8) % 1.0;
      final yy = y < 0 ? y + 1 : y;
      final x = (part.x + 0.02 * math.sin((t * 6 + part.baseY) * tau)) % 1.0;
      final op = (math.sin(yy * math.pi)).clamp(0.0, 1.0) * 0.6;
      p.color = (part.red ? C.live : C.sig).withOpacity(op * (part.red ? 0.55 : 0.4));
      canvas.drawCircle(Offset(x * size.width, yy * size.height), part.size, p);
    }
  }

  @override
  bool shouldRepaint(_LobbyPainter old) => old.t != t;
}

// ---- floating avatars -----------------------------------------------------
class _Avatar {
  _Avatar(this.ax, this.ay, this.fx, this.fy, this.phase, this.scale, this.emoji);
  final double ax, ay, fx, fy, phase, scale;
  final String? emoji;
  static const _faces = ['😂', '😳', '🔥', '👀', '😭', '💀', '😏', '🤨', '😮'];
  static _Avatar random(math.Random r, int i) => _Avatar(
        0.14 + r.nextDouble() * 0.72, // anchor x
        0.12 + r.nextDouble() * 0.44, // anchor y (upper area)
        0.035 + r.nextDouble() * 0.05, // drift amp x
        0.03 + r.nextDouble() * 0.05, // drift amp y
        r.nextDouble(),
        0.72 + r.nextDouble() * 0.5,
        // roughly half carry a small emoji face, half are pure obsidian orbs
        r.nextBool() ? _faces[r.nextInt(_faces.length)] : null,
      );
}

class _AvatarLayer extends StatelessWidget {
  const _AvatarLayer({required this.t, required this.avatars});
  final double t;
  final List<_Avatar> avatars;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final tau = math.pi * 2;
        return Stack(
          children: [
            for (final a in avatars)
              Positioned(
                left: (a.ax + a.fx * math.sin((t + a.phase) * tau)) * c.maxWidth - 24 * a.scale,
                top: (a.ay + a.fy * math.cos((t + a.phase) * tau * 0.8)) * c.maxHeight - 24 * a.scale,
                child: Opacity(
                  opacity: 0.9,
                  child: _MiniOrb(size: 48 * a.scale, emoji: a.emoji),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// A polished obsidian marble — shiny jet-black, a soft specular highlight
/// top-left, a faint purple rim. Reads as premium, never a flat grey disc.
class _MiniOrb extends StatelessWidget {
  const _MiniOrb({required this.size, this.emoji});
  final double size;
  final String? emoji;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-0.45, -0.55),
          radius: 1.05,
          colors: [Color(0xFF2A2D34), Color(0xFF0C0D10), Color(0xFF000000)],
          stops: [0.0, 0.55, 1.0],
        ),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
        boxShadow: [
          const BoxShadow(color: Color(0xCC000000), blurRadius: 16, spreadRadius: -2, offset: Offset(0, 6)),
          BoxShadow(color: C.sig.withOpacity(0.16), blurRadius: 18, spreadRadius: -8),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // specular glint
          Positioned(
            left: size * 0.2,
            top: size * 0.16,
            child: Container(
              width: size * 0.24,
              height: size * 0.24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Colors.white.withOpacity(0.5), Colors.white.withOpacity(0)],
                ),
              ),
            ),
          ),
          if (emoji != null)
            Text(emoji!, style: TextStyle(fontSize: size * 0.42)),
        ],
      ),
    );
  }
}

// ---- ephemeral activity ---------------------------------------------------
class _ActivityLayer extends StatefulWidget {
  const _ActivityLayer();
  @override
  State<_ActivityLayer> createState() => _ActivityLayerState();
}

class _ActivityLayerState extends State<_ActivityLayer> with TickerProviderStateMixin {
  final _rng = math.Random();
  final List<_Act> _items = [];
  Timer? _spawner;

  static const _pool = [
    '😂 x18', '🔥 x7', '💀', '❤️ x12', 'someone just won', '👏 x9', '😭 x4', '😳', '⚡️ CHAOS', '@kai joined', '@nova joined',
  ];

  @override
  void initState() {
    super.initState();
    _spawner = Timer.periodic(const Duration(milliseconds: 1100), (_) => _spawn());
  }

  void _spawn() {
    if (!mounted) return;
    final ctl = AnimationController(vsync: this, duration: Duration(milliseconds: 2600 + _rng.nextInt(900)));
    final act = _Act(
      text: _pool[_rng.nextInt(_pool.length)],
      x: 0.1 + _rng.nextDouble() * 0.8,
      y: 0.42 + _rng.nextDouble() * 0.22,
      ctl: ctl,
    );
    setState(() => _items.add(act));
    ctl.forward().whenComplete(() {
      if (!mounted) return;
      setState(() => _items.remove(act));
      ctl.dispose();
    });
  }

  @override
  void dispose() {
    _spawner?.cancel();
    for (final a in _items) { a.ctl.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, c) => Stack(
          children: [
            for (final a in _items)
              AnimatedBuilder(
                animation: a.ctl,
                builder: (context, _) {
                  final t = a.ctl.value;
                  final op = t < 0.15 ? t / 0.15 : (t > 0.7 ? (1 - (t - 0.7) / 0.3) : 1.0);
                  return Positioned(
                    left: a.x * c.maxWidth,
                    top: (a.y - 0.12 * t) * c.maxHeight,
                    child: Opacity(
                      opacity: op.clamp(0.0, 1.0) * 0.9,
                      child: _ActivityChip(a.text),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _Act {
  _Act({required this.text, required this.x, required this.y, required this.ctl});
  final String text;
  final double x, y;
  final AnimationController ctl;
}

class _ActivityChip extends StatelessWidget {
  const _ActivityChip(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    final chaos = text.contains('CHAOS');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x66000000),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: chaos ? C.sig.withOpacity(0.5) : C.hair),
      ),
      child: Text(text, style: T.tiny.copyWith(
        color: chaos ? C.sig : Colors.white.withOpacity(0.85), fontWeight: FontWeight.w700)),
    );
  }
}
