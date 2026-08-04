import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'network_client.dart';

/// The HTTP side of the backend: media uploads, media URLs (token embedded as
/// a query param so plain image/audio loaders work), GIF search. Fail-soft —
/// anything that breaks returns null/empty and the UI simply doesn't show it.
class Api {
  Api._();

  static String get _base => NetworkClient.instance.httpBase;
  static String get _token => NetworkClient.instance.httpToken;
  static bool get ready => _base.isNotEmpty && _token.isNotEmpty;

  /// Why the last uploadMedia returned null — surfaced in snackbars so a
  /// failing photo tells the truth instead of a generic shrug.
  static String? lastUploadError;

  /// The server validates magic bytes, so the declared mime must match what
  /// the picker ACTUALLY returned (iOS can hand back PNG where JPEG was
  /// assumed — that mismatch used to 415 the upload).
  static String sniffImageMime(Uint8List b) {
    if (b.length > 2 && b[0] == 0x89 && b[1] == 0x50) return 'image/png';
    if (b.length > 12 && b[8] == 0x57 && b[9] == 0x45 && b[10] == 0x42 && b[11] == 0x50) {
      return 'image/webp';
    }
    return 'image/jpeg';
  }

  /// Upload bytes; returns the media id or null. Pass [mime] for audio;
  /// images are sniffed from the bytes when it's omitted.
  static Future<int?> uploadMedia(Uint8List bytes, {required String kind, String? mime}) async {
    if (!ready) {
      lastUploadError = 'not connected yet — give it a second and retry';
      return null;
    }
    try {
      final r = await http.post(
        Uri.parse('$_base/api/media?kind=$kind'),
        headers: {'content-type': mime ?? sniffImageMime(bytes), 'authorization': 'Bearer $_token'},
        body: bytes,
      ).timeout(const Duration(seconds: 20));
      if (r.statusCode == 404) {
        // old server without the media API — tell it like it is
        lastUploadError = 'server update pending — photos land after the next deploy';
        return null;
      }
      if (r.statusCode != 200) {
        lastUploadError = 'upload failed (${r.statusCode}) — try a smaller photo';
        return null;
      }
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      lastUploadError = null;
      return (j['id'] as num?)?.toInt();
    } catch (_) {
      lastUploadError = 'no connection — check your signal and retry';
      return null;
    }
  }

  /// URL for a media id — loadable by Image.network / audioplayers directly.
  static String mediaUrl(int id) => '$_base/api/media/$id?tk=${Uri.encodeComponent(_token)}';

  /// GIF search via the server's Tenor proxy.
  static Future<List<Gif>> searchGifs(String q) async {
    if (!ready || !NetworkClient.instance.gifsEnabled) return const [];
    try {
      final r = await http.get(
        Uri.parse('$_base/api/gifs?q=${Uri.encodeComponent(q)}&tk=${Uri.encodeComponent(_token)}'),
      ).timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return const [];
      final j = jsonDecode(r.body);
      if (j is! List) return const [];
      return j.whereType<Map>().map((g) => Gif(
            tinyUrl: (g['tinyUrl'] as String?) ?? '',
            url: (g['url'] as String?) ?? '',
            w: ((g['w'] as num?) ?? 200).toInt(),
            h: ((g['h'] as num?) ?? 200).toInt(),
          )).where((g) => g.tinyUrl.isNotEmpty).toList();
    } catch (_) {
      return const [];
    }
  }

  /// Ask the server to re-check this account's subscription with RevenueCat
  /// right now. Called straight after a purchase or a restore so access never
  /// waits on a webhook. Returns true when the entitlement is live.
  static Future<bool> syncPlus() async {
    if (!ready) return false;
    try {
      final r = await http.post(
        Uri.parse('$_base/api/iap/sync'),
        headers: {'authorization': 'Bearer $_token'},
      ).timeout(const Duration(seconds: 20));
      if (r.statusCode != 200) return false;
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      return j['plus'] == true;
    } catch (_) {
      return false;
    }
  }
}

class Gif {
  const Gif({required this.tinyUrl, required this.url, required this.w, required this.h});
  final String tinyUrl;
  final String url;
  final int w;
  final int h;
}
