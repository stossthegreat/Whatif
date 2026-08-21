import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config.dart';
import '../core/device_id.dart';
import '../state/session.dart';

/// Thin WebSocket matchmaking client (pure Dart). Connects to the Railway
/// server, streams decoded events, and exposes the four verbs. Auto-reconnects.
/// Inert unless [AppConfig.isLive].
class NetworkClient {
  NetworkClient._();
  static final NetworkClient instance = NetworkClient._();

  WebSocketChannel? _ch;
  final StreamController<Map<String, dynamic>> _events =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get events => _events.stream;

  String? myId;
  String? myName;
  double? myHue;
  // HTTP surface (media uploads/fetch) — minted fresh in every welcome
  String httpToken = '';
  String httpBase = '';
  bool mediaEnabled = false;
  bool gifsEnabled = false;
  bool _closing = false;
  bool _welcomed = false;

  bool get connected => _ch != null;

  /// Intents that must SURVIVE a reconnect gap. Live-room verbs are
  /// deliberately absent — replaying a stale answer/vote/play after a 2s
  /// blackout would be wrong; losing a friend request or a message is worse.
  static const _queueable = {
    'dm', 'dmRead', 'friendRequest', 'friendAccept', 'friendDecline',
    'friendsSnapshot', 'chats', 'chatHistory', 'setProfile', 'pinChat',
    'rate', 'setTier',
  };
  final List<Map<String, dynamic>> _outbox = [];

  void _flushOutbox() {
    if (_ch == null || _outbox.isEmpty) return;
    final pending = List<Map<String, dynamic>>.from(_outbox);
    _outbox.clear();
    for (final m in pending) {
      try {
        _ch?.sink.add(jsonEncode(m));
      } catch (_) {
        _outbox.add(m);
      }
    }
  }

  void connect() {
    if (_ch != null || !AppConfig.isLive) return;
    _closing = false;
    final ch = WebSocketChannel.connect(Uri.parse(AppConfig.backend));
    _ch = ch;
    ch.stream.listen(
      (data) {
        try {
          final m = jsonDecode(data as String) as Map<String, dynamic>;
          if (m['t'] == 'welcome') {
            myId = m['id'] as String?;
            myName = m['name'] as String?;
            myHue = (m['hue'] as num?)?.toDouble();
            // reinstall recovery: the server resolved our Apple id to the
            // account's canonical uid — adopt it and everything comes back
            final wUid = m['uid'] as String?;
            if (wUid != null && wUid != AppSession.instance.myUid) {
              AppSession.instance.adoptUid(wUid);
            }
            final http = (m['http'] as Map?)?.cast<String, dynamic>();
            httpToken = (http?['token'] as String?) ?? '';
            final base = (http?['base'] as String?) ?? '';
            // derive from the ws url when the server doesn't know its public base
            httpBase = base.isNotEmpty
                ? base
                : AppConfig.backend
                    .replaceFirst('wss://', 'https://')
                    .replaceFirst('ws://', 'http://')
                    .replaceFirst(RegExp(r'/ws$'), '');
            final feats = (m['features'] as Map?)?.cast<String, dynamic>();
            mediaEnabled = feats?['media'] == true;
            gifsEnabled = feats?['gifs'] == true;
            // heal a stale local photo id — the server's word is the truth
            // (pre-b61 phones can hold the id of a deleted blob)
            final photo = (m['photo'] as Map?)?.cast<String, dynamic>();
            if (photo != null) {
              AppSession.instance.healPhotoId((photo['id'] as num?)?.toInt());
            }
            // Rivler+ — the server is the only authority on what you've paid
            // for and which filter is switched on
            final plus = (m['plus'] as Map?)?.cast<String, dynamic>();
            if (plus != null) {
              AppSession.instance.setPlus(
                active: plus['active'] == true,
                until: DateTime.tryParse((plus['until'] as String?) ?? ''),
                meet: plus['meet'] as String?,
              );
            }
            // the socket is fully open for business — release anything the
            // reconnect gap held back
            _welcomed = true;
            _flushOutbox();
          } else if (m['t'] == 'plus') {
            // pushed the moment RevenueCat tells the server something changed
            AppSession.instance.setPlus(
              active: m['active'] == true,
              until: DateTime.tryParse((m['until'] as String?) ?? ''),
              meet: m['meet'] as String?,
            );
          } else if (m['t'] == 'meetPref') {
            AppSession.instance.setPlus(
              active: AppSession.instance.plus,
              until: AppSession.instance.plusUntil,
              meet: m['meet'] as String?,
            );
          }
          _events.add(m);
        } catch (_) {/* ignore malformed */}
      },
      onDone: _retry,
      onError: (_) => _retry(),
      cancelOnError: true,
    );
    hello();
  }

