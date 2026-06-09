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
  bool _isLoading = false;
  Map<String, dynamic>? _report;

  final List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  void initState() {
    super.initState();
    _loadReport();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TransactionProvider>().loadTransactions();
    });
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);
    try {
      final provider = context.read<TransactionProvider>();
      final report =
          await provider.getMonthlyReport(_selectedYear, _selectedMonth);
      if (report != null) {
        setState(() => _report = {
              'totalCredit': report.totalCredit,
              'totalDebit': report.totalDebit,
              'netBalance': report.netBalance,
              'transactionCount': report.transactionCount,
            });
      }
    } catch (e) {
      if (mounted) {
        AppHelpers.showErrorSnackBar(context, 'Failed to load report');
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final txProvider = context.watch<TransactionProvider>();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
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
            // Month/Year selector
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
                        child: DropdownButton<int>(
                          value: _selectedYear,
                          isExpanded: true,
                          items: List.generate(5, (i) => DateTime.now().year - i)
                              .map((y) => DropdownMenuItem(
                                  value: y, child: Text('$y')))
                              .toList(),
                          onChanged: (y) {
                            if (y != null) {
                              setState(() => _selectedYear = y);
                              _loadReport();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButton<int>(
                          value: _selectedMonth,
                          isExpanded: true,
                          items: List.generate(12, (i) => i + 1)
                              .map((m) => DropdownMenuItem(
                                  value: m, child: Text(_months[m - 1])))
                              .toList(),
                          onChanged: (m) {
                            if (m != null) {
                              setState(() => _selectedMonth = m);
                              _loadReport();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Summary cards
            if (_isLoading)
              const Center(
                  child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator()))
            else if (_report != null) ...[
              Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      label: 'Total Given',
                      amount: _report!['totalCredit'] ?? 0.0,
                      color: AppTheme.credit,
                      icon: Icons.arrow_upward,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      label: 'Total Received',
                      amount: _report!['totalDebit'] ?? 0.0,
                      color: AppTheme.debit,
                      icon: Icons.arrow_downward,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _NetBalanceCard(
                balance: _report!['netBalance'] ?? 0.0,
                transactionCount: _report!['transactionCount'] ?? 0,
              ),
            ],

            const SizedBox(height: 20),
            const Text('Overall Summary',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            _OverallCard(
              totalGiven: txProvider.totalGiven,
              totalReceived: txProvider.totalReceived,
            ),

            const SizedBox(height: 20),
            const Text('Recent Transactions',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            ...txProvider.transactions.take(10).map((tx) => _TxRow(tx: tx)),
          ],
        ),
      ),
    );
  }
}

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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
            ],
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
                color: color, fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _NetBalanceCard extends StatelessWidget {
  final double balance;
  final int transactionCount;

  const _NetBalanceCard(
      {required this.balance, required this.transactionCount});

  @override
  Widget build(BuildContext context) {
    final isPositive = balance >= 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (isPositive ? AppTheme.credit : AppTheme.debit)
            .withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isPositive ? AppTheme.credit : AppTheme.debit),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Net Balance',
                  style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
              Text(
                AppHelpers.formatCurrency(balance.abs()),
                style: TextStyle(
                    color: isPositive ? AppTheme.credit : AppTheme.debit,
                    fontSize: 22,
                    fontWeight: FontWeight.w700),
              ),
              Text(isPositive ? 'Net to receive' : 'Net to pay',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$transactionCount',
                  style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700)),
              const Text('transactions',
                  style: TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

class _OverallCard extends StatelessWidget {
  final double totalGiven;
  final double totalReceived;

  const _OverallCard(
      {required this.totalGiven, required this.totalReceived});

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
              label: 'Total Given',
              value: AppHelpers.formatCurrency(totalGiven),
              color: AppTheme.credit,
            ),
          ),
          Container(width: 1, height: 40, color: AppTheme.divider),
          Expanded(
            child: _Stat(
              label: 'Total Received',
              value: AppHelpers.formatCurrency(totalReceived),
              color: AppTheme.debit,
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

  const _Stat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style:
                const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 15)),
      ],
    );
  }
}

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