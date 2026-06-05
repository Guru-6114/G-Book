// lib/services/notification_service.dart
// PASTE TO: gbook_flutter/lib/services/notification_service.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Top-level handler for background messages (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Background message: ${message.messageId}');
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // Use final (not const) — AndroidNotificationChannel is not const-compatible
  final AndroidNotificationChannel _paymentChannel =
      const AndroidNotificationChannel(
    'payment_reminders',
    'Payment Reminders',
    description: 'Reminders to collect or pay dues',
    importance: Importance.high,
    playSound: true,
  );

  final AndroidNotificationChannel _transactionChannel =
      const AndroidNotificationChannel(
    'transactions',
    'Transactions',
    description: 'New transaction alerts',
    importance: Importance.defaultImportance,
    playSound: true,
  );

  final AndroidNotificationChannel _generalChannel =
      const AndroidNotificationChannel(
    'general',
    'General',
    description: 'General GBook notifications',
    importance: Importance.low,
  );

  /// Call once at app startup
  Future<void> initialize() async {
    // Register background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Android init settings
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS init settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create Android channels
    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(_paymentChannel);
    await androidPlugin?.createNotificationChannel(_transactionChannel);
    await androidPlugin?.createNotificationChannel(_generalChannel);

    // Request iOS/Android 13+ permission
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Listen to foreground FCM messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Listen to notification taps when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpen);

    // Check for initial message (app opened from terminated via notification)
    final initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationOpen(initialMessage);
    }

    // Save FCM token
    await _saveFcmToken();

    // Token refresh listener
    FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token', token);
      debugPrint('FCM token refreshed: $token');
    });
  }

  Future<void> _saveFcmToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fcm_token', token);
        debugPrint('FCM Token: $token');
      }
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
    }
  }

  /// Get stored FCM token (used to send to backend)
  Future<String?> getFcmToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('fcm_token');
  }

  void _onNotificationTap(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
    // TODO: Navigate based on payload
  }

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('Foreground message: ${message.notification?.title}');
    final notification = message.notification;
    final android = message.notification?.android;

    if (notification != null) {
      _showLocalNotification(
        id: message.hashCode,
        title: notification.title ?? 'GBook',
        body: notification.body ?? '',
        channelId: android?.channelId ?? 'general',
        payload: jsonEncode(message.data),
      );
    }
  }

  void _handleNotificationOpen(RemoteMessage message) {
    debugPrint('Notification opened app: ${message.data}');
    // TODO: Navigate based on message.data['route']
  }

  Future<void> _showLocalNotification({
    required int id,
    required String title,
    required String body,
    String channelId = 'general',
    String? payload,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelId,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      styleInformation: BigTextStyleInformation(body),
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

    await _plugin.show(id, title, body, details, payload: payload);
  }

  /// Show a local payment reminder notification
  Future<void> showPaymentReminder({
    required String customerName,
    required double amount,
  }) async {
    await _showLocalNotification(
      id: customerName.hashCode,
      title: 'Payment Reminder',
      body: '$customerName has an outstanding balance of ₹${amount.toStringAsFixed(2)}',
      channelId: 'payment_reminders',
    );
  }

  /// Show a transaction notification
  Future<void> showTransactionAlert({
    required String title,
    required String message,
  }) async {
    await _showLocalNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: message,
      channelId: 'transactions',
    );
  }
}