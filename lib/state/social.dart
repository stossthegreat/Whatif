import 'package:flutter/foundation.dart';
import '../net/network_client.dart';

/// A person on your side of the graph — friend, request, or celebration.
class FriendInfo {
  FriendInfo({
    required this.uid,
    required this.name,
    required this.hue,
    this.photoId,
    this.title,
    this.tier = 0,
    this.pinned = false,
    this.online = false,
    this.lastSeen,
  });

  factory FriendInfo.fromMap(Map<String, dynamic> m) => FriendInfo(
        uid: (m['uid'] as String?) ?? '',
        name: (m['name'] as String?) ?? 'someone',
        hue: ((m['hue'] as num?) ?? 210).toDouble(),
        photoId: (m['photoId'] as num?)?.toInt(),
        title: m['title'] as String?,
        tier: ((m['tier'] as num?) ?? 0).toInt(),
        pinned: m['pinned'] == true,
        online: m['online'] == true,
        lastSeen: m['lastSeen'] as String?,
      );

  final String uid;
  final String name;
  final double hue;
  final int? photoId;
  final String? title;
  int tier; // 0 friend · 1 close · 2 favourite
  bool pinned;
  bool online;
  String? lastSeen;
}

/// Someone you met but haven't matched with (the "accidentally pressed Next"
/// recovery — a headline feature, not a footnote).
class RecentMeet {
  RecentMeet({required this.uid, required this.name, required this.hue, this.photoId, this.metAt});

  factory RecentMeet.fromMap(Map<String, dynamic> m) => RecentMeet(
        uid: (m['uid'] as String?) ?? '',
        name: (m['name'] as String?) ?? 'someone',
        hue: ((m['hue'] as num?) ?? 210).toDouble(),
        photoId: (m['photoId'] as num?)?.toInt(),
        metAt: DateTime.tryParse((m['metAt'] as String?) ?? ''),
      );

  final String uid;
  final String name;
  final double hue;
  final int? photoId;
  final DateTime? metAt;

  String get ago {
    final t = metAt;
    if (t == null) return 'recently';
    final d = DateTime.now().difference(t.toLocal());
    if (d.inMinutes < 2) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    if (d.inDays == 1) return 'yesterday';
    return '${d.inDays}d ago';
  }
}

/// One pending "Would you meet them again?" question.
class RatePromptItem {
  RatePromptItem({required this.cellId, required this.uid, required this.name, required this.hue, required this.secs});
  final String cellId;
  final String uid;
  final String name;
  final double hue;
  final int secs;
}

/// An incoming call, ringing right now.
class IncomingCall {
  IncomingCall({required this.callId, required this.uid, required this.name, required this.hue, required this.video});
  final String callId;
  final String uid;
  final String name;
  final double hue;
  final bool video;
}

/// One line of friend activity for the Home feed.
class FeedItem {
  FeedItem({required this.kind, required this.uid, required this.name, required this.x, required this.at});
  final String kind; // badge · title · party
  final String uid;
  final String name;
  final String x;
  final DateTime at;
}

/// The social layer's client state: friends, requests, recently met, pending
/// rating prompts, and the match-celebration queue. Fed by the server over
/// the existing WS event stream.
class SocialState extends ChangeNotifier {
  SocialState._();
  static final SocialState instance = SocialState._();

  List<FriendInfo> friends = [];
  List<FriendInfo> reqsIn = [];
  List<FriendInfo> reqsOut = [];

  /// Whether the server can actually persist (db online + current deploy).
  /// True until proven otherwise so the banner never flashes during connect.
  bool serverStorage = true;
  bool welcomed = false;
  List<RecentMeet> recent = [];
  final List<RatePromptItem> pendingRates = [];
  final List<FriendInfo> celebrations = []; // matched / accepted, queued FIFO
  IncomingCall? incomingCall;
  final List<FeedItem> feed = []; // rolling friend activity (max 12, in-memory)
  String? eventKey;               // active seasonal event
  String? eventName;
  DateTime? eventEndsAt;
  String? lastBadgeLabel;         // for the toast

  bool _attached = false;

  int get reqCount => reqsIn.length;
  List<FriendInfo> get onlineFriends => friends.where((f) => f.online).toList();

  void attach() {
    if (_attached) return;
    _attached = true;
    NetworkClient.instance.events.listen(_onNet);
  }

