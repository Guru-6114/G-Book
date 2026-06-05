// lib/services/notification_service.dart
// FIX: flutter_local_notifications only resolves after flutter pub get.
// This stub compiles immediately. Activate full version after pub get.

import 'package:flutter/foundation.dart';

// ─── STUB VERSION ─────────────────────────────────────────────────────────────
class NotificationService {
  static final NotificationService _instance =
      NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _paymentChannel =
      AndroidNotificationChannel(
    'payment_reminders',
    'Payment Reminders',
    description: 'Reminders for outstanding payments',
    importance: Importance.high,
  );

  static const AndroidNotificationChannel _transactionChannel =
      AndroidNotificationChannel(
    'transactions',
    'Transactions',
    description: 'New transaction notifications',
    importance: Importance.high,
  );

  static const AndroidNotificationChannel _generalChannel =
      AndroidNotificationChannel(
    'general',
    'General',
    description: 'General notifications',
    importance: Importance.defaultImportance,
  );

  Future<void> initialize() async {
    debugPrint(
        'NotificationService: stub. Run flutter pub get to activate.');
  }

  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    debugPrint('NOTIFICATION: $title — $body');
  }
}
// ─────────────────────────────────────────────────────────────────────────────

// ─── FULL VERSION — uncomment AFTER flutter pub get ──────────────────────────

//import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
//
// class NotificationService {
//   static final NotificationService _instance = NotificationService._internal();
//   factory NotificationService() => _instance;
//   NotificationService._internal();
//
//   final FlutterLocalNotificationsPlugin _plugin =
//       FlutterLocalNotificationsPlugin();
//
//   static const AndroidNotificationChannel _paymentChannel =
//       AndroidNotificationChannel(
//     'payment_reminders',
//     'Payment Reminders',
//     description: 'Reminders for outstanding payments',
//     importance: Importance.high,
//   );
//
//   static const AndroidNotificationChannel _transactionChannel =
//       AndroidNotificationChannel(
//     'transactions',
//     'Transactions',
//     description: 'New transaction notifications',
//     importance: Importance.high,
//   );
//
//   static const AndroidNotificationChannel _generalChannel =
//       AndroidNotificationChannel(
//     'general',
//     'General',
//     description: 'General notifications',
//     importance: Importance.defaultImportance,
//   );
//
//   Future<void> initialize() async {
//     const androidSettings =
//         AndroidInitializationSettings('@mipmap/ic_launcher');
//     const iosSettings = DarwinInitializationSettings(
//       requestAlertPermission: true,
//       requestBadgePermission: true,
//       requestSoundPermission: true,
//     );
//     const initSettings = InitializationSettings(
//       android: androidSettings,
//       iOS: iosSettings,
//     );
//
//     await _plugin.initialize(
//       initSettings,
//       onDidReceiveNotificationResponse: _onNotificationTap,
//       onDidReceiveBackgroundNotificationResponse: _onNotificationTap,
//     );
//
//     // Create Android channels
//     final androidPlugin = _plugin
//         .resolvePlatformSpecificImplementation<
//             AndroidFlutterLocalNotificationsPlugin>();
//     await androidPlugin?.createNotificationChannel(_paymentChannel);
//     await androidPlugin?.createNotificationChannel(_transactionChannel);
//     await androidPlugin?.createNotificationChannel(_generalChannel);
//   }
//
//   Future<void> showNotification({
//     required String title,
//     required String body,
//     String? payload,
//     String channelId = 'general',
//   }) async {
//     final styleInfo = BigTextStyleInformation(body);
//     final StyleInformation style = styleInfo;
//
//     final androidDetails = AndroidNotificationDetails(
//       channelId,
//       channelId,
//       importance: Importance.high,
//       priority: Priority.high,
//       styleInformation: style,
//       largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
//     );
//     const iosDetails = DarwinNotificationDetails(
//       presentAlert: true,
//       presentBadge: true,
//       presentSound: true,
//     );
//     final details = NotificationDetails(
//       android: androidDetails,
//       iOS: iosDetails,
//     );
//
//     await _plugin.show(
//       DateTime.now().millisecondsSinceEpoch ~/ 1000,
//       title,
//       body,
//       details,
//       payload: payload,
//     );
//   }
//
//   void showFromFcm(RemoteMessage message) {
//     final n = message.notification;
//     if (n == null) return;
//     showNotification(
//       title: n.title ?? '',
//       body: n.body ?? '',
//       payload: message.data['type'],
//       channelId: message.data['channel'] ?? 'general',
//     );
//   }
// }
//
// @pragma('vm:entry-point')
// void _onNotificationTap(NotificationResponse response) {
//   debugPrint('Notification tapped: ${response.payload}');
//}