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
import 'add_bill_screen.dart'; // AddBillScreen lives here
import '../models/models.dart';
import 'cashbook_screen.dart'; // make sure this exists or use a placeholder

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  // We can't use const here because _BillsScreen needs a callback for tab switching
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const _HomeTab(),
      const PartiesScreen(),
      _BillsScreen(onGoToReports: () => setState(() => _tab = 3)),
      const ReportsScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _tab, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.people_outline),
              activeIcon: Icon(Icons.people),
              label: 'Parties'),
          BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined),
              activeIcon: Icon(Icons.receipt_long),
              label: 'Bills'),
          BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_outlined),
              activeIcon: Icon(Icons.bar_chart),
              label: 'Reports'),
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
          // ── Header ──────────────────────────────────────────────────────
          _BillsHeader(
            businessName: auth.profile?.businessName ?? 'My Business',
            businessAddress: auth.profile?.address ?? '',
            monthlySales: billProvider.monthlySales,
            monthlyPurchases: billProvider.monthlyPurchases,
            todayIn: todayIn,
            todayOut: todayOut,
            // FIX: navigate to Reports tab via callback
            onViewReports: widget.onGoToReports,
            // FIX: open cashbook screen
            onCashbook: _openCashbook,
            onSettings: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),

          // ── Tabs ────────────────────────────────────────────────────────
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

          // ── Search bar ──────────────────────────────────────────────────
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

          // ── Bill list ────────────────────────────────────────────────────
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

      // ── Bottom bar ──────────────────────────────────────────────────────
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
                              color: AppTheme.primaryColor, fontSize: 10)),
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
  final VoidCallback onCashbook; // FIX: separate cashbook callback
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
          // Business row
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
                        Text(businessName,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15)),
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

          // Monthly stats row
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
              // FIX: tapping VIEW REPORTS now calls onViewReports which switches to Reports tab
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

          // Today IN/OUT + Cashbook row
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
                    width: 1, height: 28, color: const Color(0xFFE0E0E0)),
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
                // FIX: tapping CASHBOOK now opens cashbook screen
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
                  color: iconBg, borderRadius: BorderRadius.circular(10)),
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
                                fontSize: 11, color: Color(0xFF616161))),
                      ),
                      if (bill.partyName != null) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(bill.partyName!,
                              style: const TextStyle(
                                  fontSize: 11, color: Color(0xFF9E9E9E)),
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
              style: const TextStyle(fontSize: 13, color: Color(0xFF9E9E9E)),
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
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child:
                      Icon(o.$2, color: AppTheme.primaryColor, size: 22),
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

// ══════════════════════════════════════════════════════════════════════════════
// HOME TAB
// ══════════════════════════════════════════════════════════════════════════════
class _HomeTab extends StatelessWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final customers = context.watch<CustomerProvider>();
    final cashbook = context.watch<CashbookProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              auth.profile?.businessName ?? 'GBook',
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w800),
            ),
            if (auth.profile?.ownerName.isNotEmpty == true)
              const Text(
                'Welcome back',
                style: TextStyle(fontSize: 12, color: Colors.white70),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            context.read<CustomerProvider>().loadCustomers(),
            context.read<CashbookProvider>().loadEntries(),
          ]);
        },
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryColor,
                    AppTheme.primaryColor.withValues(alpha: 0.7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Cash Balance',
                      style:
                          TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 6),
                  Text(
                    AppHelpers.formatCurrency(cashbook.balance),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _CashStat(
                          label: 'Cash In',
                          amount: cashbook.totalIn,
                          color: const Color(0xFF90EE90),
                          icon: Icons.arrow_downward,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 36,
                        color: Colors.white24,
                        margin:
                            const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      Expanded(
                        child: _CashStat(
                          label: 'Cash Out',
                          amount: cashbook.totalOut,
                          color: const Color(0xFFFF9999),
                          icon: Icons.arrow_upward,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'You Will Get',
                    amount: customers.totalReceivable,
                    color: AppTheme.creditColor,
                    icon: Icons.arrow_circle_down_outlined,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatCard(
                    label: 'You Will Give',
                    amount: customers.totalPayable,
                    color: AppTheme.debitColor,
                    icon: Icons.arrow_circle_up_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text('Quick Actions',
                style:
                    TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 10),
            Row(
              children: [
                _QuickAction(
                  icon: Icons.person_add_outlined,
                  label: 'Add\nCustomer',
                  color: AppTheme.primaryColor,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AddCustomerScreen()),
                  ),
                ),
                const SizedBox(width: 10),
                _QuickAction(
                  icon: Icons.local_shipping_outlined,
                  label: 'Add\nSupplier',
                  color: const Color(0xFF7B68EE),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            const AddPartyScreen(isSupplier: true)),
                  ),
                ),
                const SizedBox(width: 10),
                _QuickAction(
                  icon: Icons.add_shopping_cart_outlined,
                  label: 'Add\nItem',
                  color: const Color(0xFFFF8C00),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            const AddPartyScreen(isSupplier: false)),
                  ),
                ),
                const SizedBox(width: 10),
                _QuickAction(
                  icon: Icons.receipt_outlined,
                  label: 'New\nBill',
                  color: const Color(0xFF20B2AA),
                  onTap: () {},
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Recent Parties',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
                TextButton(
                  onPressed: () {},
                  child: const Text('View All',
                      style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ...customers.customers.take(5).map((c) {
              final balance = c.balance;
              final color = balance >= 0
                  ? AppTheme.creditColor
                  : AppTheme.debitColor;
              return Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        AppTheme.primaryColor.withValues(alpha: 0.1),
                    child: Text(
                      AppHelpers.initials(c.name),
                      style: const TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 14),
                    ),
                  ),
                  title: Text(c.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(c.phone ?? '',
                      style: const TextStyle(fontSize: 12)),
                  trailing: balance != 0
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              AppHelpers.formatCurrency(balance.abs()),
                              style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13),
                            ),
                            Text(
                              balance >= 0 ? 'Will Give' : 'Will Get',
                              style:
                                  TextStyle(fontSize: 10, color: color),
                            ),
                          ],
                        )
                      : const Text('Settled',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey)),
                ),
              );
            }),
            if (customers.customers.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.people_outline,
                            size: 36, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        const Text('No customers yet',
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CashStat extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final IconData icon;
  const _CashStat(
      {required this.label,
      required this.amount,
      required this.color,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: Colors.white70, fontSize: 11)),
            Text(AppHelpers.formatCurrency(amount),
                style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final IconData icon;
  const _StatCard(
      {required this.label,
      required this.amount,
      required this.color,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 11, color: Colors.grey)),
                Text(AppHelpers.formatCurrency(amount),
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 6),
              Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}