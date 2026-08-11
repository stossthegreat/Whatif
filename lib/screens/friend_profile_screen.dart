import 'dart:async';
import 'package:flutter/material.dart';
import '../core/haptics.dart';
import '../net/network_client.dart';
import '../state/chat.dart';
import '../state/session.dart';
import '../state/social.dart';
import '../theme/tokens.dart';
import '../widgets/avatar.dart';
import '../widgets/glass.dart';
import 'chat_screen.dart';

/// Someone's full identity — photo, titles, traits the room voted, the
/// record, badges, mutuals. Opens from anywhere you can see a person.
/// The feeling on open should be: "this person has history."
class FriendProfileScreen extends StatefulWidget {
  const FriendProfileScreen({super.key, required this.uid, required this.name, required this.hue});
  final String uid;
  final String name;
  final double hue;

  static void push(BuildContext context,
      {required String uid, required String name, required double hue}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => FriendProfileScreen(uid: uid, name: name, hue: hue),
    ));
  }

  @override
  State<FriendProfileScreen> createState() => _FriendProfileScreenState();
}

class _FriendProfileScreenState extends State<FriendProfileScreen> {
  Map<String, dynamic>? _card;
  StreamSubscription<Map<String, dynamic>>? _sub;

  static const _traitMeta = {
    'funny': '😂 Funny', 'smart': '🧠 Smart', 'chill': '😎 Chill',
    'chaotic': '🌀 Chaotic', 'flirty': '😏 Flirty', 'confident': '💪 Confident',
    'competitive': '🏆 Competitive', 'listener': '👂 Good listener',
  };

