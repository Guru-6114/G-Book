// lib/services/fcm_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// Firebase Cloud Messaging: token management, foreground/background handling
// Dependencies: firebase_messaging: ^15.1.3
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import 'notification_service.dart';

// ── Background handler — MUST be top-level, not inside a class ───────────────
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM] Background message: ${message.messageId}');
  final notification = message.notification;
  if (notification != null) {
    await NotificationService.instance.showGeneralNotification(
      title: notification.title ?? 'GBook',
      body: notification.body ?? '',
      payload: message.data,
    );
  }
}

class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  String? _fcmToken;

  String? get fcmToken => _fcmToken;

  // ── Initialize ─────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    // Register background handler (must be called before any other FCM usage)
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _requestPermission();
    await _fetchAndCacheToken();

    // Listen for token refresh
    _messaging.onTokenRefresh.listen(_onTokenRefresh);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // App opened from background notification tap
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);

    // App opened from terminated state via notification
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageTap(initialMessage);
    }
  }

  // ── Permission ─────────────────────────────────────────────────────────────

  Future<bool> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    final granted =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;
    debugPrint('[FCM] Permission granted: $granted');
    return granted;
  }

  // ── Token management ───────────────────────────────────────────────────────

  Future<void> _fetchAndCacheToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        _fcmToken = token;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fcm_token', token);
        debugPrint('[FCM] Token obtained: ${token.substring(0, 20)}...');
      }
    } catch (e) {
      debugPrint('[FCM] Token fetch error: $e');
    }
  }

  Future<void> _onTokenRefresh(String newToken) async {
    _fcmToken = newToken;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fcm_token', newToken);
    debugPrint('[FCM] Token refreshed');
    await registerTokenWithBackend();
  }

  Future<String?> getStoredToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('fcm_token');
  }

  // ── Register token with Django backend ────────────────────────────────────

  Future<void> registerTokenWithBackend() async {
    try {
      final token = _fcmToken ?? await getStoredToken();
      if (token == null) return;

      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString(AppConstants.tokenKey);
      if (authToken == null) return; // Not logged in yet

      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/fcm/register/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({
          'token': token,
          'platform': defaultTargetPlatform.name.toLowerCase(),
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('[FCM] Token registered with backend');
      } else {
        debugPrint('[FCM] Backend registration failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[FCM] Backend registration error: $e');
    }
  }

  Future<void> unregisterTokenFromBackend() async {
    try {
      final token = _fcmToken ?? await getStoredToken();
      if (token == null) return;

      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString(AppConstants.tokenKey);
      if (authToken == null) return;

      await http.post(
        Uri.parse('${AppConstants.baseUrl}/fcm/unregister/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({'token': token}),
      );

      await prefs.remove('fcm_token');
      _fcmToken = null;
      debugPrint('[FCM] Token unregistered');
    } catch (e) {
      debugPrint('[FCM] Unregister error: $e');
    }
  }

  // ── Message handlers ───────────────────────────────────────────────────────

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    debugPrint('[FCM] Foreground message: ${message.messageId}');
    final notification = message.notification;
    if (notification == null) return;

    final type = message.data['type'] as String? ?? 'general';

    if (type == 'payment_reminder') {
      await NotificationService.instance.showPaymentReminder(
        customerName: message.data['customer_name'] ?? 'Customer',
        amount: message.data['amount'] ?? '0',
        message: notification.body ?? '',
        payload: message.data,
      );
    } else if (type == 'transaction') {
      await NotificationService.instance.showTransactionAlert(
        title: notification.title ?? 'New Transaction',
        body: notification.body ?? '',
        payload: message.data,
      );
    } else {
      await NotificationService.instance.showGeneralNotification(
        title: notification.title ?? 'GBook',
        body: notification.body ?? '',
        payload: message.data,
      );
    }
  }

  void _onMessageOpenedApp(RemoteMessage message) {
    debugPrint('[FCM] App opened from background notification');
    _handleMessageTap(message);
  }

  void _handleMessageTap(RemoteMessage message) {
    debugPrint('[FCM] Notification tapped, data: ${message.data}');
    // Payload handling is done in main.dart via NotificationService._onTap
  }

  // ── iOS foreground options ─────────────────────────────────────────────────

  Future<void> setForegroundNotificationPresentationOptions() async {
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  // ── Topic subscriptions ────────────────────────────────────────────────────

  Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
    debugPrint('[FCM] Subscribed to: $topic');
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
    debugPrint('[FCM] Unsubscribed from: $topic');
  }
}