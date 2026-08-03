import 'package:flutter/material.dart';
import '../core/haptics.dart';
import '../net/network_client.dart';
import '../state/chat.dart';
import '../state/social.dart';
import '../theme/tokens.dart';
import '../widgets/avatar.dart';
import '../widgets/glass.dart';
import '../widgets/identity_orb.dart';
import 'chat_screen.dart';

/// Messages — every conversation with your people. Pinned first, then by
/// recency. Only matched friends can appear here, so it's never spam.
class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key, this.embedded = false});

  /// As a bottom-nav tab there's nothing to pop, so the back button goes.
  final bool embedded;

  static void push(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChatsScreen()));
  }

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  @override
  void initState() {
    super.initState();
    NetworkClient.instance.chatsList();
    NetworkClient.instance.friendsSnapshot(); // the empty state offers friends
  }

  /// One friend, tappable — used by both the compose sheet and the
  /// no-conversations state so starting a chat is never more than two taps.
  Widget _friendRow(BuildContext context, FriendInfo f, {VoidCallback? before}) {
    return Press(
      haptic: false,
      onTap: () {
        Buzz.tick();
        before?.call();
        ChatScreen.push(context, uid: f.uid, name: f.name, hue: f.hue);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Avatar(hue: f.hue, photoId: f.photoId, size: 44, live: f.online),
            const SizedBox(width: 13),
            Expanded(
              child: Text('@${f.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: T.body.copyWith(
                      color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15.5)),
            ),
            const Icon(Icons.chevron_right_rounded, size: 20, color: C.tx3),
          ],
        ),
      ),
    );
  }

  void _composeSheet(BuildContext context) {
    final friends = SocialState.instance.friends;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(12),
        child: Glass(
          radius: 26,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('NEW MESSAGE', style: T.eyebrow),
              const SizedBox(height: 12),
              if (friends.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'No friends yet — meet someone in a room and tap 👥 to add them.',
                    style: T.body.copyWith(color: C.tx3, fontSize: 14, height: 1.4),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(ctx).size.height * 0.5),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final f in friends)
                        _friendRow(context, f, before: () => Navigator.pop(ctx)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _ago(DateTime? t) {
    if (t == null) return '';
    final d = DateTime.now().difference(t.toLocal());
    if (d.inMinutes < 1) return 'now';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    return '${d.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.black,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 6, 22, 12),
              child: Row(
                children: [
                  if (!widget.embedded) ...[
                    Press(
                      onTap: () => Navigator.of(context).maybePop(),
                      child: Container(
                        width: 38, height: 38,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle, color: C.glass, border: Border.all(color: C.hair)),
                        child: const Icon(Icons.arrow_back_rounded, size: 20, color: C.tx2),
                      ),
                    ),
                    const SizedBox(width: 14),
                  ],
                  Text('Messages', style: T.big.copyWith(fontSize: 26)),
                  const Spacer(),
                  // new message — pick any friend, start talking
                  Press(
                    onTap: () { Buzz.tick(); _composeSheet(context); },
                    child: Container(
                      width: 38, height: 38,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: C.sig),
                      child: const Icon(Icons.add_comment_rounded, size: 18, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: AnimatedBuilder(
                animation: Listenable.merge([ChatStore.instance, SocialState.instance]),
                builder: (context, _) {
                  final chats = ChatStore.instance.chats;
                  if (chats.isEmpty) {
                    // never a dead black screen: with friends, offer them right
                    // here; without, say exactly how conversations start
                    final friends = SocialState.instance.friends;
                    if (friends.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 44),
                          child: Text(
                            'Meet someone in a room and tap 👥 to add them — once you’re friends, the conversation starts here.',
                            textAlign: TextAlign.center,
                            style: T.body.copyWith(color: C.tx3, fontSize: 14.5, height: 1.5),
                          ),
                        ),
                      );
                    }
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text('No conversations yet — message one of your people:',
                              style: T.tiny.copyWith(color: C.tx3, fontSize: 13)),
                        ),
                        for (final f in friends) _friendRow(context, f),
                      ],
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
                    itemCount: chats.length,
                    itemBuilder: (context, i) {
                      final c = chats[i];
                      return GestureDetector(
                        onLongPress: () {
                          Buzz.commit();
                          NetworkClient.instance.pinChat(c.uid, !c.pinned);
                          setState(() => c.pinned = !c.pinned);
                          NetworkClient.instance.chatsList();
                        },
                        child: Press(
                        haptic: false,
                        onTap: () {
                          Buzz.tick();
                          ChatScreen.push(context, uid: c.uid, name: c.name, hue: c.hue);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              IdentityOrb(hue: c.hue, size: 46, live: c.online),
                              const SizedBox(width: 13),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text('@${c.name}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: T.body.copyWith(
                                                color: Colors.white,
                                                fontWeight: c.unread > 0 ? FontWeight.w800 : FontWeight.w700,
                                                fontSize: 15.5,
                                              )),
                                        ),
                                        if (c.pinned) ...const [
                                          SizedBox(width: 6),
                                          Icon(Icons.push_pin_rounded, size: 11, color: C.tx3),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${c.lastFromMe ? 'you: ' : ''}${c.preview}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: T.tiny.copyWith(
                                        color: c.unread > 0 ? Colors.white : C.tx3,
                                        fontWeight: c.unread > 0 ? FontWeight.w700 : FontWeight.w500,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(_ago(c.lastAt), style: T.tiny.copyWith(color: C.tx3, fontSize: 11)),
                                  const SizedBox(height: 4),
                                  if (c.unread > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                          color: C.sig, borderRadius: BorderRadius.circular(100)),
                                      child: Text('${c.unread}',
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800)),
                                    )
                                  else
                                    const SizedBox(height: 18),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