  void _onNet(Map<String, dynamic> m) {
    switch (m['t']) {
      case 'welcome':
        // fresh connection — pull the graph. Also read the server's honest
        // capability flags: social=false means NOTHING can save (no
        // DATABASE_URL, or a deploy older than the social layer) — the UI
        // shows a loud banner instead of silently eating every action.
        final feats = (m['features'] as Map?)?.cast<String, dynamic>();
        serverStorage = feats?['social'] == true;
        welcomed = true;
        notifyListeners();
        NetworkClient.instance.friendsSnapshot();
      case 'err':
        if (m['code'] == 'noDb') {
          serverStorage = false;
          welcomed = true;
          notifyListeners();
        }
      case 'friends':
        friends = _list(m['friends']).map(FriendInfo.fromMap).toList()
          ..sort((a, b) => (b.online ? 1 : 0) - (a.online ? 1 : 0));
        reqsIn = _list(m['reqsIn']).map(FriendInfo.fromMap).toList();
        reqsOut = _list(m['reqsOut']).map(FriendInfo.fromMap).toList();
        recent = _list(m['recent']).map(RecentMeet.fromMap).toList();
        notifyListeners();
      case 'friendOnline':
        final uid = m['uid'] as String?;
        final i = friends.indexWhere((f) => f.uid == uid);
        if (i >= 0) {
          friends[i].online = m['on'] == true;
          notifyListeners();
        }
      case 'ratePrompt':
        final cell = (m['cell'] as String?) ?? '';
        for (final p in _list(m['people'])) {
          final uid = (p['uid'] as String?) ?? '';
          if (uid.isEmpty || pendingRates.any((r) => r.uid == uid && r.cellId == cell)) continue;
          pendingRates.add(RatePromptItem(
            cellId: cell,
            uid: uid,
            name: (p['name'] as String?) ?? 'someone',
            hue: ((p['hue'] as num?) ?? 210).toDouble(),
            secs: ((p['secs'] as num?) ?? 0).toInt(),
          ));
        }
        notifyListeners();
      case 'matched':
      case 'friendAccepted':
        celebrations.add(FriendInfo.fromMap(m.cast<String, dynamic>()));
        notifyListeners();
      case 'friendRemoved':
        friends.removeWhere((f) => f.uid == m['uid']);
        notifyListeners();
      case 'call':
        final from = ((m['from'] as Map?) ?? const {}).cast<String, dynamic>();
        incomingCall = IncomingCall(
          callId: (m['callId'] as String?) ?? '',
          uid: (from['uid'] as String?) ?? '',
          name: (from['name'] as String?) ?? 'someone',
          hue: ((from['hue'] as num?) ?? 210).toDouble(),
          video: m['video'] == true,
        );
        notifyListeners();
      case 'callState':
        final st = m['state'] as String?;
        if (st == 'cancelled' || st == 'timeout') {
          incomingCall = null;
          notifyListeners();
        }
      case 'feedEvent':
        feed.insert(0, FeedItem(
          kind: (m['kind'] as String?) ?? '',
          uid: (m['uid'] as String?) ?? '',
          name: (m['name'] as String?) ?? 'someone',
          x: (m['x'] as String?) ?? '',
          at: DateTime.now(),
        ));
        while (feed.length > 12) {
          feed.removeLast();
        }
        notifyListeners();
      case 'event':
        eventKey = m['key'] as String?;
        eventName = m['name'] as String?;
        eventEndsAt = DateTime.tryParse((m['endsAt'] as String?) ?? '');
        notifyListeners();
      case 'badge':
        lastBadgeLabel = m['label'] as String?;
        notifyListeners();
    }
  }

  void clearIncomingCall() {
    incomingCall = null;
    notifyListeners();
  }

  void clearBadgeToast() {
    lastBadgeLabel = null;
  }

  List<Map<String, dynamic>> _list(dynamic v) =>
      ((v as List?) ?? const []).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();

  // ---- verbs ---------------------------------------------------------------
  void rate(RatePromptItem item, int score) {
    NetworkClient.instance.rate(item.uid, item.cellId, score);
    pendingRates.remove(item);
    notifyListeners();
  }

  void skipRate(RatePromptItem item) {
    pendingRates.remove(item);
    notifyListeners();
  }

  void popCelebration() {
    if (celebrations.isNotEmpty) celebrations.removeAt(0);
    notifyListeners();
  }

  void request(String uid) => NetworkClient.instance.friendRequest(uid);
  void accept(String uid) => NetworkClient.instance.friendAccept(uid);
  void decline(String uid) => NetworkClient.instance.friendDecline(uid);
  void unfriend(String uid) {
    friends.removeWhere((f) => f.uid == uid);
    NetworkClient.instance.unfriend(uid);
    notifyListeners();
  }

  void setTier(FriendInfo f, int tier) {
    f.tier = tier;
    NetworkClient.instance.setTier(f.uid, tier);
    notifyListeners();
  }

  bool requested(String uid) => reqsOut.any((r) => r.uid == uid);
}
