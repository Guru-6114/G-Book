// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import '../providers/providers.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../utils/helpers.dart';
import 'parties_screen.dart';
import 'reports_screen.dart';
import 'profile_screen.dart';
import 'add_customer_screen.dart';
import 'add_party_screen.dart';
import 'add_bill_screen.dart';
import '../models/models.dart';
import 'cashbook_screen.dart';
import 'items_screen.dart';
import 'more_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  void _switchTab(int index) {
    setState(() => _tab = index);
  }

  @override
  Widget build(BuildContext context) {
    // Build pages lazily so MoreScreen has access to _switchTab
    final pages = [
      const PartiesScreen(),
      _BillsScreen(onGoToReports: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ReportsScreen()),
        );
      }),
      const ItemsScreen(),
      MoreScreen(onNavigateToTab: _switchTab),
    ];

    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.people_outline),
              activeIcon: Icon(Icons.people),
              label: 'Parties'),
          BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined),
              activeIcon: Icon(Icons.receipt_long),
              label: 'Bills'),
          BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2_outlined),
              activeIcon: Icon(Icons.inventory_2),
              label: 'Items'),
          BottomNavigationBarItem(
              icon: Icon(Icons.more_horiz_outlined),
              activeIcon: Icon(Icons.more_horiz),
              label: 'More'),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// BILLS SCREEN — Khatabook-style
// ══════════════════════════════════════════════════════════════════════════════
class _BillsScreen extends StatefulWidget {
  final VoidCallback onGoToReports;
  const _BillsScreen({required this.onGoToReports});

  @override
  State<_BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends State<_BillsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<BillProvider>().loadBills();
      context.read<CashbookProvider>().loadEntries();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  BillType get _currentBillType {
    switch (_tabs.index) {
      case 1:
        return BillType.purchase;
      case 2:
        return BillType.expense;
      default:
        return BillType.sale;
    }
  }