  /// (Re)introduce ourselves. Called on connect, and again whenever identity
  /// changes mid-session (e.g. Sign in with Apple upgrading the uid).
  void hello() {
    final s = AppSession.instance;
    send({
      't': 'hello',
      'uid': s.myUid,
      'name': s.myHandle,
      'gender': s.gender,
      'meet': s.lookingFor ?? 'Everyone',
      'vibes': s.myVibes,
      'tz': DateTime.now().timeZoneOffset.inMinutes,
      if (s.appleUserId != null) 'appleId': s.appleUserId,
      // signed proof of the Apple identity — the server ignores the bare id
      if (s.appleToken != null) 'appleToken': s.appleToken,
      if (s.googleUserId != null) 'googleId': s.googleUserId,
      // signed proof of the Google identity — same rule, same shape
      if (s.googleToken != null) 'googleToken': s.googleToken,
      // Keychain-backed hardware id: what makes a ban survive a reinstall
      if (DeviceId.value != null) 'deviceId': DeviceId.value,
    });
  }

  void _retry() {
    _ch = null;
    _welcomed = false;
    if (!_closing && AppConfig.isLive) {
      Future<void>.delayed(const Duration(seconds: 2), connect);
    }
  }

  /// Fire-and-forget for live verbs; store-and-forward for social intents.
  /// The pre-b61 version dropped EVERYTHING silently while the 2s reconnect
  /// window was open — the root of "friend requests sometimes don't work".
  void send(Map<String, dynamic> m) {
    final canQueue = _queueable.contains(m['t']);
    if (_ch == null || (!_welcomed && canQueue && m['t'] != 'hello')) {
      if (canQueue) {
        _outbox.add(m);
        while (_outbox.length > 50) {
          _outbox.removeAt(0);
        }
      }
      return;
    }
    try {
      _ch?.sink.add(jsonEncode(m));
    } catch (_) {
      if (canQueue) _outbox.add(m);
    }
  }

  void play([String mode = 'hang']) => send({'t': 'play', 'mode': mode});
  void next() => send({'t': 'next'});
  void leaveCell() => send({'t': 'leave'});
  void host() => send({'t': 'host'});
  void joinParty(String code) => send({'t': 'joinParty', 'code': code});
  void startParty() => send({'t': 'startParty'});
  void leaveParty() => send({'t': 'leaveParty'});
  void answer(int round, dynamic v) => send({'t': 'answer', 'round': round, 'v': v});
  /// Judge Says: the judge's pick, sent AFTER the vote already closed —
  /// a distinct round-trip from the normal answer() one.
  void judgePick(int round, int choice) => send({'t': 'judgePick', 'round': round, 'choice': choice});
  void vote(String e) => send({'t': 'vote', 'e': e});
  void spinWheel() => send({'t': 'spinWheel'});
  void pickGame([String? name]) =>
      send({'t': 'pickGame', if (name != null) 'name': name});
  void react(String e) => send({'t': 'react', 'e': e});
  void report(String target, {String reason = 'other'}) =>
      send({'t': 'report', 'target': target, 'reason': reason});
  void reportPhoto(String target, int? mediaId, {String reason = 'nudity'}) => send({
        't': 'reportPhoto', 'target': target, 'reason': reason,
        if (mediaId != null) 'mediaId': mediaId,
      });
  void block(String target) => send({'t': 'block', 'target': target});
  void save(String target) => send({'t': 'save', 'target': target});
  void unsave(String target) => send({'t': 'unsave', 'target': target});
  void unblock(String target) => send({'t': 'unblock', 'target': target});
  void pushToken(String token) => send({'t': 'pushToken', 'token': token});
  void deleteAccount() => send({'t': 'deleteAccount'});

