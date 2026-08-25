import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:iFloraBuzz/firebase_options.dart';
import 'notification_remote_datasource.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // If notification block is present, OS displays it automatically on Android/iOS.
    // If only data is present, show local notification fallback.
    if (message.notification == null) {
      await FCMService.showLocalNotification(message);
    }
  } catch (e) {
    debugPrint('[FCM] Background handler error: $e');
  }
}

class FCMService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const String notificationChannelId = 'sendzyy_notifications';
  static const String notificationChannelName = 'Sendzyy Notifications';

  static Future<void> initialize({
    required String tenantId,
    required NotificationRemoteDataSource remoteDataSource,
    Function(Map<String, dynamic> data)? onNotificationTap,
  }) async {
    if (_initialized) return;

    try {
      // 1. Request Push Notification permissions
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint('[FCM] Permission status: ${settings.authorizationStatus}');

      // 2. Initialize local notifications for foreground popups
      await _initLocalNotifications(onNotificationTap: onNotificationTap);

      // 3. Register background message handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // 4. Retrieve FCM Token and register with backend
      final token = await _getToken();
      if (token != null) {
        debugPrint('[FCM] Token obtained: $token');
        await remoteDataSource.registerFcmToken(
          tenantId: tenantId,
          token: token,
          platform: _getPlatformName(),
        );
      }

      // 5. Subscribe to tenant topic client-side (for multi-device broadcast)
      if (!kIsWeb && tenantId.isNotEmpty) {
        try {
          await _messaging.subscribeToTopic('tenant_$tenantId');
          debugPrint('[FCM] Client subscribed to topic: tenant_$tenantId');
        } catch (topicErr) {
          debugPrint('[FCM] Topic subscription notice: $topicErr');
        }
      }

      // 6. Listen to token refresh
      _messaging.onTokenRefresh.listen((newToken) async {
        await remoteDataSource.registerFcmToken(
          tenantId: tenantId,
          token: newToken,
          platform: _getPlatformName(),
        );
        if (!kIsWeb && tenantId.isNotEmpty) {
          try {
            await _messaging.subscribeToTopic('tenant_$tenantId');
          } catch (_) {}
        }
      });

      // 7. Foreground message listener
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint(
          '[FCM] Foreground message received: ${message.notification?.title ?? message.data['title']}',
        );
        showLocalNotification(message);
      });

      // 8. Handle notification opened when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('[FCM] Notification opened from background: ${message.data}');
        if (onNotificationTap != null) {
          onNotificationTap(message.data);
        }
      });

      // 9. Handle notification opened when app was terminated
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('[FCM] Initial notification launch: ${initialMessage.data}');
        if (onNotificationTap != null) {
          onNotificationTap(initialMessage.data);
        }
      }

      _initialized = true;
    } catch (e) {
      debugPrint('[FCM] Initialize warning (FCM config may be pending): $e');
    }
  }

  static String get webVapidKey =>
      dotenv.env['FIREBASE_WEB_VAPID_KEY'] ?? 'error';

  static Future<String?> _getToken() async {
    try {
      if (kIsWeb) {
        return await _messaging.getToken(vapidKey: webVapidKey);
      } else {
        return await _messaging.getToken();
      }
    } catch (e) {
      debugPrint('[FCM] Could not fetch FCM token: $e');
      return null;
    }
  }

  static Future<void> _initLocalNotifications({
    Function(Map<String, dynamic> data)? onNotificationTap,
  }) async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    const androidChannel = AndroidNotificationChannel(
      notificationChannelId,
      notificationChannelName,
      description: 'All Sendzyy platform notifications',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(androidChannel);
    }

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null && response.payload!.isNotEmpty) {
          try {
            final data = jsonDecode(response.payload!) as Map<String, dynamic>;
            if (onNotificationTap != null) {
              onNotificationTap(data);
            }
          } catch (_) {}
        }
      },
    );
  }

  static Future<void> showLocalNotification(RemoteMessage message) async {
    const androidDetails = AndroidNotificationDetails(
      notificationChannelId,
      notificationChannelName,
      channelDescription: 'All Sendzyy platform notifications',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final title =
        message.notification?.title ??
        message.data['title'] ??
        'Sendzyy Notification';
    final body = message.notification?.body ?? message.data['body'] ?? '';

    await _localNotifications.show(
      message.hashCode,
      title,
      body,
      details,
      payload: jsonEncode(message.data),
    );
  }

  static String _getPlatformName() {
    if (kIsWeb) return 'web';
    if (defaultTargetPlatform == TargetPlatform.android) return 'android';
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'ios';
    return 'web';
  }
}
