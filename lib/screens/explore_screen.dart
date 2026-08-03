import 'dart:async';
import 'package:flutter/material.dart';
import '../core/analytics.dart';
import '../core/haptics.dart';
import '../net/network_client.dart';
import '../theme/tokens.dart';
import '../widgets/avatar.dart';
import '../widgets/glass.dart';
import '../widgets/person_card.dart';

/// EXPLORE — who's on right now, best matches first.
///
/// This is the surface that stops the app being empty when the queue is: even
/// with nobody to match, there are faces, and every one of them is a door.
/// Tapping opens a preview with "Meet now", which RINGS them — nobody gets
/// pulled on camera without agreeing.
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key, required this.onPlay});

  /// Falls through to the play flow from the empty state.
  final ValueChanged<String> onPlay;

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  StreamSubscription<Map<String, dynamic>>? _sub;
  Timer? _poll;
  List<_Person> _people = const [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    Track.screen('explore');
    _sub = NetworkClient.instance.events.listen(_onNet);
    _refresh();
    // a quiet refresh keeps the grid honest about who's actually free —
    // 10s is nowhere near the 40-messages-per-5s budget
    _poll = Timer.periodic(const Duration(seconds: 10), (_) => _refresh());
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
    if (m['t'] == 'explore') {
      setState(() {
        _loaded = true;
        _people = ((m['people'] as List?) ?? const [])
            .whereType<Map>()
            .map((p) => _Person.fromMap(p.cast<String, dynamic>()))
            .toList();
      });
    }
  }

  void _open(_Person p) {
    Buzz.tick();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MeetSheet(person: p),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    return Scaffold(
      backgroundColor: C.black,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(r.gutter, 8, r.gutter, 2),
              child: Row(
                children: [
                  Text('EXPLORE', style: T.display(30)),
                  const Spacer(),
                  if (_people.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: C.glass,
                        borderRadius: BorderRadius.circular(R.chip),
                        border: Border.all(color: C.hair),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6, height: 6,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: C.acid,
                              boxShadow: [BoxShadow(color: C.acidGlow, blurRadius: 6)],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text('${_people.length} ON NOW',
                              style: T.tiny.copyWith(
                                  color: Colors.white, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(r.gutter, 0, r.gutter, 12),
              child: Text('Tap anyone to say hello — they choose to accept.',
                  style: T.sub.copyWith(fontSize: 13.5)),
            ),
            Expanded(
              child: RefreshIndicator(
                color: C.sig,
                backgroundColor: C.char2,
                onRefresh: () async {
                  _refresh();
                  await Future<void>.delayed(const Duration(milliseconds: 600));
                },
                child: _people.isEmpty
                    ? _empty(context)
                    : LayoutBuilder(
                        builder: (context, box) {
                          // staggered editorial columns — the right lane runs
                          // 26px lower, so the wall reads like a poster board,
                          // not a uniform grid. Capped at 40 thumbnails, so
                          // two plain Columns beat grid virtualization.
                          final fullW = box.maxWidth - r.gutter * 2;
                          final colW = (fullW - 12) / 2;
                          final cardH = colW / 0.62;
                          Widget card(int i) {
                            final p = _people[i];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0, end: 1),
                                duration: Duration(milliseconds: 380 + (i % 8) * 45),
                                curve: Curves.easeOutCubic,
                                builder: (context, v, child) => Opacity(
                                  opacity: v,
                                  child: Transform.translate(
                                      offset: Offset(0, 18 * (1 - v)), child: child),
                                ),
                                child: SizedBox(
                                  height: cardH,
                                  child: PersonCard(
                                    name: p.name,
                                    hue: p.hue,
                                    thumbId: p.thumbId,
                                    title: p.title,
                                    shared: p.shared,
                                    busy: p.busy,
                                    online: p.online,
                                    country: p.country,
                                    age: p.age,
                                    onHi: () => _open(p),
                                    onTap: () => _open(p),
                                  ),
                                ),
                              ),
                            );
                          }
                          // person[0] is the server's best match for YOU —
                          // it gets the full-width billboard; the poster
                          // board starts from person[1]
                          final top = _people.first;
                          return ListView(
                            padding: EdgeInsets.fromLTRB(r.gutter, 2, r.gutter, 24),
                            physics: const AlwaysScrollableScrollPhysics(
                                parent: BouncingScrollPhysics()),
                            children: [
                              SizedBox(
                                height: fullW * 0.72,
                                child: PersonCard(
                                  name: top.name,
                                  hue: top.hue,
                                  thumbId: top.thumbId,
                                  title: top.title,
                                  shared: top.shared,
                                  busy: top.busy,
                                  online: top.online,
                                  country: top.country,
                                  age: top.age,
                                  hero: true,
                                  onHi: () => _open(top),
                                  onTap: () => _open(top),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      children: [
                                        for (var i = 1; i < _people.length; i += 2) card(i),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      children: [
                                        const SizedBox(height: 26),
                                        for (var i = 2; i < _people.length; i += 2) card(i),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Never a dead end — the empty state pushes straight back into the loop.
  Widget _empty(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      children: [
        const SizedBox(height: 90),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 44),
            child: Column(
              children: [
                const Text('👀', style: TextStyle(fontSize: 42)),
                const SizedBox(height: 16),
                Text(
                  _loaded ? 'Quiet right now.' : 'Looking around…',
                  style: T.h3.copyWith(fontSize: 19),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  _loaded
                      ? 'Nobody free to browse this second — press play and we’ll '
                          'find you someone the moment they land.'
                      : 'One second.',
                  textAlign: TextAlign.center,
                  style: T.body.copyWith(fontSize: 14.5, height: 1.45),
                ),
                if (_loaded) ...[
                  const SizedBox(height: 22),
                  Cta(label: 'Start a room', onTap: () => widget.onPlay('hang')),
                ],
              ],
            ),
          ),
        ),
      ],
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
        // absent-tolerant: today's server doesn't send age; the card simply
        // omits it until one does
        age: (m['age'] as num?)?.toInt(),
        shared: ((m['shared'] as List?) ?? const []).whereType<String>().toList(),
        busy: m['busy'] == true,
        // absent-tolerant: an older server that only sends online people
        // simply never marks anyone away
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

/// The tap-through: a light preview and one button. Deliberately not the full
/// profile — this is a decision point, not a dossier.
class _MeetSheet extends StatefulWidget {
  const _MeetSheet({required this.person});
  final _Person person;

  @override
  State<_MeetSheet> createState() => _MeetSheetState();
}

class _MeetSheetState extends State<_MeetSheet> {
  bool _sent = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.person;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Glass(
        radius: 26,
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Avatar(hue: p.hue, photoId: p.thumbId, size: 62, ring: C.sig),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('@${p.name}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: T.h3.copyWith(fontSize: 19)),
                      if (p.title != null) ...[
                        const SizedBox(height: 3),
                        Text(p.title!, style: T.tiny.copyWith(color: C.sig, fontWeight: FontWeight.w800)),
                      ],
                      if (p.country != null && p.country!.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(p.country!, style: T.tiny),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (p.shared.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('YOU BOTH LIKE', style: T.eyebrow),
              const SizedBox(height: 9),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in p.shared)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: C.sig.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(color: C.sig.withOpacity(0.5)),
                      ),
                      child: Text(s,
                          style: T.tiny.copyWith(
                              color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5)),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 22),
            if (!p.online)
              // away people can't be rung — but they CAN become friends, and
              // then you catch them live later. Never a dead end.
              Cta(
                label: _sent ? 'Request sent ✓' : 'Add friend',
                onTap: _sent
                    ? null
                    : () {
                        Track.event('explore_add');
                        Buzz.commit();
                        NetworkClient.instance.friendRequest(p.uid);
                        setState(() => _sent = true);
                      },
              )
            else if (p.busy)
              Text('They’re in a room right now — try again in a minute.',
                  textAlign: TextAlign.center, style: T.sub.copyWith(fontSize: 13.5))
            else
              Cta(
                label: _sent ? 'Asked — waiting for them…' : 'Meet now',
                onTap: _sent
                    ? null
                    : () {
                        Track.event('explore_meet');
                        NetworkClient.instance.meetInvite(p.uid);
                        setState(() => _sent = true);
                      },
              ),
            const SizedBox(height: 12),
            Text(
              !p.online
                  ? (_sent
                      ? 'When they accept, they’ll be in your people.'
                      : 'They’re away — add them and catch them live later.')
                  : _sent
                      ? 'We’ll drop you both into a room the moment they say yes.'
                      : 'They get a ring and choose whether to accept.',
              textAlign: TextAlign.center,
              style: T.tiny.copyWith(fontSize: 12, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
