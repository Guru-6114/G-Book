// lib/services/notification_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// Handles flutter_local_notifications: display, channels, tap routing
// Dependency: flutter_local_notifications: ^17.2.3
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Callback type invoked when user taps a notification
typedef NotificationTapCallback = void Function(Map<String, dynamic> payload);

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  NotificationTapCallback? _onTap;

  // ── Android notification channel IDs ───────────────────────────────────────
  static const String _paymentChannelId = 'payment_reminders';
  static const String _generalChannelId = 'general';
  static const String _transactionChannelId = 'transactions';

  // ── Initialize ─────────────────────────────────────────────────────────────

  Future<void> initialize({NotificationTapCallback? onTap}) async {
    _onTap = onTap;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundResponse,
    );

    // Create Android channels
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _paymentChannelId,
          'Payment Reminders',
          description:
              'Notifications for payment reminders sent to customers',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
          showBadge: true,
        ),
      );
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _generalChannelId,
          'General Notifications',
          description: 'General app notifications',
          importance: Importance.defaultImportance,
          playSound: true,
        ),
      );
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _transactionChannelId,
          'Transaction Alerts',
          description: 'Notifications for new transactions',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        ),
      );

      // Request Android 13+ notification permission
      await androidPlugin.requestNotificationsPermission();
    }

    // Request iOS permission
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  // ── Notification tap handlers ──────────────────────────────────────────────

  void _onNotificationResponse(NotificationResponse response) {
    final raw = response.payload;
    if (raw != null && raw.isNotEmpty) {
      try {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        _onTap?.call(data);
      } catch (_) {}
    }
  }

  @pragma('vm:entry-point')
  static void _onBackgroundResponse(NotificationResponse response) {
    // Minimal work only — runs in isolate
  }

  // ── Public show helpers ────────────────────────────────────────────────────

  Future<void> showPaymentReminder({
    required String customerName,
    required String amount,
    required String message,
    Map<String, dynamic>? payload,
  }) async {
    final body = message.isNotEmpty
        ? message
        : '$customerName owes you ₹$amount. Tap to send reminder.';

    await _show(
      id: customerName.hashCode.abs() % 100000,
      title: '💰 Payment Reminder: $customerName',
      body: body,
      channelId: _paymentChannelId,
      channelName: 'Payment Reminders',
      payload: payload ?? {'type': 'payment_reminder', 'customer': customerName},
      styleInformation: BigTextStyleInformation(
        '$customerName owes you ₹$amount. Tap to view details and send a reminder.',
        contentTitle: '💰 Payment Reminder',
        summaryText: customerName,
      ),
    );
  }

  Future<void> showTransactionAlert({
    required String title,
    required String body,
    Map<String, dynamic>? payload,
  }) async {
    await _show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      channelId: _transactionChannelId,
      channelName: 'Transaction Alerts',
      payload: payload ?? {'type': 'transaction'},
    );
  }

  Future<void> showGeneralNotification({
    required String title,
    required String body,
    Map<String, dynamic>? payload,
  }) async {
    await _show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      channelId: _generalChannelId,
      channelName: 'General Notifications',
      payload: payload,
    );
  }

  // ── Core show ──────────────────────────────────────────────────────────────

  Future<void> _show({
    required int id,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
    Map<String, dynamic>? payload,
    StyleInformation? styleInformation,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      styleInformation: styleInformation,
      color: const Color(0xFF1A6B3C),
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: const DarwinNotificationDetails(),
    );

    await _plugin.show(
      id,
      title,
      body,
      details,
      payload: payload != null ? jsonEncode(payload) : null,
    );
  }

  // ── Cancel ─────────────────────────────────────────────────────────────────

  Future<void> cancelAll() => _plugin.cancelAll();
  Future<void> cancel(int id) => _plugin.cancel(id);

  Future<bool> areNotificationsEnabled() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.areNotificationsEnabled() ?? false;
    }
    return true;
  }
}