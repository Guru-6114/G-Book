// lib/services/voice_notification_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// Text-to-speech voice notifications (Khatabook-style).
//
// Wraps flutter_tts + the 'voice_notifications' SharedPreferences flag that
// payment_settings_screen.dart already reads/writes, so:
//   - Toggling the switch immediately SPEAKS a confirmation
//     ("Voice notifications enabled" / "disabled"), not just flips a bool.
//   - Anywhere else in the app (e.g. when a payment is recorded) can call
//     announcePaymentReceived()/announcePaymentGiven() and it will only
//     actually speak if the user has the setting turned on.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VoiceNotificationService {
  VoiceNotificationService._();
  static final VoiceNotificationService instance =
      VoiceNotificationService._();

  static const String _prefsKey = 'voice_notifications';

  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;

  Future<void> _ensureInit() async {
    if (_initialized) return;
    try {
      await _tts.setLanguage('en-IN');
      await _tts.setSpeechRate(0.48);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);
    } catch (_) {
      // If TTS engine/voice pack isn't available on the device, fail
      // silently rather than crashing the settings screen.
    }
    _initialized = true;
  }

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsKey) ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, enabled);
  }

  /// Speaks unconditionally — used for the settings-screen toggle itself,
  /// so the user hears immediate confirmation the moment they flip it.
  Future<void> speakRaw(String message) async {
    await _ensureInit();
    try {
      await _tts.stop();
      await _tts.speak(message);
    } catch (_) {}
  }

  /// Speaks only if the user currently has voice notifications turned on —
  /// use this for real events (payment received/given) elsewhere in the app.
  Future<void> speakIfEnabled(String message) async {
    if (!await isEnabled()) return;
    await speakRaw(message);
  }

  Future<void> announceToggle(bool enabled) {
    return speakRaw(
        enabled ? 'Voice notifications enabled' : 'Voice notifications disabled');
  }

  Future<void> announcePaymentReceived(double amount) {
    return speakIfEnabled(
        'Payment of rupees ${amount.round()} received');
  }

  Future<void> announcePaymentGiven(double amount) {
    return speakIfEnabled('Payment of rupees ${amount.round()} given');
  }

  Future<void> dispose() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}