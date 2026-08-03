import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../config.dart';
import '../core/analytics.dart';
import '../core/haptics.dart';
import '../core/sound.dart';
import '../net/network_client.dart';
import '../state/social.dart';
import '../theme/tokens.dart';
import '../widgets/avatar.dart';
import '../widgets/glass.dart';
import '../widgets/identity_orb.dart';

/// Room with friends. One code, one share, your people drop in — then the same
/// engine throws the whole group into a session. Elite-minimal: the code IS the
/// screen.
class PartyScreen extends StatefulWidget {
  const PartyScreen({super.key, required this.onBack, this.initialCode, this.inviteUid});
  final VoidCallback onBack;

  /// A code that arrived via deep link — prefilled and auto-joined.
  final String? initialCode;

  /// Chat invite flow: once the room code exists, DM it to this friend.
  final String? inviteUid;

  @override
  State<PartyScreen> createState() => _PartyScreenState();
}

class _PartyMember {
  _PartyMember(this.id, this.name, this.hue);
  final String id;
  final String name;
  final double hue;
}

class _PartyScreenState extends State<PartyScreen> {
  StreamSubscription<Map<String, dynamic>>? _sub;
  final _joinCtl = TextEditingController();

  String? _code;
  String? _hostId;
  bool _invited = false;
  final Set<String> _invitedUids = {}; // friends already sent this room's code
  List<_PartyMember> _members = const [];
  String? _error;
  bool _starting = false;

  bool get _isHost => _hostId != null && _hostId == NetworkClient.instance.myId;

