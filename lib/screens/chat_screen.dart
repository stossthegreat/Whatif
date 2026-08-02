import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../core/analytics.dart';
import '../core/haptics.dart';
import '../net/api_client.dart';
import '../net/network_client.dart';
import '../state/chat.dart';
import '../state/session.dart';
import '../theme/tokens.dart';
import '../widgets/glass.dart';
import '../widgets/identity_orb.dart';
import 'friend_profile_screen.dart';

/// Hooks the app shell exposes so deep surfaces (chat, notifications) can
/// drive the play flow without owning the step machine.
class AppNav {
  AppNav._();
  static void Function(String code)? joinPartyCode;   // join a friend's room
  static void Function(String uid)? hostPartyFor;     // start a room + invite
}

/// One conversation. Text now; voice/photo/GIF buttons appear when the media
/// pipeline lands (feature-flagged by the server).
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.uid, required this.name, required this.hue});
  final String uid;
  final String name;
  final double hue;

  static void push(BuildContext context,
      {required String uid, required String name, required double hue}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChatScreen(uid: uid, name: name, hue: hue),
    ));
  }

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _ctl = TextEditingController();
  final _scroll = ScrollController();
  Timer? _typingOff;
  bool _sentTyping = false;

  // media
  final _rec = AudioRecorder();
  final _player = AudioPlayer();
  bool _recording = false;
  bool _uploading = false;
  DateTime? _recStart;
  int? _playingMediaId;

  static const _reactions = ['❤️', '😂', '🔥', '👀', '💀', '👑'];

  @override
  void initState() {
    super.initState();
    Track.screen('chat');
    ChatStore.instance.openThread(widget.uid);
  }

  @override
  void dispose() {
    if (_sentTyping) NetworkClient.instance.typing(widget.uid, false);
    _typingOff?.cancel();
    ChatStore.instance.closeThread();
    _ctl.dispose();
    _scroll.dispose();
    _rec.dispose();
    _player.dispose();
    super.dispose();
  }

  // ---- media sending --------------------------------------------------------
  Future<void> _pickPhoto() async {
    if (_uploading) return;
    Buzz.tick();
    try {
      final x = await ImagePicker().pickImage(
          source: ImageSource.gallery, maxWidth: 1080, maxHeight: 1080, imageQuality: 72);
      if (x == null || !mounted) return;
      setState(() => _uploading = true);
      final bytes = await x.readAsBytes();
      final id = await Api.uploadMedia(bytes, kind: 'photo', mime: 'image/jpeg');
      if (!mounted) return;
      setState(() => _uploading = false);
      if (id != null) {
        ChatStore.instance.sendMedia(widget.uid, 'photo', id);
      } else {
        _toast('photo didn’t send — try again');
      }
    } catch (_) {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _startRecording() async {
    if (_recording || _uploading) return;
    try {
      if (!await _rec.hasPermission()) return;
      final dir = await getTemporaryDirectory();
      await _rec.start(const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000),
          path: '${dir.path}/vn_${DateTime.now().millisecondsSinceEpoch}.m4a');
      Buzz.impact();
      setState(() { _recording = true; _recStart = DateTime.now(); });
    } catch (_) {/* mic denied — nothing to do */}
  }

  Future<void> _stopRecording({bool cancel = false}) async {
    if (!_recording) return;
    final path = await _rec.stop();
    final dur = DateTime.now().difference(_recStart ?? DateTime.now());
    setState(() => _recording = false);
    if (cancel || path == null || dur.inMilliseconds < 600) return;
    setState(() => _uploading = true);
    try {
      final bytes = await XFile(path).readAsBytes();
      final id = await Api.uploadMedia(bytes, kind: 'voice', mime: 'audio/m4a');
      if (!mounted) return;
      setState(() => _uploading = false);
      if (id != null) {
        ChatStore.instance
            .sendMedia(widget.uid, 'voice', id, meta: {'durMs': dur.inMilliseconds});
      } else {
        _toast('voice note didn’t send');
      }
    } catch (_) {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _playVoice(Msg msg) async {
    final id = msg.mediaId;
    if (id == null) return;
    Buzz.tick();
    if (_playingMediaId == id) {
      await _player.stop();
      setState(() => _playingMediaId = null);
      return;
    }
    setState(() => _playingMediaId = id);
    await _player.stop();
    await _player.play(UrlSource(Api.mediaUrl(id)));
    _player.onPlayerComplete.first.then((_) {
      if (mounted && _playingMediaId == id) setState(() => _playingMediaId = null);
    });
  }

  void _gifPanel() {
    Buzz.tick();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _GifSheet(onPick: (g) {
        Navigator.pop(ctx);
        ChatStore.instance.sendGif(widget.uid, g.tinyUrl);
      }),
    );
  }

  void _send() {
    final text = _ctl.text.trim();
    if (text.isEmpty) return;
    Buzz.tick();
    ChatStore.instance.sendText(widget.uid, text);
    _ctl.clear();
    _stopTyping();
  }

  void _onChanged(String v) {
    if (v.isNotEmpty && !_sentTyping) {
      _sentTyping = true;
      NetworkClient.instance.typing(widget.uid, true);
    }
    _typingOff?.cancel();
    _typingOff = Timer(const Duration(seconds: 2), _stopTyping);
  }

  void _stopTyping() {
    if (_sentTyping) {
      _sentTyping = false;
      NetworkClient.instance.typing(widget.uid, false);
    }
  }

  void _invite() {
    Buzz.commit();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(12),
        child: Glass(
          radius: 26,
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Start a room with @${widget.name}?', style: T.h3),
              const SizedBox(height: 8),
              Text('You’ll host the room — the invite lands right here in the chat.',
                  style: T.body.copyWith(fontSize: 14)),
              const SizedBox(height: 18),
              Cta(label: 'Start the room', onTap: () {
                Navigator.pop(ctx);
                Navigator.of(context).popUntil((r) => r.isFirst);
                AppNav.hostPartyFor?.call(widget.uid);
              }),
            ],
          ),
        ),
      ),
    );
  }

  void _menu() {
    Buzz.tick();
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
              _menuRow(ctx, Icons.flag_outlined, 'Report @${widget.name}', C.tx, () {
                NetworkClient.instance.report(widget.uid);
                _toast('reported — our team is on it');
              }),
              const Divider(height: 1, color: C.hair),
              _menuRow(ctx, Icons.block_rounded, 'Block @${widget.name}', C.live, () {
                AppSession.instance.noteBlocked(widget.uid, widget.name);
                NetworkClient.instance.block(widget.uid);
                Navigator.of(context).maybePop();
              }),
              const Divider(height: 1, color: C.hair),
              _menuRow(ctx, null, 'Cancel', C.tx2, () {}, center: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuRow(BuildContext ctx, IconData? icon, String label, Color color,
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

  void _toast(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: C.char2,
      content: Text(text, style: T.body.copyWith(color: Colors.white)),
    ));
  }

  void _reactSheet(Msg msg) {
    Buzz.commit();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(12),
        child: Glass(
          radius: 26,
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final e in _reactions)
                Press(
                  onTap: () {
                    Navigator.pop(ctx);
                    final mine = msg.reactions[AppSession.instance.myUid];
                    ChatStore.instance.react(msg, mine == e ? null : e);
                  },
                  child: Text(e, style: const TextStyle(fontSize: 28)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myUid = AppSession.instance.myUid;
    return Scaffold(
      backgroundColor: C.black,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: ChatStore.instance,
          builder: (context, _) {
            final store = ChatStore.instance;
            final msgs = store.thread(widget.uid);
            final typing = store.typingPeers.contains(widget.uid);
            final readUpTo = store.peerReadUpTo[widget.uid] ?? 0;
            final lastMineRead = msgs
                .where((x) => x.from == myUid && !x.pending && x.id <= readUpTo)
                .fold<int>(0, (a, b) => b.id > a ? b.id : a);

            return Column(
              children: [
                // header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
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
                      const SizedBox(width: 12),
                      Press(
                        haptic: false,
                        onTap: () {
                          Buzz.tick();
                          FriendProfileScreen.push(context,
                              uid: widget.uid, name: widget.name, hue: widget.hue);
                        },
                        child: IdentityOrb(hue: widget.hue, size: 36),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('@${widget.name}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: T.body.copyWith(
                                    color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                            if (typing)
                              Text('typing…',
                                  style: T.tiny.copyWith(
                                      color: C.sig, fontWeight: FontWeight.w700, fontSize: 11)),
                          ],
                        ),
                      ),
                      Press(
                        onTap: _invite,
                        child: Container(
                          width: 38, height: 38,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle, color: C.glass, border: Border.all(color: C.hair)),
                          child: const Icon(Icons.videogame_asset_rounded, size: 18, color: C.tx2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Press(
                        onTap: _menu,
                        child: Container(
                          width: 38, height: 38,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle, color: C.glass, border: Border.all(color: C.hair)),
                          child: const Icon(Icons.more_horiz_rounded, size: 19, color: C.tx2),
                        ),
                      ),
                    ],
                  ),
                ),
                // messages
                Expanded(
                  child: msgs.isEmpty
                      ? Center(
                          child: Text('say something — you both wanted this 😄',
                              style: T.body.copyWith(color: C.tx3, fontSize: 14.5)),
                        )
                      : ListView.builder(
                          controller: _scroll,
                          reverse: true,
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                          itemCount: msgs.length + (store.hasMore[widget.uid] == true ? 1 : 0),
                          itemBuilder: (context, i) {
                            if (i >= msgs.length) {
                              return Center(
                                child: Press(
                                  haptic: false,
                                  onTap: () => store.loadOlder(widget.uid),
                                  child: Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Text('load earlier…',
                                        style: T.tiny.copyWith(color: C.tx3)),
                                  ),
                                ),
                              );
                            }
                            final msg = msgs[msgs.length - 1 - i];
                            return _bubble(msg, myUid, lastMineRead);
                          },
                        ),
                ),
                // composer
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
                  child: Row(
                    children: [
                      if (NetworkClient.instance.gifsEnabled) ...[
                        Press(
                          onTap: _gifPanel,
                          child: Container(
                            width: 40, height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle, border: Border.all(color: C.hair2)),
                            child: Text('GIF',
                                style: T.tiny.copyWith(
                                    fontSize: 9.5, color: C.tx2, fontWeight: FontWeight.w800)),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      if (NetworkClient.instance.mediaEnabled) ...[
                        Press(
                          onTap: _pickPhoto,
                          child: Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle, border: Border.all(color: C.hair2)),
                            child: const Icon(Icons.photo_rounded, size: 18, color: C.tx2),
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onLongPressStart: (_) => _startRecording(),
                          onLongPressEnd: (_) => _stopRecording(),
                          onLongPressCancel: () => _stopRecording(cancel: true),
                          child: Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _recording ? C.live : Colors.transparent,
                              border: Border.all(color: _recording ? C.live : C.hair2),
                            ),
                            child: Icon(Icons.mic_rounded,
                                size: 18, color: _recording ? Colors.white : C.tx2),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: C.glass,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: C.hair2),
                          ),
                          child: TextField(
                            controller: _ctl,
                            onChanged: _onChanged,
                            onSubmitted: (_) => _send(),
                            textInputAction: TextInputAction.send,
                            minLines: 1,
                            maxLines: 4,
                            style: T.body.copyWith(color: Colors.white, fontSize: 15.5),
                            decoration: InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 13),
                              hintText: _recording
                                  ? 'recording… release to send'
                                  : _uploading
                                      ? 'sending…'
                                      : 'message @${widget.name}…',
                              hintStyle: T.body.copyWith(
                                  color: _recording ? C.live : C.tx3, fontSize: 15),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Press(
                        onTap: _send,
                        child: Container(
                          width: 46, height: 46,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft, end: Alignment.bottomRight,
                              colors: [C.sig, C.purpleDeep],
                            ),
                          ),
                          child: const Icon(Icons.arrow_upward_rounded, size: 22, color: Colors.white),
                        ),
                      ),
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

  Widget _bubble(Msg msg, String myUid, int lastMineRead) {
    final mine = msg.from == myUid;
    final Widget content;
    if (msg.kind == 'invite') {
      content = _inviteBubble(msg, mine);
    } else if (msg.kind == 'photo' && msg.mediaId != null) {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.network(
          Api.mediaUrl(msg.mediaId!),
          width: 220,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
            width: 220, height: 120,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: C.glass, borderRadius: BorderRadius.circular(16)),
            child: Text('photo expired', style: T.tiny),
          ),
        ),
      );
    } else if (msg.kind == 'gif' && msg.body.isNotEmpty) {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.network(msg.body, width: 200, fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const SizedBox.shrink()),
      );
    } else if (msg.kind == 'voice') {
      final secs = (((msg.meta['durMs'] as num?) ?? 0) / 1000).round();
      final playing = _playingMediaId != null && _playingMediaId == msg.mediaId;
      content = Press(
        haptic: false,
        onTap: () => _playVoice(msg),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: mine ? Colors.white : C.glass2,
            borderRadius: BorderRadius.circular(18),
            border: mine ? null : Border.all(color: C.hair),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
                  size: 22, color: mine ? Colors.black : Colors.white),
              const SizedBox(width: 8),
              Text('🎤 ${secs > 0 ? '${secs}s' : 'voice note'}',
                  style: T.body.copyWith(
                      color: mine ? Colors.black : Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14)),
            ],
          ),
        ),
      );
    } else {
      content = Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: mine ? Colors.white : C.glass2,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(mine ? 18 : 5),
            bottomRight: Radius.circular(mine ? 5 : 18),
          ),
          border: mine ? null : Border.all(color: C.hair),
        ),
        child: Text(
          msg.body,
          style: T.body.copyWith(
            color: mine ? Colors.black : Colors.white,
            fontSize: 15.5,
            height: 1.35,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onLongPress: () => _reactSheet(msg),
            child: Opacity(opacity: msg.pending ? 0.55 : 1, child: content),
          ),
          if (msg.reactions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: C.char2,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: C.hair),
                ),
                child: Text(msg.reactions.values.join(' '),
                    style: const TextStyle(fontSize: 12)),
              ),
            ),
          if (mine && !msg.pending && msg.id == lastMineRead && lastMineRead > 0)
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 4),
              child: Text('read', style: T.tiny.copyWith(color: C.tx3, fontSize: 10)),
            ),
        ],
      ),
    );
  }

  Widget _inviteBubble(Msg msg, bool mine) {
    final code = msg.body.toUpperCase();
    return Container(
      padding: const EdgeInsets.all(14),
      constraints: const BoxConstraints(maxWidth: 260),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: C.sig.withOpacity(0.6)),
        color: C.sig.withOpacity(0.10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🎮', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text('Room invite', style: T.tiny.copyWith(color: C.tx2, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 6),
          Text(code.split('').join(' '),
              style: T.h3.copyWith(color: Colors.white, letterSpacing: 2)),
          if (!mine) ...[
            const SizedBox(height: 10),
            Press(
              haptic: false,
              onTap: () {
                Buzz.commit();
                Navigator.of(context).popUntil((r) => r.isFirst);
                AppNav.joinPartyCode?.call(code);
              },
              child: Container(
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('Join the room',
                    style: T.body.copyWith(
                        color: Colors.black, fontWeight: FontWeight.w800, fontSize: 14)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// GIF search sheet — Tenor through the server proxy. Feature-flagged: this
/// sheet is only reachable when the server says gifs are on.
class _GifSheet extends StatefulWidget {
  const _GifSheet({required this.onPick});
  final void Function(Gif) onPick;

  @override
  State<_GifSheet> createState() => _GifSheetState();
}

class _GifSheetState extends State<_GifSheet> {
  final _q = TextEditingController();
  Timer? _debounce;
  List<Gif> _gifs = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _search('trending');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    setState(() => _loading = true);
    final r = await Api.searchGifs(q.isEmpty ? 'trending' : q);
    if (mounted) setState(() { _gifs = r; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: 420,
        decoration: const BoxDecoration(
          color: C.char,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: C.hair2, borderRadius: BorderRadius.circular(4))),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: C.glass,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: C.hair2),
                ),
                child: TextField(
                  controller: _q,
                  autofocus: true,
                  onChanged: (v) {
                    _debounce?.cancel();
                    _debounce = Timer(const Duration(milliseconds: 450), () => _search(v.trim()));
                  },
                  style: T.body.copyWith(color: Colors.white, fontSize: 15),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    hintText: 'search GIFs…',
                    hintStyle: T.body.copyWith(color: C.tx3, fontSize: 15),
                  ),
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.2, color: C.tx3)))
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3, mainAxisSpacing: 6, crossAxisSpacing: 6),
                      itemCount: _gifs.length,
                      itemBuilder: (context, i) => Press(
                        haptic: false,
                        onTap: () => widget.onPick(_gifs[i]),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(_gifs[i].tinyUrl, fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const ColoredBox(color: C.char2)),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
