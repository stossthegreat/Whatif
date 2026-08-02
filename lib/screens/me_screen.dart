import 'package:flutter/material.dart';
import '../core/haptics.dart';
import '../state/session.dart';
import '../state/social.dart';
import '../theme/tokens.dart';
import '../widgets/glass.dart';
import '../widgets/identity_orb.dart';
import 'edit_profile_screen.dart';
import 'moments_screen.dart';
import 'settings_screen.dart';
import 'friends_screen.dart';
import '../widgets/avatar.dart';

/// YOU — one page, everything. Your glow, your rank, the badges rooms voted
/// you, the stats, your people (sparks), your moments. Not six screens; one
/// scrolling identity. This page is where the "maybe find the one" thread
/// quietly lives.
class MeScreen extends StatelessWidget {
  const MeScreen({super.key, this.embedded = false, this.onSignOut});

  /// When shown as a bottom-nav tab there's nothing to pop.
  final bool embedded;
  final VoidCallback? onSignOut;

  static void push(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MeScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.black,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: AppSession.instance,
          builder: (context, _) {
            final s = AppSession.instance;
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 30),
              children: [
                // header row
                Row(
                  children: [
                    if (embedded)
                      Text('you', style: T.big.copyWith(fontSize: 26))
                    else
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
                    // your people — always one tap away (requests badge included)
                    AnimatedBuilder(
                      animation: SocialState.instance,
                      builder: (context, _) {
                        final reqs = SocialState.instance.reqCount;
                        return Press(
                          onTap: () {
                            Buzz.tick();
                            FriendsScreen.push(context, tab: reqs > 0 ? 4 : 0);
                          },
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 38, height: 38,
                                decoration: BoxDecoration(
                                    shape: BoxShape.circle, color: C.glass, border: Border.all(color: C.hair)),
                                child: const Icon(Icons.group_rounded, size: 19, color: C.tx2),
                              ),
                              if (reqs > 0)
                                Positioned(
                                  right: -3, top: -3,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    constraints: const BoxConstraints(minWidth: 16),
                                    decoration: BoxDecoration(
                                        color: C.sig, borderRadius: BorderRadius.circular(100)),
                                    child: Text('$reqs',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                            fontSize: 10, color: Colors.white, fontWeight: FontWeight.w800)),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 10),
                    Press(
                      onTap: () {
                        Buzz.tick();
                        SettingsScreen.push(context, onSignOut ?? () {});
                      },
                      child: Container(
                        width: 38, height: 38,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle, color: C.glass, border: Border.all(color: C.hair)),
                        child: const Icon(Icons.settings_rounded, size: 19, color: C.tx2),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // identity
                Center(
                  child: Column(
                    children: [
                      Press(
                        haptic: false,
                        onTap: () { Buzz.tick(); EditProfileScreen.push(context); },
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Avatar(hue: s.myHue, photoId: s.photoId, size: 104, ring: C.sig),
                            Positioned(
                              right: -2, bottom: -2,
                              child: Container(
                                width: 30, height: 30,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  border: Border.all(color: C.black, width: 3),
                                ),
                                child: const Icon(Icons.edit_rounded, size: 13, color: Colors.black),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('@${s.myHandle}', style: T.big.copyWith(fontSize: 27)),
                      if (s.bio.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(s.bio,
                            textAlign: TextAlign.center,
                            style: T.tiny.copyWith(color: C.tx2, fontSize: 13)),
                      ],
                      const SizedBox(height: 9),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: C.glass,
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(color: C.hair2),
                        ),
                        child: Text(s.rankTitle,
                            style: T.body.copyWith(
                                fontSize: 14, color: Colors.white, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // badges — what rooms voted you
                _SectionHead(title: 'badges', trailing: 'the room decides'),
                const SizedBox(height: 10),
                if (s.badges.isEmpty)
                  Text('Win a room and the badges land here.', style: T.tiny)
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final e in s.badges.entries) _BadgeChip(label: e.key, count: e.value),
                    ],
                  ),
                const SizedBox(height: 24),

                // stats
                _SectionHead(title: 'the record'),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _Stat(emoji: '🔥', value: '${s.streak}', label: 'day streak')),
                  const SizedBox(width: 8),
                  Expanded(child: _Stat(emoji: '🎪', value: '${s.matchesPlayed}', label: 'rooms')),
                  const SizedBox(width: 8),
                  Expanded(child: _Stat(emoji: '😂', value: '${s.laughs}', label: 'laughs')),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _Stat(emoji: '🌀', value: '${s.chaosScore}', label: 'chaos score')),
                  const SizedBox(width: 8),
                  Expanded(child: _Stat(emoji: '🤥', value: '${s.lies}', label: 'lies caught')),
                  const SizedBox(width: 8),
                  Expanded(
                      child: AnimatedBuilder(
                          animation: SocialState.instance,
                          builder: (context, _) => _Stat(
                              emoji: '✨',
                              value: '${SocialState.instance.friends.length}',
                              label: 'friends'))),
                ]),
                const SizedBox(height: 24),

                // your people — the matched friendships (rating both ways)
                AnimatedBuilder(
                  animation: SocialState.instance,
                  builder: (context, _) {
                    final friends = SocialState.instance.friends;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionHead(
                          title: 'your people ✨',
                          trailing: 'see all',
                          onTrailing: () => FriendsScreen.push(context),
                        ),
                        const SizedBox(height: 10),
                        if (friends.isEmpty)
                          Text(
                              'Meet someone and tap 👥 in the room to add them — or both say “meet again”. They land here forever.',
                              style: T.tiny)
                        else
                          for (final f in friends.take(3)) _PersonRow(friend: f),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),

                // moments (BeReal-memories style — inside the profile)
                _SectionHead(
                  title: 'moments',
                  trailing: s.moments.isEmpty ? null : 'see all',
                  onTrailing: s.moments.isEmpty ? null : () => MomentsScreen.push(context),
                ),
                const SizedBox(height: 10),
                if (s.moments.isEmpty)
                  Text('Every big reveal becomes a card here, ready to share.', style: T.tiny)
                else
                  SizedBox(
                    height: 150,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: s.moments.length.clamp(0, 8),
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, i) {
                        final m = s.moments[i];
                        return Press(
                          onTap: () {
                            Buzz.tap();
                            ShareCardScreen.push(context, m);
                          },
                          child: _MomentMini(m),
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SectionHead extends StatelessWidget {
  const _SectionHead({required this.title, this.trailing, this.onTrailing});
  final String title;
  final String? trailing;
  final VoidCallback? onTrailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: T.h3.copyWith(fontSize: 17)),
        const Spacer(),
        if (trailing != null)
          Press(
            onTap: onTrailing ?? () {},
            child: Text(trailing!,
                style: T.tiny.copyWith(color: onTrailing == null ? C.tx3 : C.sig, fontWeight: FontWeight.w700)),
          ),
      ],
    );
  }
}

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({required this.label, required this.count});
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: C.glass,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: C.hair2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: T.tiny.copyWith(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5)),
          if (count > 1) ...[
            const SizedBox(width: 7),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(color: C.sig, borderRadius: BorderRadius.circular(100)),
              child: Text('x$count',
                  style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w900)),
            ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.emoji, required this.value, required this.label});
  final String emoji;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: C.glass,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: C.hair),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 6),
          Text(value, style: T.h3.copyWith(fontSize: 19)),
          const SizedBox(height: 2),
          Text(label, style: T.tiny.copyWith(fontSize: 10.5)),
        ],
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.friend});
  final FriendInfo friend;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: C.glass,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: C.sig.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            IdentityOrb(hue: friend.hue, size: 38, live: friend.online),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text('@${friend.name}',
                        style: T.body.copyWith(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                    const SizedBox(width: 6),
                    const Text('✨', style: TextStyle(fontSize: 12)),
                  ]),
                  Text(friend.online ? 'online now' : 'away', style: T.tiny),
                ],
              ),
            ),
            if (friend.online)
              Text('LIVE', style: T.tiny.copyWith(color: C.live, fontWeight: FontWeight.w900, letterSpacing: 1)),
          ],
        ),
      ),
    );
  }
}

class _MomentMini extends StatelessWidget {
  const _MomentMini(this.m);
  final Moment m;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 128,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color(0xFF17091F), Color(0xFF0A0B10)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: C.hair2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(m.game.toUpperCase(),
              style: T.eyebrow.copyWith(color: C.sig, fontSize: 8.5, letterSpacing: 1.4)),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              m.result,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: T.tiny.copyWith(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12, height: 1.25),
            ),
          ),
          const SizedBox(height: 6),
          Row(children: [
            Text('😂 ${m.laughs}', style: T.tiny.copyWith(fontSize: 10, color: C.tx2, fontWeight: FontWeight.w800)),
            const Spacer(),
            Text(m.ago, style: T.tiny.copyWith(fontSize: 10)),
          ]),
        ],
      ),
    );
  }
}
