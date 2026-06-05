// lib/screens/permissions_screen.dart
// PASTE TO: gbook_flutter/lib/screens/permissions_screen.dart
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme/app_theme.dart';
import 'auth_screens.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  bool _isRequesting = false;

  static const List<_PermissionItem> _permissions = [
    _PermissionItem(
      icon: Icons.sms_outlined,
      title: 'SMS',
      description:
          'We collect SMS data to show Passbook, send payment alerts '
          'and provide relevant financial services. We do not collect '
          'personal messages or OTPs. SMS data may be collected even '
          'when the app is not in use',
    ),
    _PermissionItem(
      icon: Icons.location_on_outlined,
      title: 'LOCATION',
      description:
          'We use your approximate location to enable regional features '
          'and provide relevant financial services. Location data is '
          'collected only when the app is in use.',
    ),
    _PermissionItem(
      icon: Icons.notifications_outlined,
      title: 'NOTIFICATIONS',
      description:
          'We send payment reminders, collection alerts, and important '
          'account updates through notifications to help you manage your '
          'business with ease.',
    ),
    _PermissionItem(
      icon: Icons.phone_android_outlined,
      title: 'PHONE STATE',
      description:
          'GBook needs access to your phone state to identify the default '
          'SIM card for sending Reminder SMSes from your device.',
    ),
  ];

  Future<void> _requestPermissionsAndContinue() async {
    if (_isRequesting) return;
    setState(() => _isRequesting = true);

    try {
      await Permission.sms.request();
      await Permission.locationWhenInUse.request();
      await Permission.notification.request();
      await Permission.phone.request();
    } catch (_) {
      // Some permissions may not be available on all devices
    }

    if (!mounted) return;
    setState(() => _isRequesting = false);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const AuthScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: SafeArea(
        child: Column(
          children: [
            // Blue header
            Container(
              width: double.infinity,
              color: AppTheme.primaryColor,
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 24),
              child: Column(
                children: [
                  const Text(
                    'Allow permissions to continue',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Grant access to use GBook',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  // Security badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_outlined,
                            color: Colors.white, size: 16),
                        SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'GBook guarantees 100% data safety & security',
                            style: TextStyle(
                                color: Colors.white, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Permissions list card
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _permissions.length,
                  separatorBuilder: (_, __) => const Divider(
                    height: 1,
                    indent: 56,
                    endIndent: 16,
                  ),
                  itemBuilder: (_, i) {
                    final p = _permissions[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(p.icon,
                              color: const Color(0xFF546E7A), size: 24),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: Color(0xFF212121),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  p.description,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF757575),
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),

            // Bottom buttons
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isRequesting
                          ? null
                          : _requestPermissionsAndContinue,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: _isRequesting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              'Continue',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AuthScreen()),
                    ),
                    child: const Text.rich(
                      TextSpan(
                        style: TextStyle(
                            fontSize: 12, color: Color(0xFF757575)),
                        children: [
                          TextSpan(text: 'By continuing, you agree to our '),
                          TextSpan(
                            text: 'Privacy Policy',
                            style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Must be const-constructible for use in const list
class _PermissionItem {
  final IconData icon;
  final String title;
  final String description;
  const _PermissionItem({
    required this.icon,
    required this.title,
    required this.description,
  });
}