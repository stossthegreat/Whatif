import 'dart:async';
import 'package:flutter/foundation.dart';
import '../net/network_client.dart';

/// One message in a thread. id == -1 while in flight (tmp holds the local id
/// until the server ack swaps the real one in).
class Msg {
  Msg({
    required this.id,
    required this.from,
    required this.kind,
    required this.body,
    this.mediaId,
    this.meta = const {},
    required this.at,
    this.tmp,
  });

  int id;
  final String? tmp;
  final String from;
  final String kind; // text · voice · photo · gif · invite · call
  final String body;
  final int? mediaId;
  final Map<String, dynamic> meta;
  final DateTime at;
  final Map<String, String> reactions = {}; // uid -> emoji

  bool get pending => id < 0;
}

class ChatSummary {
  ChatSummary({
    required this.uid,
    required this.name,
    required this.hue,
    this.photoId,
    required this.preview,
    required this.lastAt,
    required this.lastFromMe,
    required this.unread,
    required this.pinned,
    required this.online,
  });
  final String uid;
  final String name;
  final double hue;
  final int? photoId;
  final String preview;
  final DateTime? lastAt;
  final bool lastFromMe;
  final int unread;
  bool pinned;
  final bool online;
}

/// Client messaging state: per-peer thread caches, optimistic sends, unread,
/// typing, read receipts. Fed by the WS stream.
class ChatStore extends ChangeNotifier {
  ChatStore._();
  static final ChatStore instance = ChatStore._();

  final Map<String, List<Msg>> threads = {};
  final Map<String, bool> hasMore = {};
  final Set<String> typingPeers = {};
  final Map<String, int> peerReadUpTo = {};
  final Map<String, String> _tmpPeer = {}; // tmp id -> peer uid
  final Map<String, Timer> _typingOff = {};
  List<ChatSummary> chats = [];
  int unreadTotal = 0;
  String? activePeer; // open thread — incoming msgs auto-read
  int _tmpSeq = 0;
  String _myUid = '';

  bool _attached = false;

  void attach(String myUid) {
    _myUid = myUid;
    if (_attached) return;
    _attached = true;
    NetworkClient.instance.events.listen(_onNet);
  }

  List<Msg> thread(String uid) => threads.putIfAbsent(uid, () => []);

  void _onNet(Map<String, dynamic> m) {
    switch (m['t']) {
      case 'welcome':
        NetworkClient.instance.chatsList();
      case 'unread':
        unreadTotal = ((m['n'] as num?) ?? 0).toInt();
        notifyListeners();
      case 'chats':
        chats = _parseChats(m['list']);
        unreadTotal = chats.fold(0, (a, c) => a + c.unread);
        notifyListeners();
      case 'dm':
        _onDm((m['msg'] as Map?)?.cast<String, dynamic>());
      case 'dmAck':
        final tmp = m['tmp'] as String?;
        final peer = tmp == null ? null : _tmpPeer.remove(tmp);
        if (peer != null) {
          final i = thread(peer).indexWhere((x) => x.tmp == tmp);
          if (i >= 0) thread(peer)[i].id = ((m['id'] as num?) ?? -1).toInt();
          notifyListeners();
        }
      case 'dmHistory':
        _onHistory(m);
      case 'dmRead':
        final w = m['with'] as String?;
        if (w != null) {
          peerReadUpTo[w] = ((m['upTo'] as num?) ?? 0).toInt();
          notifyListeners();
        }
      case 'typing':
        final from = m['from'] as String?;
        if (from == null) break;
        _typingOff[from]?.cancel();
        if (m['on'] == true) {
          typingPeers.add(from);
          _typingOff[from] = Timer(const Duration(seconds: 4), () {
            typingPeers.remove(from);
            notifyListeners();
          });
        } else {
          typingPeers.remove(from);
        }
        notifyListeners();
      case 'msgReact':
        final id = ((m['id'] as num?) ?? -1).toInt();
        final from = m['from'] as String?;
        final e = m['e'] as String?;
        if (from == null) break;
        for (final t in threads.values) {
          final i = t.indexWhere((x) => x.id == id);
          if (i >= 0) {
            if (e == null) {
              t[i].reactions.remove(from);
            } else {
              t[i].reactions[from] = e;
            }
            notifyListeners();
            break;
          }
        }
    }
  }

  void _onDm(Map<String, dynamic>? raw) {
    if (raw == null) return;
    final from = (raw['from'] as String?) ?? '';
    if (from.isEmpty) return;
    final msg = _parseMsg(raw);
    final t = thread(from);
    if (t.any((x) => x.id == msg.id)) return;
    t.add(msg);
    if (activePeer == from) {
      NetworkClient.instance.dmRead(from, msg.id);
    } else {
      unreadTotal += 1;
    }
    NetworkClient.instance.chatsList(); // refresh previews/ordering
    notifyListeners();
  }

