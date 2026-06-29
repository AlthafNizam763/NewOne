import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../firebase_options.dart';

// ── Notification channels (declared at top level so background handler can reach them) ─

const _chatChannelId = 'chat_messages_channel';
const _chatChannelName = 'Chat Messages';

const _onlineChannelId = 'online_status_channel';
const _onlineChannelName = 'Online Status Notifications';

// ── Background handler — runs in a separate isolate, MUST be top-level ──────

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background isolate has NO Firebase — must initialize before any Firebase call.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('[FCM] Background message: ${message.messageId} '
      '| title: ${message.notification?.title}');
}

// ── Background notification tap handler — must be top-level ─────────────────

@pragma('vm:entry-point')
void _onBackgroundNotificationTapped(NotificationResponse response) {
  debugPrint('[FCM] Background notification tapped | payload: ${response.payload}');
}

// ── Provider ──────────────────────────────────────────────────────────────────

final pushNotificationServiceProvider =
    Provider<PushNotificationService>((ref) {
  return PushNotificationService(FirebaseMessaging.instance);
});

// ── Service ───────────────────────────────────────────────────────────────────

class PushNotificationService {
  final FirebaseMessaging _fcm;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  /// Optional callback invoked when the user taps a notification.
  /// Register this from your router/shell to perform navigation.
  /// [data] contains the FCM message's data payload (e.g. {'roomId': '...'}).
  void Function(Map<String, dynamic> data)? onNotificationTap;

  PushNotificationService(this._fcm);

  // ── Public initialiser ────────────────────────────────────────────────────

  Future<void> init() async {
    if (kIsWeb) return;

    // 1. flutter_local_notifications v21 — all parameters are named.
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onForegroundNotificationTapped,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundNotificationTapped,
    );

    // 2. Create persistent notification channels.
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(const AndroidNotificationChannel(
      _chatChannelId,
      _chatChannelName,
      description: 'New messages from your partner',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    ));
    await androidPlugin?.createNotificationChannel(const AndroidNotificationChannel(
      _onlineChannelId,
      _onlineChannelName,
      description: 'Notifies when a partner comes online',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    ));

    // 3. Background handler must be registered before requestPermission.
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 4. Request permission — on Android 13+ this triggers POST_NOTIFICATIONS dialog.
    final permissionSettings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint('[FCM] Permission: ${permissionSettings.authorizationStatus}');
    if (permissionSettings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('[FCM] Notifications denied — skipping listener setup');
      return;
    }

    // 5. iOS foreground presentation (shows banner even when app is open).
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // 6. FOREGROUND handler — FCM does NOT auto-show a notification when the app
    //    is open; we must call _localNotifications.show() ourselves.
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('[FCM] Foreground message: ${message.messageId} '
          '| title: ${message.notification?.title}');
      final n = message.notification;
      if (n == null) return;
      _showLocal(
        id: message.hashCode,
        title: n.title ?? 'New Message',
        body: n.body ?? '',
        channelId: _chatChannelId,
        channelName: _chatChannelName,
        payload: message.data['roomId'] as String?,
      );
    });

    // 7. BACKGROUND → app opened by tapping notification.
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('[FCM] Opened from background notification: ${message.messageId}');
      onNotificationTap?.call(message.data);
    });

    // 8. TERMINATED → app launched by tapping notification.
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('[FCM] Launched from terminated-state notification: '
          '${initialMessage.messageId}');
      onNotificationTap?.call(initialMessage.data);
    }

    // 9. Get token and persist to Firestore.
    await _refreshAndSaveToken();

    // 10. Keep token fresh — FCM may rotate it at any time.
    _fcm.onTokenRefresh.listen((String newToken) {
      debugPrint('[FCM] Token refreshed');
      _saveTokenToFirestore(newToken);
    });
  }

  // ── Token management ──────────────────────────────────────────────────────

  Future<void> _refreshAndSaveToken() async {
    try {
      final token = await _fcm.getToken();
      debugPrint('[FCM] Token: $token');
      if (token != null) await _saveTokenToFirestore(token);
    } catch (e) {
      debugPrint('[FCM] Failed to get token: $e');
    }
  }

  Future<void> _saveTokenToFirestore(String token) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        debugPrint('[FCM] No authenticated user — token not saved yet');
        return;
      }
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('[FCM] Token persisted to Firestore (uid=$uid)');
    } catch (e) {
      debugPrint('[FCM] Failed to save token to Firestore: $e');
    }
  }

  /// Call this immediately after a successful login so the FCM token is
  /// persisted for the newly authenticated user.
  Future<void> updateTokenForCurrentUser() => _refreshAndSaveToken();

  // ── Notification tap handler (foreground) ─────────────────────────────────

  void _onForegroundNotificationTapped(NotificationResponse response) {
    debugPrint('[FCM] Notification tapped | payload: ${response.payload}');
    if (response.payload != null) {
      onNotificationTap?.call({'roomId': response.payload});
    }
  }

  // ── Public notification methods ───────────────────────────────────────────

  Future<void> showOnlineNotification(String username) => _showLocal(
        id: username.hashCode,
        title: '$username is Online',
        body: '$username just came online! Tap to chat.',
        channelId: _onlineChannelId,
        channelName: _onlineChannelName,
      );

  Future<void> showComeOnlineRequest(String username) => _showLocal(
        id: username.hashCode ^ 0x1,
        title: 'Come Online Request',
        body: '$username is waiting for you to come online!',
        channelId: _onlineChannelId,
        channelName: _onlineChannelName,
      );

  Future<void> showChatMessageNotification({
    required String senderName,
    required String message,
    required String roomId,
  }) =>
      _showLocal(
        id: roomId.hashCode,
        title: senderName,
        body: message,
        channelId: _chatChannelId,
        channelName: _chatChannelName,
        payload: roomId,
      );

  // ── Internal helper ───────────────────────────────────────────────────────

  Future<void> _showLocal({
    required int id,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
    String? payload,
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
      ),
    );
    // v21 named-parameter API
    await _localNotifications.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }
}
