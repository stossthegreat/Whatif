import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'api_client.dart';

/// Any photo, any size. The picker hands over the full-resolution file and
/// this ladder steps it down until it fits the server's 1MB cap (target
/// 900KB for headroom). Output is always JPEG — which also converts iOS
/// HEIC — so Api.sniffImageMime stays truthful downstream.
const _fitBytes = 900 * 1024;
const _ladder = [(2048, 90), (1440, 80), (1080, 70), (960, 60)];

Future<Uint8List?> compressForUpload(XFile x) async {
  Uint8List? out;
  for (final (px, q) in _ladder) {
    try {
      out = await FlutterImageCompress.compressWithFile(
        x.path,
        minWidth: px,
        minHeight: px,
        quality: q,
        format: CompressFormat.jpeg,
      );
    } catch (_) {
      out = null;
    }
    if (out != null && out.length <= _fitBytes) return out;
  }
  // last rung even if slightly over — the server cap has 100KB of headroom;
  // if the native compressor failed entirely, fall back to the raw bytes and
  // let the server's honest 413 explain itself
  return out ?? await x.readAsBytes();
}

/// Compress + upload in one move; returns the media id or null (with the
/// reason in Api.lastUploadError).
Future<int?> uploadPickedImage(XFile x, {required String kind}) async {
  final bytes = await compressForUpload(x);
  if (bytes == null) return null;
  return Api.uploadMedia(bytes, kind: kind);
}
