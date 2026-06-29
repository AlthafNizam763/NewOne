import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/call_signaling_service.dart';

// ── Call state ────────────────────────────────────────────────────────────────

enum CallStatus { idle, outgoing, incoming, active }

class CallState {
  final CallStatus status;
  final String? callId;
  final String? callerId;
  final String? callerName;
  final String? type; // 'audio' | 'video'
  final bool isMuted;
  final bool isVideoEnabled;

  const CallState({
    this.status = CallStatus.idle,
    this.callId,
    this.callerId,
    this.callerName,
    this.type,
    this.isMuted = false,
    this.isVideoEnabled = true,
  });

  CallState copyWith({
    CallStatus? status,
    String? callId,
    String? callerId,
    String? callerName,
    String? type,
    bool? isMuted,
    bool? isVideoEnabled,
  }) {
    return CallState(
      status: status ?? this.status,
      callId: callId ?? this.callId,
      callerId: callerId ?? this.callerId,
      callerName: callerName ?? this.callerName,
      type: type ?? this.type,
      isMuted: isMuted ?? this.isMuted,
      isVideoEnabled: isVideoEnabled ?? this.isVideoEnabled,
    );
  }

  bool get isIdle => status == CallStatus.idle;
}

// ── Providers ─────────────────────────────────────────────────────────────────

final callSignalingServiceProvider = Provider<CallSignalingService>((ref) {
  final svc = CallSignalingService();
  ref.onDispose(svc.dispose);
  return svc;
});

final callControllerProvider =
    StateNotifierProvider<CallController, CallState>((ref) {
  return CallController(ref);
});

/// Streams the first ringing call where the current user is the callee.
final incomingCallStreamProvider =
    StreamProvider<DocumentSnapshot<Map<String, dynamic>>?>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(null);
  return FirebaseFirestore.instance
      .collection('calls')
      .where('calleeId', isEqualTo: uid)
      .where('status', isEqualTo: 'ringing')
      .snapshots()
      .map((s) => s.docs.isNotEmpty ? s.docs.first : null);
});

// ── Controller ────────────────────────────────────────────────────────────────

class CallController extends StateNotifier<CallState> {
  final Ref _ref;

  CallController(this._ref) : super(const CallState());

  CallSignalingService get _sig => _ref.read(callSignalingServiceProvider);

  // Called from HomeScreen when an incoming call doc is detected.
  void setIncoming({
    required String callId,
    required String callerId,
    required String callerName,
    required String type,
  }) {
    if (state.status != CallStatus.idle) return;
    state = CallState(
      status: CallStatus.incoming,
      callId: callId,
      callerId: callerId,
      callerName: callerName,
      type: type,
    );
  }

  /// Initiates an outgoing call. Returns the [callId] or null on failure.
  Future<String?> makeCall({
    required String calleeId,
    required String type,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    try {
      final callId = await _sig.makeCall(
        callerId: uid,
        calleeId: calleeId,
        type: type,
        onConnected: () {
          if (mounted && state.status == CallStatus.outgoing) {
            state = state.copyWith(status: CallStatus.active);
          }
        },
      );
      state = CallState(
        status: CallStatus.outgoing,
        callId: callId,
        type: type,
        isVideoEnabled: type == 'video',
      );
      return callId;
    } catch (e) {
      debugPrint('CallController.makeCall error: $e');
      return null;
    }
  }

  /// Accepts the incoming call.
  Future<void> answerCall() async {
    final callId = state.callId;
    if (callId == null || state.status != CallStatus.incoming) return;
    try {
      await _sig.answerCall(
        callId: callId,
        withVideo: state.type == 'video',
        onConnected: () {
          if (mounted) state = state.copyWith(status: CallStatus.active);
        },
      );
      state = state.copyWith(status: CallStatus.active);
    } catch (e) {
      debugPrint('CallController.answerCall error: $e');
    }
  }

  /// Rejects an incoming call.
  Future<void> rejectCall() async {
    final callId = state.callId;
    if (callId == null) return;
    await _sig.rejectCall(callId);
    state = const CallState();
  }

  /// Ends the active/outgoing call.
  Future<void> endCall() async {
    final callId = state.callId;
    if (callId == null) return;
    await _sig.endCall(callId);
    state = const CallState();
  }

  Future<void> toggleMute() async {
    final newMuted = !state.isMuted;
    _sig.setMuted(newMuted);
    state = state.copyWith(isMuted: newMuted);
  }

  Future<void> toggleVideo() async {
    final newEnabled = !state.isVideoEnabled;
    _sig.setVideoEnabled(newEnabled);
    state = state.copyWith(isVideoEnabled: newEnabled);
  }

  void switchCamera() => _sig.switchCamera();
}
