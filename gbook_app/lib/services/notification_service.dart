import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_local_notifications_platform_interface/flutter_local_notifications_platform_interface.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // ignore: avoid_print
  print('Background message: ${message.messageId}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'Used for important notifications',
    importance: Importance.high,
  );

  Future<void> initialize() async {
    // 1. Request permission
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    // 2. Create Android notification channel — fixed syntax
    final T? Function<T extends FlutterLocalNotificationsPlatform>() androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation;
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin.createNotificationChannel(channel);

    // 3. Init local notifications
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    await _localNotifications.initialize(
      const InitializationSettings(android: androidSettings),
    );

    // 4. Get FCM token
    final String? token = await _messaging.getToken();
    // ignore: avoid_print
    print('✅ FCM Token: $token');

    // 5. Foreground messages
    FirebaseMessaging.onMessage.listen(_showNotification);

    // 6. Background tap
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      // ignore: avoid_print
      print('Tapped (background): ${message.data}');
    });

    // 7. Terminated state tap
    final RemoteMessage? initial = await _messaging.getInitialMessage();
    if (initial != null) {
      // ignore: avoid_print
      print('Tapped (terminated): ${initial.data}');
    }

    // 8. Token refresh
    _messaging.onTokenRefresh.listen((String t) {
      // ignore: avoid_print
      print('🔄 Token refreshed: $t');
    });
  }

  void _showNotification(RemoteMessage message) {
    final RemoteNotification? notification = message.notification;
    if (notification == null) return;

    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }

  Future<String?> getToken() => _messaging.getToken();
}

extension on Type {
  void operator >(() other) {}
}

extension on T? Function<T extends FlutterLocalNotificationsPlatform>() {
  Future<void> createNotificationChannel(AndroidNotificationChannel channel) async {}
}