// lib/screens/add_transaction_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../utils/helpers.dart';

class AddTransactionScreen extends StatefulWidget {
  final String customerId;
  final String customerName;

  const AddTransactionScreen({
    super.key,
    required this.customerId,
    required this.customerName,
  });

  @override
  State<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState
    extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _refCtrl = TextEditingController();

  // 'credit' = you gave, 'debit' = you received
  String _type = TransactionType.credit;
  String _paymentMode = 'Cash';
  DateTime _date = DateTime.now();
  bool _isLoading = false;

  static const List<String> _paymentModes = [
    'Cash',
    'UPI',
    'Cheque',
    'Bank Transfer',
    'Credit',
  ];

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    _refCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final isIncome = _type == TransactionType.debit;

    final transaction = AppTransaction(
      id: AppHelpers.generateId(),
      amount: double.parse(_amountCtrl.text.trim()),
      isIncome: isIncome,
      paymentMode: _paymentMode,
      note: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      date: _date,
      customerId: widget.customerId,
      description:
          _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      referenceNumber:
          _refCtrl.text.trim().isEmpty ? null : _refCtrl.text.trim(),
      type: _type,
    );

    final provider = context.read<TransactionProvider>();
    final result = await provider.addTransaction(transaction);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result != null) {
      AppHelpers.showSuccessSnackBar(context, 'Transaction added!');
      Navigator.pop(context);
    } else {
      AppHelpers.showErrorSnackBar(
        context,
        provider.error ?? 'Something went wrong',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text(
          'Add Transaction',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
        elevation: 1,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Customer chip
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person, color: AppTheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    widget.customerName,
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Type selector
            const Text(
              'Transaction Type',
              style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _TypeButton(
                    label: 'Credit (You gave)',
                    icon: Icons.arrow_upward,
                    color: AppTheme.credit,
                    selected: _type == TransactionType.credit,
                    onTap: () =>
                        setState(() => _type = TransactionType.credit),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TypeButton(
                    label: 'Debit (You got)',
                    icon: Icons.arrow_downward,
                    color: AppTheme.debit,
                    selected: _type == TransactionType.debit,
                    onTap: () =>
                        setState(() => _type = TransactionType.debit),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Amount
            TextFormField(
              controller: _amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600),
              decoration: _inputDecoration(
                label: 'Amount *',
                hint: '0.00',
                prefix: const Text('₹ ',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18)),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Amount is required';
                }
                final d = double.tryParse(v.trim());
                if (d == null || d <= 0) return 'Enter valid amount';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Date
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today,
                        color: AppTheme.textSecondary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        AppHelpers.formatDate(_date),
                        style: const TextStyle(color: AppTheme.textPrimary),
                      ),
                    ),
                    const Icon(Icons.chevron_right,
                        color: AppTheme.textSecondary, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Payment mode — use initialValue instead of deprecated value=
            DropdownButtonFormField<String>(
              initialValue: _paymentMode,
              items: _paymentModes
                  .map((m) =>
                      DropdownMenuItem(value: m, child: Text(m)))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _paymentMode = v ?? 'Cash'),
              style: const TextStyle(color: AppTheme.textPrimary),
              dropdownColor: AppTheme.surface,
              decoration: _inputDecoration(
                label: 'Payment Mode',
                hint: 'Select mode',
                icon: Icons.payment,
              ),
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descCtrl,
              style: const TextStyle(color: AppTheme.textPrimary),
              maxLines: 2,
              decoration: _inputDecoration(
                label: 'Description (optional)',
                hint: 'Enter description',
                icon: Icons.notes,
              ),
            ),
            const SizedBox(height: 16),

            // Reference
            TextFormField(
              controller: _refCtrl,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: _inputDecoration(
                label: 'Reference No. (optional)',
                hint: 'UPI/Cheque/TXN ID',
                icon: Icons.tag,
              ),
            ),
            const SizedBox(height: 32),

            // Save button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _type == TransactionType.credit
                      ? AppTheme.credit
                      : AppTheme.debit,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        'Save Transaction',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    IconData? icon,
    Widget? prefix,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon != null
          ? Icon(icon, color: AppTheme.textSecondary, size: 20)
          : null,
      prefix: prefix,
      labelStyle: const TextStyle(color: AppTheme.textSecondary),
      hintStyle: const TextStyle(color: AppTheme.textSecondary),
      filled: true,
      fillColor: AppTheme.surface,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.debit),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.debit, width: 2),
      ),
    );
  }
}

// ── Type toggle button ────────────────────────────────────────────────────────
class _TypeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _TypeButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.12)
              : AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : AppTheme.divider,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                color: selected ? color : AppTheme.textSecondary,
                size: 18),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? color : AppTheme.textSecondary,
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}