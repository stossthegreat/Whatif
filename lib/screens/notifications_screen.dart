import 'package:flutter/material.dart';
import '../core/haptics.dart';
import '../state/social.dart';
import '../theme/tokens.dart';
import '../widgets/avatar.dart';
import '../widgets/glass.dart';
import 'chat_screen.dart' show AppNav;
import 'friend_profile_screen.dart';

/// Notifications — the social ledger, TikTok-clean: friend requests, room
/// invites, friend activity. NO messages in here — messages live in the
/// Messages tab with their own badge; duplicating them here just makes two
/// screens claim the same unread.
///
/// The style rule for this screen: no cards, no colour blocks, no accent
/// bars. Rows on black, real faces, one bold name, one grey line, one clean
/// action. Whitespace does the separating — that's the app's own language.
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
          animation: SocialState.instance,
          builder: (context, _) {
            final s = SocialState.instance;
            final requests = s.reqsIn;
            final knock = s.knock;
            final activity = s.feed;
            final empty = requests.isEmpty && knock == null && activity.isEmpty;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
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
                if (empty)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🔔', style: TextStyle(fontSize: 40)),
                          const SizedBox(height: 14),
                          Text('All caught up',
                              style: T.body.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          Text('Friend requests and room invites land here',
                              style: T.tiny.copyWith(color: C.tx3)),
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 6, 20, 30),
                      children: [
                        if (knock != null) ...[
                          _label('ROOM INVITES'),
                          _KnockRow(knock: knock),
                        ],
                        if (requests.isNotEmpty) ...[
                          _label('REQUESTS'),
                          for (final f in requests) _RequestRow(friend: f),
                        ],
                        if (activity.isNotEmpty) ...[
                          _label('ACTIVITY'),
                          for (final a in activity) _ActivityRow(item: a),
                        ],
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 20, 0, 10),
        child: Text(text, style: T.eyebrow.copyWith(letterSpacing: 2.4, fontSize: 10.5)),
      );
}

/// A friend holding a room open for you — the one row that gets the app's
/// primary-action treatment, because it's live RIGHT NOW.
class _KnockRow extends StatelessWidget {
  const _KnockRow({required this.knock});
  final RoomKnock knock;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Avatar(hue: knock.hue, size: 46, live: true),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('@${knock.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: T.body.copyWith(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 2),
                Text('is holding a room open for you',
                    style: T.tiny.copyWith(color: C.tx3, fontSize: 12.5)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Press(
            onTap: () {
              Buzz.commit();
              final code = knock.code;
              SocialState.instance.clearKnock();
              // this screen is a pushed route — clear it first or the party
              // screen changes underneath and stays hidden (chat_screen's
              // invite bubbles use the exact same pattern)
              Navigator.of(context).popUntil((r) => r.isFirst);
              AppNav.joinPartyCode?.call(code);
            },
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: C.gradSig,
                borderRadius: BorderRadius.circular(R.chip),
              ),
              child: const Text('Join',
                  style: TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestRow extends StatelessWidget {
  const _RequestRow({required this.friend});
  final FriendInfo friend;

  @override
  Widget build(BuildContext context) {
    return Press(
      haptic: false,
      scale: 0.99,
      onTap: () {
        Buzz.tick();
        FriendProfileScreen.push(context, uid: friend.uid, name: friend.name, hue: friend.hue);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Avatar(hue: friend.hue, photoId: friend.photoId, size: 46),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('@${friend.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: T.body.copyWith(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text('wants to be friends', style: T.tiny.copyWith(color: C.tx3, fontSize: 12.5)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Press(
              onTap: () {
                Buzz.tick();
                SocialState.instance.decline(friend.uid);
              },
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                    shape: BoxShape.circle, color: C.glass, border: Border.all(color: C.hair)),
                child: const Icon(Icons.close_rounded, size: 16, color: C.tx2),
              ),
            ),
            const SizedBox(width: 8),
            Press(
              onTap: () {
                Buzz.commit();
                SocialState.instance.accept(friend.uid);
              },
              child: Container(
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: C.gradSig,
                  borderRadius: BorderRadius.circular(R.chip),
                ),
                child: const Text('Accept',
                    style: TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
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
        'title' => 'is now “${item.x}”',
        'party' => 'is hosting a room · tap to join',
        _ => item.x,
      };

  String get _ago {
    final d = DateTime.now().difference(item.at);
    if (d.inMinutes < 1) return 'now';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    return '${d.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    // real face if they're a friend; a steady default otherwise
    final known = SocialState.instance.friends.where((f) => f.uid == item.uid);
    final hue = known.isEmpty ? 210.0 : known.first.hue;
    final photoId = known.isEmpty ? null : known.first.photoId;
    final isParty = item.kind == 'party';

    return Press(
      haptic: false,
      scale: 0.99,
      onTap: () {
        Buzz.tick();
        if (isParty && item.x.isNotEmpty) {
          Navigator.of(context).popUntil((r) => r.isFirst);
          AppNav.joinPartyCode?.call(item.x);
        } else {
          FriendProfileScreen.push(context, uid: item.uid, name: item.name, hue: hue);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Avatar(hue: hue, photoId: photoId, size: 40, live: isParty),
            const SizedBox(width: 13),
            Expanded(
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(
                      text: '@${item.name} ',
                      style: T.tiny.copyWith(
                          color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13.5)),
                  TextSpan(text: _line, style: T.tiny.copyWith(color: C.tx3, fontSize: 13.5)),
                ]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 10),
            Text(_ago, style: T.tiny.copyWith(color: C.tx3, fontSize: 11.5)),
          ],
        ),
      ),
    );
  }
}
