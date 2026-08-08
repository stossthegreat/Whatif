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

class _RequestRow extends StatelessWidget {
  const _RequestRow({required this.friend});
  final FriendInfo friend;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Press(
        haptic: false,
        onTap: () {
          Buzz.tick();
          FriendProfileScreen.push(context, uid: friend.uid, name: friend.name, hue: friend.hue);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(color: C.sig.withOpacity(0.06), borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              Avatar(hue: friend.hue, photoId: friend.photoId, size: 46),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('@${friend.name}', style: T.body.copyWith(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15.5)),
                    const SizedBox(height: 2),
                    Text('wants to be friends', style: T.tiny.copyWith(color: C.tx3, fontSize: 12.5)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Press(
                onTap: () { Buzz.commit(); SocialState.instance.decline(friend.uid); },
                child: Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0x33FF3B5C)),
                  child: const Icon(Icons.close_rounded, size: 17, color: C.live),
                ),
              ),
              const SizedBox(width: 8),
              Press(
                onTap: () { Buzz.commit(); SocialState.instance.accept(friend.uid); },
                child: Container(
                  width: 34, height: 34,
                  decoration: const BoxDecoration(shape: BoxShape.circle, gradient: C.gradSig),
                  child: const Icon(Icons.check_rounded, size: 18, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageRow extends StatelessWidget {
  const _MessageRow({required this.chat});
  final ChatSummary chat;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Press(
        haptic: false,
        onTap: () {
          Buzz.tick();
          ChatScreen.push(context, uid: chat.uid, name: chat.name, hue: chat.hue);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(color: C.sig.withOpacity(0.06), borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              Avatar(hue: chat.hue, photoId: chat.photoId, size: 46, live: chat.online),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('@${chat.name}', style: T.body.copyWith(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15.5)),
                    const SizedBox(height: 2),
                    Text(chat.preview, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: T.tiny.copyWith(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: const BoxDecoration(color: C.acid, borderRadius: BorderRadius.all(Radius.circular(100))),
                child: Text('${chat.unread}',
                    style: const TextStyle(fontSize: 11, color: Colors.black, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Press(
        haptic: false,
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
      ),
    );
  }
}
