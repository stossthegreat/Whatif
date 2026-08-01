import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config.dart';

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
          }
          _events.add(m);
        } catch (_) {/* ignore malformed */}
      },
      onDone: _retry,
      onError: (_) => _retry(),
      cancelOnError: true,
    );
    send({'t': 'hello'});
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

  void play() => send({'t': 'play'});
  void next() => send({'t': 'next'});
  void leaveCell() => send({'t': 'leave'});
  void answer(dynamic v) => send({'t': 'answer', 'v': v});
  void react(String e) => send({'t': 'react', 'e': e});
  void report(String target) => send({'t': 'report', 'target': target});
  void block(String target) => send({'t': 'block', 'target': target});
}
