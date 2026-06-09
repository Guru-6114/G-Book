// lib/screens/cashbook_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../utils/helpers.dart';
import '../models/models.dart';

class CashbookScreen extends StatefulWidget {
  const CashbookScreen({super.key});

  @override
  State<CashbookScreen> createState() => _CashbookScreenState();
}

class _CashbookScreenState extends State<CashbookScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CashbookProvider>().loadEntries();
    });
  }

  void _showAddEntry(bool isCashIn) {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                    isCashIn ? Icons.arrow_downward : Icons.arrow_upward,
                    color: isCashIn
                        ? AppTheme.creditColor
                        : AppTheme.debitColor),
                const SizedBox(width: 8),
                Text(
                  isCashIn ? 'Cash In' : 'Cash Out',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isCashIn
                          ? AppTheme.creditColor
                          : AppTheme.debitColor),
                ),
                const Spacer(),
                IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                prefixText: '₹ ',
                hintText: '0.00',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: isCashIn
                            ? AppTheme.creditColor
                            : AppTheme.debitColor,
                        width: 2)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                prefixIcon: Icon(Icons.note_outlined, size: 18),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: isCashIn
                        ? AppTheme.creditColor
                        : AppTheme.debitColor),
                onPressed: () {
                  final amount = double.tryParse(amountCtrl.text.trim());
                  if (amount == null || amount <= 0) return;
                  final entry = CashbookEntry(
                    id: AppHelpers.generateId(),
                    amount: amount,
                    isCashIn: isCashIn,
                    description: descCtrl.text.trim().isEmpty
                        ? null
                        : descCtrl.text.trim(),
                    date: DateTime.now(),
                  );
                  Navigator.pop(ctx);
                  context.read<CashbookProvider>().addEntry(entry);
                },
                child: const Text('Save Entry',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CashbookProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cashbook'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Balance summary
          Container(
            color: AppTheme.primaryColor,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: _SummaryTile(
                    label: 'Cash In',
                    amount: provider.totalIn,
                    color: const Color(0xFF4ADE80),
                    icon: Icons.arrow_downward,
                  ),
                ),
                Container(
                    width: 1,
                    height: 40,
                    color: Colors.white24,
                    margin: const EdgeInsets.symmetric(horizontal: 12)),
                Expanded(
                  child: _SummaryTile(
                    label: 'Cash Out',
                    amount: provider.totalOut,
                    color: const Color(0xFFFCA5A5),
                    icon: Icons.arrow_upward,
                  ),
                ),
                Container(
                    width: 1,
                    height: 40,
                    color: Colors.white24,
                    margin: const EdgeInsets.symmetric(horizontal: 12)),
                Expanded(
                  child: _SummaryTile(
                    label: 'Balance',
                    amount: provider.balance,
                    color: Colors.white,
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                ),
              ],
            ),
          ),

          // Entry list
          Expanded(
            child: provider.loading
                ? const Center(child: CircularProgressIndicator())
                : provider.entries.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.account_balance_wallet_outlined,
                                size: 60,
                                color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            const Text('No cashbook entries yet',
                                style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: provider.entries.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, indent: 68),
                        itemBuilder: (_, i) {
                          final e = provider.entries[i];
                          final color = e.isCashIn
                              ? AppTheme.creditColor
                              : AppTheme.debitColor;
                          return ListTile(
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                  e.isCashIn
                                      ? Icons.arrow_downward
                                      : Icons.arrow_upward,
                                  color: color,
                                  size: 20),
                            ),
                            title: Text(
                              e.description ??
                                  (e.isCashIn ? 'Cash In' : 'Cash Out'),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500, fontSize: 14),
                            ),
                            subtitle: Text(AppHelpers.formatDate(e.date),
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.grey)),
                            trailing: Text(
                              '${e.isCashIn ? '+' : '-'} ${AppHelpers.formatCurrency(e.amount)}',
                              style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          color: Colors.white,
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.debitColor),
                  onPressed: () => _showAddEntry(false),
                  icon: const Icon(Icons.arrow_upward, size: 18),
                  label: const Text('Cash Out'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.creditColor),
                  onPressed: () => _showAddEntry(true),
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
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final IconData icon;

  const _SummaryTile(
      {required this.label,
      required this.amount,
      required this.color,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
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
              color: color, fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ],
    );
  }
}