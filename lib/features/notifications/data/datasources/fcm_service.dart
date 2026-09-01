import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:iFloraBuzz/firebase_options.dart';
import 'notification_remote_datasource.dart';

/// Background handler — must be a top-level function annotated @pragma('vm:entry-point').
/// Android calls this in a separate Isolate when the app is killed/terminated.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // If message contains a 'notification' payload, Firebase Android/iOS automatically
    // displays the notification in the status bar/tray when app is in background or closed.
    // Only manually trigger local notification for data-only messages to prevent duplicate alerts.
    if (message.notification == null && message.data.isNotEmpty) {
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

  /// Call this when the user logs out so FCM re-initializes on the next login.
  static void reset() {
    _initialized = false;
  }

  static Future<void> initialize({
    required String tenantId,
    required NotificationRemoteDataSource remoteDataSource,
    Function(Map<String, dynamic> data)? onNotificationTap,
  }) async {
    if (_initialized) return;

    try {
      // 1. Explicitly request Android 13+ POST_NOTIFICATIONS via permission_handler
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        final permStatus = await Permission.notification.status;
        if (!permStatus.isGranted) {
          final reqResult = await Permission.notification.request();
          debugPrint('[FCM] Android 13+ POST_NOTIFICATIONS permission: $reqResult');
        }
      }

      // 2. Request Push Notification permissions via FirebaseMessaging
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

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('[FCM] Notification permission denied — notifications will not work.');
        return;
      }

      // 2. Initialize local notifications for foreground popups
      await _initLocalNotifications(onNotificationTap: onNotificationTap);

      // 3. iOS — show notifications in foreground (critical for iOS killed-state behaviour)
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // 4. Register background message handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // 5. Retrieve FCM Token and register with backend
      final token = await _getToken();
      if (token != null) {
        debugPrint('[FCM] Token obtained: $token');
        await remoteDataSource.registerFcmToken(
          tenantId: tenantId,
          token: token,
          platform: _getPlatformName(),
        );
      }

      // 6. Subscribe to tenant topic (for multi-device broadcast)
      if (!kIsWeb && tenantId.isNotEmpty) {
        try {
          await _messaging.subscribeToTopic('tenant_$tenantId');
          debugPrint('[FCM] Client subscribed to topic: tenant_$tenantId');
        } catch (topicErr) {
          debugPrint('[FCM] Topic subscription notice: $topicErr');
        }
      }

      // 7. Listen to token refresh
      _messaging.onTokenRefresh.listen((newToken) async {
        debugPrint('[FCM] Token refreshed: $newToken');
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

      // 8. Foreground message listener
      // When app is open, FCM does NOT show a system notification automatically —
      // we must show it via flutter_local_notifications.
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint(
          '[FCM] Foreground message: ${message.notification?.title ?? message.data['title']}',
        );
        showLocalNotification(message);
      });

      // 9. Handle notification tap when app is in BACKGROUND (but not killed)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('[FCM] Notification tapped from background: ${message.data}');
        if (onNotificationTap != null) {
          onNotificationTap(message.data);
        }
      });

      // 10. Handle notification tap when app was TERMINATED
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('[FCM] App launched from terminated via notification: ${initialMessage.data}');
        if (onNotificationTap != null) {
          onNotificationTap(initialMessage.data);
        }
      }

      _initialized = true;
      debugPrint('[FCM] FCMService fully initialized for tenant: $tenantId');
    } catch (e) {
      debugPrint('[FCM] Initialize error: $e');
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

    // Create the Android notification channel via the plugin as well.
    // The native MainApplication.kt creates it before Flutter starts;
    // creating it here is idempotent (Android ignores duplicate creates).
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
    // Deduplicate: use a stable int from the message ID or timestamp.
    final notifId = (message.messageId ?? message.sentTime?.millisecondsSinceEpoch.toString() ?? '0')
        .hashCode
        .abs() %
        100000;

    final androidDetails = AndroidNotificationDetails(
      notificationChannelId,
      notificationChannelName,
      channelDescription: 'All Sendzyy platform notifications',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      // Show on lock screen
      visibility: NotificationVisibility.public,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final title =
        message.notification?.title ??
        message.data['title'] ??
        'Sendzyy Notification';
    final body = message.notification?.body ?? message.data['body'] ?? '';

    try {
      await _localNotifications.show(
        notifId,
        title,
        body,
        details,
        payload: jsonEncode(message.data),
      );
    } catch (e) {
      debugPrint('[FCM] showLocalNotification error: $e');
    }
  }

  static String _getPlatformName() {
    if (kIsWeb) return 'web';
    if (defaultTargetPlatform == TargetPlatform.android) return 'android';
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'ios';
    return 'web';
  }
}
