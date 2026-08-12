import 'dart:async';
import 'package:flutter/material.dart';
import '../core/analytics.dart';
import '../core/haptics.dart';
import '../net/api_client.dart';
import '../net/network_client.dart';
import '../theme/tokens.dart';
import '../widgets/glass.dart';
import '../widgets/notification_bell.dart';
import '../widgets/person_card.dart' show flagEmoji;

/// DISCOVER — the 1-on-1 door. One face at a time, full screen: skip past
/// people who don't interest you, invite the ones who do. This is the SAME
/// roster and the SAME ring machinery as Explore's grid (`explore` /
/// `meetInvite`) — just presented one card at a time instead of a wall.
/// Inviting really rings them; nothing happens without their yes, and a
/// decline or timeout here just advances to the next face, same as a skip.
class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  static Future<void> push(BuildContext context) {
    Track.screen('discover');
    return Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const DiscoverScreen(),
      fullscreenDialog: true,
    ));
  }

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  StreamSubscription<Map<String, dynamic>>? _sub;
  Timer? _poll;
  List<_Person> _people = const [];
  int _i = 0;
  bool _loaded = false;
  String? _ringingUid; // set while an invite is out; blocks a second one

  @override
  void initState() {
    super.initState();
    _sub = NetworkClient.instance.events.listen(_onNet);
    _refresh();
    _poll = Timer.periodic(const Duration(seconds: 20), (_) => _refresh());
  }

  @override
  void dispose() {
    _sub?.cancel();
    _poll?.cancel();
    super.dispose();
  }

  void _refresh() => NetworkClient.instance.explore();

  void _onNet(Map<String, dynamic> m) {
    if (!mounted) return;
    switch (m['t']) {
      case 'explore':
        // Discover is a live-invite surface — away people can't be rung, and
        // a dead "invite" button on every third card is worse than a
        // slightly shorter stack. Explore's grid is where they belong.
        final fresh = ((m['people'] as List?) ?? const [])
            .whereType<Map>()
            .map((p) => _Person.fromMap(p.cast<String, dynamic>()))
            .where((p) => p.online && !p.busy)
            .toList();
        setState(() {
          _loaded = true;
          _people = fresh;
          if (_i >= _people.length) _i = 0;
        });
      case 'callState':
        // any answer to the one invite this screen can have outstanding —
        // accepted forms a room (handled below via 'cell'), everything else
        // means "no" and the right move is straight to the next face
        final st = m['state'] as String?;
        if (_ringingUid != null &&
            (st == 'declined' || st == 'timeout' || st == 'busy' || st == 'cancelled')) {
          setState(() => _ringingUid = null);
          _toast(st == 'busy' ? 'they’re in a room right now' : 'no answer — next up');
          _skip();
        }
      case 'cell':
        // the invite landed — a real room is forming. This screen's job is
        // done; step out of the way so the live room underneath shows.
        if (mounted) Navigator.of(context).maybePop();
    }
  }

  void _toast(String s) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: C.char2,
      content: Text(s, style: T.body.copyWith(color: Colors.white)),
    ));
  }

  void _skip() {
    if (_ringingUid != null || _people.isEmpty) return;
    Buzz.tick();
    setState(() => _i = (_i + 1) % _people.length);
  }

  void _invite(_Person p) {
    if (_ringingUid != null) return;
    Buzz.commit();
    Track.event('discover_invite');
    NetworkClient.instance.meetInvite(p.uid);
    setState(() => _ringingUid = p.uid);
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final person = _people.isEmpty ? null : _people[_i];
    return Scaffold(
      backgroundColor: C.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(r.gutter, 8, r.gutter, 4),
              child: Row(
                children: [
                  Press(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle, color: C.glass, border: Border.all(color: C.hair)),
                      child: const Icon(Icons.arrow_back_rounded, size: 19, color: C.tx2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('1 on 1', style: T.display(22)),
                  const Spacer(),
                  const NotificationBell(size: 34, iconSize: 17),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(r.gutter, 10, r.gutter, 0),
                child: person == null ? _empty() : _stack(person),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(r.gutter, 18, r.gutter, 14),
              child: person == null
                  ? const SizedBox(height: 76)
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _RoundAction(
                          icon: Icons.close_rounded,
                          bg: const Color(0x66000000),
                          border: C.hair2,
                          iconColor: Colors.white,
                          onTap: _skip,
                        ),
                        const SizedBox(width: 28),
                        _RoundAction(
                          icon: Icons.videocam_rounded,
                          bg: null,
                          gradient: C.gradSig,
                          iconColor: Colors.white,
                          size: 72,
                          glow: true,
                          busy: _ringingUid == person.uid,
                          onTap: () => _invite(person),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// The current card, with the next one peeking behind it — the same "there's
  /// more" cue Explore's stack of cards gives, just felt through depth instead
  /// of scroll.
  Widget _stack(_Person p) {
    final behind = _people.length > 1 ? _people[(_i + 1) % _people.length] : null;
    return Stack(
      alignment: Alignment.center,
      children: [
        if (behind != null)
          Transform.scale(
            scale: 0.94,
            child: Transform.translate(
              offset: const Offset(0, 14),
              child: Opacity(opacity: 0.5, child: _Card(person: behind)),
            ),
          ),
        AnimatedSwitcher(
          duration: M.base,
          switchInCurve: M.ease,
          switchOutCurve: M.ease,
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(anim),
              child: child,
            ),
          ),
          child: _Card(key: ValueKey(p.uid), person: p, ringing: _ringingUid == p.uid),
        ),
      ],
    );
  }

  Widget _empty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('👀', style: TextStyle(fontSize: 42)),
            const SizedBox(height: 16),
            Text(
              _loaded ? 'Nobody free to browse this second' : 'Looking around…',
              style: T.h3.copyWith(fontSize: 19),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              _loaded
                  ? 'Everyone’s either offline or already in a room — check back in a bit.'
                  : 'One second.',
              textAlign: TextAlign.center,
              style: T.body.copyWith(fontSize: 14.5, height: 1.45),
            ),
            if (_loaded) ...[
              const SizedBox(height: 22),
              Cta(label: 'Refresh', onTap: _refresh),
            ],
          ],
        ),
      ),
    );
  }
}

