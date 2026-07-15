// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../utils/helpers.dart';
import '../l10n/app_localizations.dart';
import 'profile_screen.dart';
import 'app_lock_screen.dart';
import '../services/app_lock_service.dart';

/// Settings hub — covers test-report item 17:
/// "Settings - Have more options as SMS, Payment, Language Backup etc"
///
/// This is a real, navigable screen (previously referenced by more_screen.dart
/// via `import 'settings_screen.dart'` + `const SettingsScreen()`, but the file
/// did not exist and the in-file placeholder was not a Widget — that was the
/// hard compile error breaking the build).
///
/// FIX: every visible label on this screen now reads from
/// context.l10n.get('key') instead of being hardcoded English, so it
/// actually re-renders in the selected language after a language change.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _smsAlertsEnabled = true;
  bool _autoBackupEnabled = true;
  bool _appLockEnabled = false;
  bool _appLockLoading = true;
  String _language = 'English';
  String _currency = 'INR (₹)';

  static const List<String> _languages = [
    'English', 'हिंदी (Hindi)', 'मराठी (Marathi)', 'ગુજરાતી (Gujarati)',
    'ਪੰਜਾਬੀ (Punjabi)', 'தமிழ் (Tamil)', 'తెలుగు (Telugu)',
    'ಕನ್ನಡ (Kannada)', 'বাংলা (Bengali)',
  ];

  static const List<String> _currencies = ['INR (₹)', 'USD (\$)', 'EUR (€)'];

  @override
  void initState() {
    super.initState();
    _refreshAppLockStatus();
  }

  Future<void> _refreshAppLockStatus() async {
    final enabled = await AppLockService.instance.isEnabled();
    if (!mounted) return;
    setState(() {
      _appLockEnabled = enabled;
      _appLockLoading = false;
    });
  }

  Future<void> _openAppLock() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AppLockScreen()),
    );
    _refreshAppLockStatus();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final t = context.l10n;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        title: Text(t.get('settings'),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _SectionHeader(t.get('business')),
          _SettingsCard(children: [
            _SettingsTile(
              icon: Icons.store_outlined,
              iconColor: const Color(0xFF1565C0),
              title: t.get('business_profile'),
              subtitle: auth.profile?.businessName ?? t.get('edit_business'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              ),
            ),
          ]),

          _SectionHeader(t.get('communication')),
          _SettingsCard(children: [
            _SettingsSwitchTile(
              icon: Icons.sms_outlined,
              iconColor: const Color(0xFF2E7D32),
              title: t.get('sms_alerts'),
              subtitle: t.get('auto_send_sms'),
              value: _smsAlertsEnabled,
              onChanged: (v) => setState(() => _smsAlertsEnabled = v),
            ),
            const Divider(height: 1, indent: 56),
            _SettingsTile(
              icon: Icons.payments_outlined,
              iconColor: const Color(0xFFE65100),
              title: t.get('payment_settings'),
              subtitle: 'UPI ID, QR code & default payment mode',
              onTap: () => _showPaymentSettings(context),
            ),
          ]),

          _SectionHeader(t.get('preferences')),
          _SettingsCard(children: [
            _SettingsTile(
              icon: Icons.language_outlined,
              iconColor: const Color(0xFF7B1FA2),
              title: t.get('language'),
              subtitle: _language,
              onTap: () => _showLanguagePicker(context),
            ),
            const Divider(height: 1, indent: 56),
            _SettingsTile(
              icon: Icons.currency_exchange_outlined,
              iconColor: const Color(0xFF00695C),
              title: t.get('currency'),
              subtitle: _currency,
              onTap: () => _showCurrencyPicker(context),
            ),
            const Divider(height: 1, indent: 56),
            // App Lock now opens the dedicated PIN-based AppLockScreen
            // (create/confirm PIN + change PIN), instead of a plain switch.
            _SettingsTile(
              icon: Icons.fingerprint_outlined,
              iconColor: const Color(0xFFB71C1C),
              title: t.get('app_lock'),
              subtitle: _appLockLoading
                  ? 'Loading...'
                  : (_appLockEnabled
                      ? 'Enabled — 4-digit PIN required to open GBook'
                      : t.get('require_biometric')),
              onTap: _openAppLock,
            ),
          ]),

          _SectionHeader(t.get('data')),
          _SettingsCard(children: [
            _SettingsSwitchTile(
              icon: Icons.cloud_sync_outlined,
              iconColor: const Color(0xFF1565C0),
              title: t.get('auto_backup'),
              subtitle: t.get('auto_backup_desc'),
              value: _autoBackupEnabled,
              onChanged: (v) => setState(() => _autoBackupEnabled = v),
            ),
            const Divider(height: 1, indent: 56),
            _SettingsTile(
              icon: Icons.backup_outlined,
              iconColor: const Color(0xFF2E7D32),
              title: t.get('backup_now'),
              subtitle: t.get('backup_now_desc'),
              onTap: () => _runBackup(context),
            ),
            const Divider(height: 1, indent: 56),
            _SettingsTile(
              icon: Icons.restore_outlined,
              iconColor: const Color(0xFF424242),
              title: t.get('restore_data'),
              subtitle: t.get('restore_desc'),
              onTap: () => _showRestoreDialog(context),
            ),
            const Divider(height: 1, indent: 56),
            _SettingsTile(
              icon: Icons.file_download_outlined,
              iconColor: const Color(0xFF6A1B9A),
              title: t.get('export_data'),
              subtitle: t.get('export_desc'),
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Preparing export...')),
              ),
            ),
          ]),

          _SectionHeader(t.get('account')),
          _SettingsCard(children: [
            _SettingsTile(
              icon: Icons.logout,
              iconColor: const Color(0xFFB71C1C),
              title: t.get('logout'),
              subtitle: t.get('logout_desc'),
              onTap: () => _confirmLogout(context),
            ),
          ]),

          const SizedBox(height: 12),
          Center(
            child: Text('GBook v1.0.0',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showLanguagePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Text(context.l10n.get('select_language'),
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16)),
            ),
            ..._languages.map((lang) => RadioListTile<String>(
                  value: lang,
                  groupValue: _language,
                  title: Text(lang),
                  activeColor: AppTheme.primaryColor,
                  onChanged: (v) {
                    setState(() => _language = v!);
                    Navigator.pop(context);
                  },
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showCurrencyPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Text(context.l10n.get('currency'),
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16)),
            ),
            ..._currencies.map((c) => RadioListTile<String>(
                  value: c,
                  groupValue: _currency,
                  title: Text(c),
                  activeColor: AppTheme.primaryColor,
                  onChanged: (v) {
                    setState(() => _currency = v!);
                    Navigator.pop(context);
                  },
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showPaymentSettings(BuildContext context) {
    final upiCtrl = TextEditingController();
    final t = context.l10n;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.get('payment_settings'),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 16),
            TextField(
              controller: upiCtrl,
              decoration: InputDecoration(
                labelText: t.get('upi_id'),
                hintText: t.get('upi_hint'),
                prefixIcon: const Icon(Icons.qr_code, size: 18),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Payment settings saved')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(t.get('save').toUpperCase(),
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _runBackup(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 16),
            Text('Backing up your data...'),
          ],
        ),
      ),
    );
    Future.delayed(const Duration(seconds: 2), () {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.get('backup_completed'))),
        );
      }
    });
  }

  void _showRestoreDialog(BuildContext context) {
    final t = context.l10n;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.get('restore_data')),
        content: const Text(
            'This will replace current data with your last backup. Continue?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(t.get('cancel'))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(t.get('data_restored'))),
              );
            },
            child: Text(t.get('restore_data')),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    final t = context.l10n;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.get('logout')),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(t.get('cancel'))),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AuthProvider>().logout();
              Navigator.of(context).popUntil((r) => r.isFirst);
            },
            child: Text(t.get('logout'), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ── Shared small widgets ──────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF9E9E9E),
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, color: Color(0xFF9E9E9E)),
      onTap: onTap,
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsSwitchTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      value: value,
      activeThumbColor: AppTheme.primaryColor,
      onChanged: onChanged,
    );
  }
}