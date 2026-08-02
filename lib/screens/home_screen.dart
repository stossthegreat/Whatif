import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../config.dart';
import '../core/analytics.dart';
import '../core/haptics.dart';
import '../models/game.dart';
import '../state/chat.dart';
import '../state/session.dart';
import '../state/social.dart';
import '../theme/tokens.dart';
import '../widgets/glass.dart';
import '../widgets/identity_orb.dart';
import 'chats_screen.dart';
import 'friends_screen.dart';
import 'settings_screen.dart';

/// HOME — one job: get you to press Start within half a second.
///
/// The hero is the ACTION, not a statistic: a huge glowing Start with
/// "connect to a random person" over it. Live numbers only appear when they're
/// big enough to create FOMO — a real count when the world is busy, and
/// "someone is waiting" when it isn't. A low number is never shown; a shown
/// number is never invented.
///
/// Below the fold: trending games, the Chaos Hour banner, friends.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.onSignOut,
    required this.onParty,
    required this.onPlay,
  });
  final VoidCallback onSignOut;
  final VoidCallback onParty;
  final VoidCallback onPlay;

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
          // legibility scrim above the nav bar
          const Positioned(
            bottom: 0, left: 0, right: 0, height: 220,
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
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 6),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: r.gutter),
                  child: Row(
                    children: [
                      const Wordmark(size: 30),
                      const Spacer(),
                      const _RequestsChip(),
                      const _MessagesBtn(),
                      const SizedBox(width: 8),
                      const _LivePill(),
                      const SizedBox(width: 8),
                      _RoundBtn(
                        icon: Icons.settings_rounded,
                        onTap: () { Buzz.tick(); SettingsScreen.push(context, widget.onSignOut); },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, box) => SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ---- HERO — the words do the work; the Play orb in
                          // the tab bar is the one and only button.
                          SizedBox(
                            height: math.max(box.maxHeight * 0.36, 250),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const _StatusLine(),
                                const SizedBox(height: 16),
                                Text(
                                  'Connect to a\nrandom person',
                                  textAlign: TextAlign.center,
                                  style: T.huge(38),
                                ),
                                const SizedBox(height: 18),
                                const _StatsStrip(),
                              ],
                            ),
                          ),
                          // ---- RECENTLY MET — pressing Next never loses anyone
                          const _RecentlyMetRail(),
                          // ---- TRENDING — swipeable game cards
                          Padding(
                            padding: EdgeInsets.only(left: r.gutter, right: r.gutter, bottom: 12),
                            child: Text('TRENDING TONIGHT', style: T.eyebrow),
                          ),
                          SizedBox(
                            height: 128,
                            child: ListView.separated(
                              physics: const BouncingScrollPhysics(),
                              scrollDirection: Axis.horizontal,
                              padding: EdgeInsets.symmetric(horizontal: r.gutter),
                              itemCount: _trending.length,
                              separatorBuilder: (_, _) => const SizedBox(width: 10),
                              itemBuilder: (context, i) =>
                                  _GameCard(def: _trending[i], onTap: widget.onPlay),
                            ),
                          ),
                          const SizedBox(height: 22),
                          // ---- CHAOS HOUR — full-width ritual banner
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: r.gutter),
                            child: _ChaosBanner(onTap: widget.onPlay),
                          ),
                          const SizedBox(height: 26),
                          // ---- FRIENDS
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: r.gutter),
                            child: const _FriendsSection(),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: r.gutter),
                            child: _PartyRow(onTap: widget.onParty),
                          ),
                          // clear the floating Play orb, which pokes above the bar
                          const SizedBox(height: 72),
                        ],
                      ),
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

  /// "Trending" order rotates daily so the rail feels alive — editorial
  /// ordering, not fabricated player counts.
  List<SeqDef> get _trending {
    final shift = DateTime.now().difference(DateTime(2026)).inDays % SeqDef.ten.length;
    return [...SeqDef.ten.sublist(shift), ...SeqDef.ten.sublist(0, shift)];
  }
}

// ---- hero pieces -----------------------------------------------------------