  // ---- social layer ---------------------------------------------------------
  void rate(String target, String cell, int score) =>
      send({'t': 'rate', 'target': target, 'cell': cell, 'score': score});
  void friendRequest(String target) => send({'t': 'friendRequest', 'target': target});
  void friendAccept(String target) => send({'t': 'friendAccept', 'target': target});
  void friendDecline(String target) => send({'t': 'friendDecline', 'target': target});
  void unfriend(String target) => send({'t': 'unfriend', 'target': target});
  void setTier(String target, int tier) => send({'t': 'setTier', 'target': target, 'tier': tier});
  void pinChat(String target, bool on) => send({'t': 'pinChat', 'target': target, 'on': on});
  void friendsSnapshot() => send({'t': 'friends'});

  /// Pull a friend into the room you're hosting. The server rings them if
  /// they're connected and answers 'partyRingSent' either way, so we know
  /// whether to fall back to a DM'd code.
  void partyRing(String uid) => send({'t': 'partyRing', 'to': uid});
  void traitVote(String target, String trait) =>
      send({'t': 'traitVote', 'target': target, 'trait': trait});

  // ---- messaging ------------------------------------------------------------
  void dm(String to, String kind, String body, {String? tmp, int? mediaId, Map<String, dynamic>? meta}) =>
      send({
        't': 'dm', 'to': to, 'kind': kind, 'body': body,
        if (tmp != null) 'tmp': tmp,
        if (mediaId != null) 'mediaId': mediaId,
        if (meta != null) 'meta': meta,
      });
  void dmHistory(String withUid, {int? before}) =>
      send({'t': 'dmHistory', 'with': withUid, if (before != null) 'before': before});
  void dmRead(String withUid, int upTo) => send({'t': 'dmRead', 'with': withUid, 'upTo': upTo});
  void typing(String to, bool on) => send({'t': 'typing', 'to': to, 'on': on});
  void reactMsg(int id, String? e) => send({'t': 'reactMsg', 'id': id, 'e': e});
  void chatsList() => send({'t': 'chats'});
  void profile([String? uid]) => send({'t': 'profile', if (uid != null) 'uid': uid});
  void setProfile(Map<String, dynamic> fields) => send({'t': 'setProfile', ...fields});
  void titles() => send({'t': 'titles'});
  void setTitle(String title) => send({'t': 'setTitle', 'title': title});
  void callInvite(String to, {required bool video}) =>
      send({'t': 'callInvite', 'to': to, 'video': video});

  // ---- explore --------------------------------------------------------------
  void explore() => send({'t': 'explore'});
  void searchUsers(String q) => send({'t': 'searchUsers', 'q': q});

  /// The paid gender filter. The server rejects this with `needPlus` unless
  /// the subscription is live — the client never decides entitlement.
  void meetPref(String meet) => send({'t': 'meetPref', 'meet': meet});

  /// Who rated you Friend+ and is waiting on you. Free accounts get a count,
  /// Plus gets the faces.
  void likesMe() => send({'t': 'likesMe'});

  /// Widen to everyone for ONE room. The saved filter is untouched — the
  /// next search goes back to what they chose.
  void widenOnce() => send({'t': 'widenOnce'});

  /// Ring someone from the Explore grid. Same machinery as a friend call, but
  /// origin 'explore' lets it reach strangers and forms a NORMAL room (games,
  /// P2P) instead of a private call cell.
  void meetInvite(String to) =>
      send({'t': 'callInvite', 'to': to, 'origin': 'explore', 'video': true});
  void callAccept(String callId) => send({'t': 'callAccept', 'callId': callId});
  void callDecline(String callId) => send({'t': 'callDecline', 'callId': callId});
  void rtcSignal(String to, Map<String, dynamic> d) => send({'t': 'rtc', 'to': to, 'd': d});
}
