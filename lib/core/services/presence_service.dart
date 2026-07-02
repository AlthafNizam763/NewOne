import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final presenceServiceProvider = Provider<PresenceService>((ref) {
  final service = PresenceService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Manages the current user's online/offline presence using both
/// Firebase Realtime Database (for reliable onDisconnect) and
/// Firestore (for rich profile reads). Also provides a stream of
/// a partner's real-time online status via RTDB.
///
/// Presence rules:
///   • App opens / user logs in → online immediately
///   • App paused / detached / hidden → offline immediately
///   • No user interaction for 5 minutes → offline (inactivity)
///   • Any pointer event (tap, scroll, etc.) → resets inactivity timer; if
///     offline due to inactivity, restores online immediately
///   • Network drop → RTDB onDisconnect fires server-side → offline
class PresenceService with WidgetsBindingObserver {
  String? _uid;
  bool _initialized = false;
  StreamSubscription? _connectedSub;

  Timer? _inactivityTimer;
  static const _inactivityTimeout = Duration(minutes: 5);

  // Tracks whether we went offline only due to inactivity (vs app backgrounded).
  bool _offlineDueToInactivity = false;

  void initialize(String uid) {
    if (_initialized && _uid == uid) return;
    if (_initialized) _teardown();
    _uid = uid;
    _initialized = true;
    _offlineDueToInactivity = false;
    WidgetsBinding.instance.addObserver(this);
    _setupRtdbPresence();
    _setFirestoreOnline(true);
    // Write RTDB status immediately — don't wait for .info/connected, which can
    // be delayed or blocked, causing the RTDB node to stay stale.
    _setRtdbOnline(true);
    _resetInactivityTimer();
  }

  /// Call on every user pointer event (tap, scroll, key press).
  /// No-op if not yet initialised (user not logged in).
  void onUserActivity() {
    if (!_initialized || _uid == null) return;
    // If we went offline because of inactivity only, come back online now.
    if (_offlineDueToInactivity) {
      _offlineDueToInactivity = false;
      _setFirestoreOnline(true);
      _setRtdbOnline(true);
    }
    _resetInactivityTimer();
  }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(_inactivityTimeout, _goOfflineDueToInactivity);
  }

  void _goOfflineDueToInactivity() {
    if (!_initialized || _uid == null) return;
    debugPrint('PresenceService: going offline due to 5-min inactivity');
    _offlineDueToInactivity = true;
    _setFirestoreOnline(false);
    _setRtdbOnline(false);
  }

  Future<void> _setupRtdbPresence() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final rtdbRef = FirebaseDatabase.instance.ref('status/$uid');

      // Re-register onDisconnect each time the RTDB connection comes up.
      _connectedSub = FirebaseDatabase.instance
          .ref('.info/connected')
          .onValue
          .listen((event) async {
        final connected = event.snapshot.value as bool? ?? false;
        if (!connected) return;
        try {
          await rtdbRef.onDisconnect().update({
            'isOnline': false,
            'lastSeen': ServerValue.timestamp,
          });
          await rtdbRef.update({'isOnline': true});
        } catch (e) {
          debugPrint('PresenceService RTDB update error: $e');
        }
      });
    } catch (e) {
      debugPrint('PresenceService._setupRtdbPresence error: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _inactivityTimer?.cancel();
        _offlineDueToInactivity = false;
        _setFirestoreOnline(false);
        _setRtdbOnline(false);
        break;
      case AppLifecycleState.resumed:
        _offlineDueToInactivity = false;
        _setFirestoreOnline(true);
        _setRtdbOnline(true);
        _resetInactivityTimer();
        break;
      default:
        break;
    }
  }

  Future<void> _setFirestoreOnline(bool online) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'isOnline': online,
        if (!online) 'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('PresenceService Firestore update error: $e');
    }
  }

  Future<void> _setRtdbOnline(bool online) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await FirebaseDatabase.instance.ref('status/$uid').update({
        'isOnline': online,
        'lastSeen': ServerValue.timestamp,
      });
    } catch (e) {
      debugPrint('PresenceService RTDB direct update error: $e');
    }
  }

  /// Returns a stream of the partner's real-time online status.
  ///
  /// Merges Firestore and RTDB so either source going online triggers a true.
  /// Firestore is the reliable primary (written immediately on every open/resume).
  /// RTDB supplements with server-side onDisconnect accuracy on network drops.
  Stream<bool> watchPartnerOnline(String partnerUid) {
    bool rtdbOnline = false;
    bool fsOnline = false;
    // ignore: close_sinks — closed in onCancel
    final controller = StreamController<bool>.broadcast();

    final rtdbSub = FirebaseDatabase.instance
        .ref('status/$partnerUid')
        .onValue
        .listen(
      (event) {
        final data = event.snapshot.value;
        rtdbOnline = data is Map ? (data['isOnline'] as bool? ?? false) : false;
        if (!controller.isClosed) controller.add(rtdbOnline || fsOnline);
      },
      onError: (_) {},
    );

    final fsSub = FirebaseFirestore.instance
        .collection('users')
        .doc(partnerUid)
        .snapshots()
        .listen(
      (snap) {
        fsOnline = snap.data()?['isOnline'] as bool? ?? false;
        if (!controller.isClosed) controller.add(rtdbOnline || fsOnline);
      },
      onError: (_) {},
    );

    controller.onCancel = () {
      rtdbSub.cancel();
      fsSub.cancel();
      controller.close();
    };

    return controller.stream;
  }

  void _teardown() {
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
    _connectedSub?.cancel();
    _connectedSub = null;
    if (_initialized) {
      WidgetsBinding.instance.removeObserver(this);
    }
    _setFirestoreOnline(false);
    _setRtdbOnline(false);
    _initialized = false;
    _offlineDueToInactivity = false;
    _uid = null;
  }

  void dispose() => _teardown();
}
