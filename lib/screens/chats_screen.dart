import 'package:flutter/material.dart';
import '../core/haptics.dart';
import '../net/network_client.dart';
import '../state/chat.dart';
import '../theme/tokens.dart';
import '../widgets/glass.dart';
import '../widgets/identity_orb.dart';
import 'chat_screen.dart';

/// Messages — every conversation with your people. Pinned first, then by
/// recency. Only matched friends can appear here, so it's never spam.
class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

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
                  Text('Messages', style: T.big.copyWith(fontSize: 26)),
                ],
              ),
            ),
            Expanded(
              child: AnimatedBuilder(
                animation: ChatStore.instance,
                builder: (context, _) {
                  final chats = ChatStore.instance.chats;
                  if (chats.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 44),
                        child: Text(
                          'Match with someone — both say “meet again” — and the conversation starts here.',
                          textAlign: TextAlign.center,
                          style: T.body.copyWith(color: C.tx3, fontSize: 14.5, height: 1.5),
                        ),
                      ),
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
