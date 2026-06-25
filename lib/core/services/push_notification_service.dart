import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Top-level function to handle background messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you need to initialize Firebase here, do it before processing
  debugPrint("Handling a background message: ${message.messageId}");
}

final pushNotificationServiceProvider =
    Provider<PushNotificationService>((ref) {
  return PushNotificationService(FirebaseMessaging.instance);
});

class PushNotificationService {
  final FirebaseMessaging _fcm;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  PushNotificationService(this._fcm);

  Future<void> init() async {
    if (kIsWeb) return;

    // Setup Local Notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings();
    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    await _localNotificationsPlugin.initialize(
      settings: initializationSettings,
    );

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'online_status_channel',
      'Online Status Notifications',
      description: 'Notifies when a partner comes online',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // 1. Request permission for iOS/Web
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted push notification permission');
    } else {
      debugPrint('User declined push notification permission');
    }

    // 2. Setup Local Notifications for Foreground messages
    // (Temporarily disabled due to flutter_local_notifications v21.0.0 breaking changes on positional arguments)

    // 3. Register Background Handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 4. Listen to Foreground Messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Received foreground message: ${message.messageId}');
    });

    // 5. Get FCM Token (Used for targeting this device from your server)
    try {
      String? token = await _fcm.getToken();
      debugPrint('FCM Token: $token');
      // Here you would typically send the token to your Firestore `users/{uid}` document
    } catch (e) {
      debugPrint('Failed to get FCM token: $e');
    }
  }

  Future<void> showOnlineNotification(String username) async {
    if (kIsWeb) return;
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'online_status_channel',
      'Online Status Notifications',
      channelDescription: 'Notifies when a partner comes online',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    await _localNotificationsPlugin.show(
      id: DateTime.now().millisecond,
      title: '$username is Online',
      body: '$username just came online! Tap to chat.',
      notificationDetails: platformChannelSpecifics,
    );
  }

  Future<void> showComeOnlineRequest(String username) async {
    if (kIsWeb) return;
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'online_status_channel',
      'Online Status Notifications',
      channelDescription: 'Notifies when a partner requests you to come online',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    await _localNotificationsPlugin.show(
      id: DateTime.now().millisecond,
      title: 'Come Online Request',
      body: '$username is waiting for you to come online!',
      notificationDetails: platformChannelSpecifics,
    );
  }
}
