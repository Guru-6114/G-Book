// lib/screens/permissions_screen.dart
// FIX: permission_handler is imported but package won't resolve until
//      flutter pub get is run. This file is correct once pub get is done.
//      However, to keep the app building right now, we guard the import.

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ─── IMPORTANT ────────────────────────────────────────────────────────────────
// Run: flutter pub get
// Then the import below will work. Until then this screen shows a placeholder.
// Once pub get is done, replace this file with the full version below.
// ─────────────────────────────────────────────────────────────────────────────

class PermissionsScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const PermissionsScreen({super.key, required this.onComplete});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  bool _requesting = false;

  Future<void> _requestAll() async {
    setState(() => _requesting = true);

    // ── After flutter pub get: uncomment this block ──────────────────────────
    // import 'package:permission_handler/permission_handler.dart';
    // await [
    //   Permission.sms,
    //   Permission.contacts,
    //   Permission.camera,
    //   Permission.notification,
    // ].request();
    // ─────────────────────────────────────────────────────────────────────────

    // Simulate permission request delay
    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      setState(() => _requesting = false);
      widget.onComplete();
    }
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
              const SizedBox(height: 20),
              Center(
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Center(
                    child: Text(
                      'G',
                      style: TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.w900,
                          color: Colors.white),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Allow GBook to\nwork better',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    height: 1.3),
              ),
              const SizedBox(height: 8),
              const Text(
                'These permissions help GBook track payments and send reminders.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 32),
              _PermissionTile(
                icon: Icons.sms_outlined,
                color: const Color(0xFF1565C0),
                title: 'Read SMS',
                subtitle: 'Auto-detect bank transactions',
              ),
              _PermissionTile(
                icon: Icons.contacts_outlined,
                color: const Color(0xFF00695C),
                title: 'Contacts',
                subtitle: 'Add customers from your contacts',
              ),
              _PermissionTile(
                icon: Icons.camera_alt_outlined,
                color: const Color(0xFFAD1457),
                title: 'Camera',
                subtitle: 'Scan bills and upload receipts',
              ),
              _PermissionTile(
                icon: Icons.notifications_outlined,
                color: const Color(0xFFE65100),
                title: 'Notifications',
                subtitle: 'Get payment reminders',
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _requesting ? null : _requestAll,
                  child: _requesting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text(
                          'Allow Permissions',
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
  final Color color;
  final String title;
  final String subtitle;

  const _PermissionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
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
        ],
      ),
    );
  }
}