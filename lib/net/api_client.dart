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

  /// Upload bytes; returns the media id or null.
  static Future<int?> uploadMedia(Uint8List bytes, {required String kind, required String mime}) async {
    if (!ready) return null;
    try {
      final r = await http.post(
        Uri.parse('$_base/api/media?kind=$kind'),
        headers: {'content-type': mime, 'authorization': 'Bearer $_token'},
        body: bytes,
      ).timeout(const Duration(seconds: 20));
      if (r.statusCode != 200) return null;
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      return (j['id'] as num?)?.toInt();
    } catch (_) {
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
}

class Gif {
  const Gif({required this.tinyUrl, required this.url, required this.w, required this.h});
  final String tinyUrl;
  final String url;
  final int w;
  final int h;
}
