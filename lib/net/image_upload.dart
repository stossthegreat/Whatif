import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'api_client.dart';
import 'network_client.dart';

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
///
/// For avatars this ALSO uploads a small thumbnail and registers it. Explore
/// shows a grid of faces, and pulling full-size avatars for every cell is by
/// far the most expensive thing the backend would do — a ~25KB derivative
/// makes a page of cards cheaper than a single full photo.
Future<int?> uploadPickedImage(XFile x, {required String kind}) async {
  final bytes = await compressForUpload(x);
  if (bytes == null) return null;
  final id = await Api.uploadMedia(bytes, kind: kind);
  if (id != null && kind == 'avatar') {
    unawaited(_uploadThumb(x));
  }
  return id;
}

Future<void> _uploadThumb(XFile x) async {
  try {
    final thumb = await FlutterImageCompress.compressWithFile(
      x.path, minWidth: 256, minHeight: 256, quality: 72,
      format: CompressFormat.jpeg,
    );
    if (thumb == null) return;
    // kind MUST be 'thumb', never 'avatar' — the avatar kind repoints
    // photo_media_id and deletes the previous blob, so uploading the
    // derivative as a second avatar destroyed the full photo (pre-b61 bug).
    // The server sets users.photo_thumb_id itself; no profile round-trip.
    await Api.uploadMedia(thumb, kind: 'thumb');
  } catch (_) {/* the full avatar still works — thumbs are an optimisation */}
}
