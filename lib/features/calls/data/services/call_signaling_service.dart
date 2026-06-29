import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show VoidCallback, debugPrint;
import 'package:flutter_webrtc/flutter_webrtc.dart';

class CallSignalingService {
  static const Map<String, dynamic> _iceConfig = {
    'iceServers': [
      {
        'urls': [
          'stun:stun.l.google.com:19302',
          'stun:stun1.l.google.com:19302',
        ]
      },
    ],
    'sdpSemantics': 'unified-plan',
  };

  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  bool _remoteDescriptionSet = false;

  final _localStreamCtrl = StreamController<MediaStream?>.broadcast();
  final _remoteStreamCtrl = StreamController<MediaStream?>.broadcast();

  Stream<MediaStream?> get localStream => _localStreamCtrl.stream;
  Stream<MediaStream?> get remoteStream => _remoteStreamCtrl.stream;

  StreamSubscription? _answerSub;
  StreamSubscription? _callerCandidatesSub;
  StreamSubscription? _calleeCandidatesSub;

  Future<MediaStream> _getUserMedia({required bool withVideo}) async {
    final constraints = <String, dynamic>{
      'audio': true,
      'video': withVideo
          ? {'facingMode': 'user', 'width': 640, 'height': 480}
          : false,
    };
    return navigator.mediaDevices.getUserMedia(constraints);
  }

  // ── Caller side ─────────────────────────────────────────────────────────────

  /// Creates a Firestore call doc, starts local media, creates an SDP offer.
  /// Returns the newly created [callId].
  /// [onConnected] fires when the remote peer connects.
  Future<String> makeCall({
    required String callerId,
    required String calleeId,
    required String type,
    VoidCallback? onConnected,
  }) async {
    final db = FirebaseFirestore.instance;
    final callDoc = db.collection('calls').doc();
    final callId = callDoc.id;

    _pc = await createPeerConnection(_iceConfig);
    _localStream = await _getUserMedia(withVideo: type == 'video');
    _localStreamCtrl.add(_localStream);

    for (final track in _localStream!.getTracks()) {
      await _pc!.addTrack(track, _localStream!);
    }

    _pc!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteStreamCtrl.add(event.streams[0]);
        onConnected?.call();
      }
    };

    _pc!.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate.candidate != null) {
        callDoc.collection('callerCandidates').add({
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        });
      }
    };

    final offer = await _pc!.createOffer();
    await _pc!.setLocalDescription(offer);

    await callDoc.set({
      'callId': callId,
      'callerId': callerId,
      'calleeId': calleeId,
      'type': type,
      'status': 'ringing',
      'offer': {'type': offer.type, 'sdp': offer.sdp},
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Watch for callee's answer
    _answerSub = callDoc.snapshots().listen((snap) async {
      final data = snap.data();
      if (data == null) return;
      if (data['answer'] != null && !_remoteDescriptionSet) {
        _remoteDescriptionSet = true;
        try {
          final answerData = data['answer'] as Map<String, dynamic>;
          final answer = RTCSessionDescription(
              answerData['sdp'] as String?, answerData['type'] as String?);
          await _pc!.setRemoteDescription(answer);
        } catch (e) {
          debugPrint('setRemoteDescription error: $e');
        }
      }
    });

    // Watch for callee's ICE candidates
    _calleeCandidatesSub =
        callDoc.collection('calleeCandidates').snapshots().listen((snap) {
      for (final change in snap.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final d = change.doc.data()!;
          _pc!.addCandidate(RTCIceCandidate(
            d['candidate'] as String?,
            d['sdpMid'] as String?,
            d['sdpMLineIndex'] as int?,
          ));
        }
      }
    });

    return callId;
  }

  // ── Callee side ─────────────────────────────────────────────────────────────

  /// Reads the existing call doc, starts local media, creates an SDP answer.
  Future<void> answerCall({
    required String callId,
    required bool withVideo,
    VoidCallback? onConnected,
  }) async {
    final db = FirebaseFirestore.instance;
    final callDoc = db.collection('calls').doc(callId);
    final snap = await callDoc.get();
    final callData = snap.data()!;

    _pc = await createPeerConnection(_iceConfig);
    _localStream = await _getUserMedia(withVideo: withVideo);
    _localStreamCtrl.add(_localStream);

    for (final track in _localStream!.getTracks()) {
      await _pc!.addTrack(track, _localStream!);
    }

    _pc!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteStreamCtrl.add(event.streams[0]);
        onConnected?.call();
      }
    };

    _pc!.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate.candidate != null) {
        callDoc.collection('calleeCandidates').add({
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        });
      }
    };

    final offerData = callData['offer'] as Map<String, dynamic>;
    final offer = RTCSessionDescription(
        offerData['sdp'] as String?, offerData['type'] as String?);
    await _pc!.setRemoteDescription(offer);

    final answer = await _pc!.createAnswer();
    await _pc!.setLocalDescription(answer);

    await callDoc.update({
      'answer': {'type': answer.type, 'sdp': answer.sdp},
      'status': 'active',
    });

    // Watch for caller's ICE candidates
    _callerCandidatesSub =
        callDoc.collection('callerCandidates').snapshots().listen((snap) {
      for (final change in snap.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final d = change.doc.data()!;
          _pc!.addCandidate(RTCIceCandidate(
            d['candidate'] as String?,
            d['sdpMid'] as String?,
            d['sdpMLineIndex'] as int?,
          ));
        }
      }
    });
  }

  // ── Control ─────────────────────────────────────────────────────────────────

  Future<void> rejectCall(String callId) async {
    try {
      await FirebaseFirestore.instance.collection('calls').doc(callId).update({
        'status': 'rejected',
        'endedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('rejectCall error: $e');
    }
    await cleanup();
  }

  Future<void> endCall(String callId) async {
    try {
      await FirebaseFirestore.instance.collection('calls').doc(callId).update({
        'status': 'ended',
        'endedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('endCall error: $e');
    }
    await cleanup();
  }

  void setMuted(bool muted) {
    _localStream?.getAudioTracks().forEach((t) => t.enabled = !muted);
  }

  void setVideoEnabled(bool enabled) {
    _localStream?.getVideoTracks().forEach((t) => t.enabled = enabled);
  }

  void switchCamera() {
    final tracks = _localStream?.getVideoTracks();
    if (tracks != null && tracks.isNotEmpty) {
      Helper.switchCamera(tracks[0]);
    }
  }

  // ── Cleanup ──────────────────────────────────────────────────────────────────

  Future<void> cleanup() async {
    _answerSub?.cancel();
    _callerCandidatesSub?.cancel();
    _calleeCandidatesSub?.cancel();

    _localStream?.getTracks().forEach((t) => t.stop());
    await _localStream?.dispose();
    _localStream = null;

    await _pc?.close();
    _pc = null;
    _remoteDescriptionSet = false;

    if (!_localStreamCtrl.isClosed) _localStreamCtrl.add(null);
    if (!_remoteStreamCtrl.isClosed) _remoteStreamCtrl.add(null);
  }

  void dispose() {
    cleanup();
    _localStreamCtrl.close();
    _remoteStreamCtrl.close();
  }
}
