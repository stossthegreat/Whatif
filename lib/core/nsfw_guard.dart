import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import '../net/api_client.dart';
import 'analytics.dart';

/// LIVE VIDEO SAFETY — the thing that blurs the screen when the other person
/// goes naked.
///
/// How it works, and what it deliberately does NOT do:
///
/// Every few seconds a single frame of the OTHER person's video is captured
/// from the widget tree, shrunk to a thumbnail, and checked. If it comes back
/// flagged, their video is blurred on this phone immediately and the viewer
/// is asked what to do. Nothing is written to disk, nothing is uploaded to
/// storage, nothing is kept — the frame exists for the length of one request
/// and is discarded. "We never record your video" stays true, because a scan
/// that keeps nothing is not a recording.
///
/// Three design decisions worth stating plainly:
///
/// 1. IT BLURS, IT DOESN'T ACCUSE. A classifier will occasionally flag a bare
///    shoulder or a bad frame. Blurring with a "show anyway" escape is
///    recoverable; auto-banning on a guess is not. Only repeated hits file a
///    report on their own.
///
/// 2. IT FAILS OPEN. No API key, a timeout, a black frame — all mean "not
///    flagged". A safety feature that kills the call whenever it can't reach
///    an API does more damage than the thing it guards against, and report +
///    block sit underneath it regardless.
///
/// 3. IT NEVER BLOCKS THE VIDEO PATH. Capture and upload happen off to the
///    side; the room does not wait on them. A slow network makes the check
///    late, never the call stuttery.
class NsfwGuard {
  NsfwGuard._();
  static final NsfwGuard instance = NsfwGuard._();

  /// How often to sample. Fast enough that nobody gets more than a few
  /// seconds of exposure, slow enough to be invisible on battery and data
  /// (a 224px JPEG is roughly 8-12KB, so this is ~4KB/minute).
  static const _interval = Duration(seconds: 3);

  /// A flag decays: one bad frame shouldn't blur someone for the rest of the
  /// room if they've since covered up. Two consecutive CLEAN frames lift it.
  static const _clearAfterCleanFrames = 2;

  /// Consecutive flags before we file a report without being asked. One is a
  /// maybe; three in a row over ~9 seconds is not an accident.
  static const _reportAfterHits = 3;

  Timer? _timer;
  GlobalKey? _key;
  bool _busy = false;
  int _cleanRun = 0;
  int _hitRun = 0;

  /// Set when the current remote video should be covered.
  final ValueNotifier<bool> blurred = ValueNotifier<bool>(false);

  /// True once the viewer has chosen "show anyway" for this person — their
  /// call, and it sticks until the room changes.
  bool _override = false;

  /// Fired when the guard decides this needs reporting on its own.
  void Function()? onAutoReport;

  /// Begin watching the widget behind [key]. Safe to call repeatedly.
  void watch(GlobalKey key, {void Function()? autoReport}) {
    if (!Api.ready) return; // no token, no scanning — and nothing to report to
    _key = key;
    onAutoReport = autoReport;
    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) => _tick());
  }

  /// Room over, or the peer changed. Clears every piece of state — a blur
  /// must never survive into the next person's room.
  void stop() {
    _timer?.cancel();
    _timer = null;
    _key = null;
    _busy = false;
    _cleanRun = 0;
    _hitRun = 0;
    _override = false;
    blurred.value = false;
  }

  /// The viewer chose to see it anyway. Stops covering, keeps scanning (so a
  /// later escalation still counts), and never asks again this room.
  void showAnyway() {
    _override = true;
    blurred.value = false;
  }

  Future<void> _tick() async {
    if (_busy) return; // a slow round trip must not queue up more work
    final key = _key;
    if (key == null) return;
    _busy = true;
    try {
      final jpeg = await _grabFrame(key);
      if (jpeg == null) return;
      final flagged = await Api.moderateFrame(jpeg);
      if (_key == null) return; // stopped while we were away
      if (flagged) {
        _cleanRun = 0;
        _hitRun++;
        if (!_override) blurred.value = true;
        Track.event('nsfw_frame_flagged', {'run': _hitRun});
        if (_hitRun == _reportAfterHits) onAutoReport?.call();
      } else {
        _hitRun = 0;
        if (++_cleanRun >= _clearAfterCleanFrames) blurred.value = false;
      }
    } catch (_) {
      // fail open, always
    } finally {
      _busy = false;
    }
  }

  /// Capture what's actually on screen for that widget and shrink it hard.
  /// 224px is what these classifiers look at anyway, so sending more would be
  /// paying for bandwidth the model throws away.
  Future<Uint8List?> _grabFrame(GlobalKey key) async {
    try {
      final obj = key.currentContext?.findRenderObject();
      if (obj is! RenderRepaintBoundary) return null;
      // a boundary that hasn't painted yet returns a blank image — skip the
      // round trip rather than asking whether black is nudity
      if (obj.debugNeedsPaint) return null;
      final full = await obj.toImage(pixelRatio: 0.35);
      final small = await _resize(full, 224);
      full.dispose();
      final data = await small.toByteData(format: ui.ImageByteFormat.png);
      small.dispose();
      return data?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<ui.Image> _resize(ui.Image src, int target) async {
    if (src.width <= target && src.height <= target) return src;
    final scale = target / (src.width > src.height ? src.width : src.height);
    final w = (src.width * scale).round().clamp(1, target);
    final h = (src.height * scale).round().clamp(1, target);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImageRect(
      src,
      Rect.fromLTWH(0, 0, src.width.toDouble(), src.height.toDouble()),
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      Paint()..filterQuality = FilterQuality.low,
    );
    return recorder.endRecording().toImage(w, h);
  }
}