/// One line of truth above the headline — warm copy only, no digits (the
/// number lives in the header pill). Never "1 stranger on camera".
class _StatusLine extends StatelessWidget {
  const _StatusLine();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppSession.instance,
      builder: (context, _) {
        final s = AppSession.instance;
        // In live builds the drifting simulated count must never leak — treat
        // the world as quiet until the server's first presence message.
        final trusted = !AppConfig.isLive || s.serverDriven;
        final String text;
        if (trusted && s.liveCount >= 100) {
          text = 'PEOPLE ARE LIVE RIGHT NOW';
        } else if (AppConfig.isLive && s.serverDriven && s.liveCount >= 2) {
          text = 'SOMEONE IS WAITING RIGHT NOW';
        } else {
          text = 'READY TO MATCH';
        }
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _PulseDot(),
            const SizedBox(width: 8),
            AnimatedSwitcher(
              duration: M.base,
              child: Text(
                text,
                key: ValueKey(text),
                style: T.eyebrow.copyWith(
                  color: C.tx2,
                  fontSize: 11,
                  letterSpacing: 2.6,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The live headcount — a quiet pill beside settings. Green dot + the real
/// number when it's big enough to impress; just "LIVE" while the world is
/// small; nothing at all until the server has actually spoken.
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
        final showCount = !AppConfig.isLive || s.liveCount >= 100;
        return Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: C.glass,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: C.hair),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7, height: 7,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF30D158),
                  boxShadow: [BoxShadow(color: Color(0x8030D158), blurRadius: 6)],
                ),
              ),
              const SizedBox(width: 7),
              Text(
                showCount ? _fmt(s.liveCount) : 'LIVE',
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

/// Real activity, dot-separated — each entry appears only once it's big
/// enough to impress. Early days: the row simply isn't there.
class _StatsStrip extends StatelessWidget {
  const _StatsStrip();

  String _fmt(int n) =>
      n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppSession.instance,
      builder: (context, _) {
        final s = AppSession.instance;
        final parts = <String>[
          if (s.roomsLive >= 8) '${s.roomsLive} rooms open',
          if (s.matchesToday >= 500) '${_fmt(s.matchesToday)} matches today',
        ];
        if (parts.isEmpty) return const SizedBox(height: 18);
        return SizedBox(
          height: 18,
          child: Text(
            parts.join('  ·  '),
            style: T.tiny.copyWith(color: C.tx3, fontWeight: FontWeight.w600, letterSpacing: 0.2),
          ),
        );
      },
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot();
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

// ---- trending cards --------------------------------------------------------

class _GameCard extends StatelessWidget {
  const _GameCard({required this.def, required this.onTap});
  final SeqDef def;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final spark = def.vibe == 'spark';
    return Press(
      onTap: () { Buzz.tick(); Track.event('trending_tap', {'game': def.name}); onTap(); },
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: C.glass,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: C.hair),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(def.icon, style: const TextStyle(fontSize: 30)),
            const Spacer(),
            Text(def.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: T.body.copyWith(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: -0.2)),
            const SizedBox(height: 3),
            Text(
              spark ? 'SPARK' : (def.vibe == 'wild' ? 'WILD' : 'WARM'),
              style: T.tiny.copyWith(
                fontSize: 9.5,
                letterSpacing: 1.6,
                fontWeight: FontWeight.w800,
                color: spark ? C.sig : C.tx3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---- chaos hour banner -----------------------------------------------------

/// The hourly ritual, full width. Counting down it's quiet glass; for the
/// first five minutes of every hour it flips to hot white.
class _ChaosBanner extends StatefulWidget {
  const _ChaosBanner({required this.onTap});
  final VoidCallback onTap;
  @override
  State<_ChaosBanner> createState() => _ChaosBannerState();
}

class _ChaosBannerState extends State<_ChaosBanner> {
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
      _left = DateTime(now.year, now.month, now.day, now.hour, 5).difference(now);
    } else {
      _live = false;
      _left = DateTime(now.year, now.month, now.day, now.hour + 1).difference(now);
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
    final fg = _live ? Colors.black : Colors.white;
    final fg2 = _live ? Colors.black.withOpacity(0.6) : C.tx3;
    return Press(
      onTap: () { Buzz.tick(); Track.event('chaos_banner_tap'); widget.onTap(); },
      child: AnimatedContainer(
        duration: M.base,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: _live ? Colors.white : C.glass,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _live ? Colors.white : C.hair),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_live ? '⚡ CHAOS HOUR — LIVE' : 'CHAOS HOUR',
                      style: T.body.copyWith(color: fg, fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 0.4)),
                  const SizedBox(height: 4),
                  Text('2× badges · wilder games · top of every hour',
                      style: T.tiny.copyWith(color: fg2, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '$m:$s',
              style: T.huge(26).copyWith(
                color: fg,
                fontFeatures: const [FontFeature.tabularFigures()],
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---- friends ---------------------------------------------------------------

/// Your real friends (the matched ones), online first. Hidden entirely until
/// you have some — no hollow placeholder rows.
class _FriendsSection extends StatelessWidget {
  const _FriendsSection();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: SocialState.instance,
      builder: (context, _) {
        final friends = SocialState.instance.friends;
        if (friends.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('YOUR PEOPLE', style: T.eyebrow),
                const Spacer(),
                Press(
                  haptic: false,
                  onTap: () { Buzz.tick(); FriendsScreen.push(context); },
                  child: Text('see all  ›',
                      style: T.tiny.copyWith(color: C.tx2, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final f in friends.take(4)) _FriendRow(friend: f),
            const SizedBox(height: 6),
          ],
        );
      },
    );
  }
}

class _FriendRow extends StatelessWidget {
  const _FriendRow({required this.friend});
  final FriendInfo friend;

  @override
  Widget build(BuildContext context) {
    return Press(
      haptic: false,
      onTap: () { Buzz.tick(); FriendsScreen.push(context); },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            IdentityOrb(hue: friend.hue, size: 36, live: friend.online),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('@${friend.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: T.body.copyWith(
                          color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                  Text(
                    friend.online ? 'online now' : 'away',
                    style: T.tiny.copyWith(
                      color: friend.online ? const Color(0xFF3BE07A) : C.tx3,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The "accidentally pressed Next" recovery — people you just met, one tap
/// from becoming permanent. A headline surface, right under the hero.
class _RecentlyMetRail extends StatelessWidget {
  const _RecentlyMetRail();

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    return AnimatedBuilder(
      animation: SocialState.instance,
      builder: (context, _) {
        final recent = SocialState.instance.recent;
        if (recent.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(left: r.gutter, right: r.gutter, bottom: 12),
              child: Text('RECENTLY MET', style: T.eyebrow),
            ),
            SizedBox(
              height: 92,
              child: ListView.separated(
                physics: const BouncingScrollPhysics(),
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: r.gutter),
                itemCount: recent.length,
                separatorBuilder: (_, i) => const SizedBox(width: 16),
                itemBuilder: (context, i) {
                  final m = recent[i];
                  return Press(
                    haptic: false,
                    onTap: () { Buzz.tick(); FriendsScreen.push(context, tab: 3); },
                    child: Column(
                      children: [
                        IdentityOrb(hue: m.hue, size: 52),
                        const SizedBox(height: 7),
                        Text('@${m.name}',
                            style: T.tiny.copyWith(
                                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11.5)),
                        Text(m.ago, style: T.tiny.copyWith(color: C.tx3, fontSize: 10)),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 22),
          ],
        );
      },
    );
  }
}

/// Messages entry — badge shows total unread across every conversation.
class _MessagesBtn extends StatelessWidget {
  const _MessagesBtn();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ChatStore.instance,
      builder: (context, _) {
        final n = ChatStore.instance.unreadTotal;
        return Press(
          onTap: () { Buzz.tick(); ChatsScreen.push(context); },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                    shape: BoxShape.circle, color: C.glass, border: Border.all(color: C.hair)),
                child: const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: C.tx2),
              ),
              if (n > 0)
                Positioned(
                  right: -4, top: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    constraints: const BoxConstraints(minWidth: 16),
                    decoration: BoxDecoration(
                        color: C.sig, borderRadius: BorderRadius.circular(100)),
                    child: Text('$n',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 10, color: Colors.white, fontWeight: FontWeight.w800)),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Pending friend requests — a quiet purple chip beside the live pill.
class _RequestsChip extends StatelessWidget {
  const _RequestsChip();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: SocialState.instance,
      builder: (context, _) {
        final n = SocialState.instance.reqCount;
        if (n == 0) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Press(
            haptic: false,
            onTap: () { Buzz.tick(); FriendsScreen.push(context, tab: 4); },
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: C.sig.withOpacity(0.16),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: C.sig.withOpacity(0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person_add_rounded, size: 14, color: C.sig),
                  const SizedBox(width: 6),
                  Text('$n',
                      style: T.tiny.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      )),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The friends-room entry — always present, right under the friends list.
class _PartyRow extends StatelessWidget {
  const _PartyRow({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Press(
      onTap: () { Buzz.tick(); onTap(); },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: C.hair2),
        ),
        child: Row(
          children: [
            Container(
              width: 34, height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, color: C.glass2, border: Border.all(color: C.hair)),
              child: const Icon(Icons.group_add_rounded, size: 17, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Room with friends',
                      style: T.body.copyWith(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                  Text('invite with a code', style: T.tiny.copyWith(color: C.tx3)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 20, color: C.tx3),
          ],
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
