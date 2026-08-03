import 'package:flutter/services.dart';

/// The device's stable id, read once per launch from the native Keychain.
///
/// SharedPreferences dies with the app, so our random uid gave a banned user a
/// clean slate every reinstall. The Keychain survives deletion, so this is the
/// anchor that makes a ban mean something.
///
/// Fail-soft everywhere: no channel (Android, simulator quirks, Keychain
/// refusal) simply returns null, `hello` omits the field, and the server falls
/// back to account-only enforcement.
class DeviceId {
  DeviceId._();

  static const _ch = MethodChannel('rivlr/native');
  static String? _cached;
  static bool _tried = false;

  /// Cached after the first successful read — the value never changes for the
  /// life of an install.
  static String? get value => _cached;

  static Future<String?> load() async {
    if (_tried) return _cached;
    _tried = true;
    try {
      _cached = await _ch.invokeMethod<String>('deviceId');
    } catch (_) {
      _cached = null; // platform without the channel — carry on unbound
    }
    return _cached;
  }
}