  @override
  void initState() {
    super.initState();
    _sub = NetworkClient.instance.events.listen((m) {
      if (m['t'] == 'profileCard' && m['uid'] == widget.uid && mounted) {
        setState(() => _card = m);
      } else if ((m['t'] == 'faceFresh' || m['t'] == 'profileFresh') &&
          m['uid'] == widget.uid && mounted) {
        // their photo changed while we're looking at them — re-pull the
        // card instead of showing the old face until reopen
        NetworkClient.instance.profile(widget.uid);
      }
    });
    NetworkClient.instance.profile(widget.uid);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _card;
    final photoId = (c?['photoId'] as num?)?.toInt();
    final title = c?['title'] as String?;
    final friendState = (c?['friendState'] as String?) ?? 'none';
    final canVote = c?['canVote'] == true;
    final stats = ((c?['stats'] as Map?) ?? const {}).cast<String, dynamic>();
    final traits = ((c?['traits'] as Map?) ?? const {}).cast<String, dynamic>();
    final myVote = c?['myTraitVote'] as String?;
    final badges = ((c?['badges'] as List?) ?? const []).whereType<String>().toList();
    final mutuals = ((c?['mutuals'] as List?) ?? const []).whereType<Map>().toList();
    final bio = (c?['bio'] as String?) ?? '';
    final interests = ((c?['interests'] as List?) ?? const []).whereType<String>().toList();
    final metaLine = [
      if (c?['age'] != null) '${c!['age']}',
      if (c?['city'] is String && (c!['city'] as String).isNotEmpty) c['city'] as String,
      if (c?['country'] is String && (c!['country'] as String).isNotEmpty) c['country'] as String,
      if (c?['pronouns'] is String && (c!['pronouns'] as String).isNotEmpty) c['pronouns'] as String,
    ].join(' · ');

    return Scaffold(
      backgroundColor: C.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Row(
                children: [
                  Press(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle, color: C.glass, border: Border.all(color: C.hair)),
                      child: const Icon(Icons.arrow_back_rounded, size: 20, color: C.tx2),
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 30),
                children: [
                  Center(
                    child: Column(
                      children: [
                        // server truth over push-time params — the card
                        // carries live name/hue, the ctor values are frozen
                        // at whatever the pushing screen knew
                        Avatar(
                            hue: ((c?['hue'] as num?) ?? widget.hue).toDouble(),
                            photoId: photoId, size: 104, ring: C.sig),
                        const SizedBox(height: 14),
                        Text('@${(c?['name'] as String?) ?? widget.name}',
                            style: T.big.copyWith(fontSize: 26)),
                        if (title != null && title.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(color: C.sig.withOpacity(0.6)),
                            ),
                            child: Text(title,
                                style: T.tiny.copyWith(color: C.sig, fontWeight: FontWeight.w800)),
                          ),
                        ],
                        if (metaLine.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(metaLine, style: T.tiny.copyWith(color: C.tx2)),
                        ],
                        if (bio.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(bio,
                              textAlign: TextAlign.center,
                              style: T.body.copyWith(fontSize: 14.5, height: 1.45)),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // The same frosted pills the Explore cards use — one shape
                  // for "do something about this person", wherever you meet
                  // them. Four stacked gradient slabs read as an advert; this
                  // reads as a profile.
                  ..._actions(context, friendState),
                  const SizedBox(height: 26),
                  // personality — votes from people who actually met them
                  Text('PERSONALITY', style: T.eyebrow),
                  const SizedBox(height: 10),
                  if (traits.isEmpty && !canVote)
                    Text('No votes yet — people who meet them decide.', style: T.tiny)
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final e in _traitMeta.entries)
                          if ((traits[e.key] ?? 0) > 0 || canVote)
                            Press(
                              haptic: false,
                              onTap: canVote
                                  ? () {
                                      Buzz.tick();
                                      NetworkClient.instance.traitVote(widget.uid, e.key);
                                      Timer(const Duration(milliseconds: 400),
                                          () => NetworkClient.instance.profile(widget.uid));
                                    }
                                  : null,
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                decoration: BoxDecoration(
                                  color: myVote == e.key ? Colors.white : C.glass,
                                  borderRadius: BorderRadius.circular(100),
                                  border: Border.all(
                                      color: myVote == e.key ? Colors.white : C.hair2),
                                ),
                                child: Text(
                                  '${e.value}${(traits[e.key] ?? 0) > 0 ? ' · ${traits[e.key]}' : ''}',
                                  style: T.tiny.copyWith(
                                    color: myVote == e.key ? Colors.black : C.tx2,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                      ],
                    ),
                  if (interests.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text('INTO', style: T.eyebrow),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final i in interests)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(color: C.hair2),
                            ),
                            child: Text(i,
                                style: T.tiny.copyWith(color: C.tx2, fontWeight: FontWeight.w700)),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),
                  // the record
                  Text('THE RECORD', style: T.eyebrow),
                  const SizedBox(height: 10),
                  Glass(
                    radius: 22,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _statRow([
                          ('🔥', '${stats['streak'] ?? 0}', 'streak'),
                          ('🏆', '${stats['wins'] ?? 0}', 'rooms won'),
                          ('😂', '${stats['laughs'] ?? 0}', 'laughs'),
                        ]),
                        const SizedBox(height: 14),
                        _statRow([
                          ('🎤', '${stats['hours'] ?? 0}h', 'talked'),
                          ('🌎', '${stats['countries'] ?? 0}', 'countries'),
                          ('🎮', '${stats['games'] ?? 0}', 'games'),
                        ]),
                        const SizedBox(height: 14),
                        _statRow([
                          ('❤️', '${stats['friends'] ?? 0}', 'friends'),
                          ('👑', '${stats['legend'] ?? 0}', 'legend votes'),
                          ('⚡', '${stats['chaos'] ?? 0}', 'chaos'),
                        ]),
                      ],
                    ),
                  ),
                  if (badges.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text('BADGES', style: T.eyebrow),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final b in badges)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: C.glass,
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(color: C.hair),
                            ),
                            child: Text(b,
                                style: T.tiny.copyWith(
                                    color: Colors.white, fontWeight: FontWeight.w700)),
                          ),
                      ],
                    ),
                  ],
                  if (mutuals.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text('MUTUAL FRIENDS', style: T.eyebrow),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 74,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: mutuals.length,
                        separatorBuilder: (_, i) => const SizedBox(width: 14),
                        itemBuilder: (context, i) {
                          final mu = mutuals[i].cast<String, dynamic>();
                          return Column(
                            children: [
                              Avatar(
                                hue: ((mu['hue'] as num?) ?? 210).toDouble(),
                                photoId: (mu['photoId'] as num?)?.toInt(),
                                size: 46,
                              ),
                              const SizedBox(height: 5),
                              Text('@${mu['name'] ?? ''}',
                                  style: T.tiny.copyWith(fontSize: 10.5, color: C.tx2)),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                  // block/report — required reachable from any profile
                  const SizedBox(height: 26),
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // reporting a profile PHOTO is its own path: it carries
                        // the media id so a moderator can view and take it down
                        if (photoId != null) ...[
                          Press(
                            haptic: false,
                            onTap: () {
                              Buzz.tick();
                              NetworkClient.instance.reportPhoto(widget.uid, photoId);
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: C.char2,
                                content: Text('photo reported — a human reviews this',
                                    style: T.body.copyWith(color: Colors.white)),
                              ));
                            },
                            child: Text('Report photo',
                                style: T.tiny.copyWith(
                                    color: C.tx2, fontWeight: FontWeight.w700)),
                          ),
                          Text('   ·   ', style: T.tiny.copyWith(color: C.tx3)),
                        ],
                        Press(
                          haptic: false,
                          onTap: () {
                            Buzz.tick();
                            AppSession.instance.noteBlocked(widget.uid, widget.name);
                            NetworkClient.instance.block(widget.uid);
                            Navigator.of(context).maybePop();
                          },
                          child: Text('Block @${widget.name}',
                              style: T.tiny.copyWith(color: C.live, fontWeight: FontWeight.w700)),
                        ),
                      ],
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

  /// What you can do about this person, in the order you'd want it, and never
  /// an action the server would refuse. Strangers get one honest button;
  /// friends get the four that actually work.
  List<Widget> _actions(BuildContext context, String friendState) {
    void home() => Navigator.of(context).popUntil((r) => r.isFirst);

    if (friendState == 'pendingOut') {
      return const [ActionPill(label: 'Requested', muted: true, height: 46)];
    }
    if (friendState == 'pendingIn') {
      return [
        ActionPill(
          label: 'Accept friend request',
          icon: Icons.person_add_alt_1_rounded,
          live: true,
          height: 46,
          onTap: () {
            Buzz.commit();
            SocialState.instance.accept(widget.uid);
            NetworkClient.instance.profile(widget.uid);
          },
        ),
      ];
    }
    if (friendState != 'friends') {
      return [
        ActionPill(
          label: 'Add friend',
          icon: Icons.person_add_alt_1_rounded,
          live: true,
          height: 46,
          onTap: () {
            Buzz.commit();
            SocialState.instance.request(widget.uid);
            NetworkClient.instance.profile(widget.uid);
          },
        ),
      ];
    }
    return [
      Row(
        children: [
          Expanded(
            child: ActionPill(
              label: 'Message',
              icon: Icons.chat_bubble_rounded,
              height: 46,
              onTap: () {
                Buzz.commit();
                ChatScreen.push(context,
                    uid: widget.uid, name: widget.name, hue: widget.hue);
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ActionPill(
              label: 'Video',
              icon: Icons.videocam_rounded,
              live: true,
              height: 46,
              onTap: () { Buzz.commit(); home(); AppNav.startCall?.call(widget.uid, true); },
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: ActionPill(
              label: 'Voice',
              icon: Icons.call_rounded,
              height: 46,
              onTap: () { Buzz.commit(); home(); AppNav.startCall?.call(widget.uid, false); },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ActionPill(
              label: 'Invite to room',
              icon: Icons.group_rounded,
              height: 46,
              onTap: () { Buzz.commit(); home(); AppNav.hostPartyFor?.call(widget.uid); },
            ),
          ),
        ],
      ),
    ];
  }

  Widget _statRow(List<(String, String, String)> items) {
    return Row(
      children: [
        for (final (emoji, value, label) in items)
          Expanded(
            child: Column(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 4),
                Text(value,
                    style: T.h3.copyWith(
                        fontSize: 18,
                        fontFeatures: const [FontFeature.tabularFigures()])),
                Text(label, style: T.tiny.copyWith(fontSize: 10.5)),
              ],
            ),
          ),
      ],
    );
  }
}
