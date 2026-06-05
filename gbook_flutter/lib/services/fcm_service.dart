// lib/services/fcm_service.dart
// FIX: Firebase packages only resolve after flutter pub get + flutterfire configure.
// This file is a safe stub that compiles immediately.
// See the FULL VERSION at the bottom (commented) to activate after setup.

import 'package:flutter/foundation.dart';

// ─── STUB VERSION (works before firebase setup) ───────────────────────────────
class FcmService {
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;
  FcmService._internal();

  String? _token;
  String? get token => _token;

  Future<void> initialize() async {
    debugPrint('FCM: Not initialized yet. Run flutterfire configure first.');
  }

  Future<String?> getToken() async => null;
}
// ─────────────────────────────────────────────────────────────────────────────

// ─── FULL VERSION — uncomment AFTER: flutter pub get + flutterfire configure ──
//
// import 'dart:convert';
// import 'package:flutter/foundation.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:http/http.dart' as http;
// import 'package:shared_preferences/shared_preferences.dart';
// import '../utils/constants.dart';
//
// @pragma('vm:entry-point')
// Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
//   debugPrint('FCM background: ${message.notification?.title}');
// }
//
// class FcmService {
//   static final FcmService _instance = FcmService._internal();
//   factory FcmService() => _instance;
//   FcmService._internal();
//
//   final FirebaseMessaging _messaging = FirebaseMessaging.instance;
//   String? _token;
//   String? get token => _token;
//
//   Future<void> initialize() async {
//     // Register background handler
//     FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
//
//     // Request permissions (iOS)
//     final settings = await _messaging.requestPermission(
//       alert: true, badge: true, sound: true,
//     );
//
//     if (settings.authorizationStatus == AuthorizationStatus.authorized ||
//         settings.authorizationStatus == AuthorizationStatus.provisional) {
//       _token = await _messaging.getToken();
//       debugPrint('FCM Token: $_token');
//       await _saveTokenLocally(_token);
//       await _sendTokenToBackend(_token);
//     }
//
//     // Foreground messages
//     FirebaseMessaging.onMessage.listen((RemoteMessage message) {
//       debugPrint('FCM foreground: ${message.notification?.title}');
//       // NotificationService().showNotification(message) — enable after setup
//     });
//
//     // Token refresh
//     _messaging.onTokenRefresh.listen((newToken) {
//       _token = newToken;
//       _saveTokenLocally(newToken);
//       _sendTokenToBackend(newToken);
//     });
//   }
//
//   Future<String?> getToken() async {
//     _token ??= await _messaging.getToken();
//     return _token;
//   }
//
//   Future<void> _saveTokenLocally(String? token) async {
//     if (token == null) return;
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setString('fcm_token', token);
//   }
//
//   Future<void> _sendTokenToBackend(String? token) async {
//     if (token == null) return;
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       final authToken = prefs.getString('auth_token');
//       if (authToken == null) return;
//       await http.post(
//         Uri.parse('${AppConstants.baseUrl}/fcm/register/'),
//         headers: {
//           'Content-Type': 'application/json',
//           'Authorization': 'Bearer $authToken',
//         },
//         body: jsonEncode({'token': token, 'device_type': 'android'}),
//       );
//     } catch (e) {
//       debugPrint('FCM token backend sync failed: $e');
//     }
//   }
// }