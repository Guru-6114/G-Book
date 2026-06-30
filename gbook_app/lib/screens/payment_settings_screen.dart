// lib/screens/payment_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/locale_provider.dart';
import '../theme/app_theme.dart';
import '../utils/helpers.dart';
import '../l10n/app_localizations.dart';

class PaymentSettingsScreen extends StatefulWidget {
  const PaymentSettingsScreen({super.key});

  @override
  State<PaymentSettingsScreen> createState() => _PaymentSettingsScreenState();
}

class _PaymentSettingsScreenState extends State<PaymentSettingsScreen> {
  bool _voiceNotifications = false;
  bool _dailySettlements = true;
  final _upiCtrl = TextEditingController();
  bool _saving = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _voiceNotifications = prefs.getBool('voice_notifications') ?? false;
      _dailySettlements = prefs.getBool('daily_settlements') ?? true;
      _upiCtrl.text = prefs.getString('upi_id') ?? '';
      _loading = false;
    });
  }

  @override
  void dispose() {
    _upiCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('voice_notifications', _voiceNotifications);
    await prefs.setBool('daily_settlements', _dailySettlements);
    await prefs.setString('upi_id', _upiCtrl.text.trim());
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() => _saving = false);
    AppHelpers.showSuccessSnackBar(
        context, '${context.l10n.get('payment_settings')} ${context.l10n.get('save')}');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          title: Text(t.get('payment_settings')),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        title: Text(t.get('payment_settings'),
            style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 16),
                  decoration: const BoxDecoration(
                    border: Border(
                        bottom: BorderSide(color: Color(0xFFE0E0E0))),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(t.get('voice_notifications'),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15)),
                                const SizedBox(width: 8),
                                const Icon(Icons.volume_off,
                                    size: 18, color: Colors.grey),
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  color: Colors.red,
                                  child: const Text('NEW',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              t.get('voice_alert'),
                              style: const TextStyle(
                                  fontSize: 13, color: Color(0xFF757575)),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _voiceNotifications,
                        activeThumbColor: AppTheme.primaryColor,
                        onChanged: (v) =>
                            setState(() => _voiceNotifications = v),
                      ),
                    ],
                  ),
                ),

                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 16),
                  decoration: const BoxDecoration(
                    border: Border(
                        bottom: BorderSide(color: Color(0xFFE0E0E0))),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.get('daily_settlements'),
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 4),
                      Text(
                        t.get('auto_settle'),
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF757575)),
                      ),
                    ],
                  ),
                ),

                InkWell(
                  onTap: () => _showBankAccounts(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    decoration: const BoxDecoration(
                      border: Border(
                          bottom: BorderSide(color: Color(0xFFE0E0E0))),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t.get('bank_accounts'),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15)),
                              Text(
                                t.get('manage_bank'),
                                style: const TextStyle(
                                    fontSize: 13, color: Color(0xFF757575)),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right,
                            color: AppTheme.primaryColor),
                      ],
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.get('upi_id'),
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _upiCtrl,
                        decoration: InputDecoration(
                          hintText: t.get('upi_hint'),
                          prefixIcon: const Icon(Icons.qr_code, size: 18),
                          filled: true,
                          fillColor: const Color(0xFFF5F5F5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                InkWell(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(t.get('payment_settings')),
                        content: const Text(
                            'For payment queries:\n\nCall: 1800-000-000\nEmail: support@gbook.in\n\nMon-Sat, 9 AM – 7 PM'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: Text(t.get('cancel'))),
                        ],
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    decoration: const BoxDecoration(
                      border: Border(
                          bottom: BorderSide(color: Color(0xFFE0E0E0))),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t.get('help'),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15)),
                              Text(
                                t.get('payment_faqs'),
                                style: const TextStyle(
                                    fontSize: 13, color: Color(0xFF757575)),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right,
                            color: AppTheme.primaryColor),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(context).padding.bottom + 12,
            ),
            color: Colors.white,
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text(t.get('save').toUpperCase(),
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            letterSpacing: 1)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showBankAccounts(BuildContext context) {
    final t = context.l10n;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, ctrl) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Text(t.get('bank_accounts'),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16)),
                  const Spacer(),
                  IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.all(16),
                children: [
                  const Icon(Icons.account_balance_outlined,
                      size: 48, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Center(
                    child: Text(
                      'No bank accounts added yet.\nAdd your UPI ID or bank account to receive payments.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Bank Account'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      minimumSize: const Size(double.infinity, 48),
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

