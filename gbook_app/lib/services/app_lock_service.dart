// lib/services/app_lock_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// Stores whether App Lock is enabled and the 4-digit PIN (SharedPreferences).
// ─────────────────────────────────────────────────────────────────────────────
import 'package:shared_preferences/shared_preferences.dart';

class AppLockService {
  AppLockService._();
  static final AppLockService instance = AppLockService._();

  static const _kEnabledKey = 'app_lock_enabled';
  static const _kPinKey = 'app_lock_pin';

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kEnabledKey) ?? false;
  }

  Future<bool> hasPin() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString(_kPinKey) ?? '').isNotEmpty;
  }

  /// Saves the PIN and turns App Lock on.
  Future<void> setPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPinKey, pin);
    await prefs.setBool(_kEnabledKey, true);
  }

  Future<bool> verifyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_kPinKey) ?? '';
    return stored.isNotEmpty && stored == pin;
  }

  /// Turns lock ON only if a PIN already exists.
  Future<void> enable() async {
    if (await hasPin()) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kEnabledKey, true);
    }
  }

  Future<void> disable() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabledKey, false);
  }
}