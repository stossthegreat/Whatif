import 'package:flutter/material.dart';
import '../core/haptics.dart';
import '../state/chat.dart';
import '../state/social.dart';
import '../theme/tokens.dart';
import '../widgets/avatar.dart';
import '../widgets/glass.dart';
import 'chat_screen.dart';
import 'friend_profile_screen.dart';

/// Everything that needs your attention, one screen: friend requests,
/// unread messages, recent friend activity. Every row routes exactly where
/// tapping it anywhere else in the app would — the profile, the thread, the
/// room — because it reuses the same static push() the rest of the app uses.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  static void push(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.black,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: Listenable.merge([SocialState.instance, ChatStore.instance]),
          builder: (context, _) {
            final social = SocialState.instance;
            final chats = ChatStore.instance;
            final requests = social.reqsIn;
            final unreadChats = chats.chats.where((c) => c.unread > 0).toList();
            final activity = social.feed;
            final empty = requests.isEmpty && unreadChats.isEmpty && activity.isEmpty;

            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      children: [
                        Press(
                          onTap: () => Navigator.of(context).maybePop(),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle, color: C.glass, border: Border.all(color: C.hair)),
                            child: const Icon(Icons.arrow_back_rounded, size: 20, color: C.tx2),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Text('Notifications', style: T.big.copyWith(fontSize: 24)),
                      ],
                    ),
                  ),
                ),
                if (empty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🔔', style: TextStyle(fontSize: 44)),
                            const SizedBox(height: 14),
                            Text('You’re all caught up', style: T.body.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            Text('Friend requests, messages and room invites land here',
                                textAlign: TextAlign.center, style: T.tiny.copyWith(color: C.tx3)),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (requests.isNotEmpty) ...[
                  _section('FRIEND REQUESTS'),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList.builder(
                      itemCount: requests.length,
                      itemBuilder: (context, i) => _RequestRow(friend: requests[i]),
                    ),
                  ),
                ],
                if (unreadChats.isNotEmpty) ...[
                  _section('MESSAGES'),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList.builder(
                      itemCount: unreadChats.length,
                      itemBuilder: (context, i) => _MessageRow(chat: unreadChats[i]),
                    ),
                  ),
                ],
                if (activity.isNotEmpty) ...[
                  _section('RECENT ACTIVITY'),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    sliver: SliverList.builder(
                      itemCount: activity.length,
                      itemBuilder: (context, i) => _ActivityRow(item: activity[i]),
                    ),
                  ),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 30)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _section(String label) => SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
        sliver: SliverToBoxAdapter(
          child: Text(label, style: T.eyebrow.copyWith(letterSpacing: 2, fontSize: 11)),
        ),
      );
}

