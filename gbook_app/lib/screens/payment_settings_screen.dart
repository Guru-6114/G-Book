// lib/screens/payment_settings_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/locale_provider.dart';
import '../services/voice_notification_service.dart';
import '../theme/app_theme.dart';
import '../utils/helpers.dart';
import '../l10n/app_localizations.dart';
import 'add_bank_account_screen.dart';
import 'more_screen.dart' show FaqCategoriesScreen;

class PaymentSettingsScreen extends StatefulWidget {
  const PaymentSettingsScreen({super.key});

  @override
  State<PaymentSettingsScreen> createState() => _PaymentSettingsScreenState();
}

class _PaymentSettingsScreenState extends State<PaymentSettingsScreen> {
  bool _voiceNotifications = false;
  bool _dailySettlements = true;
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
      _loading = false;
    });
  }

  // ── Voice Notifications toggle ──────────────────────────────────────────
  // Unlike a plain UI switch, this now behaves like Khatabook's: flipping it
  // immediately persists the flag AND speaks a confirmation out loud via TTS
  // ("Voice notifications enabled"/"disabled"), instead of waiting for the
  // user to tap Save. The volume icon next to the label also updates
  // immediately (volume_up when on, volume_off when off) instead of staying
  // static. Other parts of the app can later call
  // VoiceNotificationService.instance.announcePaymentReceived(...) /
  // announcePaymentGiven(...) and those will only actually speak while this
  // setting is on.
  Future<void> _onVoiceNotificationsChanged(bool value) async {
    setState(() => _voiceNotifications = value);
    await VoiceNotificationService.instance.setEnabled(value);
    await VoiceNotificationService.instance.announceToggle(value);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('voice_notifications', _voiceNotifications);
    await prefs.setBool('daily_settlements', _dailySettlements);
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
                                Icon(
                                  _voiceNotifications
                                      ? Icons.volume_up
                                      : Icons.volume_off,
                                  size: 18,
                                  color: _voiceNotifications
                                      ? AppTheme.primaryColor
                                      : Colors.grey,
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
                        onChanged: _onVoiceNotificationsChanged,
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

                // ── Help — now navigates to the FAQ list, matching
                // Khatabook's behaviour instead of showing a static dialog.
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const FaqCategoriesScreen()),
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _BankAccountsSheet(),
    );
  }
}

// ── Bank Accounts sheet — lists saved accounts (persisted via
// SharedPreferences, keyed by kBankAccountsPrefsKey from
// add_bank_account_screen.dart) and lets the user add or remove one. ──────
class _BankAccountsSheet extends StatefulWidget {
  const _BankAccountsSheet();

  @override
  State<_BankAccountsSheet> createState() => _BankAccountsSheetState();
}

class _BankAccountsSheetState extends State<_BankAccountsSheet> {
  bool _loading = true;
  List<Map<String, dynamic>> _accounts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(kBankAccountsPrefsKey) ?? [];
    if (!mounted) return;
    setState(() {
      _accounts = raw
          .map((e) => jsonDecode(e) as Map<String, dynamic>)
          .toList()
          .reversed
          .toList();
      _loading = false;
    });
  }

  Future<void> _delete(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(kBankAccountsPrefsKey) ?? [];
    final remaining = raw
        .map((e) => jsonDecode(e) as Map<String, dynamic>)
        .where((a) => a['id'] != id)
        .map((e) => jsonEncode(e))
        .toList();
    await prefs.setStringList(kBankAccountsPrefsKey, remaining);
    if (!mounted) return;
    AppHelpers.showSuccessSnackBar(context, 'Bank account removed');
    _load();
  }

  Future<void> _addAccount() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddBankAccountScreen()),
    );
    if (result == true) _load();
  }

  String _maskAccountNumber(String number) {
    if (number.length <= 4) return number;
    return '•' * (number.length - 4) + number.substring(number.length - 4);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LocaleProvider>();
    return DraggableScrollableSheet(
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
                Text(t.tr('bank_accounts'),
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
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _accounts.isEmpty
                    ? ListView(
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
                        ],
                      )
                    : ListView.separated(
                        controller: ctrl,
                        padding: const EdgeInsets.all(16),
                        itemCount: _accounts.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final acc = _accounts[i];
                          final name =
                              (acc['accountHolderName'] as String?) ?? '';
                          final ifsc = (acc['ifscCode'] as String?) ?? '';
                          final number =
                              (acc['accountNumber'] as String?) ?? '';
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F5F5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                      Icons.account_balance_outlined,
                                      color: AppTheme.primaryColor,
                                      size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(name,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14)),
                                      Text(
                                        '${_maskAccountNumber(number)} • $ifsc',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF9E9E9E)),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: Colors.red, size: 20),
                                  onPressed: () =>
                                      _delete(acc['id'] as String),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
          Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 8,
              bottom: MediaQuery.of(context).padding.bottom + 16,
            ),
            child: ElevatedButton.icon(
              onPressed: _addAccount,
              icon: const Icon(Icons.add),
              label: const Text('Add Bank Account'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ),
        ],
      ),
    );
  }
}