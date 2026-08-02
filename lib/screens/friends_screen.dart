import 'package:flutter/material.dart';
import '../core/haptics.dart';
import '../net/network_client.dart';
import '../state/session.dart';
import '../state/social.dart';
import '../theme/tokens.dart';
import '../widgets/glass.dart';
import '../widgets/identity_orb.dart';

/// Your people — the whole graph on one screen. Friends (online first),
/// Close, Favourites, Recently met (the "accidentally pressed Next" recovery),
/// Requests, Blocked.
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key, this.initialTab = 0});
  final int initialTab;

  static void push(BuildContext context, {int tab = 0}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => FriendsScreen(initialTab: tab),
    ));
  }

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  static const tabs = ['People', 'Close', 'Favourites', 'Recently met', 'Requests', 'Blocked'];
  late int _tab = widget.initialTab;

  @override
  void initState() {
    super.initState();
    NetworkClient.instance.friendsSnapshot(); // freshest graph on open
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.black,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: Listenable.merge([SocialState.instance, AppSession.instance]),
          builder: (context, _) {
            final s = SocialState.instance;
            return Column(
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
                      Text('Your people', style: T.big.copyWith(fontSize: 26)),
                    ],
                  ),
                ),
                // segment chips
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: tabs.length,
                    separatorBuilder: (_, i) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final sel = i == _tab;
                      final badge = i == 4 ? s.reqCount : 0;
                      return Press(
                        haptic: false,
                        onTap: () { Buzz.tick(); setState(() => _tab = i); },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 15),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: sel ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(color: sel ? Colors.white : C.hair2),
                          ),
                          child: Row(
                            children: [
                              Text(tabs[i],
                                  style: T.tiny.copyWith(
                                    color: sel ? Colors.black : C.tx2,
                                    fontWeight: FontWeight.w800,
                                  )),
                              if (badge > 0) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                      color: C.sig, borderRadius: BorderRadius.circular(100)),
                                  child: Text('$badge',
                                      style: const TextStyle(
                                          fontSize: 10, color: Colors.white, fontWeight: FontWeight.w800)),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(child: _body(s)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _body(SocialState s) {
    switch (_tab) {
      case 0:
        return _friendList(s.friends,
            empty: 'Meet someone, both say “meet again” — they land here forever.');
      case 1:
        return _friendList(s.friends.where((f) => f.tier >= 1).toList(),
            empty: 'Long-press a friend to make them a Close Friend.');
      case 2:
        return _friendList(s.friends.where((f) => f.tier == 2).toList(),
            empty: 'Your favourite people — long-press a friend to add one.');
      case 3:
        return _recentList(s);
      case 4:
        return _requestList(s);
      default:
        return _blockedList();
    }
  }

  // ---- friends -------------------------------------------------------------
  Widget _friendList(List<FriendInfo> list, {required String empty}) {
    if (list.isEmpty) return _empty(empty);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 30),
      itemCount: list.length,
      itemBuilder: (context, i) {
        final f = list[i];
        return Press(
          haptic: false,
          onTap: () { Buzz.tick(); _friendSheet(f); },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Row(
              children: [
                IdentityOrb(hue: f.hue, size: 44, live: f.online),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text('@${f.name}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: T.body.copyWith(
                                    color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15.5)),
                          ),
                          if (f.tier == 2) ...const [
                            SizedBox(width: 6),
                            Text('⭐', style: TextStyle(fontSize: 11)),
                          ] else if (f.tier == 1) ...const [
                            SizedBox(width: 6),
                            Icon(Icons.favorite_rounded, size: 12, color: C.sig),
                          ],
                        ],
                      ),
                      Text(
                        f.online ? 'online now' : 'away',
                        style: T.tiny.copyWith(
                          color: f.online ? const Color(0xFF3BE07A) : C.tx3,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, size: 20, color: C.tx3),
              ],
            ),
          ),
        );
      },
    );
  }

  void _friendSheet(FriendInfo f) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(12),
        child: Glass(
          radius: 26,
          padding: const EdgeInsets.all(6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _sheetRow(ctx, f.tier >= 1 ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
                  f.tier >= 1 ? 'Remove Close Friend' : 'Close Friend', C.tx, () {
                SocialState.instance.setTier(f, f.tier >= 1 ? 0 : 1);
              }),
              const Divider(height: 1, color: C.hair),
              _sheetRow(ctx, Icons.star_rounded,
                  f.tier == 2 ? 'Remove Favourite' : 'Favourite person', C.tx, () {
                SocialState.instance.setTier(f, f.tier == 2 ? 1 : 2);
              }),
              const Divider(height: 1, color: C.hair),
              _sheetRow(ctx, Icons.person_remove_rounded, 'Unfriend @${f.name}', C.live, () {
                SocialState.instance.unfriend(f.uid);
              }),
              const Divider(height: 1, color: C.hair),
              _sheetRow(ctx, null, 'Cancel', C.tx2, () {}, center: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetRow(BuildContext ctx, IconData? icon, String label, Color color,
      VoidCallback onTap, {bool center = false}) {
    return InkWell(
      onTap: () { Buzz.tick(); Navigator.pop(ctx); onTap(); },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        child: Row(
          mainAxisAlignment: center ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            if (icon != null) ...[Icon(icon, size: 19, color: color), const SizedBox(width: 12)],
            Text(label, style: T.body.copyWith(color: color, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  // ---- recently met ---------------------------------------------------------
  Widget _recentList(SocialState s) {
    if (s.recent.isEmpty) {
      return _empty('People you meet land here — so pressing Next never loses anyone.');
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 30),
      itemCount: s.recent.length,
      itemBuilder: (context, i) {
        final r = s.recent[i];
        final requested = s.requested(r.uid);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            children: [
              IdentityOrb(hue: r.hue, size: 44),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('@${r.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: T.body.copyWith(
                            color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15.5)),
                    Text(r.ago, style: T.tiny.copyWith(color: C.tx3)),
                  ],
                ),
              ),
              Press(
                haptic: false,
                onTap: requested
                    ? null
                    : () { Buzz.commit(); SocialState.instance.request(r.uid); },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                  decoration: BoxDecoration(
                    color: requested ? Colors.transparent : Colors.white,
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: requested ? C.hair2 : Colors.white),
                  ),
                  child: Text(
                    requested ? 'sent ✓' : 'Add friend',
                    style: T.tiny.copyWith(
                      color: requested ? C.tx3 : Colors.black,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---- requests -------------------------------------------------------------
  Widget _requestList(SocialState s) {
    if (s.reqsIn.isEmpty && s.reqsOut.isEmpty) {
      return _empty('Friend requests show up here.');
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 30),
      children: [
        for (final f in s.reqsIn)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Row(
              children: [
                IdentityOrb(hue: f.hue, size: 44),
                const SizedBox(width: 13),
                Expanded(
                  child: Text('@${f.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: T.body.copyWith(
                          color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15.5)),
                ),
                Press(
                  haptic: false,
                  onTap: () { Buzz.commit(); SocialState.instance.accept(f.uid); },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                        color: Colors.white, borderRadius: BorderRadius.circular(100)),
                    child: Text('Accept',
                        style: T.tiny.copyWith(color: Colors.black, fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(width: 8),
                Press(
                  haptic: false,
                  onTap: () { Buzz.tick(); SocialState.instance.decline(f.uid); },
                  child: Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle, border: Border.all(color: C.hair2)),
                    child: const Icon(Icons.close_rounded, size: 17, color: C.tx2),
                  ),
                ),
              ],
            ),
          ),
        for (final f in s.reqsOut)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Row(
              children: [
                IdentityOrb(hue: f.hue, size: 44),
                const SizedBox(width: 13),
                Expanded(
                  child: Text('@${f.name}',
                      style: T.body.copyWith(
                          color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15.5)),
                ),
                Text('sent · waiting', style: T.tiny.copyWith(color: C.tx3)),
              ],
            ),
          ),
      ],
    );
  }

  // ---- blocked --------------------------------------------------------------
  Widget _blockedList() {
    final blocked = AppSession.instance.blocked;
    if (blocked.isEmpty) return _empty('Nobody blocked. Block from any room via ⋯');
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 30),
      children: [
        for (final e in blocked)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Row(
              children: [
                Expanded(
                  child: Text('@${e.split('|').length > 1 ? e.split('|')[1] : 'someone'}',
                      style: T.body.copyWith(
                          color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15.5)),
                ),
                Press(
                  onTap: () {
                    Buzz.tick();
                    final uid = e.split('|').first;
                    AppSession.instance.removeBlocked(uid);
                    NetworkClient.instance.unblock(uid);
                    setState(() {});
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: C.hair2),
                    ),
                    child: Text('Unblock',
                        style: T.tiny.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _empty(String text) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 44),
          child: Text(text,
              textAlign: TextAlign.center,
              style: T.body.copyWith(color: C.tx3, fontSize: 14.5, height: 1.5)),
        ),
      );
}
