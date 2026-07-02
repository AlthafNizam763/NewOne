import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, debugPrint, defaultTargetPlatform, TargetPlatform;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../firebase_options.dart';
import 'badge_service.dart';

// ── Notification channels ─────────────────────────────────────────────────────
// Declared at top level so the background isolate handler can reference them.

const _chatChannelId   = 'chat_messages_channel';
const _chatChannelName = 'Chat Messages';

const _onlineChannelId   = 'online_status_channel';
const _onlineChannelName = 'Online Status';

const _alertChannelId   = 'alerts_channel';
const _alertChannelName = 'Alerts';

// ── Background message handler ────────────────────────────────────────────────
// Must be a top-level function — runs in a separate isolate when the app is
// killed. Firebase is NOT initialized in that isolate, so we do it here.

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('[FCM] Background message received: '
      '${message.messageId} | ${message.notification?.title}');
  // Platform channels (AppBadgePlus) are unavailable in background isolates.
  // Increment the server-side counter instead; the badge syncs when the app
  // resumes via BadgeService.syncFromFirestore().
  await BadgeService.firestoreIncrementInBackground();
}

// ── Background local-notification tap handler ─────────────────────────────────
// Also must be top-level per flutter_local_notifications v21 contract.

@pragma('vm:entry-point')
void _onBackgroundLocalNotificationTapped(NotificationResponse response) {
  debugPrint('[FCM] Background local tap | payload: ${response.payload}');
  // Navigation from this point is handled by the app when it resumes.
}

// ── Provider ──────────────────────────────────────────────────────────────────

final pushNotificationServiceProvider =
    Provider<PushNotificationService>((ref) {
  return PushNotificationService(FirebaseMessaging.instance);
});

// ── Service ───────────────────────────────────────────────────────────────────

class PushNotificationService {
  final FirebaseMessaging _fcm;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  // ── Navigation callback ───────────────────────────────────────────────────
  // Set once in AnataNoTameNiApp.initState() so the service can drive
  // GoRouter from background / foreground notification taps.
  // (For terminated-state taps, see consumeInitialNotification() instead.)
  void Function(Map<String, dynamic> data)? onNotificationTap;

  // Holds the data payload when the app was opened from a terminated-state
  // notification. Consumed exactly once by SplashScreen._resolveDestination().
  Map<String, dynamic>? _pendingInitialMessage;

  PushNotificationService(this._fcm);

  // ── Initialise ────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (kIsWeb) return;