  void _openAddBill(BillType type) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AddBillScreen(billType: type)),
    );
    if (result == true && mounted) {
      context.read<BillProvider>().loadBills();
    }
  }

  void _openMoreOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _MoreOptionsSheet(
        onSelected: (type) {
          Navigator.pop(context);
          _openAddBill(type);
        },
      ),
    );
  }

  void _openCashbook() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CashbookScreen()),
    );
  }

  String _tabLabel(int i) {
    switch (i) {
      case 1:
        return 'purchase';
      case 2:
        return 'expense';
      default:
        return 'sales';
    }
  }

  @override
  Widget build(BuildContext context) {
    final billProvider = context.watch<BillProvider>();
    final cashbook = context.watch<CashbookProvider>();
    final auth = context.watch<AuthProvider>();

    final BillType tabType = _currentBillType;
    final allTabBills =
        billProvider.bills.where((b) => b.billType == tabType).toList();
    final filteredBills = _query.isEmpty
        ? allTabBills
        : allTabBills
            .where((b) =>
                (b.partyName ?? '')
                    .toLowerCase()
                    .contains(_query.toLowerCase()) ||
                b.billNumber
                    .toLowerCase()
                    .contains(_query.toLowerCase()))
            .toList();

    final today = DateTime.now();
    final todayIn = cashbook.entries
        .where((e) =>
            e.isCashIn &&
            e.date.year == today.year &&
            e.date.month == today.month &&
            e.date.day == today.day)
        .fold(0.0, (s, e) => s + e.amount);
    final todayOut = cashbook.entries
        .where((e) =>
            !e.isCashIn &&
            e.date.year == today.year &&
            e.date.month == today.month &&
            e.date.day == today.day)
        .fold(0.0, (s, e) => s + e.amount);

    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      body: Column(
        children: [
          _BillsHeader(
            businessName: auth.profile?.businessName ?? 'My Business',
            businessAddress: auth.profile?.address ?? '',
            monthlySales: billProvider.monthlySales,
            monthlyPurchases: billProvider.monthlyPurchases,
            todayIn: todayIn,
            todayOut: todayOut,
            onViewReports: widget.onGoToReports,
            onCashbook: _openCashbook,
            onSettings: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
          Container(
            color: AppTheme.primaryColor,
            child: TabBar(
              controller: _tabs,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              labelStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  letterSpacing: 0.5),
              unselectedLabelStyle: const TextStyle(fontSize: 14),
              tabs: const [
                Tab(text: 'Sale'),
                Tab(text: 'Purchase'),
                Tab(text: 'Expense'),
              ],
            ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText:
                          'Search for ${_tabLabel(_tabs.index)} transactions',
                      hintStyle: const TextStyle(
                          fontSize: 13, color: Color(0xFFBDBDBD)),
                      prefixIcon: const Icon(Icons.search,
                          size: 20, color: Color(0xFF9E9E9E)),
                      suffixIcon: _query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _query = '');
                              })
                          : null,
                      isDense: true,
                      filled: true,
                      fillColor: const Color(0xFFF5F5F5),
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                const SizedBox(width: 8),
                _IconBtn(icon: Icons.filter_list, onTap: () {}),
                const SizedBox(width: 6),
                _IconBtn(icon: Icons.sort, onTap: () {}),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: billProvider.loading
                ? const Center(child: CircularProgressIndicator())
                : filteredBills.isEmpty
                    ? _EmptyBills(
                        tabIndex: _tabs.index,
                        onAddBill: () => _openAddBill(_currentBillType),
                      )
                    : RefreshIndicator(
                        onRefresh: () =>
                            context.read<BillProvider>().loadBills(),
                        child: ListView.separated(
                          padding: EdgeInsets.zero,
                          itemCount: filteredBills.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, indent: 70),
                          itemBuilder: (_, i) =>
                              _BillTile(bill: filteredBills[i]),
                        ),
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
                child: OutlinedButton(
                  onPressed: _openMoreOptions,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                        color: AppTheme.primaryColor, width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('MORE',
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            letterSpacing: 1,
                          )),
                      Text('Payment & Return',
                          style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontSize: 10)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: () => _openAddBill(_currentBillType),
                  icon: const Icon(Icons.receipt_long, size: 18),
                  label: const Text('ADD BILL',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          letterSpacing: 1)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                    elevation: 2,
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

// ── Bills Header ──────────────────────────────────────────────────────────────
class _BillsHeader extends StatelessWidget {
  final String businessName;
  final String businessAddress;
  final double monthlySales;
  final double monthlyPurchases;
  final double todayIn;
  final double todayOut;
  final VoidCallback onViewReports;
  final VoidCallback onCashbook;
  final VoidCallback onSettings;

  const _BillsHeader({
    required this.businessName,
    required this.businessAddress,
    required this.monthlySales,
    required this.monthlyPurchases,
    required this.todayIn,
    required this.todayOut,
    required this.onViewReports,
    required this.onCashbook,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.primaryColor,
      padding: const EdgeInsets.fromLTRB(14, 46, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.book_outlined,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(businessName,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15),
                              overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.edit,
                            color: Colors.white70, size: 13),
                      ],
                    ),
                    if (businessAddress.isNotEmpty)
                      Row(
                        children: [
                          const Icon(Icons.location_on,
                              color: Colors.white54, size: 11),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(businessAddress,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 11),
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onSettings,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.settings_outlined,
                          color: Colors.white, size: 15),
                      SizedBox(width: 4),
                      Text('Settings',
                          style:
                              TextStyle(color: Colors.white, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatBox(
                  amount: monthlySales,
                  label: 'Monthly Sales',
                  amountColor: const Color(0xFF4ADE80),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatBox(
                  amount: monthlyPurchases,
                  label: 'Monthly Purchases',
                  amountColor: const Color(0xFFFCA5A5),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: onViewReports,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text('VIEW\nREPORTS',
                              style: TextStyle(
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                  letterSpacing: 0.3,
                                  height: 1.3),
                              textAlign: TextAlign.center),
                        ),
                        Icon(Icons.chevron_right,
                            color: AppTheme.primaryColor, size: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppHelpers.formatCurrencyCompact(todayIn),
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: Color(0xFF212121)),
                      ),
                      const Text("Today's IN",
                          style: TextStyle(
                              fontSize: 11, color: Color(0xFF9E9E9E))),
                    ],
                  ),
                ),
                Container(
                    width: 1,
                    height: 28,
                    color: const Color(0xFFE0E0E0)),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppHelpers.formatCurrencyCompact(todayOut),
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Color(0xFF212121)),
                        ),
                        const Text("Today's OUT",
                            style: TextStyle(
                                fontSize: 11, color: Color(0xFF9E9E9E))),
                      ],
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: onCashbook,
                  child: const Row(
                    children: [
                      Text('CASHBOOK',
                          style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              letterSpacing: 0.5)),
                      Icon(Icons.chevron_right,
                          color: AppTheme.primaryColor, size: 18),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final double amount;
  final String label;
  final Color amountColor;

  const _StatBox({
    required this.amount,
    required this.label,
    required this.amountColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppHelpers.formatCurrencyCompact(amount),
                  style: TextStyle(
                      color: amountColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(label,
                    style: const TextStyle(
                        fontSize: 10, color: Color(0xFF9E9E9E))),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 16),
        ],
      ),
    );
  }
}

