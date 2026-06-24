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
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AddTransactionSheet(
        customer: _customer,
        isGiven: isGiven,
        onAdded: (tx) async {
          await context.read<CustomerProvider>().addTransaction(tx);
          if (!mounted) return;
          final updated = context
              .read<CustomerProvider>()
              .customers
              .firstWhere((c) => c.id == _customer.id,
                  orElse: () => _customer);
          setState(() {
            _customer = updated;
            _transactions.insert(0, tx);
          });
          AppHelpers.showSuccessSnackBar(context, 'Entry added');
          // Show SMS option after adding transaction
          if (mounted) _showSmsSentPrompt(tx);
        },
      ),
    );
  }

  void _showSmsSentPrompt(CustomerTransaction tx) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send SMS'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Send transaction details to customer?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Hi ${_customer.name}, ${tx.isGiven ? "You have given" : "You have received"} '
                '${AppHelpers.formatCurrency(tx.amount)}. '
                'Balance: ${AppHelpers.formatCurrency(_customer.balance.abs())}. '
                '- via GBook',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Skip'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              AppHelpers.showSuccessSnackBar(context, 'SMS sent to ${_customer.phone ?? _customer.name}');
            },
            child: const Text('Send SMS'),
          ),
        ],
      ),
    );
  }

  void _showReminderDialog() {
    final msgCtrl = TextEditingController(
      text: 'Hi ${_customer.name}, you have a pending balance of '
          '${AppHelpers.formatCurrency(_customer.balance.abs())}. Please clear it. - GBook',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send Reminder'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: msgCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Reminder Message',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              AppHelpers.showSuccessSnackBar(context, 'Reminder sent!');
            },
            icon: const Icon(Icons.send, size: 16),
            label: const Text('Send'),
          ),
        ],
      ),
    );
  }

  void _showReportOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Row(
                children: [
                  const Text('Reports',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined, color: Color(0xFF1565C0)),
              title: const Text('Download PDF Report'),
              subtitle: const Text('Get full transaction history as PDF'),
              onTap: () {
                Navigator.pop(ctx);
                AppHelpers.showSuccessSnackBar(context, 'PDF Report generated!');
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined, color: Color(0xFF1565C0)),
              title: const Text('Share Report via WhatsApp'),
              subtitle: const Text('Send PDF to customer on WhatsApp'),
              onTap: () {
                Navigator.pop(ctx);
                AppHelpers.showSuccessSnackBar(context, 'Opening WhatsApp...');
              },
            ),
            ListTile(
              leading: const Icon(Icons.bar_chart_outlined, color: Color(0xFF1565C0)),
              title: const Text('Statement of Account'),
              subtitle: const Text('View full ledger summary'),
              onTap: () {
                Navigator.pop(ctx);
                _showStatementDialog();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showStatementDialog() {
    double totalGiven = _transactions.where((t) => t.isGiven).fold(0.0, (s, t) => s + t.amount);
    double totalReceived = _transactions.where((t) => !t.isGiven).fold(0.0, (s, t) => s + t.amount);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Statement — ${_customer.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StatRow('Total Given', AppHelpers.formatCurrency(totalGiven), AppTheme.debitColor),
            _StatRow('Total Received', AppHelpers.formatCurrency(totalReceived), AppTheme.creditColor),
            const Divider(),
            _StatRow(
              'Balance',
              AppHelpers.formatCurrency(_customer.balance.abs()),
              _customer.balance >= 0 ? AppTheme.creditColor : AppTheme.debitColor,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _deleteCustomer() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Customer'),
        content: Text('Delete ${_customer.name} and all their transactions?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
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
    final isPositive = balance >= 0;

    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      appBar: AppBar(
        title: Text(_customer.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'Send Reminder',
            onPressed: _showReminderDialog,
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Reports',
            onPressed: _showReportOptions,
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'edit') {
                Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                      builder: (_) => AddCustomerScreen(customer: _customer)),
                ).then((result) {
                  if (result == true && mounted) {
                    final updated = context
                        .read<CustomerProvider>()
                        .customers
                        .firstWhere((c) => c.id == _customer.id,
                            orElse: () => _customer);
                    setState(() => _customer = updated);
                  }
                });
              } else if (v == 'delete') {
                _deleteCustomer();
              } else if (v == 'sms') {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Send SMS'),
                    content: Text(
                      'Send balance reminder SMS to ${_customer.phone ?? _customer.name}?',
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          AppHelpers.showSuccessSnackBar(context, 'SMS sent!');
                        },
                        child: const Text('Send'),
                      ),
                    ],
                  ),
                );
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 8), Text('Edit')])),
              const PopupMenuItem(value: 'sms', child: Row(children: [Icon(Icons.sms_outlined, size: 18), SizedBox(width: 8), Text('Send SMS')])),
              const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, size: 18, color: Colors.red), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))])),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Balance banner
          Container(
            color: AppTheme.primaryColor,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
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
                    Text(
                      isPositive ? 'Will Give' : 'Will Get',
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                    Text(
                      AppHelpers.formatCurrency(balance.abs()),
                      style: TextStyle(
                        color: isPositive
                            ? const Color(0xFFFFD700)
                            : const Color(0xFF90EE90),
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Quick action row: Report | Reminder | SMS
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: Row(
              children: [
                _QuickActionBtn(
                  icon: Icons.picture_as_pdf_outlined,
                  label: 'Report',
                  color: const Color(0xFF1565C0),
                  onTap: _showReportOptions,
                ),
                const SizedBox(width: 8),
                _QuickActionBtn(
                  icon: Icons.notifications_outlined,
                  label: 'Reminder',
                  color: const Color(0xFFE65100),
                  onTap: _showReminderDialog,
                ),
                const SizedBox(width: 8),
                _QuickActionBtn(
                  icon: Icons.sms_outlined,
                  label: 'SMS',
                  color: const Color(0xFF2E7D32),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Send SMS'),
                        content: Text(
                          'Send balance reminder SMS to ${_customer.phone ?? _customer.name}?',
                        ),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cancel')),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              AppHelpers.showSuccessSnackBar(context, 'SMS sent!');
                            },
                            child: const Text('Send'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Transactions list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _transactions.isEmpty
                    ? EmptyState(
                        title: 'No transactions yet',
                        subtitle: 'Add a payment or credit entry to get started',
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
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.debitColor),
                  onPressed: () => _showAddTransaction(true),
                  icon: const Icon(Icons.arrow_upward, size: 18),
                  label: const Text('Given'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.creditColor),
                  onPressed: () => _showAddTransaction(false),
                  icon: const Icon(Icons.arrow_downward, size: 18),
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

class _QuickActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 3),
              Text(label,
                  style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatRow(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(value,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ],
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

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      AppHelpers.showErrorSnackBar(context, 'Enter a valid amount');
      return;
    }
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
    final label = isGiven ? 'Amount Given' : 'Amount Received';

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
            Icon(isGiven ? Icons.arrow_upward : Icons.arrow_downward,
                color: color),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: color)),
            const Spacer(),
            IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close)),
          ]),
          const SizedBox(height: 14),
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
              onPressed: _submit,
              child: const Text('Save Entry',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}