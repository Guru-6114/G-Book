// lib/services/notification_service.dart
// Stub - flutter_local_notifications disabled for now
typedef NotificationTapCallback = void Function(Map<String, dynamic> payload);

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();
  Future<void> initialize({NotificationTapCallback? onTap}) async {}
  Future<void> showPaymentReminder({required String customerName, required String amount, required String message, Map<String, dynamic>? payload}) async {}
  Future<void> showTransactionAlert({required String title, required String body, Map<String, dynamic>? payload}) async {}
  Future<void> showGeneralNotification({required String title, required String body, Map<String, dynamic>? payload}) async {}
  Future<void> cancelAll() async {}
  Future<void> cancel(int id) async {}
  Future<bool> areNotificationsEnabled() async => true;
}