  @override
  void initState() {
    super.initState();
    if (AppConfig.isLive) {
      _sub = NetworkClient.instance.events.listen(_onNet);
      NetworkClient.instance.host();
      NetworkClient.instance.friendsSnapshot(); // fresh rail for invites
      Track.event('party_hosted');
      final code = widget.initialCode;
      if (code != null && code.length >= 4) {
        _joinCtl.text = code;
        // small beat so the hello/host round-trip lands first
        Timer(const Duration(milliseconds: 700), () {
          if (mounted) _join();
        });
      }
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _joinCtl.dispose();
    super.dispose();
  }

  void _onNet(Map<String, dynamic> m) {
    if (!mounted) return;
    switch (m['t']) {
      // the socket dropped and reconnected — the old party died with the old
      // connection, so re-host: a fresh live code replaces the dead one on
      // screen instead of silently showing a code nobody can join.
      case 'welcome':
        NetworkClient.instance.host();
      case 'party':
        // chat-invite flow: the moment we have a code, DM it to the friend
        final newCode = m['code'] as String?;
        final invitee = widget.inviteUid;
        if (invitee != null && newCode != null && newCode != _code && !_invited) {
          _invited = true;
          NetworkClient.instance.dm(invitee, 'invite', newCode);
        }
        setState(() {
          _error = null;
          _code = m['code'] as String?;
          _hostId = m['hostId'] as String?;
          _members = ((m['members'] as List?) ?? const [])
              .whereType<Map>()
              .map((e) => _PartyMember(
                    (e['id'] as String?) ?? '',
                    (e['name'] as String?) ?? '?',
                    ((e['hue'] as num?) ?? 205).toDouble(),
                  ))
              .toList();
        });
        Buzz.tick();
      case 'partyError':
        setState(() => _error = (m['reason'] as String?) ?? 'That didn’t work');
        Buzz.impact();
      // when the cell arrives the root swaps straight to the live room —
      // nothing to do here.
    }
  }

  /// One friend in the invite rail. Tap → the room code lands in their DMs as
  /// an invite bubble (one tap to join on their side). Capped at 3 — a room
  /// of four is the sweet spot.
  Widget _inviteChip(FriendInfo f) {
    final sent = _invitedUids.contains(f.uid);
    return Press(
      haptic: false,
      onTap: () {
        if (sent || _code == null) return;
        if (_invitedUids.length >= 3) {
          setState(() => _error = 'three invites max — keep the room tight');
          return;
        }
        Buzz.commit();
        NetworkClient.instance.dm(f.uid, 'invite', _code!);
        setState(() {
          _error = null;
          _invitedUids.add(f.uid);
        });
      },
      child: Padding(
        padding: const EdgeInsets.only(right: 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Avatar(hue: f.hue, photoId: f.photoId, size: 48, live: f.online),
                if (sent)
                  Positioned(
                    right: -2, bottom: -2,
                    child: Container(
                      width: 18, height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: C.sig,
                        border: Border.all(color: C.black, width: 2),
                      ),
                      child: const Icon(Icons.check_rounded, size: 11, color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              sent ? 'sent ✓' : '@${f.name}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: T.tiny.copyWith(
                color: sent ? C.sig : C.tx2,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _share() {
    final code = _code;
    if (code == null) return;
    Track.event('party_share');
    Buzz.commit();
    Sfx.pop();
    Share.share(
      'Drop into my Rivlr room 🎥 code $code — tap rivlr://join/$code or open Rivlr and enter it. You never know who you’ll get.',
    );
  }

  void _join() {
    final code = _joinCtl.text.trim().toUpperCase();
    if (code.length < 4) return;
    Buzz.commit();
    FocusScope.of(context).unfocus();
    if (code == _code) {
      // typing your own code back in — gently point at the share button
      setState(() => _error = 'that’s your room — send the code to a friend');
      return;
    }
    Track.event('party_join_attempt');
    NetworkClient.instance.joinParty(code);
  }

  void _start() {
    if (!_isHost || _starting) return;
    Track.event('party_started', {'people': _members.length});
    setState(() => _starting = true);
    Buzz.pop();
    Sfx.match();
    NetworkClient.instance.startParty();
  }

  void _back() {
    // Hosts keep their room alive on back — the code they shared stays
    // joinable (the server hands the same party back on reopen). Joining a
    // stranger queue kills it server-side anyway. Guests DO leave, so the
    // host isn't holding ghosts.
    if (!_isHost) NetworkClient.instance.leaveParty();
    widget.onBack();
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final hostName = _members
        .where((m) => m.id == _hostId)
        .map((m) => m.name)
        .followedBy(const ['host'])
        .first;

    return Scaffold(
      backgroundColor: C.black,
      body: SafeArea(
        // scrollable + min-height: identical layout when everything fits,
        // scrolls when the keyboard steals the space — the code field always
        // stays reachable (focused fields auto-scroll into view).
        child: LayoutBuilder(builder: (context, box) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: r.gutter),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Press(
                          onTap: _back,
                          child: Container(
                            width: 38, height: 38,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle, color: C.glass, border: Border.all(color: C.hair)),
                            child: const Icon(Icons.arrow_back_rounded, size: 20, color: C.tx2),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Text('Room with friends', style: T.big.copyWith(fontSize: 24)),
                      ],
                    ),
                    const Spacer(),
                    // the code — huge, the whole point of the screen
                    Center(
                      child: Column(
                        children: [
                          Text('YOUR ROOM CODE',
                              style: T.eyebrow.copyWith(color: C.tx3, letterSpacing: 3.2, fontSize: 11)),
                          const SizedBox(height: 14),
                          _code == null
                              ? Text(AppConfig.isLive ? '· · · ·' : 'OFFLINE',
                                  style: T.display(56).copyWith(color: C.tx3, letterSpacing: 8))
                              : Press(
                                  onTap: () {
                                    Clipboard.setData(ClipboardData(text: _code!));
                                    Buzz.tick();
                                  },
                                  child: Text(
                                    _code!.split('').join(' '),
                                    style: T.display(64).copyWith(letterSpacing: 6),
                                  ),
                                ),
                          const SizedBox(height: 8),
                          Text('tap to copy · share it anywhere', style: T.tiny),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    // who's here
                    if (_members.isNotEmpty)
                      Center(
                        child: Wrap(
                          spacing: 14,
                          runSpacing: 12,
                          alignment: WrapAlignment.center,
                          children: [
                            for (final m in _members)
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IdentityOrb(hue: m.hue, size: 46, ring: m.id == _hostId ? C.sig : null),
                                  const SizedBox(height: 6),
                                  Text(
                                    m.id == NetworkClient.instance.myId ? 'you' : '@${m.name}',
                                    style: T.tiny.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        _members.length <= 1
                            ? 'waiting for your people…'
                            : _isHost
                                ? '${_members.length} in — start when ready'
                                : 'waiting for @$hostName to start',
                        style: T.body.copyWith(color: C.tx2, fontSize: 14),
                      ),
                    ),
                    // your people, one tap — no code-typing needed on their end
                    if (AppConfig.isLive && _code != null && _isHost)
                      AnimatedBuilder(
                        animation: SocialState.instance,
                        builder: (context, _) {
                          final friends = SocialState.instance.friends;
                          if (friends.isEmpty) return const SizedBox.shrink();
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 22),
                              Text('TAP A FRIEND TO INVITE · UP TO 3',
                                  style: T.eyebrow.copyWith(color: C.tx3, fontSize: 10.5)),
                              const SizedBox(height: 10),
                              SizedBox(
                                height: 76,
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  children: [
                                    for (final f in friends) _inviteChip(f),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    const Spacer(),
                    if (_error != null) ...[
                      Center(child: Text(_error!, style: T.tiny.copyWith(color: C.live))),
                      const SizedBox(height: 10),
                    ],
                    Cta(label: 'Share the code', onTap: _code == null ? null : _share),
                    const SizedBox(height: 10),
                    if (_isHost)
                      Press(
                        haptic: false,
                        onTap: _members.length >= 2 && !_starting ? _start : null,
                        child: Opacity(
                          opacity: _members.length >= 2 && !_starting ? 1 : 0.4,
                          child: Container(
                            height: 56,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: C.hair2),
                            ),
                            child: Text(
                              _starting ? 'Starting…' : 'Start the room  ›',
                              style: T.body.copyWith(color: C.tx, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 18),
                    // join someone else's room instead
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 52,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: C.hair2),
                            ),
                            child: Center(
                              child: TextField(
                                controller: _joinCtl,
                                maxLength: 4,
                                textCapitalization: TextCapitalization.characters,
                                style: T.body.copyWith(
                                    color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 4),
                                decoration: InputDecoration(
                                  isDense: true,
                                  border: InputBorder.none,
                                  counterText: '',
                                  hintText: 'got a code?',
                                  hintStyle: T.body.copyWith(color: C.tx3, letterSpacing: 0),
                                ),
                                onSubmitted: (_) => _join(),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Press(
                          onTap: _join,
                          child: Container(
                            height: 52,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: C.glass,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: C.hair2),
                            ),
                            child: Text('Join', style: T.body.copyWith(color: C.tx, fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
