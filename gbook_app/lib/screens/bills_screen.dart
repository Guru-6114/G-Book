// lib/screens/bills_screen.dart
// Real "Bills" tab — replaces the old placeholder BillsScreen.
// Shows saved Sale / Purchase bills in tabs, a "+" to add a new Sale Bill
// directly, and a "More" menu (top-right) with Sale Return, Purchase
// Return, and Expense — matching the Khatabook-style bill flows.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../utils/helpers.dart';
import '../widgets/widgets.dart';
import 'add_bill_screen.dart';

class BillsScreen extends StatefulWidget {
  const BillsScreen({super.key});

  @override
  State<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends State<BillsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  static const List<_MoreOption> _moreOptions = [
    _MoreOption(
      label: 'Sale Return',
      icon: Icons.undo,
      billType: BillType.saleReturn,
    ),
    _MoreOption(
      label: 'Purchase Return',
      icon: Icons.redo,
      billType: BillType.purchaseReturn,
    ),
    _MoreOption(
      label: 'Expense',
      icon: Icons.money_off,
      billType: BillType.expense,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _openAddBill(BillType type) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AddBillScreen(billType: type)),
    );
    // FIX: AddBillScreen pops with `true` after a successful save. Reload
    // the bill list here so the newly-saved bill actually appears instead
    // of the list staying stale (this was the "not displaying" bug).
    if (result == true && mounted) {
      await context.read<BillProvider>().loadBills();
    }
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                child: Row(
                  children: [
                    const Text(
                      'More Options',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(sheetContext),
                    ),
                  ],
                ),
              ),
              ..._moreOptions.map((opt) => ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(opt.icon,
                          color: AppTheme.primaryColor, size: 20),
                    ),
                    title: Text(opt.label,
                        style:
                            const TextStyle(fontWeight: FontWeight.w600)),
                    onTap: () {
                      // FIX: close the sheet using its own context first,
                      // then open the add-bill screen using this widget's
                      // context. Previously these flows were not wired up
                      // at all, so Sale Return / Purchase Return did
                      // nothing when tapped.
                      Navigator.pop(sheetContext);
                      _openAddBill(opt.billType);
                    },
                  )),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      appBar: AppBar(
        title: const Text('Bills'),
        actions: [
          IconButton(
            tooltip: 'More',
            icon: const Icon(Icons.more_vert),
            onPressed: _showMoreOptions,
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [
            Tab(text: 'SALES'),
            Tab(text: 'PURCHASES'),
            Tab(text: 'EXPENSES'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _BillList(
            billType: BillType.sale,
            emptyTitle: 'No sale bills yet',
            emptySubtitle: 'Create your first sale bill',
          ),
          _BillList(
            billType: BillType.purchase,
            emptyTitle: 'No purchase bills yet',
            emptySubtitle: 'Create your first purchase bill',
          ),
          _BillList(
            billType: BillType.expense,
            emptyTitle: 'No expenses yet',
            emptySubtitle: 'Record your business expenses',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // The "+" always starts a Sale Bill (the most common action);
          // returns/expense/purchase live in the More menu and the
          // Purchases tab's own add button below.
          final currentTab = _tabs.index;
          final type = switch (currentTab) {
            1 => BillType.purchase,
            2 => BillType.expense,
            _ => BillType.sale,
          };
          _openAddBill(type);
        },
        icon: const Icon(Icons.add),
        label: const Text('New Bill'),
      ),
    );
  }
}

class _MoreOption {
  final String label;
  final IconData icon;
  final BillType billType;
  const _MoreOption({
    required this.label,
    required this.icon,
    required this.billType,
  });
}

// ── Bill list for one BillType, backed by BillProvider ─────────────────────
class _BillList extends StatelessWidget {
  final BillType billType;
  final String emptyTitle;
  final String emptySubtitle;

  const _BillList({
    required this.billType,
    required this.emptyTitle,
    required this.emptySubtitle,
  });

  List<Bill> _billsFor(BillProvider provider) {
    switch (billType) {
      case BillType.sale:
        return provider.saleBills;
      case BillType.purchase:
        return provider.purchaseBills;
      case BillType.expense:
        return provider.expenseBills;
      case BillType.saleReturn:
        return provider.bills
            .where((b) => b.billType == BillType.saleReturn)
            .toList();
      case BillType.purchaseReturn:
        return provider.bills
            .where((b) => b.billType == BillType.purchaseReturn)
            .toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BillProvider>();
    final bills = _billsFor(provider);

    if (provider.loading && bills.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (bills.isEmpty) {
      return EmptyState(
        title: emptyTitle,
        subtitle: emptySubtitle,
        icon: Icons.receipt_long_outlined,
      );
    }

    return RefreshIndicator(
      onRefresh: () => context.read<BillProvider>().loadBills(),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: bills.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 68),
        itemBuilder: (_, i) => _BillTile(bill: bills[i]),
      ),
    );
  }
}

class _BillTile extends StatelessWidget {
  final Bill bill;
  const _BillTile({required this.bill});

  Color get _amountColor {
    switch (bill.billType) {
      case BillType.sale:
      case BillType.purchaseReturn:
        return AppTheme.creditColor;
      case BillType.purchase:
      case BillType.saleReturn:
      case BillType.expense:
        return AppTheme.debitColor;
    }
  }

  IconData get _icon {
    switch (bill.billType) {
      case BillType.sale:
        return Icons.point_of_sale_outlined;
      case BillType.purchase:
        return Icons.shopping_cart_outlined;
      case BillType.saleReturn:
        return Icons.undo;
      case BillType.purchaseReturn:
        return Icons.redo;
      case BillType.expense:
        return Icons.money_off;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _amountColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_icon, color: _amountColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bill.partyName?.isNotEmpty == true
                      ? bill.partyName!
                      : bill.billNumber,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: Color(0xFF212121)),
                ),
                Text(
                  '${bill.billNumber} • ${AppHelpers.formatDate(bill.date)}',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF9E9E9E)),
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
                  color: _amountColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              Text(
                bill.isPaid ? 'Paid' : 'Due ${AppHelpers.formatCurrency(bill.balanceDue)}',
                style: TextStyle(
                  fontSize: 11,
                  color: bill.isPaid ? AppTheme.creditColor : AppTheme.debitColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}