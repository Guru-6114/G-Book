// lib/screens/customer_screen.dart
import 'package:flutter/material.dart';
import '../providers/providers.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/helpers.dart';
import '../widgets/widgets.dart';
import 'add_customer_screen.dart';

class CustomerScreen extends StatefulWidget {
  final Customer customer;
  const CustomerScreen({super.key, required this.customer});

  @override
  State<CustomerScreen> createState() => _CustomerScreenState();
}

class _CustomerScreenState extends State<CustomerScreen> {
  late Customer _customer;
  List<CustomerTransaction> _transactions = [];
  bool _loading = true;
  // FIX #5: Guard flag to prevent double-submission while bottom sheet is open
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _customer = widget.customer;
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() => _loading = true);
    final list = await context
        .read<CustomerProvider>()
        .getTransactions(_customer.id);
    if (!mounted) return;
    setState(() {
      _transactions = list;
      _loading = false;
    });
  }

  void _deleteTransaction(String txId) async {
    await context
        .read<CustomerProvider>()
        .deleteTransaction(txId, _customer.id);
    if (!mounted) return;
    final provider = context.read<CustomerProvider>();
    final updated = provider.customers
        .firstWhere((c) => c.id == _customer.id, orElse: () => _customer);
    setState(() {
      _customer = updated;
      _transactions.removeWhere((t) => t.id == txId);
    });
    if (!mounted) return;
    AppHelpers.showSuccessSnackBar(context, 'Entry deleted');
  }

  Future<void> _showAddTransaction(bool isGiven) async {
    // FIX #5: Prevent opening sheet again while one is already open / saving
    if (_isSubmitting) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AddTransactionSheet(
        customer: _customer,
        isGiven: isGiven,
        onAdded: (tx) async {
          // FIX #5: Set guard before saving to block any race condition
          if (_isSubmitting) return;
          _isSubmitting = true;
          try {
            await context.read<CustomerProvider>().addTransaction(tx);
            if (!mounted) return;
            final updated = context
                .read<CustomerProvider>()
                .customers
                .firstWhere((c) => c.id == _customer.id,
                    orElse: () => _customer);
            setState(() {
              _customer = updated;
              // FIX #5: Only insert if not already present (idempotency check)
              if (!_transactions.any((t) => t.id == tx.id)) {
                _transactions.insert(0, tx);
              }
            });
            AppHelpers.showSuccessSnackBar(context, 'Entry added');
          } finally {
            _isSubmitting = false;
          }
        },
      ),
    );
  }

  Future<void> _deleteCustomer() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Customer'),
        content: Text(
            'Delete ${_customer.name} and all their transactions?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<CustomerProvider>().deleteCustomer(_customer.id);
      if (!mounted) return;
      AppHelpers.showSuccessSnackBar(context, 'Customer deleted');
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final balance = _customer.balance;

    // FIX #6: Clarified Give/Get logic with clear explanation:
    // balance > 0 means customer OWES you money → customer "Will Give" you
    // balance < 0 means you OWE customer money → you "Will Give" them back
    // "Will Give" shown in amber (warning) = customer owes you
    // "Will Get"  shown in green (positive) = you owe them (they'll get back)
    final bool customerOwesYou = balance > 0;
    final bool youOweCustomer = balance < 0;

    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      appBar: AppBar(
        title: Text(_customer.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              final result = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        AddCustomerScreen(customer: _customer)),
              );
              if (result == true && mounted) {
                // ignore: use_build_context_synchronously
                final updated = context
                    .read<CustomerProvider>()
                    .customers
                    .firstWhere((c) => c.id == _customer.id,
                        orElse: () => _customer);
                setState(() => _customer = updated);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _deleteCustomer,
          ),
        ],
      ),
      body: Column(
        children: [
          // FIX #6: Redesigned balance banner with clearer Give/Get labels
          Container(
            color: AppTheme.primaryColor,
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  child: Text(
                    AppHelpers.initials(_customer.name),
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 18),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_customer.name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16)),
                      if (_customer.phone != null)
                        Text(_customer.phone!,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (balance == 0) ...[
                      const Icon(Icons.check_circle,
                          color: Colors.white70, size: 16),
                      const Text('Settled',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 12)),
                    ] else ...[
                      // FIX #6: Clear labels explaining who gives/gets
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: customerOwesYou
                              ? const Color(0xFFFFD700).withValues(alpha: 0.2)
                              : const Color(0xFF90EE90).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          // FIX #6: Explicit phrasing — who gives to whom
                          customerOwesYou
                              ? '${_customer.name.split(' ')[0]} will give you'
                              : 'You will give ${_customer.name.split(' ')[0]}',
                          style: TextStyle(
                            color: customerOwesYou
                                ? const Color(0xFFFFD700)
                                : const Color(0xFF90EE90),
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppHelpers.formatCurrency(balance.abs()),
                        style: TextStyle(
                          color: customerOwesYou
                              ? const Color(0xFFFFD700)
                              : const Color(0xFF90EE90),
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // FIX #6: Summary strip below banner for quick reference
          if (balance != 0)
            Container(
              width: double.infinity,
              color: customerOwesYou
                  ? const Color(0xFFFFF8E1)
                  : const Color(0xFFE8F5E9),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    customerOwesYou
                        ? Icons.arrow_downward
                        : Icons.arrow_upward,
                    size: 14,
                    color: customerOwesYou
                        ? const Color(0xFFF9A825)
                        : const Color(0xFF2E7D32),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    customerOwesYou
                        ? 'Outstanding: ${_customer.name.split(' ')[0]} owes you ${AppHelpers.formatCurrency(balance.abs())}'
                        : 'Advance: You owe ${_customer.name.split(' ')[0]} ${AppHelpers.formatCurrency(balance.abs())}',
                    style: TextStyle(
                      fontSize: 12,
                      color: customerOwesYou
                          ? const Color(0xFFF9A825)
                          : const Color(0xFF2E7D32),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

          // Transactions
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _transactions.isEmpty
                    ? EmptyState(
                        title: 'No transactions yet',
                        subtitle:
                            'Add a payment or credit entry to get started',
                        icon: Icons.receipt_long_outlined,
                        actionLabel: 'Add Entry',
                        onAction: () => _showAddTransaction(false),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _transactions.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, indent: 70),
                        itemBuilder: (_, i) {
                          final tx = _transactions[i];
                          return TransactionTile(
                            id: tx.id,
                            amount: tx.amount,
                            isGiven: tx.isGiven,
                            note: tx.note,
                            date: tx.date,
                            paymentMode: tx.paymentMode,
                            onDelete: () => _deleteTransaction(tx.id),
                          );
                        },
                      ),
          ),
        ],
      ),
      // FIX #6: Renamed buttons to clearly indicate direction of money flow
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.debitColor),
                  onPressed: () => _showAddTransaction(true),
                  icon: const Icon(Icons.arrow_upward, size: 18),
                  // FIX #6: "Given" = you gave money to customer (isGiven=true)
                  label: const Text('Given (You Paid)'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.creditColor),
                  onPressed: () => _showAddTransaction(false),
                  icon: const Icon(Icons.arrow_downward, size: 18),
                  // FIX #6: "Received" = customer paid you (isGiven=false)
                  label: const Text('Received'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Add Transaction Bottom Sheet ──────────────────────────────────────────────
class _AddTransactionSheet extends StatefulWidget {
  final Customer customer;
  final bool isGiven;
  final void Function(CustomerTransaction) onAdded;

  const _AddTransactionSheet({
    required this.customer,
    required this.isGiven,
    required this.onAdded,
  });

  @override
  State<_AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<_AddTransactionSheet> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String _paymentMode = 'cash';
  final _date = DateTime.now();
  // FIX #5: Local saving flag to prevent double-tap submission
  bool _saving = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    // FIX #5: Prevent double submission
    if (_saving) return;

    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      AppHelpers.showErrorSnackBar(context, 'Enter a valid amount');
      return;
    }
    setState(() => _saving = true);

    final tx = CustomerTransaction(
      id: AppHelpers.generateId(),
      customerId: widget.customer.id,
      amount: amount,
      isGiven: widget.isGiven,
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      paymentMode: _paymentMode,
      date: _date,
    );
    Navigator.pop(context);
    widget.onAdded(tx);
  }

  @override
  Widget build(BuildContext context) {
    final isGiven = widget.isGiven;
    final color = isGiven ? AppTheme.debitColor : AppTheme.creditColor;

    // FIX #6: Clearer label in the bottom sheet
    final label = isGiven
        ? 'Amount Given (You Paid Customer)'
        : 'Amount Received (Customer Paid You)';

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(
                isGiven ? Icons.arrow_upward : Icons.arrow_downward,
                color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: color)),
            ),
            IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close)),
          ]),
          // FIX #6: Context hint below the label
          Padding(
            padding: const EdgeInsets.only(left: 32, bottom: 10),
            child: Text(
              isGiven
                  ? 'Record money you paid to ${widget.customer.name}'
                  : 'Record money ${widget.customer.name} paid you',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          TextField(
            controller: _amountCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              prefixText: '₹ ',
              prefixStyle: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w700, color: color),
              hintText: '0.00',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: color)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: color, width: 2)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteCtrl,
            decoration: const InputDecoration(
              labelText: 'Note (optional)',
              prefixIcon: Icon(Icons.note_outlined, size: 18),
            ),
          ),
          const SizedBox(height: 12),
          PaymentModeSelector(
            selected: _paymentMode,
            onChanged: (m) => setState(() => _paymentMode = m),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: color),
              // FIX #5: Disable button while saving
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Save Entry',
                      style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}