/// The shared card shell every notification row sits inside — real depth
/// (gradient, not a flat tint), a specular top hairline (the same trick
/// Glass uses, without BackdropFilter's per-row GPU cost in a long scroll),
/// a soft lift shadow, and a coloured accent bar that says what kind of
/// thing this is before you've even read it.
class _NotifCard extends StatelessWidget {
  const _NotifCard({required this.accent, required this.onTap, required this.child, this.glow = false});
  final Color accent;
  final VoidCallback onTap;
  final Widget child;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Press(
        haptic: false,
        scale: 0.98,
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(R.card),
            boxShadow: [
              const BoxShadow(color: Color(0x66000000), blurRadius: 18, offset: Offset(0, 8)),
              if (glow) BoxShadow(color: accent.withOpacity(0.35), blurRadius: 26, spreadRadius: -14),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(R.card),
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [accent.withOpacity(0.16), C.char2.withOpacity(0.55)],
                    ),
                    border: Border.all(color: C.hair2),
                  ),
                  padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
                  child: Row(
                    children: [
                      Container(
                        width: 3,
                        height: 40,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: const BorderRadius.all(Radius.circular(100)),
                          boxShadow: [BoxShadow(color: accent.withOpacity(0.7), blurRadius: 8, spreadRadius: -1)],
                        ),
                      ),
                      Expanded(child: child),
                    ],
                  ),
                ),
                // specular hairline — Glass's gloss trick, no blur needed
                Positioned(
                  top: 0,
                  left: R.card * 0.5,
                  right: R.card * 0.5,
                  child: Container(
                    height: 1,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [Color(0x00FFFFFF), C.spec, Color(0x00FFFFFF)]),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RequestRow extends StatelessWidget {
  const _RequestRow({required this.friend});
  final FriendInfo friend;

  @override
  Widget build(BuildContext context) {
    return _NotifCard(
      accent: C.sig,
      glow: true,
      onTap: () {
        Buzz.tick();
        FriendProfileScreen.push(context, uid: friend.uid, name: friend.name, hue: friend.hue);
      },
      child: Row(
        children: [
          Avatar(hue: friend.hue, photoId: friend.photoId, size: 48, ring: C.sig),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('@${friend.name}', style: T.body.copyWith(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15.5)),
                const SizedBox(height: 3),
                Row(children: [
                  const Icon(Icons.person_add_alt_1_rounded, size: 12, color: C.sig),
                  const SizedBox(width: 4),
                  Text('wants to be friends', style: T.tiny.copyWith(color: C.sig, fontSize: 12.5, fontWeight: FontWeight.w700)),
                ]),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Press(
            onTap: () { Buzz.commit(); SocialState.instance.decline(friend.uid); },
            child: Container(
              width: 36, height: 36,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x33FF3B5C)),
              child: const Icon(Icons.close_rounded, size: 18, color: C.live),
            ),
          ),
          const SizedBox(width: 8),
          Press(
            onTap: () { Buzz.commit(); SocialState.instance.accept(friend.uid); },
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: C.gradSig,
                boxShadow: C.glowSig(blur: 14, spread: -5),
              ),
              child: const Icon(Icons.check_rounded, size: 19, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageRow extends StatelessWidget {
  const _MessageRow({required this.chat});
  final ChatSummary chat;

  @override
  Widget build(BuildContext context) {
    return _NotifCard(
      accent: C.acid,
      onTap: () {
        Buzz.tick();
        ChatScreen.push(context, uid: chat.uid, name: chat.name, hue: chat.hue);
      },
      child: Row(
        children: [
          Avatar(hue: chat.hue, photoId: chat.photoId, size: 48, live: chat.online),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('@${chat.name}', style: T.body.copyWith(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15.5)),
                const SizedBox(height: 3),
                Text(chat.preview, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: T.tiny.copyWith(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: C.acid,
              borderRadius: const BorderRadius.all(Radius.circular(100)),
              boxShadow: [BoxShadow(color: C.acidGlow, blurRadius: 10, spreadRadius: -2)],
            ),
            child: Text('${chat.unread}',
                style: const TextStyle(fontSize: 11.5, color: Colors.black, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.item});
  final FeedItem item;

  String get _line => switch (item.kind) {
        'badge' => 'earned ${item.x}',
        'title' => 'is now wearing "${item.x}"',
        'party' => 'is hosting a room — join with ${item.x}',
        _ => item.x,
      };

  IconData get _icon => switch (item.kind) {
        'badge' => Icons.emoji_events_rounded,
        'title' => Icons.style_rounded,
        'party' => Icons.meeting_room_rounded,
        _ => Icons.notifications_rounded,
      };

  @override
  Widget build(BuildContext context) {
    // real hue if they're a friend; a steady default otherwise — feed items
    // don't carry one, and this is decoration, not identity
    final known = SocialState.instance.friends.where((f) => f.uid == item.uid);
    final hue = known.isEmpty ? 210.0 : known.first.hue;
    final photoId = known.isEmpty ? null : known.first.photoId;

    return _NotifCard(
      accent: C.blue,
      onTap: () {
        Buzz.tick();
        FriendProfileScreen.push(context, uid: item.uid, name: item.name, hue: hue);
      },
      child: Row(
        children: [
          Avatar(hue: hue, photoId: photoId, size: 38),
          const SizedBox(width: 12),
          Icon(_icon, size: 14, color: C.tx3),
          const SizedBox(width: 6),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: '@${item.name} ', style: T.tiny.copyWith(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                TextSpan(text: _line, style: T.tiny.copyWith(color: C.tx3, fontSize: 13)),
              ]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