  void _onHistory(Map<String, dynamic> m) {
    final w = m['with'] as String?;
    if (w == null) return;
    final t = thread(w);
    final incoming = ((m['msgs'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => _parseMsg(e.cast<String, dynamic>()))
        .where((msg) => !t.any((x) => x.id == msg.id))
        .toList();
    t.insertAll(0, incoming);
    t.sort((a, b) {
      final ai = a.pending ? 1 << 40 : a.id;
      final bi = b.pending ? 1 << 40 : b.id;
      return ai.compareTo(bi);
    });
    for (final r in (m['reactions'] as List?) ?? const []) {
      if (r is List && r.length >= 3) {
        final i = t.indexWhere((x) => x.id == (r[0] as num).toInt());
        if (i >= 0) t[i].reactions[r[1] as String] = r[2] as String;
      }
    }
    hasMore[w] = m['more'] == true;
    notifyListeners();
  }

  Msg _parseMsg(Map<String, dynamic> raw) => Msg(
        id: ((raw['id'] as num?) ?? -1).toInt(),
        from: (raw['from'] as String?) ?? '',
        kind: (raw['kind'] as String?) ?? 'text',
        body: (raw['body'] as String?) ?? '',
        mediaId: (raw['mediaId'] as num?)?.toInt(),
        meta: ((raw['meta'] as Map?) ?? const {}).cast<String, dynamic>(),
        at: DateTime.tryParse((raw['at'] as String?) ?? '') ?? DateTime.now(),
      );

  List<ChatSummary> _parseChats(dynamic v) {
    return ((v as List?) ?? const []).whereType<Map>().map((e) {
      final c = e.cast<String, dynamic>();
      final peer = ((c['peer'] as Map?) ?? const {}).cast<String, dynamic>();
      final last = ((c['last'] as Map?) ?? const {}).cast<String, dynamic>();
      final kind = (last['kind'] as String?) ?? 'text';
      final body = (last['body'] as String?) ?? '';
      final preview = switch (kind) {
        'voice' => '🎤 voice note',
        'photo' => '📷 photo',
        'gif' => 'GIF',
        'invite' => '🎮 room invite',
        'call' => '📞 call',
        _ => body,
      };
      return ChatSummary(
        uid: (peer['uid'] as String?) ?? '',
        name: (peer['name'] as String?) ?? 'someone',
        hue: ((peer['hue'] as num?) ?? 210).toDouble(),
        photoId: (peer['photoId'] as num?)?.toInt(),
        preview: preview,
        lastAt: DateTime.tryParse((last['at'] as String?) ?? ''),
        lastFromMe: last['sender'] == _myUid,
        unread: ((c['unread'] as num?) ?? 0).toInt(),
        pinned: c['pinned'] == true,
        online: c['online'] == true,
      );
    }).where((c) => c.uid.isNotEmpty).toList();
  }

  // ---- verbs ---------------------------------------------------------------
  void sendText(String to, String body) => _send(to, 'text', body);
  void sendInvite(String to, String code) => _send(to, 'invite', code);
  void sendGif(String to, String url) => _send(to, 'gif', url);

  void sendMedia(String to, String kind, int mediaId, {Map<String, dynamic> meta = const {}}) =>
      _send(to, kind, '', mediaId: mediaId, meta: meta);

  void _send(String to, String kind, String body,
      {int? mediaId, Map<String, dynamic> meta = const {}}) {
    final tmp = 'tmp${_tmpSeq++}';
    _tmpPeer[tmp] = to;
    thread(to).add(Msg(
      id: -1, tmp: tmp, from: _myUid, kind: kind, body: body,
      mediaId: mediaId, meta: meta, at: DateTime.now(),
    ));
    NetworkClient.instance.dm(to, kind, body, tmp: tmp, mediaId: mediaId,
        meta: meta.isEmpty ? null : meta);
    notifyListeners();
  }

  void openThread(String uid) {
    activePeer = uid;
    if (thread(uid).isEmpty) NetworkClient.instance.dmHistory(uid);
    markRead(uid);
  }

  void loadOlder(String uid) {
    final t = thread(uid);
    final oldest = t.where((x) => !x.pending).map((x) => x.id).fold<int?>(
        null, (a, b) => a == null || b < a ? b : a);
    if (oldest != null) NetworkClient.instance.dmHistory(uid, before: oldest);
  }

  void markRead(String uid) {
    final t = thread(uid);
    final lastIn = t.lastWhere((x) => x.from == uid && !x.pending,
        orElse: () => Msg(id: 0, from: '', kind: 'text', body: '', at: DateTime.now()));
    if (lastIn.id > 0) NetworkClient.instance.dmRead(uid, lastIn.id);
    NetworkClient.instance.chatsList();
  }

  void closeThread() {
    activePeer = null;
    NetworkClient.instance.chatsList();
  }

  void react(Msg msg, String? emoji) {
    if (msg.pending) return;
    NetworkClient.instance.reactMsg(msg.id, emoji);
  }
}