/// One full-bleed face. Deliberately not the whole profile — a decision
/// point, not a dossier, same philosophy as Explore's tap-through sheet.
class _Card extends StatelessWidget {
  const _Card({super.key, required this.person, this.ringing = false});
  final _Person person;
  final bool ringing;

  Color get _tint {
    final safe = ((person.hue % 360) + 360) % 360;
    return Color.lerp(C.purpleDeep, HSLColor.fromAHSL(1.0, safe, 0.55, 0.45).toColor(), 0.45)!;
  }

  @override
  Widget build(BuildContext context) {
    final flag = flagEmoji(person.country);
    final id = person.thumbId;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: C.char2,
        borderRadius: BorderRadius.circular(R.card),
        boxShadow: [BoxShadow(color: _tint.withOpacity(0.22), blurRadius: 26, spreadRadius: -10)],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (id != null && Api.ready)
            Image.network(
              Api.mediaUrl(id),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _Placeholder(name: person.name, tint: _tint),
              loadingBuilder: (context, child, progress) =>
                  progress == null ? child : _Placeholder(name: person.name, tint: _tint),
            )
          else
            _Placeholder(name: person.name, tint: _tint),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x22000000), Color(0x00000000), Color(0xE6000000)],
                stops: [0.0, 0.42, 1.0],
              ),
            ),
          ),
          Positioned(
            left: 9, top: 9,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(color: const Color(0x8C000000), borderRadius: BorderRadius.circular(R.chip)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const SizedBox(
                  width: 6, height: 6,
                  child: DecoratedBox(
                      decoration: BoxDecoration(color: C.acid, shape: BoxShape.circle, boxShadow: [BoxShadow(color: C.acidGlow, blurRadius: 5)])),
                ),
                const SizedBox(width: 6),
                Text('live', style: T.tiny.copyWith(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
          Positioned(
            left: 16, right: 16, bottom: 22,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(person.age == null ? person.name : '${person.name}, ${person.age}',
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: T.display(28)),
                    ),
                    if (flag.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(flag, style: const TextStyle(fontSize: 20, fontFamily: 'Apple Color Emoji')),
                    ],
                  ],
                ),
                if (person.shared.isNotEmpty || person.title != null) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: [
                      for (final s in person.shared)
                        _tag('both like $s', accent: true),
                      if (person.shared.isEmpty && person.title != null) _tag(person.title!),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (ringing)
            Positioned.fill(
              child: DecoratedBox(
                decoration: const BoxDecoration(color: Color(0x99000000)),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 30, height: 30,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      ),
                      const SizedBox(height: 14),
                      Text('ringing @${person.name}…',
                          style: T.body.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tag(String label, {bool accent = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(color: const Color(0x33FFFFFF), borderRadius: BorderRadius.circular(R.chip)),
        child: Text(label,
            style: T.tiny.copyWith(color: accent ? C.acid : Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
      );
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.name, required this.tint});
  final String name;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final t = name.trim();
    final letter = t.isEmpty ? '?' : String.fromCharCode(t.runes.first).toUpperCase();
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [tint.withOpacity(0.85), C.char2]),
      ),
      child: Center(
        child: Text(letter, style: T.display(72).copyWith(color: Colors.white.withOpacity(0.16))),
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.iconColor,
    this.bg,
    this.gradient,
    this.border,
    this.size = 60,
    this.glow = false,
    this.busy = false,
    required this.onTap,
  });
  final IconData icon;
  final Color iconColor;
  final Color? bg;
  final Gradient? gradient;
  final Color? border;
  final double size;
  final bool glow;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Press(
      onTap: busy ? () {} : onTap,
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: bg,
          gradient: gradient,
          border: border != null ? Border.all(color: border!, width: 1) : null,
          boxShadow: glow ? C.glowSig(blur: 20, spread: -4) : null,
        ),
        child: busy
            ? const Padding(
                padding: EdgeInsets.all(18),
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
              )
            : Icon(icon, size: size * 0.42, color: iconColor),
      ),
    );
  }
}

class _Person {
  _Person({
    required this.uid,
    required this.name,
    required this.hue,
    this.thumbId,
    this.title,
    this.country,
    this.age,
    this.shared = const [],
    this.busy = false,
    this.online = true,
  });

  factory _Person.fromMap(Map<String, dynamic> m) => _Person(
        uid: (m['uid'] as String?) ?? '',
        name: (m['name'] as String?) ?? 'someone',
        hue: ((m['hue'] as num?) ?? 210).toDouble(),
        thumbId: (m['thumbId'] as num?)?.toInt(),
        title: m['title'] as String?,
        country: m['country'] as String?,
        age: (m['age'] as num?)?.toInt(),
        shared: ((m['shared'] as List?) ?? const []).whereType<String>().toList(),
        busy: m['busy'] == true,
        online: m['online'] != false,
      );

  final String uid;
  final String name;
  final double hue;
  final int? thumbId;
  final String? title;
  final String? country;
  final int? age;
  final List<String> shared;
  final bool busy;
  final bool online;
}
