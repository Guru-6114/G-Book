// lib/screens/bill_screen.dart
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
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BillsProvider>().loadAll();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BillsProvider>(builder: (_, billsProvider, __) {
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          titleSpacing: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Consumer<BusinessProfileProvider>(
                builder: (_, p, __) => Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Text(
                    p.profile?.businessName ?? 'My Business',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => Navigator.pushNamed(context, '/settings'),
            )
          ],
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelStyle: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 13),
            unselectedLabelStyle: const TextStyle(fontSize: 13),
            tabs: const [
              Tab(text: 'Sale'),
              Tab(text: 'Purchase'),
              Tab(text: 'Expense'),
            ],
          ),
        ),
        body: Column(
          children: [
            Container(
              color: AppColors.primary,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryTile(
                          label: 'Monthly Sales',
                          amount: billsProvider.monthlySales,
                          color: AppColors.green,
                          onTap: () => _tabController.animateTo(0),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _SummaryTile(
                          label: 'Monthly Purchases',
                          amount: billsProvider.monthlyPurchases,
                          color: AppColors.red,
                          onTap: () => _tabController.animateTo(1),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ReportTile(
                          onTap: () =>
                              Navigator.pushNamed(context, '/reports'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const _CashbookRow(),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _BillsList(
                      bills: billsProvider.saleBills,
                      type: BillType.sale),
                  _BillsList(
                      bills: billsProvider.purchaseBills,
                      type: BillType.purchase),
                  _BillsList(
                      bills: billsProvider.expenseBills,
                      type: BillType.expense),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Container(
            color: Colors.white,
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('MORE',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12)),
                        Text('Payment & Return',
                            style: TextStyle(fontSize: 10)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final tab = _tabController.index;
                      final type = tab == 0
                          ? BillType.sale
                          : tab == 1
                              ? BillType.purchase
                              : BillType.expense;
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                AddBillScreen(billType: type)),
                      );
                      if (result == true && mounted) {
                        context.read<BillsProvider>().loadAll();
                      }
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: AnimatedBuilder(
                      animation: _tabController,
                      builder: (_, __) {
                        final tab = _tabController.index;
                        final label = tab == 0
                            ? 'ADD BILL'
                            : tab == 1
                                ? 'ADD PURCHASE'
                                : 'ADD EXPENSE';
                        return Text(label,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14));
                      },
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final VoidCallback? onTap;

  const _SummaryTile(
      {required this.label,
      required this.amount,
      required this.color,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppHelpers.formatCurrency(amount),
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 15)),
            Text(label,
                style: const TextStyle(
                    color: Colors.white70, fontSize: 10)),
            const Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('›',
                    style: TextStyle(
                        color: Colors.white70, fontSize: 16)),
              ],
            )
          ],
        ),
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  final VoidCallback onTap;
  const _ReportTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart, color: Colors.white, size: 22),
            SizedBox(height: 4),
            Text('VIEW\nREPORTS',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700)),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('›',
                    style:
                        TextStyle(color: Colors.white70, fontSize: 16)),
              ],
            )
          ],
        ),
      ),
    );
  }
}

class _CashbookRow extends StatelessWidget {
  const _CashbookRow();

  @override
  Widget build(BuildContext context) {
    return Consumer<CashbookProvider>(builder: (_, p, __) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Today's IN",
                      style:
                          TextStyle(color: Colors.white70, fontSize: 11)),
                  Text(AppHelpers.formatCurrency(p.totalIn),
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Today's OUT",
                      style:
                          TextStyle(color: Colors.white70, fontSize: 11)),
                  Text(AppHelpers.formatCurrency(p.totalOut),
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                ],
              ),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pushNamed(context, '/cashbook'),
              style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  side: const BorderSide(color: Colors.white38)),
              child: const Text('CASHBOOK ›',
                  style: TextStyle(fontSize: 11)),
            ),
          ],
        ),
      );
    });
  }
}

class _BillsList extends StatelessWidget {
  final List<Bill> bills;
  final BillType type;

  const _BillsList({required this.bills, required this.type});

  @override
  Widget build(BuildContext context) {
    if (bills.isEmpty) {
      return EmptyState(
        icon: Icons.receipt_long_outlined,
        title:
            'No ${type == BillType.sale ? "sale" : type == BillType.purchase ? "purchase" : "expense"} bills yet',
        subtitle: type == BillType.sale
            ? 'Create professional bills in 3 seconds.\nAuto-updates Khata, Inventory & Cashbook.'
            : 'Track your ${type == BillType.purchase ? "purchases" : "expenses"} easily',
      );
    }

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText:
                        'Search ${type == BillType.sale ? "sales" : type == BillType.purchase ? "purchases" : "expenses"}',
                    hintStyle: const TextStyle(fontSize: 12),
                    prefixIcon: const Icon(Icons.search, size: 18),
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                            color: Color(0xFFBDBDBD))),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                            color: Color(0xFFBDBDBD))),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                  icon: const Icon(Icons.filter_list,
                      color: AppColors.primary),
                  onPressed: () {}),
              IconButton(
                  icon: const Icon(Icons.sort,
                      color: AppColors.primary),
                  onPressed: () {}),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: bills.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, indent: 16),
            itemBuilder: (_, i) {
              final bill = bills[i];
              return _BillTile(bill: bill);
            },
          ),
        ),
      ],
    );
  }
}

class _BillTile extends StatelessWidget {
  final Bill bill;
  const _BillTile({required this.bill});

  @override
  Widget build(BuildContext context) {
    final isPaid = bill.paymentStatus == PaymentStatus.fullyPaid;
    final isPartial =
        bill.paymentStatus == PaymentStatus.partiallyPaid;

    return InkWell(
      onTap: () {}, // TODO: bill detail screen
      child: Container(
        color: Colors.white,
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.lightBlue,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                bill.billType == BillType.sale
                    ? Icons.receipt_outlined
                    : bill.billType == BillType.purchase
                        ? Icons.shopping_cart_outlined
                        : Icons.money_off_outlined,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bill.billType == BillType.sale
                        ? 'Sale Bill'
                        : bill.billType == BillType.purchase
                            ? 'Purchase Bill'
                            : 'Expense',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.lightGrey,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(bill.billNumber,
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.grey)),
                      ),
                      const SizedBox(width: 6),
                      Text(AppHelpers.formatDate(bill.date),
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.grey)),
                    ],
                  ),
                  if (bill.partyName != null &&
                      bill.partyName!.isNotEmpty)
                    Text(bill.partyName!,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.grey)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  AppHelpers.formatCurrency(bill.totalAmount),
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isPaid
                        ? AppColors.green.withValues(alpha: 0.1)
                        : isPartial
                            ? Colors.orange.withValues(alpha: 0.1)
                            : AppColors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isPaid
                        ? 'Fully Paid'
                        : isPartial
                            ? 'Partial'
                            : 'Unpaid',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isPaid
                          ? AppColors.green
                          : isPartial
                              ? Colors.orange
                              : AppColors.red,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}