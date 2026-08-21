import 'dart:async';
import 'package:flutter/material.dart';
import '../core/analytics.dart';
import '../core/haptics.dart';
import '../net/network_client.dart';
import '../state/social.dart';
import '../theme/tokens.dart';
import '../widgets/avatar.dart';
import '../widgets/glass.dart';
import '../widgets/notification_bell.dart';
import '../widgets/person_card.dart';
import 'chat_screen.dart';

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
    } else if (m['t'] == 'faceFresh' || m['t'] == 'profileFresh') {
      // someone's photo just changed — re-pull the grid now instead of
      // letting their old face sit here until the next 10s poll
      _refresh();
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
                  Text('Explore', style: T.display(32)),
                  const Spacer(),
                  // ONLY people actually on right now. Explore lists everyone,
                  // online or not, so counting the list was counting profiles
                  // — three cards became "3 ON NOW" whether or not a single
                  // one of them was awake.
                  if (_people.any((p) => p.online))
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
                          Text('${_people.where((p) => p.online).length} ON NOW',
                              style: T.tiny.copyWith(
                                  color: Colors.white, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  const SizedBox(width: 8),
                  const NotificationBell(size: 34, iconSize: 17),
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
                    : AnimatedBuilder(
                        // the card buttons read the friend graph, so they have
                        // to redraw the moment an add lands — otherwise "Add"
                        // sits there after you've already tapped it
                        animation: SocialState.instance,
                        builder: (context, _) => LayoutBuilder(
                          builder: (context, box) {
                            // one even grid, both lanes level and every card
                            // the same height. The old staggered columns
                            // offset one lane by 26px, which read as a
                            // mistake rather than as an editorial choice.
                            final fullW = box.maxWidth - r.gutter * 2;
                            final colW = (fullW - 12) / 2;
                            final cardH = colW / 0.70;
                            // person[0] is the server's best match for YOU and
                            // gets the billboard — but ONLY with a photo to
                            // put in it. A full-width card with no picture is
                            // just a big empty rectangle, which made the whole
                            // wall look broken.
                            final top = _people.first.thumbId != null
                                ? _people.first : null;
                            final rest =
                                (top == null ? _people : _people.skip(1)).toList();
                            return ListView(
                              padding: EdgeInsets.fromLTRB(r.gutter, 2, r.gutter, 24),
                              physics: const AlwaysScrollableScrollPhysics(
                                  parent: BouncingScrollPhysics()),
                              children: [
                                if (top != null) ...[
                                  SizedBox(
                                    height: fullW * 0.78,
                                    child: _card(top, hero: true),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                for (var row = 0; row * 2 < rest.length; row++)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: SizedBox(
                                      height: cardH,
                                      child: Row(
                                        children: [
                                          Expanded(child: _fadeIn(row * 2, rest)),
                                          const SizedBox(width: 12),
                                          Expanded(child: _fadeIn(row * 2 + 1, rest)),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// An odd tail leaves one empty half — a gap, never a stretched card.
  Widget _fadeIn(int i, List<_Person> list) {
    if (i >= list.length) return const SizedBox.shrink();
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 380 + (i % 8) * 45),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 18 * (1 - v)), child: child),
      ),
      child: _card(list[i]),
    );
  }

  /// The card's own state comes from the friend graph, and so does what its
  /// button does — they're read in the same breath so a button can never
  /// promise something the server would refuse.
  Widget _card(_Person p, {bool hero = false}) {
    final s = SocialState.instance;
    final friend = s.isFriend(p.uid);
    final asked = s.requested(p.uid);
    return PersonCard(
      name: p.name,
      hue: p.hue,
      thumbId: p.thumbId,
      photoId: p.photoId,
      title: p.title,
      shared: p.shared,
      busy: p.busy,
      online: p.online,
      country: p.country,
      age: p.age,
      hero: hero,
      isFriend: friend,
      requested: asked,
      onAdd: () => _add(p),
      onHi: () => _open(p),
      // shown to everyone, so tapping it always says something. The server
      // refuses DMs between strangers, so for anyone not yet connected this
      // explains the rule instead of opening a thread that can't send.
      onMessage: () {
        Buzz.tick();
        if (friend) {
          ChatScreen.push(context, uid: p.uid, name: p.name, hue: p.hue);
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: C.char2,
          content: Text(
            asked
                ? 'Waiting on @${p.name} — you can message once they follow back'
                : 'Follow @${p.name} first — messaging opens when you both follow',
            style: T.body.copyWith(color: Colors.white),
          ),
        ));
      },
      onTap: () => _open(p),
    );
  }

  /// Add straight from the card — no sheet, no second tap. The button flips
  /// to "Requested" because SocialState records the outgoing request.
  void _add(_Person p) {
    Track.event('explore_add');
    Buzz.commit();
    NetworkClient.instance.friendRequest(p.uid);
    SocialState.instance.noteRequested(p.uid);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: C.char2,
      content: Text('Asked @${p.name} to be friends',
          style: T.body.copyWith(color: Colors.white)),
    ));
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
    this.photoId,
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
        photoId: (m['photoId'] as num?)?.toInt(),
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
  final int? photoId;
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
    final social = SocialState.instance;
    final friend = social.isFriend(p.uid);
    final asked = !friend && social.requested(p.uid);
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
            // Already friends — offering "Add friend" again was the sheet
            // ignoring the friend graph the card behind it was reading from.
            if (friend)
              Cta(
                label: 'Message',
                onTap: () {
                  Buzz.tick();
                  Navigator.of(context).maybePop();
                  ChatScreen.push(context, uid: p.uid, name: p.name, hue: p.hue);
                },
              )
            else if (asked)
              Cta(label: 'Requested ✓', onTap: null)
            else if (!p.online)
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
                        SocialState.instance.noteRequested(p.uid);
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
              friend
                  ? (p.online
                      ? 'You’re already friends — they’re on right now.'
                      : 'You’re already friends. They’ll show up when they’re on.')
                  : asked
                      ? 'Request sent — it’s waiting for them.'
                      : !p.online
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
