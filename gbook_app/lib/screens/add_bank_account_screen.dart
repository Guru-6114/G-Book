// lib/screens/add_bank_account_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../utils/helpers.dart';

/// Shared storage key so [AddBankAccountScreen] and the bank-accounts
/// list sheet in payment_settings_screen.dart read/write the same data.
const String kBankAccountsPrefsKey = 'bank_accounts';

class AddBankAccountScreen extends StatefulWidget {
  const AddBankAccountScreen({super.key});

  @override
  State<AddBankAccountScreen> createState() => _AddBankAccountScreenState();
}

class _AddBankAccountScreenState extends State<AddBankAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _ifscCtrl = TextEditingController();
  final _accountCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ifscCtrl.dispose();
    _accountCtrl.dispose();
    super.dispose();
  }

  String? _validateName(String? v) {
    if (v == null || v.trim().isEmpty) {
      return 'Account holder name is required';
    }
    return null;
  }

  String? _validateIfsc(String? v) {
    if (v == null || v.trim().isEmpty) return 'IFSC code is required';
    final ifsc = v.trim().toUpperCase();
    final ifscRegex = RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$');
    if (!ifscRegex.hasMatch(ifsc)) return 'Enter a valid IFSC code';
    return null;
  }

  String? _validateAccount(String? v) {
    if (v == null || v.trim().isEmpty) return 'Account number is required';
    if (v.trim().length < 9 || v.trim().length > 18) {
      return 'Enter a valid account number';
    }
    return null;
  }

  Future<void> _verify() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final existingRaw = prefs.getStringList(kBankAccountsPrefsKey) ?? [];
      final accounts = existingRaw
          .map((e) => jsonDecode(e) as Map<String, dynamic>)
          .toList();

      final newAccount = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'accountHolderName': _nameCtrl.text.trim(),
        'ifscCode': _ifscCtrl.text.trim().toUpperCase(),
        'accountNumber': _accountCtrl.text.trim(),
        'addedAt': DateTime.now().toIso8601String(),
      };
      accounts.add(newAccount);

      final updatedRaw = accounts.map((e) => jsonEncode(e)).toList();
      await prefs.setStringList(kBankAccountsPrefsKey, updatedRaw);

      // brief pause so the loading state is visible, mirrors a real
      // verification call
      await Future.delayed(const Duration(milliseconds: 400));

      if (!mounted) return;
      AppHelpers.showSuccessSnackBar(
          context, 'Bank account added successfully');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      AppHelpers.showErrorSnackBar(context, 'Failed to add bank account');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: Colors.grey.shade400),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: Colors.grey.shade400),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'ADD BANK ACCOUNT',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        elevation: 0,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                  children: [
                    Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(
                          color: Color(0xFF2E7D32),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check,
                            color: Colors.white, size: 34),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'ADD BANK ACCOUNT',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Rewards & Payments you receive will be transferred to your bank account.',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: _fieldDecoration('Account holder name'),
                      validator: _validateName,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _ifscCtrl,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'[a-zA-Z0-9]')),
                        LengthLimitingTextInputFormatter(11),
                      ],
                      decoration: _fieldDecoration('IFSC code'),
                      validator: _validateIfsc,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _accountCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(18),
                      ],
                      decoration: _fieldDecoration('Account number'),
                      validator: _validateAccount,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: Color(0xFFE8F5E9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.verified_user,
                              color: Color(0xFF2E7D32), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'All payments are 100% Safe and Secure on GBook.',
                            style: TextStyle(
                                color: Colors.grey.shade700, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _verify,
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
                        : const Text(
                            'VERIFY',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1),
                          ),
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