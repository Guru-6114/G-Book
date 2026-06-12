// lib/screens/cashbook_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../utils/helpers.dart';
import '../widgets/widgets.dart';

class CashbookScreen extends StatefulWidget {
  const CashbookScreen({super.key});

  @override
  State<CashbookScreen> createState() => _CashbookScreenState();
}

class _CashbookScreenState extends State<CashbookScreen> {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CashbookProvider>();

    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      appBar: AppBar(title: const Text('Cashbook')),
      body: Column(
        children: [
          // Balance summary
          Container(
            color: AppTheme.primaryColor,
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                _BalanceStat(
                    label: 'Cash In',
                    amount: provider.totalIn,
                    color: const Color(0xFF90EE90),
                    icon: Icons.arrow_downward),
                Container(
                    width: 1,
                    height: 40,
                    color: Colors.white24,
                    margin: const EdgeInsets.symmetric(horizontal: 16)),
                _BalanceStat(
                    label: 'Cash Out',
                    amount: provider.totalOut,
                    color: const Color(0xFFFF9999),
                    icon: Icons.arrow_upward),
                Container(
                    width: 1,
                    height: 40,
                    color: Colors.white24,
                    margin: const EdgeInsets.symmetric(horizontal: 16)),
                _BalanceStat(
                    label: 'Balance',
                    amount: provider.balance,
                    color: Colors.white,
                    icon: Icons.account_balance_wallet_outlined),
              ],
            ),
          ),
          // Entries list
          Expanded(
            child: provider.loading
                ? const Center(child: CircularProgressIndicator())
                : provider.entries.isEmpty
                    ? EmptyState(
                        title: 'No cashbook entries',
                        subtitle: 'Record your cash in / cash out',
                        icon: Icons.account_balance_wallet_outlined,
                        actionLabel: 'Add Entry',
                        onAction: () => _showAddEntry(context),
                      )
                    : RefreshIndicator(
                        onRefresh: () =>
                            context.read<CashbookProvider>().loadEntries(),
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: provider.entries.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, indent: 68),
                          itemBuilder: (_, i) {
                            final e = provider.entries[i];
                            return _CashbookTile(
                              entry: e,
                              onDelete: () async {
                                await context
                                    .read<CashbookProvider>()
                                    .deleteEntry(e.id);
                                if (!context.mounted) return;
                                AppHelpers.showSuccessSnackBar(
                                    context, 'Entry deleted');
                              },
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
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
                  onPressed: () => _showAddEntry(context, isCashIn: false),
                  icon: const Icon(Icons.arrow_upward, size: 18),
                  label: const Text('Cash Out'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.creditColor),
                  onPressed: () => _showAddEntry(context, isCashIn: true),
                  icon: const Icon(Icons.arrow_downward, size: 18),
                  label: const Text('Cash In'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddEntry(BuildContext context, {bool isCashIn = true}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AddCashbookEntrySheet(
        isCashIn: isCashIn,
        onAdded: (entry) async {
          await context.read<CashbookProvider>().addEntry(entry);
          if (!context.mounted) return;
          AppHelpers.showSuccessSnackBar(context, 'Entry added');
        },
      ),
    );
  }
}

class _BalanceStat extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final IconData icon;

  const _BalanceStat({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 4),
              Text(label,
                  style:
                      const TextStyle(color: Colors.white70, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            AppHelpers.formatCurrencyCompact(amount),
            style: TextStyle(
                color: color, fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _CashbookTile extends StatelessWidget {
  final CashbookEntry entry;
  final VoidCallback onDelete;

  const _CashbookTile({required this.entry, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final color =
        entry.isCashIn ? AppTheme.creditColor : AppTheme.debitColor;
    final label = entry.isCashIn ? 'Cash In' : 'Cash Out';
    final icon =
        entry.isCashIn ? Icons.arrow_downward : Icons.arrow_upward;

    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        entry.description?.isNotEmpty == true
            ? entry.description!
            : label,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${AppHelpers.formatDate(entry.date)}  •  ${entry.paymentMode.toUpperCase()}',
        style: const TextStyle(fontSize: 11, color: Colors.grey),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${entry.isCashIn ? '+' : '-'} ${AppHelpers.formatCurrency(entry.amount)}',
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700, color: color),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete Entry'),
                  content: const Text('Delete this entry?'),
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
              if (confirmed == true) onDelete();
            },
            child: const Icon(Icons.delete_outline,
                size: 18, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _AddCashbookEntrySheet extends StatefulWidget {
  final bool isCashIn;
  final void Function(CashbookEntry) onAdded;

  const _AddCashbookEntrySheet(
      {required this.isCashIn, required this.onAdded});

  @override
  State<_AddCashbookEntrySheet> createState() =>
      _AddCashbookEntrySheetState();
}

class _AddCashbookEntrySheetState extends State<_AddCashbookEntrySheet> {
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _paymentMode = 'cash';

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      AppHelpers.showErrorSnackBar(context, 'Enter a valid amount');
      return;
    }
    final entry = CashbookEntry(
      id: AppHelpers.generateId(),
      amount: amount,
      isCashIn: widget.isCashIn,
      description:
          _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      paymentMode: _paymentMode,
      date: DateTime.now(),
    );
    Navigator.pop(context);
    widget.onAdded(entry);
  }

  @override
  Widget build(BuildContext context) {
    final color =
        widget.isCashIn ? AppTheme.creditColor : AppTheme.debitColor;
    final label = widget.isCashIn ? 'Cash In' : 'Cash Out';

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Icon(
                widget.isCashIn
                    ? Icons.arrow_downward
                    : Icons.arrow_upward,
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
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            style:
                const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
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
            controller: _descCtrl,
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
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