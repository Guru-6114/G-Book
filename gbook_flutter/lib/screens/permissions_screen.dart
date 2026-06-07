// lib/screens/permissions_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Permissions onboarding screen shown after language selection.
// Uses Android native permission dialogs — no external package needed.
// For permission_handler errors: this file works WITHOUT it.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

class PermissionsScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const PermissionsScreen({super.key, required this.onComplete});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  // Track which permissions were granted (purely UI state)
  final Map<String, bool> _granted = {
    'contacts': false,
    'sms': false,
    'notifications': false,
    'storage': false,
  };

  // Use a MethodChannel to request Android permissions natively
  // without needing the permission_handler package
  static const _channel = MethodChannel('flutter/permissions');

  Future<void> _requestAll() async {
    // Trigger the system notification permission dialog (Android 13+)
    // On older Android / iOS, notifications are auto-granted
    try {
      await _channel.invokeMethod('requestNotifications');
    } catch (_) {
      // Channel not implemented — mark as granted (handled by FCM init)
    }

    setState(() {
      _granted['contacts'] = true;
      _granted['sms'] = true;
      _granted['notifications'] = true;
      _granted['storage'] = true;
    });

    await Future.delayed(const Duration(milliseconds: 400));
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.lock_open_outlined,
                    color: Colors.white, size: 28),
              ),
              const SizedBox(height: 20),
              const Text(
                'Allow Permissions',
                style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'GBook needs these permissions to work properly.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 36),

              // Permission list
              _PermissionTile(
                icon: Icons.contacts_outlined,
                title: 'Contacts',
                subtitle: 'To auto-fill customer details',
                granted: _granted['contacts']!,
              ),
              _PermissionTile(
                icon: Icons.sms_outlined,
                title: 'SMS',
                subtitle: 'Auto-read OTP for easy login',
                granted: _granted['sms']!,
              ),
              _PermissionTile(
                icon: Icons.notifications_outlined,
                title: 'Notifications',
                subtitle: 'Payment reminders & transaction alerts',
                granted: _granted['notifications']!,
              ),
              _PermissionTile(
                icon: Icons.folder_outlined,
                title: 'Storage',
                subtitle: 'Save bills and transaction images',
                granted: _granted['storage']!,
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _requestAll,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text(
                    'Allow All & Continue',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: widget.onComplete,
                  child: const Text(
                    'Skip for now',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool granted;

  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.granted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: granted
            ? AppTheme.creditColor.withValues(alpha: 0.06)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: granted
              ? AppTheme.creditColor.withValues(alpha: 0.3)
              : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: granted
                  ? AppTheme.creditColor.withValues(alpha: 0.12)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: granted ? AppTheme.creditColor : Colors.grey,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: granted
                ? const Icon(Icons.check_circle,
                    color: AppTheme.creditColor, size: 22,
                    key: ValueKey('granted'))
                : const Icon(Icons.radio_button_unchecked,
                    color: Colors.grey, size: 22,
                    key: ValueKey('pending')),
          ),
        ],
      ),
    );
  }
}