// lib/services/sim_info_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// Reads the phone's ACTUAL SIM cards (carrier name per slot), matching
// Khatabook's "Select SIM Slot" behaviour — e.g. "SIM 1 (Airtel)" — instead
// of a hardcoded 'SIM 1' / 'SIM 2' placeholder list.
//
// Implemented via a native MethodChannel (android/.../MainActivity.java)
// using android.telephony.SubscriptionManager, since the sim_data pub
// package (last published 0.0.2) only supports Flutter's old v1 Android
// embedding and no longer compiles against current Flutter SDKs.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class SimCardInfo {
  final int slotIndex;
  final String displayName;
  final String? carrierName;

  const SimCardInfo({
    required this.slotIndex,
    required this.displayName,
    this.carrierName,
  });

  /// Label shown in the picker, e.g. "SIM 1 (Airtel)".
  String get label {
    final carrier = (carrierName != null && carrierName!.trim().isNotEmpty)
        ? carrierName!.trim()
        : displayName;
    return 'SIM ${slotIndex + 1} ($carrier)';
  }
}

class SimInfoService {
  SimInfoService._();
  static final SimInfoService instance = SimInfoService._();

  static const _channel = MethodChannel('com.gbook.app/sim_info');

  /// Returns the phone's real SIM cards. Returns an empty list if the
  /// permission is denied, the device has no readable SIM info, or this
  /// isn't a platform that exposes SIM data (e.g. iOS) — callers should
  /// fall back to a "Default" option in that case.
  Future<List<SimCardInfo>> getSimCards() async {
    try {
      final status = await Permission.phone.request();
      if (!status.isGranted) return [];

      final result = await _channel.invokeMethod<List<dynamic>>('getSimCards');
      if (result == null) return [];

      return result.map((raw) {
        final map = Map<String, dynamic>.from(raw as Map);
        return SimCardInfo(
          slotIndex: map['slotIndex'] as int,
          displayName: map['displayName'] as String,
          carrierName: map['carrierName'] as String?,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }
}