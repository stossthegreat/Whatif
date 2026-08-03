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

  bool get connected => _ch != null;

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
      // Keychain-backed hardware id: what makes a ban survive a reinstall
      if (DeviceId.value != null) 'deviceId': DeviceId.value,
    });
  }

  void _retry() {
    _ch = null;
    if (!_closing && AppConfig.isLive) {
      Future<void>.delayed(const Duration(seconds: 2), connect);
    }
  }

  void send(Map<String, dynamic> m) {
    try {
      _ch?.sink.add(jsonEncode(m));
    } catch (_) {}
  }

  void play([String mode = 'hang']) => send({'t': 'play', 'mode': mode});
  void next() => send({'t': 'next'});
  void leaveCell() => send({'t': 'leave'});
  void host() => send({'t': 'host'});
  void joinParty(String code) => send({'t': 'joinParty', 'code': code});
  void startParty() => send({'t': 'startParty'});
  void leaveParty() => send({'t': 'leaveParty'});
  void answer(int round, dynamic v) => send({'t': 'answer', 'round': round, 'v': v});
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
  void callAccept(String callId) => send({'t': 'callAccept', 'callId': callId});
  void callDecline(String callId) => send({'t': 'callDecline', 'callId': callId});
  void rtcSignal(String to, Map<String, dynamic> d) => send({'t': 'rtc', 'to': to, 'd': d});
}
