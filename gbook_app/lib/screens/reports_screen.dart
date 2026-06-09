// lib/screens/reports_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../utils/helpers.dart';
import '../models/models.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;

  final List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<BillProvider>().loadBills();
      context.read<TransactionProvider>().loadTransactions();
      context.read<CustomerProvider>().loadCustomers();
    });
  }

  /// Calculate monthly stats from bills for the selected period
  _MonthlyBillStats _calcBillStats(List<Bill> bills) {
    final filtered = bills.where((b) {
      return b.date.year == _selectedYear &&
          b.date.month == _selectedMonth;
    }).toList();

    double sales = 0, purchases = 0, expenses = 0;
    int count = 0;

    for (final b in filtered) {
      count++;
      switch (b.billType) {
        case BillType.sale:
        case BillType.saleReturn:
          sales += b.grandTotal;
          break;
        case BillType.purchase:
        case BillType.purchaseReturn:
          purchases += b.grandTotal;
          break;
        case BillType.expense:
          expenses += b.grandTotal;
          break;
      }
    }

    return _MonthlyBillStats(
      sales: sales,
      purchases: purchases,
      expenses: expenses,
      count: count,
    );
  }

  @override
  Widget build(BuildContext context) {
    final billProvider = context.watch<BillProvider>();
    final txProvider = context.watch<TransactionProvider>();
    final customerProvider = context.watch<CustomerProvider>();

    final stats = _calcBillStats(billProvider.bills);
    final netProfit = stats.sales - stats.purchases - stats.expenses;

    // All bills for the selected month
    final monthBills = billProvider.bills.where((b) {
      return b.date.year == _selectedYear &&
          b.date.month == _selectedMonth;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        automaticallyImplyLeading: false,
        title: const Text('Reports',
            style: TextStyle(
                color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Period selector ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select Period',
                      style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: _selectedYear,
                          decoration: const InputDecoration(
                              isDense: true,
                              contentPadding:
                                  EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                          items: List.generate(
                                  5, (i) => DateTime.now().year - i)
                              .map((y) => DropdownMenuItem(
                                  value: y, child: Text('$y')))
                              .toList(),
                          onChanged: (y) {
                            if (y != null) setState(() => _selectedYear = y);
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: _selectedMonth,
                          decoration: const InputDecoration(
                              isDense: true,
                              contentPadding:
                                  EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                          items: List.generate(12, (i) => i + 1)
                              .map((m) => DropdownMenuItem(
                                  value: m,
                                  child: Text(_months[m - 1])))
                              .toList(),
                          onChanged: (m) {
                            if (m != null) setState(() => _selectedMonth = m);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Monthly Bill Summary ─────────────────────────────────────
            const Text('Monthly Summary',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    label: 'Total Sales',
                    amount: stats.sales,
                    color: AppTheme.credit,
                    icon: Icons.receipt_long,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryCard(
                    label: 'Total Purchases',
                    amount: stats.purchases,
                    color: AppTheme.debit,
                    icon: Icons.shopping_cart_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    label: 'Expenses',
                    amount: stats.expenses,
                    color: const Color(0xFFF97316),
                    icon: Icons.payments_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _NetProfitCard(
                    profit: netProfit,
                    count: stats.count,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Party Summary ────────────────────────────────────────────
            const Text('Party Summary',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            _OverallCard(
              totalReceivable: customerProvider.totalReceivable,
              totalPayable: customerProvider.totalPayable,
            ),
            const SizedBox(height: 16),

            // ── All-time Bill Stats ──────────────────────────────────────
            const Text('All-time Overview',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            _AllTimeBillCard(
              totalSales: billProvider.totalSales,
              totalPurchases: billProvider.totalPurchases,
              totalBills: billProvider.bills.length,
            ),
            const SizedBox(height: 20),

            // ── Recent Bills ─────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Recent Bills',
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                Text(
                  '${_months[_selectedMonth - 1]} $_selectedYear',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (monthBills.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.receipt_long_outlined,
                          size: 36, color: Colors.grey.shade300),
                      const SizedBox(height: 8),
                      Text(
                        'No bills in ${_months[_selectedMonth - 1]} $_selectedYear',
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...monthBills.take(10).map((b) => _BillRow(bill: b)),

            // ── Recent Transactions ──────────────────────────────────────
            if (txProvider.transactions.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text('Recent Transactions',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              ...txProvider.transactions.take(5).map((tx) => _TxRow(tx: tx)),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Data class ────────────────────────────────────────────────────────────────
class _MonthlyBillStats {
  final double sales;
  final double purchases;
  final double expenses;
  final int count;

  _MonthlyBillStats({
    required this.sales,
    required this.purchases,
    required this.expenses,
    required this.count,
  });
}

// ── Summary card ──────────────────────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final IconData icon;

  const _SummaryCard(
      {required this.label,
      required this.amount,
      required this.color,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 10),
          Text(label,
              style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(
            AppHelpers.formatCurrency(amount),
            style: TextStyle(
                color: color, fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

// ── Net profit card ───────────────────────────────────────────────────────────
class _NetProfitCard extends StatelessWidget {
  final double profit;
  final int count;

  const _NetProfitCard({required this.profit, required this.count});

  @override
  Widget build(BuildContext context) {
    final isPositive = profit >= 0;
    final color = isPositive ? AppTheme.credit : AppTheme.debit;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
                isPositive
                    ? Icons.trending_up
                    : Icons.trending_down,
                color: color,
                size: 16),
          ),
          const SizedBox(height: 10),
          const Text('Net Profit',
              style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(
            AppHelpers.formatCurrency(profit.abs()),
            style: TextStyle(
                color: color, fontSize: 16, fontWeight: FontWeight.w700),
          ),
          Text('$count bills',
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }
}

// ── Overall party card ────────────────────────────────────────────────────────
class _OverallCard extends StatelessWidget {
  final double totalReceivable;
  final double totalPayable;

  const _OverallCard(
      {required this.totalReceivable, required this.totalPayable});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Stat(
              label: 'You Will Get',
              value: AppHelpers.formatCurrency(totalReceivable),
              color: AppTheme.credit,
            ),
          ),
          Container(width: 1, height: 40, color: AppTheme.divider),
          Expanded(
            child: _Stat(
              label: 'You Will Give',
              value: AppHelpers.formatCurrency(totalPayable),
              color: AppTheme.debit,
            ),
          ),
        ],
      ),
    );
  }
}

// ── All-time bill card ────────────────────────────────────────────────────────
class _AllTimeBillCard extends StatelessWidget {
  final double totalSales;
  final double totalPurchases;
  final int totalBills;

  const _AllTimeBillCard(
      {required this.totalSales,
      required this.totalPurchases,
      required this.totalBills});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Stat(
              label: 'Total Sales',
              value: AppHelpers.formatCurrency(totalSales),
              color: AppTheme.credit,
            ),
          ),
          Container(width: 1, height: 40, color: AppTheme.divider),
          Expanded(
            child: _Stat(
              label: 'Total Purchases',
              value: AppHelpers.formatCurrency(totalPurchases),
              color: AppTheme.debit,
            ),
          ),
          Container(width: 1, height: 40, color: AppTheme.divider),
          Expanded(
            child: _Stat(
              label: 'Total Bills',
              value: '$totalBills',
              color: AppTheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _Stat(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 14)),
      ],
    );
  }
}

// ── Bill row ──────────────────────────────────────────────────────────────────
class _BillRow extends StatelessWidget {
  final Bill bill;

  const _BillRow({required this.bill});

  String get _typeLabel {
    switch (bill.billType) {
      case BillType.sale:
        return 'Sale';
      case BillType.purchase:
        return 'Purchase';
      case BillType.expense:
        return 'Expense';
      case BillType.saleReturn:
        return 'Sale Return';
      case BillType.purchaseReturn:
        return 'Purchase Return';
    }
  }

  Color get _typeColor {
    switch (bill.billType) {
      case BillType.sale:
      case BillType.saleReturn:
        return AppTheme.credit;
      case BillType.purchase:
      case BillType.purchaseReturn:
        return AppTheme.debit;
      case BillType.expense:
        return const Color(0xFFF97316);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _typeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.receipt_long, color: _typeColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(_typeLabel,
                        style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w500,
                            fontSize: 13)),
                    const SizedBox(width: 6),
                    if (bill.partyName != null)
                      Flexible(
                        child: Text(
                          '• ${bill.partyName}',
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
                Text(
                  '${bill.billNumber}  •  ${AppHelpers.formatDate(bill.date)}',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                AppHelpers.formatCurrency(bill.grandTotal),
                style: TextStyle(
                  color: _typeColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              Text(
                bill.isPaid
                    ? 'Paid'
                    : bill.paidAmount > 0
                        ? 'Partial'
                        : 'Unpaid',
                style: TextStyle(
                    color: bill.isPaid
                        ? AppTheme.credit
                        : bill.paidAmount > 0
                            ? const Color(0xFFF97316)
                            : AppTheme.debit,
                    fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Transaction row ───────────────────────────────────────────────────────────
class _TxRow extends StatelessWidget {
  final AppTransaction tx;

  const _TxRow({required this.tx});

  @override
  Widget build(BuildContext context) {
    final isCredit = tx.type == TransactionType.credit;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: (isCredit ? AppTheme.credit : AppTheme.debit)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isCredit ? Icons.arrow_upward : Icons.arrow_downward,
              color: isCredit ? AppTheme.credit : AppTheme.debit,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.description ?? (isCredit ? 'Credit' : 'Debit'),
                  style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w500,
                      fontSize: 14),
                ),
                Text(
                  AppHelpers.formatDate(tx.date),
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            AppHelpers.formatCurrency(tx.amount),
            style: TextStyle(
              color: isCredit ? AppTheme.credit : AppTheme.debit,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}