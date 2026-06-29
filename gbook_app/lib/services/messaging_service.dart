// lib/services/messaging_service.dart
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

enum SmsResult {
  sent,
  permissionDenied,
  unsupportedPlatform,
  failed,
}

enum WhatsAppResult {
  sent,
  notInstalled,
  failed,
}

class MessagingService {
  MessagingService._();

  // Optional native channel for silently sending SMS (Android only).
  // If no native implementation is registered, calls fall through to the
  // intent-based fallback in sendSmsAutomatically/sendSmsViaIntent below.
  static const _smsChannel = MethodChannel('flutter/sms_sender');

  /// Attempts to send an SMS automatically via a native SmsManager channel
  /// (Android). If that's unavailable, permission is denied, or this is a
  /// platform where automatic sending isn't supported (e.g. iOS, desktop),
  /// this returns a result the caller can use to fall back to
  /// [sendSmsViaIntent] (opens the Messages app pre-filled).
  static Future<SmsResult> sendSmsAutomatically({
    required String phone,
    required String message,
  }) async {
    if (!Platform.isAndroid) {
      return SmsResult.unsupportedPlatform;
    }
    try {
      final result = await _smsChannel.invokeMethod<bool>('sendSms', {
        'phone': phone,
        'message': message,
      });
      if (result == true) return SmsResult.sent;
      return SmsResult.failed;
    } on PlatformException catch (e) {
      if (e.code == 'PERMISSION_DENIED') {
        return SmsResult.permissionDenied;
      }
      // No native implementation registered, or any other failure —
      // treat as unsupported so the caller falls back to the intent.
      return SmsResult.unsupportedPlatform;
    } on MissingPluginException {
      return SmsResult.unsupportedPlatform;
    } catch (_) {
      return SmsResult.failed;
    }
  }

  /// Opens the device's Messages app with the recipient and body
  /// pre-filled. The user still has to tap send — this is the universal
  /// fallback that works on every platform.
  static Future<void> sendSmsViaIntent({
    required String phone,
    required String message,
  }) async {
    final uri = Uri(
      scheme: 'sms',
      path: phone,
      queryParameters: {'body': message},
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Nothing more we can do — silently ignore so the UI doesn't crash.
    }
  }

  /// Opens WhatsApp directly to a chat with [phone] with [message]
  /// pre-filled, using the native `whatsapp://` scheme (more reliable than
  /// the `https://wa.me` web link, which can silently fail to detect
  /// whether WhatsApp is actually installed).
  static Future<WhatsAppResult> sendWhatsApp({
    required String phone,
    required String message,
  }) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    // Assume Indian numbers if no country code was given.
    final fullPhone =
        cleanPhone.startsWith('+') ? cleanPhone.substring(1) : '91$cleanPhone';

    final nativeUri = Uri.parse(
      'whatsapp://send?phone=$fullPhone&text=${Uri.encodeComponent(message)}',
    );
    final webUri = Uri.parse(
      'https://wa.me/$fullPhone?text=${Uri.encodeComponent(message)}',
    );

    try {
      final canOpenNative = await canLaunchUrl(nativeUri);
      if (canOpenNative) {
        final launched =
            await launchUrl(nativeUri, mode: LaunchMode.externalApplication);
        return launched ? WhatsAppResult.sent : WhatsAppResult.failed;
      }

      // WhatsApp app scheme not handled — it's not installed.
      final canOpenWeb = await canLaunchUrl(webUri);
      if (canOpenWeb) {
        // Falls back to WhatsApp Web / browser; still report not installed
        // since the app itself isn't present, but at least try to help.
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
        return WhatsAppResult.notInstalled;
      }

      return WhatsAppResult.notInstalled;
    } catch (_) {
      return WhatsAppResult.failed;
    }
  }
}