// ── Bill tile ─────────────────────────────────────────────────────────────────
class _BillTile extends StatelessWidget {
  final Bill bill;
  const _BillTile({required this.bill});

  IconData get _icon {
    switch (bill.billType) {
      case BillType.sale:
        return Icons.receipt_long;
      case BillType.purchase:
        return Icons.shopping_cart_outlined;
      case BillType.expense:
        return Icons.payments_outlined;
      case BillType.saleReturn:
        return Icons.assignment_return_outlined;
      case BillType.purchaseReturn:
        return Icons.keyboard_return_outlined;
    }
  }

  String get _typeLabel {
    switch (bill.billType) {
      case BillType.sale:
        return 'Sale Bill';
      case BillType.purchase:
        return 'Purchase Bill';
      case BillType.expense:
        return 'Expense';
      case BillType.saleReturn:
        return 'Sale Return';
      case BillType.purchaseReturn:
        return 'Purchase Return';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPaid = bill.isPaid;
    final isPartial = !isPaid && bill.paidAmount > 0;

    final Color statusColor;
    final String statusLabel;
    if (isPaid) {
      statusColor = AppTheme.creditColor;
      statusLabel = 'Fully Paid';
    } else if (isPartial) {
      statusColor = const Color(0xFFF97316);
      statusLabel = 'Partial';
    } else {
      statusColor = AppTheme.debitColor;
      statusLabel = 'Unpaid';
    }

    final isSaleType = bill.billType == BillType.sale ||
        bill.billType == BillType.saleReturn;
    final iconBg = isSaleType
        ? AppTheme.creditColor.withValues(alpha: 0.12)
        : AppTheme.debitColor.withValues(alpha: 0.12);
    final iconColor =
        isSaleType ? AppTheme.creditColor : AppTheme.debitColor;

    return InkWell(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(_icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_typeLabel,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: Color(0xFF212121))),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F0F0),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(bill.billNumber,
                            style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF616161))),
                      ),
                      if (bill.partyName != null) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(bill.partyName!,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF9E9E9E)),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(AppHelpers.formatDate(bill.date),
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF9E9E9E))),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  AppHelpers.formatCurrencyCompact(bill.grandTotal),
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Color(0xFF212121)),
                ),
                const SizedBox(height: 4),
                Text(statusLabel,
                    style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────
class _EmptyBills extends StatelessWidget {
  final int tabIndex;
  final VoidCallback onAddBill;
  const _EmptyBills({required this.tabIndex, required this.onAddBill});

  @override
  Widget build(BuildContext context) {
    const labels = ['Sale Bill', 'Purchase Bill', 'Expense'];
    const icons = [
      Icons.receipt_long_outlined,
      Icons.shopping_cart_outlined,
      Icons.payments_outlined,
    ];
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.07),
              shape: BoxShape.circle,
            ),
            child: Icon(icons[tabIndex],
                size: 48,
                color: AppTheme.primaryColor.withValues(alpha: 0.35)),
          ),
          const SizedBox(height: 20),
          Text('No ${labels[tabIndex]}s yet',
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF424242))),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Tap ADD BILL below to create your first ${labels[tabIndex].toLowerCase()}',
              style:
                  const TextStyle(fontSize: 13, color: Color(0xFF9E9E9E)),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

// ── More options sheet ────────────────────────────────────────────────────────
class _MoreOptionsSheet extends StatelessWidget {
  final void Function(BillType) onSelected;
  const _MoreOptionsSheet({required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final options = [
      (BillType.saleReturn, Icons.assignment_return_outlined, 'Sale Return',
          'Customer returned goods'),
      (BillType.purchaseReturn, Icons.keyboard_return_outlined,
          'Purchase Return', 'Return goods to supplier'),
    ];
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('More Options',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF212121))),
          const SizedBox(height: 16),
          ...options.map((o) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color:
                        AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(o.$2,
                      color: AppTheme.primaryColor, size: 22),
                ),
                title: Text(o.$3,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text(o.$4,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF9E9E9E))),
                onTap: () => onSelected(o.$1),
              )),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Small icon button ─────────────────────────────────────────────────────────
class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 20, color: const Color(0xFF616161)),
      ),
    );
  }
}