import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // ignore: avoid_print
  print('Background message: ${message.messageId}');
}

class NotificationService {
  static final NotificationService _instance =
      NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel channel =
      AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'Used for important notifications',
    importance: Importance.high,
  );

  Future<void> initialize() async {
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation as AndroidFlutterLocalNotificationsPlugin?;
            AndroidFlutterLocalNotificationsPlugin();
    await androidPlugin?.createNotificationChannel(channel);

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    await _localNotifications.initialize(
      const InitializationSettings(android: androidSettings),
    );

    final String? token = await _messaging.getToken();
    // ignore: avoid_print
    print('FCM Token: $token');

    FirebaseMessaging.onMessage.listen(_showNotification);

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      // ignore: avoid_print
      print('Tapped (background): ${message.data}');
    });

    final RemoteMessage? initial = await _messaging.getInitialMessage();
    if (initial != null) {
      // ignore: avoid_print
      print('Tapped (terminated): ${initial.data}');
    }

    _messaging.onTokenRefresh.listen((String t) {
      // ignore: avoid_print
      print('Token refreshed: $t');
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