    // 1. flutter_local_notifications (v21 — all named parameters)
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _local.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onForegroundLocalTap,
      onDidReceiveBackgroundNotificationResponse:
          _onBackgroundLocalNotificationTapped,
    );

    // 2. Android notification channels (no-op on older APIs)
    final androidPlugin = _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _chatChannelId,
        _chatChannelName,
        description: 'New messages from your partner',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ),
    );
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _onlineChannelId,
        _onlineChannelName,
        description: 'Alerts when your partner comes online',
        importance: Importance.defaultImportance,
        playSound: true,
      ),
    );
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _alertChannelId,
        _alertChannelName,
        description: 'Attention alerts from your partner',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ),
    );

    // 3. Background handler — must be registered BEFORE requestPermission
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 4. Foreground FCM listener
    //    Android: FCM never shows a system notification in foreground —
    //    we show one via flutter_local_notifications instead.
    //    iOS: setForegroundNotificationPresentationOptions below lets the OS
    //    show the system alert; we skip showing a duplicate local one on iOS.
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      debugPrint('[FCM] Foreground: ${message.messageId} '
          '| ${message.notification?.title}');
      if (kIsWeb) return;
      final n = message.notification;
      if (n == null) return;
      // Increment badge for every foreground notification.
      await BadgeService.increment();
      final badgeCount = await BadgeService.getCount();
      // Only show local notification on Android (iOS already shows the system
      // notification via setForegroundNotificationPresentationOptions).
      // Avoids duplicates on iOS.
      if (defaultTargetPlatform == TargetPlatform.android) {
        final type = message.data['type'] as String? ?? 'chat';
        final channelId   = type == 'alert' ? _alertChannelId   : _chatChannelId;
        final channelName = type == 'alert' ? _alertChannelName : _chatChannelName;
        _showLocal(
          id: message.hashCode,
          title: n.title ?? 'New Message',
          body: n.body ?? '',
          channelId: channelId,
          channelName: channelName,
          payload: jsonEncode(message.data),
          badgeCount: badgeCount,
        );
      }
    });

    // 5. Background → foreground tap (app was in background when user tapped)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('[FCM] Opened from background: ${message.messageId}');
      BadgeService.clear();
      onNotificationTap?.call(message.data);
    });

    // 6. Non-blocking permission + post-permission setup
    _fcm
        .requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        )
        .then((settings) async {
      debugPrint('[FCM] Permission: ${settings.authorizationStatus}');
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      await _fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Terminated-state: app was launched by tapping a notification.
      // Store the data for SplashScreen to consume — do NOT try to navigate
      // here because GoRouter is not mounted in this isolate phase yet.
      final initial = await _fcm.getInitialMessage();
      if (initial != null) {
        debugPrint('[FCM] Launched from terminated: ${initial.messageId}');
        _pendingInitialMessage = initial.data;
      }

      // Persist token, then keep it fresh automatically.
      await _refreshAndSaveToken();
      _fcm.onTokenRefresh.listen((newToken) {
        debugPrint('[FCM] Token refreshed');
        _saveTokenToFirestore(newToken);
      });
    }).catchError((Object e) {
      debugPrint('[FCM] Permission error: $e');
    });
  }

  // ── Terminated-state navigation helper ───────────────────────────────────
  // SplashScreen calls this once after auth is confirmed.
  // Returns the FCM data payload from the tap that launched the app, or null.
  Map<String, dynamic>? consumeInitialNotification() {
    final data = _pendingInitialMessage;
    _pendingInitialMessage = null;
    return data;
  }

  // ── Token management ──────────────────────────────────────────────────────

  Future<void> _refreshAndSaveToken() async {
    try {
      final token = await _fcm.getToken();
      if (token != null) await _saveTokenToFirestore(token);
    } catch (e) {
      debugPrint('[FCM] getToken error: $e');
    }
  }

  Future<void> _saveTokenToFirestore(String token) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return; // User not signed in yet — token saved on login
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('[FCM] Token saved (uid=$uid)');
    } catch (e) {
      debugPrint('[FCM] saveToken error: $e');
    }
  }

  /// Call after a successful login to persist the FCM token for this session.
  Future<void> updateTokenForCurrentUser() => _refreshAndSaveToken();

  /// Call during logout. Removes the token from Firestore and invalidates it
  /// on-device so the server stops delivering notifications immediately.
  Future<void> clearTokenForCurrentUser() async {
    if (kIsWeb) return;
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'fcmToken': FieldValue.delete(),
          'fcmTokenUpdatedAt': FieldValue.delete(),
        });
      }
      await _fcm.deleteToken();
      debugPrint('[FCM] Token cleared for logout');
    } catch (e) {
      debugPrint('[FCM] clearToken error: $e');
    }
  }

  // ── Local notification: foreground tap ───────────────────────────────────

  void _onForegroundLocalTap(NotificationResponse response) {
    debugPrint('[FCM] Local notification tapped | payload: ${response.payload}');
    BadgeService.clear();
    final payload = response.payload;
    if (payload == null) return;
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      onNotificationTap?.call(data);
    } catch (_) {
      // Legacy: plain roomId string — treat as chat tap
      onNotificationTap?.call({'type': 'chat', 'roomId': payload});
    }
  }

  // ── Presence-based local notifications (triggered by Firestore listener) ──
  // These show on the CURRENT device when the partner's Firestore status
  // changes — no Cloud Function needed for cross-device delivery here
  // because the current device reads the change via its own stream.

  Future<void> showOnlineNotification(String username) async {
    await BadgeService.increment();
    final count = await BadgeService.getCount();
    return _showLocal(
      id: username.hashCode,
      title: '$username is Online',
      body: '$username just came online! Tap to chat.',
      channelId: _onlineChannelId,
      channelName: _onlineChannelName,
      badgeCount: count,
    );
  }

  Future<void> showComeOnlineRequest(String username) async {
    await BadgeService.increment();
    final count = await BadgeService.getCount();
    return _showLocal(
      id: username.hashCode ^ 0x1,
      title: 'Come Online Request',
      body: '$username is waiting for you to come online!',
      channelId: _onlineChannelId,
      channelName: _onlineChannelName,
      badgeCount: count,
    );
  }

  // ── Internal: show a local notification ──────────────────────────────────

  Future<void> _showLocal({
    required int id,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
    String? payload,
    int badgeCount = 0,
  }) async {
    if (kIsWeb) return;
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
        number: badgeCount > 0 ? badgeCount : null,
      ),
      iOS: DarwinNotificationDetails(
        badgeNumber: badgeCount > 0 ? badgeCount : null,
      ),
    );
    await _local.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }
}
