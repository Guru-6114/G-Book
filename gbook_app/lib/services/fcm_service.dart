// lib/services/fcm_service.dart
// Stub - Firebase disabled for now
class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();
  String? get fcmToken => null;
  Future<void> initialize() async {}
  Future<void> registerTokenWithBackend() async {}
  Future<void> unregisterTokenFromBackend() async {}
}