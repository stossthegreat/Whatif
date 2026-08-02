import 'package:firebase_messaging/firebase_messaging.dart';
import '../firebase_config.dart';
import '../net/network_client.dart';

/// Push registration — ask once, hand the token to the server, keep it fresh.
/// Entirely fail-soft: unconfigured Firebase, denied permission, or a missing
/// APNs key just means no pushes, never a crash.
class Push {
  Push._();
  static bool _inited = false;
  static String? _token;

  static Future<void> init() async {
    if (_inited || !FirebaseCfg.configured) return;
    _inited = true;
    try {
      final fm = FirebaseMessaging.instance;
      final settings = await fm.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      final t = await fm.getToken();
      if (t != null) {
        _token = t;
        NetworkClient.instance.pushToken(t);
      }
      fm.onTokenRefresh.listen((t) {
        _token = t;
        NetworkClient.instance.pushToken(t);
      });
    } catch (_) {/* push is a bonus, never a blocker */}
  }

  /// Re-send the cached token (after a socket reconnect the server may be
  /// talking to a fresh connection that never saw it).
  static void resend() {
    final t = _token;
    if (t != null) NetworkClient.instance.pushToken(t);
  }
}
