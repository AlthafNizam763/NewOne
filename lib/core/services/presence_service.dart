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
class PresenceService with WidgetsBindingObserver {
  String? _uid;
  bool _initialized = false;
  StreamSubscription? _connectedSub;

  void initialize(String uid) {
    if (_initialized && _uid == uid) return;
    if (_initialized) _teardown();
    _uid = uid;
    _initialized = true;
    WidgetsBinding.instance.addObserver(this);
    _setupRtdbPresence();
    _setFirestoreOnline(true);
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
        _setFirestoreOnline(false);
        _setRtdbOnline(false);
        break;
      case AppLifecycleState.resumed:
        _setFirestoreOnline(true);
        _setRtdbOnline(true);
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

  /// Returns a stream of the partner's real-time online status from RTDB.
  /// More accurate than Firestore because RTDB uses onDisconnect server-side.
  Stream<bool> watchPartnerOnline(String partnerUid) {
    return FirebaseDatabase.instance
        .ref('status/$partnerUid')
        .onValue
        .map((event) {
      final data = event.snapshot.value;
      if (data is Map) {
        return data['isOnline'] as bool? ?? false;
      }
      return false;
    });
  }

  void _teardown() {
    _connectedSub?.cancel();
    _connectedSub = null;
    if (_initialized) {
      WidgetsBinding.instance.removeObserver(this);
    }
    _setFirestoreOnline(false);
    _setRtdbOnline(false);
    _initialized = false;
    _uid = null;
  }

  void dispose() => _teardown();
}
