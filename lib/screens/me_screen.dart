import 'package:flutter/material.dart';
import '../core/haptics.dart';
import '../state/session.dart';
import '../state/social.dart';
import '../theme/tokens.dart';
import '../widgets/glass.dart';
import '../widgets/identity_orb.dart';
import '../widgets/notification_bell.dart';
import '../state/chat.dart';
import 'chat_screen.dart' show AppNav;
import 'chats_screen.dart';
import 'friend_profile_screen.dart';
import 'edit_profile_screen.dart';
import 'likes_screen.dart';
import 'moments_screen.dart';
import 'settings_screen.dart';
import 'friends_screen.dart';
import '../widgets/avatar.dart';
import '../widgets/person_card.dart' show flagEmoji;

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
                    const NotificationBell(),
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

                // identity — the billboard, tinted YOUR hue. No two profiles
                // render the same color; this page is yours down to the light.
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color.lerp(
                                C.purpleDeep,
                                HSLColor.fromAHSL(
                                        1.0, ((s.myHue % 360) + 360) % 360, 0.55, 0.45)
                                    .toColor(),
                                0.4)!
                            .withOpacity(0.40),
                        C.char2.withOpacity(0.45),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(R.card),
                    border: Border.all(color: C.hair2),
                  ),
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
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text('@${s.myHandle}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: T.display(26)),
                          ),
                          if (s.age != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                              decoration: BoxDecoration(
                                color: C.glass2,
                                borderRadius: BorderRadius.circular(R.chip),
                                border: Border.all(color: C.hair2),
                              ),
                              child: Text('${s.age}',
                                  style: T.body.copyWith(
                                      fontSize: 13,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800)),
                            ),
                          ],
                        ],
                      ),
                      if (s.bio.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(s.bio,
                            textAlign: TextAlign.center,
                            style: T.tiny.copyWith(color: C.tx2, fontSize: 13)),
                      ],
                      const SizedBox(height: 10),
                      if (s.plus) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            gradient: C.gradSigHot,
                            borderRadius: BorderRadius.circular(R.chip),
                            boxShadow: C.glowSig(blur: 14, spread: -5),
                          ),
                          child: Text('Rivlr+',
                              style: T.display(13).copyWith(letterSpacing: 0.4)),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0x40000000),
                          borderRadius: BorderRadius.circular(R.chip),
                          border: Border.all(color: C.hair2),
                        ),
                        child: Text(s.rankTitle,
                            style: T.body.copyWith(
                                fontSize: 14, color: Colors.white, fontWeight: FontWeight.w800)),
                      ),
                      // who you are — country, languages, interests as chips
                      if (s.country.isNotEmpty ||
                          s.languages.isNotEmpty ||
                          s.interests.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 7,
                          runSpacing: 7,
                          alignment: WrapAlignment.center,
                          children: [
                            if (s.country.isNotEmpty)
                              _IdChip('${flagEmoji(s.country)} ${s.country}'.trim()),
                            for (final l in s.languages.take(3)) _IdChip(l),
                            for (final i in s.interests.take(4)) _IdChip(i),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // the two blocks — your rep, your moments
                SizedBox(
                  height: 112,
                  child: Row(
                    children: [
                      Expanded(
                        child: _RepBlock(
                            rank: s.rankTitle,
                            streak: s.streak,
                            rooms: s.matchesPlayed),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MomentsBlock(
                          count: s.moments.length,
                          onTap: s.moments.isEmpty
                              ? null
                              : () { Buzz.tick(); MomentsScreen.push(context); },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // who said yes to you — the strongest reason to open the app
                Press(
                  haptic: false,
                  onTap: () { Buzz.tick(); LikesScreen.push(context); },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                    decoration: BoxDecoration(
                      gradient: C.gradSig,
                      borderRadius: BorderRadius.circular(R.card),
                      boxShadow: C.glowSig(blur: 18, spread: -8),
                    ),
                    child: Row(
                      children: [
                        const Text('💜', style: TextStyle(fontSize: 20)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Who wants to meet you', style: T.display(17)),
                              const SizedBox(height: 2),
                              Text(
                                s.plus
                                    ? 'everyone who said yes to you'
                                    : 'see who said yes — with Rivlr+',
                                style: T.tiny.copyWith(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, size: 22, color: Colors.white),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // people you just met — the accidental-Next recovery
                const _RecentlyMetRailM(),
                // what your people are up to
                const _FeedSectionM(),
                // your people
                const _FriendsSectionM(),
                const SizedBox(height: 8),

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
                // Moments used to appear twice on this screen — the block
                // under your photo AND a strip down here. One profile, one
                // way in: the block above owns it.
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
        Text(title, style: T.display(15).copyWith(letterSpacing: 0.5)),
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
    // a trophy, not a grey pill
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: C.sig.withOpacity(0.16),
        borderRadius: BorderRadius.circular(R.chip),
        border: Border.all(color: C.sig.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: T.tiny.copyWith(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5)),
          if (count > 1) ...[
            const SizedBox(width: 7),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: const BoxDecoration(
                  color: C.acid, borderRadius: BorderRadius.all(Radius.circular(100))),
              child: Text('x$count',
                  style: const TextStyle(fontSize: 10, color: Colors.black, fontWeight: FontWeight.w900)),
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
          Text(value, style: T.display(21)),
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
            Avatar(hue: friend.hue, photoId: friend.photoId, size: 38, live: friend.online),
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

class _RecentlyMetRailM extends StatelessWidget {
  const _RecentlyMetRailM();

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
                        Avatar(hue: m.hue, photoId: m.photoId, size: 52),
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

class _FeedSectionM extends StatelessWidget {
  const _FeedSectionM();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([SocialState.instance, ChatStore.instance]),
      builder: (context, _) {
        final s = SocialState.instance;
        final unread = ChatStore.instance.unreadTotal;
        final rows = <Widget>[];

        for (final f in s.feed.take(5)) {
          final line = switch (f.kind) {
            'badge' => '🏅 @${f.name} earned ${f.x}',
            'title' => '👑 @${f.name} is now “${f.x}”',
            'party' => '🎮 @${f.name} opened a room',
            _ => '',
          };
          if (line.isEmpty) continue;
          rows.add(_row(context, line,
              trailing: f.kind == 'party' ? 'Join' : null,
              onTap: () {
                Buzz.tick();
                if (f.kind == 'party') {
                  AppNav.joinPartyCode?.call(f.x);
                  return;
                }
                final friend =
                    s.friends.where((x) => x.uid == f.uid).toList();
                if (friend.isNotEmpty) {
                  FriendProfileScreen.push(context,
                      uid: f.uid, name: f.name, hue: friend.first.hue);
                }
              }));
        }
        if (unread > 0) {
          rows.add(_row(context, '💬 $unread unread message${unread == 1 ? '' : 's'}',
              onTap: () { Buzz.tick(); ChatsScreen.push(context); }));
        }
        if (s.reqCount > 0) {
          rows.add(_row(context, '⭐ ${s.reqCount} friend request${s.reqCount == 1 ? '' : 's'}',
              onTap: () { Buzz.tick(); FriendsScreen.push(context, tab: 4); }));
        }
        if (rows.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('HAPPENING NOW', style: T.eyebrow),
            const SizedBox(height: 10),
            ...rows,
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _row(BuildContext context, String text, {String? trailing, VoidCallback? onTap}) {
    return Press(
      haptic: false,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Expanded(
              child: Text(text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: T.body.copyWith(
                      color: C.tx2, fontSize: 14, fontWeight: FontWeight.w600)),
            ),
            if (trailing != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(100)),
                child: Text(trailing,
                    style: T.tiny.copyWith(
                        color: Colors.black, fontWeight: FontWeight.w800, fontSize: 11)),
              )
            else
              const Icon(Icons.chevron_right_rounded, size: 16, color: C.tx3),
          ],
        ),
      ),
    );
  }
}

class _FriendsSectionM extends StatelessWidget {
  const _FriendsSectionM();

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
            for (final f in friends.take(4)) _FriendRowM(friend: f),
            const SizedBox(height: 6),
          ],
        );
      },
    );
  }
}

class _FriendRowM extends StatelessWidget {
  const _FriendRowM({required this.friend});
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
            Avatar(hue: friend.hue, photoId: friend.photoId, size: 36, live: friend.online),
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
                      color: friend.online ? C.acid : C.tx3,
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

// ---- identity chips + blocks ----------------------------------------------

/// One fact about you — country, a language, an interest.
class _IdChip extends StatelessWidget {
  const _IdChip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x33000000),
        borderRadius: BorderRadius.circular(R.chip),
        border: Border.all(color: C.hair2),
      ),
      child: Text(label,
          style: T.tiny.copyWith(
              color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

/// REP — the loud block: your rank in display caps on the signature gradient.
class _RepBlock extends StatelessWidget {
  const _RepBlock({required this.rank, required this.streak, required this.rooms});
  final String rank;
  final int streak;
  final int rooms;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: C.gradSig,
        borderRadius: BorderRadius.circular(R.card),
        boxShadow: C.glowSig(blur: 18, spread: -8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('REP', style: T.eyebrow.copyWith(color: Colors.white70)),
          const SizedBox(height: 5),
          Text(rank.toUpperCase(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: T.display(17)),
          const Spacer(),
          Text('🔥 $streak · 🎪 $rooms',
              style: T.tiny.copyWith(
                  color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
        ],
      ),
    );
  }
}

/// MOMENTS — the quiet block beside it; taps into the gallery when there is one.
class _MomentsBlock extends StatelessWidget {
  const _MomentsBlock({required this.count, this.onTap});
  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final body = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: C.char3,
        borderRadius: BorderRadius.circular(R.card),
        border: Border.all(color: C.hair2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('MOMENTS', style: T.eyebrow),
          const SizedBox(height: 5),
          Text(count == 0 ? '—' : '$count', style: T.display(24)),
          const Spacer(),
          Text(
            count == 0 ? 'big reveals land here' : 'tap to relive them ›',
            style: T.tiny.copyWith(
                color: count == 0 ? C.tx3 : C.sig,
                fontWeight: FontWeight.w700,
                fontSize: 11.5),
          ),
        ],
      ),
    );
    if (onTap == null) return body;
    return Press(haptic: false, onTap: onTap, child: body);
  }
}
