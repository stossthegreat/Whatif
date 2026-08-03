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
import 'friends_screen.dart';

/// Messages — two lanes under one roof, Monkey-style: MESSAGE is every
/// conversation (pinned first, then recency), FRIENDS is your people. Only
/// matched friends can appear in either, so it's never spam.
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
  int _seg = 0; // 0 MESSAGE · 1 FRIENDS

  @override
  void initState() {
    super.initState();
    NetworkClient.instance.chatsList();
    NetworkClient.instance.friendsSnapshot(); // the FRIENDS lane needs this
  }

  /// One friend, tappable — used by the FRIENDS lane, the compose sheet and
  /// the no-conversations state, so starting a chat is never more than two taps.
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
            Avatar(hue: f.hue, photoId: f.photoId, size: 46, live: f.online),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('@${f.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: T.body.copyWith(
                          color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15.5)),
                  if (f.online) ...[
                    const SizedBox(height: 2),
                    Text('online now',
                        style: T.tiny.copyWith(
                            color: C.acid, fontWeight: FontWeight.w700, fontSize: 11)),
                  ],
                ],
              ),
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
          radius: R.sheet,
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
      body: Container(
        // the header zone breathes purple; it fades out well above the lists
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 0.22],
            colors: [C.purpleDeep.withOpacity(0.30), Colors.transparent],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 10, 22, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
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
                    _SegTab(
                      label: 'Messages',
                      active: _seg == 0,
                      onTap: () { Buzz.tick(); setState(() => _seg = 0); },
                    ),
                    const SizedBox(width: 22),
                    AnimatedBuilder(
                      animation: SocialState.instance,
                      builder: (context, _) => _SegTab(
                        label: 'Friends',
                        active: _seg == 1,
                        badge: SocialState.instance.reqCount,
                        onTap: () { Buzz.tick(); setState(() => _seg = 1); },
                      ),
                    ),
                    const Spacer(),
                    // new message — pick any friend, start talking
                    Press(
                      onTap: () { Buzz.tick(); _composeSheet(context); },
                      child: Container(
                        width: 38, height: 38,
                        decoration: BoxDecoration(
                          gradient: C.gradSig,
                          shape: BoxShape.circle,
                          boxShadow: C.glowSig(blur: 14, spread: -4),
                        ),
                        child: const Icon(Icons.add_comment_rounded, size: 18, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: AnimatedBuilder(
                  animation: Listenable.merge([ChatStore.instance, SocialState.instance]),
                  builder: (context, _) =>
                      _seg == 0 ? _messagesLane(context) : _friendsLane(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- MESSAGE lane --------------------------------------------------------

  /// Friends who are on RIGHT NOW — the most valuable pixel in a live app's
  /// message tab. Hidden entirely when nobody's on.
  Widget _onNowRail(BuildContext context) {
    final on = SocialState.instance.friends.where((f) => f.online).toList();
    if (on.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 8),
          child: Row(
            children: [
              Container(
                width: 6, height: 6,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: C.acid,
                  boxShadow: [BoxShadow(color: C.acidGlow, blurRadius: 6)],
                ),
              ),
              const SizedBox(width: 7),
              Text('ON NOW', style: T.eyebrow),
            ],
          ),
        ),
        SizedBox(
          height: 84,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: on.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, i) {
              final f = on[i];
              return Press(
                haptic: false,
                onTap: () {
                  Buzz.tick();
                  ChatScreen.push(context, uid: f.uid, name: f.name, hue: f.hue);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Avatar(hue: f.hue, photoId: f.photoId, size: 54, ring: C.acid),
                    const SizedBox(height: 5),
                    SizedBox(
                      width: 62,
                      child: Text(f.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: T.tiny.copyWith(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _messagesLane(BuildContext context) {
    final chats = ChatStore.instance.chats;
    if (chats.isEmpty) {
      // never a dead black screen: with friends, offer them right here;
      // without, say exactly how conversations start
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
          _onNowRail(context),
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
      itemCount: chats.length + 1,
      itemBuilder: (context, idx) {
        if (idx == 0) return _onNowRail(context);
        final i = idx - 1;
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
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 2),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              decoration: c.unread > 0
                  ? BoxDecoration(
                      color: C.sig.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(14),
                    )
                  : null,
              child: Row(
                children: [
                  // the heat bar — acid means something is waiting for you
                  if (c.unread > 0)
                    Container(
                      width: 3,
                      height: 34,
                      margin: const EdgeInsets.only(right: 9),
                      decoration: const BoxDecoration(
                        color: C.acid,
                        borderRadius: BorderRadius.all(Radius.circular(100)),
                        boxShadow: [
                          BoxShadow(color: C.acidGlow, blurRadius: 8, spreadRadius: -1),
                        ],
                      ),
                    ),
                  Avatar(hue: c.hue, photoId: c.photoId, size: 46, live: c.online),
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
                          decoration: const BoxDecoration(
                              color: C.acid,
                              borderRadius: BorderRadius.all(Radius.circular(100))),
                          child: Text('${c.unread}',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.black,
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
  }

  // ---- FRIENDS lane --------------------------------------------------------

  Widget _friendsLane(BuildContext context) {
    final s = SocialState.instance;
    final friends = [...s.friends]..sort((a, b) {
        if (a.online != b.online) return a.online ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
      children: [
        if (s.reqCount > 0)
          Press(
            haptic: false,
            onTap: () { Buzz.tick(); FriendsScreen.push(context, tab: 4); },
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: C.sig.withOpacity(0.16),
                borderRadius: BorderRadius.circular(R.btn),
                border: Border.all(color: C.sig.withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  const Text('✨', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${s.reqCount} ${s.reqCount == 1 ? 'person wants' : 'people want'} to be your friend',
                      style: T.body.copyWith(
                          color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, size: 20, color: C.tx2),
                ],
              ),
            ),
          ),
        if (friends.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 90, 24, 0),
            child: Text(
              'Nobody yet. Meet someone in a room, tap 👥, and when they add you back they land here.',
              textAlign: TextAlign.center,
              style: T.body.copyWith(color: C.tx3, fontSize: 14.5, height: 1.5),
            ),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text('${friends.length} ${friends.length == 1 ? 'FRIEND' : 'FRIENDS'}',
                style: T.eyebrow),
          ),
          for (final f in friends) _friendRow(context, f),
          const SizedBox(height: 14),
          Center(
            child: Press(
              haptic: false,
              onTap: () { Buzz.tick(); FriendsScreen.push(context); },
              child: Text('see everyone ›',
                  style: T.tiny.copyWith(color: C.sig, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ],
    );
  }
}

/// One segmented-header tab: display caps + a sliding acid underline.
class _SegTab extends StatelessWidget {
  const _SegTab({
    required this.label,
    required this.active,
    required this.onTap,
    this.badge = 0,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedDefaultTextStyle(
                duration: M.quick,
                style: T.display(21).copyWith(
                    color: active ? Colors.white : Colors.white.withOpacity(0.35)),
                child: Text(label),
              ),
              if (badge > 0) ...[
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  constraints: const BoxConstraints(minWidth: 15),
                  decoration: const BoxDecoration(
                    color: C.acid,
                    borderRadius: BorderRadius.all(Radius.circular(100)),
                  ),
                  child: Text('$badge',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 9.5, color: Colors.black, fontWeight: FontWeight.w800)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          AnimatedContainer(
            duration: M.quick,
            curve: M.ease,
            width: active ? 30 : 0,
            height: 3,
            decoration: const BoxDecoration(
              color: C.acid,
              borderRadius: BorderRadius.all(Radius.circular(100)),
              boxShadow: [BoxShadow(color: C.acidGlow, blurRadius: 8, spreadRadius: -1)],
            ),
          ),
        ],
      ),
    );
  }
}
