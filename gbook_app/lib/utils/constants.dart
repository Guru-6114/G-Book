library constants;

class AppConstants {
  static const String appName = 'GBook';

  // ─── Base URL ─────────────────────────────────────────────────
  // Physical device (wireless) — your PC's LAN IP
 static const String baseUrl = 'https://resolved-matching-establish.ngrok-free.dev/api';
  // Android emulator
  // static const String baseUrl = 'http://10.0.2.2:8000/api';
  // iOS simulator
  // static const String baseUrl = 'http://localhost:8000/api';

  // ─── Storage keys ─────────────────────────────────────────────
  static const String tokenKey = 'auth_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userKey = 'user_data';

  // ─── Timeouts ─────────────────────────────────────────────────
  static const int connectionTimeout = 30000;
  static const int receiveTimeout = 30000;

  // ─── Transaction types ────────────────────────────────────────
  static const String credit = 'credit';
  static const String debit = 'debit';

  // ─── Payment modes ────────────────────────────────────────────
  // Must match Django backend choices (lowercase)
  static const List<String> paymentModes = [
    'Cash',
    'UPI',
    'Bank Transfer',
    'Cheque',
    'Other',
  ];

  // ─── Payment mode API values ──────────────────────────────────
  // Django expects lowercase: cash, upi, bank_transfer, cheque, other
  static String paymentModeToApi(String mode) {
    return switch (mode) {
      'Cash' => 'cash',
      'UPI' => 'upi',
      'Bank Transfer' => 'bank_transfer',
      'Cheque' => 'cheque',
      _ => 'other',
    };
  }

  static String paymentModeFromApi(String mode) {
    return switch (mode) {
      'cash' => 'Cash',
      'upi' => 'UPI',
      'bank_transfer' => 'Bank Transfer',
      'cheque' => 'Cheque',
      _ => 'Other',
    };
  }
}