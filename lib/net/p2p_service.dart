import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'network_client.dart';

/// Direct phone-to-phone video for 1:1 rooms — the Omegle architecture. The
/// server only relays signaling ({t:'rtc'}); media never touches anything we
/// pay for. STUN-only on purpose: the ~15% of networks that can't connect
/// directly simply FALL BACK to LiveKit (the caller provides onFailed), so
/// the worst case is exactly the app as it was before P2P existed.
///
/// AUDIO ROUTE — learned the hard way with LiveKit: a face-to-face app plays
/// through the LOUDSPEAKER. setSpeakerphoneOn(true) after capture, always.
class P2PService {
  P2PService._();
  static final P2PService instance = P2PService._();

  /// Bumps whenever connection/track state changes — UI listens like RtcService.rev.
  final ValueNotifier<int> rev = ValueNotifier<int>(0);

  rtc.RTCPeerConnection? _pc;
  rtc.MediaStream? _local;
  final localRenderer = rtc.RTCVideoRenderer();
  final remoteRenderer = rtc.RTCVideoRenderer();
  bool _renderersReady = false;

  bool attempting = false; // negotiating right now
  bool active = false;     // connected — P2P is carrying the room
  bool remoteReady = false;
  String? _peerId;
  int _session = 0; // guards stale async callbacks after dispose/retry
  Timer? _deadline;
  final List<Map<String, dynamic>> _iceQueue = [];
  bool _remoteDescSet = false;

  /// Set per-room by the caller: invoked ONCE if P2P can't (or stops) carrying
  /// the room — the fallback joins LiveKit exactly as before P2P existed.
  void Function()? onFailed;
  bool _failedFired = false;

  void _bump() => rev.value++;

  Future<void> _ensureRenderers() async {
    if (_renderersReady) return;
    await localRenderer.initialize();
    await remoteRenderer.initialize();
    _renderersReady = true;
  }

  /// Try to carry this 1:1 room directly. [offerer] must be true on exactly
  /// one side (decided deterministically by conn-id comparison).
  Future<void> attempt({required String peerId, required bool offerer}) async {
    await leave();
    final session = ++_session;
    attempting = true;
    active = false;
    remoteReady = false;
    _failedFired = false;
    _peerId = peerId;
    _remoteDescSet = false;
    _iceQueue.clear();
    _bump();

    try {
      await _ensureRenderers();
      final local = await rtc.navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': {
          'facingMode': 'user',
          'width': {'ideal': 960},
          'height': {'ideal': 1280},
          'frameRate': {'ideal': 24},
        },
      });
      if (session != _session) {
        for (final t in local.getTracks()) {
          t.stop();
        }
        return;
      }
      _local = local;
      localRenderer.srcObject = local;
      try {
        await rtc.Helper.setSpeakerphoneOn(true);
      } catch (_) {}

      final pc = await rtc.createPeerConnection({
        'iceServers': [
          {
            'urls': [
              'stun:stun.l.google.com:19302',
              'stun:stun1.l.google.com:19302',
            ]
          },
        ],
        'sdpSemantics': 'unified-plan',
      });
      if (session != _session) {
        await pc.close();
        return;
      }
      _pc = pc;
      for (final t in local.getTracks()) {
        await pc.addTrack(t, local);
      }
      pc.onTrack = (e) {
        if (session != _session) return;
        if (e.streams.isNotEmpty) {
          remoteRenderer.srcObject = e.streams[0];
          remoteReady = true;
          _bump();
        }
      };
      pc.onIceCandidate = (c) {
        if (session != _session || c.candidate == null) return;
        NetworkClient.instance.rtcSignal(peerId, {'kind': 'ice', 'cand': c.toMap()});
      };
      pc.onConnectionState = (s) {
        if (session != _session) return;
        if (s == rtc.RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          attempting = false;
          active = true;
          _deadline?.cancel();
          _bump();
        } else if (s == rtc.RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
            s == rtc.RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
          _fail();
        }
      };

      if (offerer) {
        final offer = await pc.createOffer({});
        if (session != _session) return;
        await pc.setLocalDescription(offer);
        NetworkClient.instance
            .rtcSignal(peerId, {'kind': 'offer', 'sdp': offer.sdp, 'type': offer.type});
      }

      // the patience window — direct or we go back to LiveKit
      _deadline?.cancel();
      _deadline = Timer(const Duration(seconds: 4), () {
        if (session == _session && !active) _fail();
      });
    } catch (_) {
      if (session == _session) _fail();
    }
  }

  /// Incoming {t:'rtc'} signaling from the peer (routed by app.dart).
  Future<void> onSignal(String from, Map<String, dynamic> d) async {
    final session = _session;
    final pc = _pc;
    if (pc == null || from != _peerId) return;
    try {
      switch (d['kind']) {
        case 'offer':
          await pc.setRemoteDescription(
              rtc.RTCSessionDescription(d['sdp'] as String?, d['type'] as String?));
          _remoteDescSet = true;
          await _drainIce();
          final answer = await pc.createAnswer({});
          if (session != _session) return;
          await pc.setLocalDescription(answer);
          NetworkClient.instance
              .rtcSignal(from, {'kind': 'answer', 'sdp': answer.sdp, 'type': answer.type});
        case 'answer':
          await pc.setRemoteDescription(
              rtc.RTCSessionDescription(d['sdp'] as String?, d['type'] as String?));
          _remoteDescSet = true;
          await _drainIce();
        case 'ice':
          final cand = (d['cand'] as Map?)?.cast<String, dynamic>();
          if (cand == null) return;
          if (_remoteDescSet) {
            await pc.addCandidate(rtc.RTCIceCandidate(
                cand['candidate'] as String?,
                cand['sdpMid'] as String?,
                (cand['sdpMLineIndex'] as num?)?.toInt()));
          } else {
            _iceQueue.add(cand); // ICE can arrive before the offer — hold it
          }
      }
    } catch (_) {
      if (session == _session) _fail();
    }
  }

  Future<void> _drainIce() async {
    final pc = _pc;
    if (pc == null) return;
    for (final cand in _iceQueue) {
      try {
        await pc.addCandidate(rtc.RTCIceCandidate(
            cand['candidate'] as String?,
            cand['sdpMid'] as String?,
            (cand['sdpMLineIndex'] as num?)?.toInt()));
      } catch (_) {}
    }
    _iceQueue.clear();
  }

  void _fail() {
    final cb = onFailed;
    _cleanup();
    if (!_failedFired) {
      _failedFired = true;
      cb?.call(); // → LiveKit, exactly as before P2P existed
    }
    _bump();
  }

  void setMic(bool on) {
    for (final t in _local?.getAudioTracks() ?? const <rtc.MediaStreamTrack>[]) {
      t.enabled = on;
    }
  }

  Future<void> leave() async {
    _session++;
    _cleanup();
    _bump();
  }

  void _cleanup() {
    _deadline?.cancel();
    _deadline = null;
    attempting = false;
    active = false;
    remoteReady = false;
    _remoteDescSet = false;
    _iceQueue.clear();
    _peerId = null;
    final pc = _pc;
    _pc = null;
    if (pc != null) {
      try {
        pc.close();
      } catch (_) {}
    }
    final local = _local;
    _local = null;
    if (local != null) {
      for (final t in local.getTracks()) {
        try {
          t.stop();
        } catch (_) {}
      }
      try {
        local.dispose();
      } catch (_) {}
    }
    try {
      localRenderer.srcObject = null;
      remoteRenderer.srcObject = null;
    } catch (_) {}
  }
}
