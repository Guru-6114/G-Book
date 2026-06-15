// lib/screens/home_screen.dart
import 'dart:io';
import 'dart:typed_data';
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
import 'add_expense_screen.dart';
import '../models/models.dart';
import 'cashbook_screen.dart';
import 'items_screen.dart';
import 'more_screen.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_file/open_file.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  int _billsInitialSubTab = 0;

  void _switchTab(int index, {int? billSubTab}) {
    setState(() {
      _tab = index;
      if (index == 1 && billSubTab != null) {
        _billsInitialSubTab = billSubTab;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: IndexedStack(
        index: _tab,
        children: [
          const PartiesScreen(),
          _BillsScreen(
            key: ValueKey('bills_$_billsInitialSubTab'),
            initialSubTab: _billsInitialSubTab,
            onGoToReports: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReportsScreen()),
              );
            },
          ),
          const ItemsScreen(),
          MoreScreen(
            onNavigateToTab: (index) => _switchTab(index),
            onNavigateToTabWithSubTab: (index, {billSubTab}) =>
                _switchTab(index, billSubTab: billSubTab),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) => setState(() {
          _tab = i;
          if (i == 1) _billsInitialSubTab = 0;
        }),
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
// BILLS SCREEN
// ══════════════════════════════════════════════════════════════════════════════
class _BillsScreen extends StatefulWidget {
  final VoidCallback onGoToReports;
  final int initialSubTab;

  const _BillsScreen({
    super.key,
    required this.onGoToReports,
    this.initialSubTab = 0,
  });

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
    _tabs = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialSubTab,
    );
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
    bool? result;
    if (type == BillType.expense) {
      result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const AddExpenseScreen()),
      );
    } else {
      result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => AddBillScreen(billType: type)),
      );
    }
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
      resizeToAvoidBottomInset: false,
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
          Container(
            color: Colors.white,
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 10,
              bottom: MediaQuery.of(context).padding.bottom + 10,
            ),
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
        ],
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
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BillDetailScreen(bill: bill),
        ),
      ),
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

// ══════════════════════════════════════════════════════════════════════════════
// BILL DETAIL SCREEN
// ══════════════════════════════════════════════════════════════════════════════
class BillDetailScreen extends StatelessWidget {
  final Bill bill;
  const BillDetailScreen({super.key, required this.bill});

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

  String get _returnLabel {
    switch (bill.billType) {
      case BillType.sale:
        return 'SALE RETURN';
      case BillType.purchase:
        return 'PURCHASE RETURN';
      default:
        return '';
    }
  }

  Color get _headerColor {
    switch (bill.billType) {
      case BillType.sale:
      case BillType.saleReturn:
        return const Color(0xFF1565C0);
      case BillType.purchase:
      case BillType.purchaseReturn:
        return const Color(0xFFB71C1C);
      default:
        return const Color(0xFF424242);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPaid = bill.isPaid;
    final isPartial = !isPaid && bill.paidAmount > 0;

    final Color statusColor;
    final String statusLabel;
    if (isPaid) {
      statusColor = const Color(0xFF2E7D32);
      statusLabel = 'Fully Paid';
    } else if (isPartial) {
      statusColor = const Color(0xFFF97316);
      statusLabel = 'Partial';
    } else {
      statusColor = const Color(0xFFB71C1C);
      statusLabel = 'Unpaid';
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: _headerColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          bill.billNumber,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 17),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.white),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete Bill'),
                  content: const Text(
                      'Are you sure you want to delete this bill?'),
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
              if (confirmed == true && context.mounted) {
                await context.read<BillProvider>().deleteBill(bill.id);
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE0E0E0)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Created On: ${AppHelpers.formatDate(bill.createdAt)}',
                            style: const TextStyle(
                                fontSize: 13, color: Color(0xFF757575)),
                          ),
                          if (bill.partyName != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              bill.partyName!,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF212121)),
                            ),
                          ],
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₹ ${bill.grandTotal.toStringAsFixed(0)}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 22,
                                color: Color(0xFF212121)),
                          ),
                          Text(
                            statusLabel,
                            style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 13),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (bill.paidAmount > 0 && !bill.isPaid) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Amount Paid',
                            style: TextStyle(
                                fontSize: 13, color: Color(0xFF757575))),
                        Text(
                          '₹ ${bill.paidAmount.toStringAsFixed(0)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Color(0xFF2E7D32)),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Balance Due',
                            style: TextStyle(
                                fontSize: 13, color: Color(0xFF757575))),
                        Text(
                          '₹ ${bill.balanceDue.toStringAsFixed(0)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Color(0xFFB71C1C)),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),

          if (bill.billType == BillType.sale ||
              bill.billType == BillType.purchase) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE0E0E0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Continue with:',
                      style: TextStyle(
                          fontSize: 13, color: Color(0xFF757575))),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: () => _openAddReturn(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _headerColor,
                      side: BorderSide(color: _headerColor),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                    ),
                    child: Text(
                      '+ $_returnLabel',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: _headerColor),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE0E0E0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Linked transactions;',
                    style:
                        TextStyle(fontSize: 13, color: Color(0xFF757575))),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () {},
                  child: Text(
                    'PAYMENT IN #1',
                    style: TextStyle(
                        color: _headerColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE0E0E0)),
            ),
            child: Column(
              children: [
                ...bill.items.map((item) => Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.itemName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                          color: Color(0xFF212121)),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${item.quantity.toStringAsFixed(item.quantity % 1 == 0 ? 0 : 1)} x ₹ ${item.rate.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF757575)),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '₹ ${item.total.toStringAsFixed(0)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: Color(0xFF212121)),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1, indent: 16),
                      ],
                    )),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _TotalRow(
                          label: 'Net Amount',
                          value: '₹ ${bill.subtotal.toStringAsFixed(0)}'),
                      const SizedBox(height: 6),
                      _TotalRow(
                          label: 'Taxes',
                          value:
                              '₹ ${bill.taxTotal.toStringAsFixed(0)}'),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Gross Amount',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: Color(0xFF212121))),
                          Text(
                            '₹ ${bill.grandTotal.toStringAsFixed(0)}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: Color(0xFF212121)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (bill.notes != null && bill.notes!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE0E0E0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Notes',
                      style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF757575),
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(bill.notes!,
                      style: const TextStyle(
                          fontSize: 14, color: Color(0xFF424242))),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          color: Colors.white,
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: OutlinedButton.icon(
            onPressed: () => _openViewPdf(context),
            icon: Icon(Icons.picture_as_pdf_outlined, color: _headerColor),
            label: Text('VIEW PDF',
                style: TextStyle(
                    color: _headerColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    letterSpacing: 1)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: _headerColor, width: 1.5),
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
      ),
    );
  }

  void _openAddReturn(BuildContext context) {
    final returnType = bill.billType == BillType.sale
        ? BillType.saleReturn
        : BillType.purchaseReturn;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddReturnScreen(
          originalBill: bill,
          returnType: returnType,
        ),
      ),
    );
  }

  void _openViewPdf(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BillPdfScreen(bill: bill, headerColor: _headerColor),
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  const _TotalRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13, color: Color(0xFF757575))),
        Text(value,
            style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF424242),
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}

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
// ADD RETURN SCREEN
// ══════════════════════════════════════════════════════════════════════════════
class AddReturnScreen extends StatefulWidget {
  final Bill originalBill;
  final BillType returnType;

  const AddReturnScreen({
    super.key,
    required this.originalBill,
    required this.returnType,
  });

  @override
  State<AddReturnScreen> createState() => _AddReturnScreenState();
}

class _AddReturnScreenState extends State<AddReturnScreen> {
  DateTime _date = DateTime.now();
  String _refundMode = '';
  bool _saving = false;

  late List<_ReturnItemRow> _items;

  final List<_AdditionalCharge> _charges = [_AdditionalCharge()];
  String _discountType = 'rupees';
  final _discountCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _items = widget.originalBill.items
        .map((item) => _ReturnItemRow(
              itemName: item.itemName,
              quantity: item.quantity,
              rate: item.rate,
              total: item.total,
              qtyCtrl: TextEditingController(
                  text: item.quantity.toStringAsFixed(
                      item.quantity % 1 == 0 ? 0 : 1)),
            ))
        .toList();
  }

  @override
  void dispose() {
    for (final r in _items) {
      r.qtyCtrl.dispose();
    }
    _discountCtrl.dispose();
    for (final c in _charges) {
      c.nameCtrl.dispose();
      c.amountCtrl.dispose();
    }
    super.dispose();
  }

  String get _typeLabel =>
      widget.returnType == BillType.saleReturn
          ? 'Sale Return'
          : 'Purchase Return';

  int get _returnNumber => 1;

  double get _subTotal =>
      _items.fold(0.0, (s, r) => s + r.effectiveTotal);

  double get _additionalChargesTotal => _charges.fold(
      0.0, (s, c) => s + (double.tryParse(c.amountCtrl.text) ?? 0));

  double get _discountAmount {
    final val = double.tryParse(_discountCtrl.text) ?? 0;
    if (_discountType == 'percent') {
      return _subTotal * val / 100;
    }
    return val;
  }

  double get _totalAmount =>
      _subTotal + _additionalChargesTotal - _discountAmount;

  Color get _headerColor =>
      widget.returnType == BillType.saleReturn
          ? const Color(0xFF1565C0)
          : const Color(0xFFB71C1C);

  void _openItemSearch() {
    final itemProvider = context.read<ItemProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _ItemSearchSheet(
        availableItems: itemProvider.items,
        selectedItems: _items,
        headerColor: _headerColor,
        onDone: (updatedItems) {
          setState(() => _items
            ..clear()
            ..addAll(updatedItems));
        },
      ),
    );
  }

  void _showAdditionalCharges() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _AdditionalChargesSheet(
        charges: _charges,
        onSave: () => setState(() {}),
      ),
    );
  }

  void _showAddDiscount() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _AddDiscountSheet(
        discountType: _discountType,
        discountCtrl: _discountCtrl,
        onSave: (type) {
          setState(() => _discountType = type);
        },
      ),
    );
  }

  Future<void> _generate() async {
    if (_refundMode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a refund mode')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final billsProvider = context.read<BillProvider>();
      final billNo =
          await billsProvider.nextBillNumber(widget.returnType);
      if (!mounted) return;

      final now = DateTime.now();
      final billId = AppHelpers.generateId();

      final billItems = _items
          .where((r) => r.effectiveQty > 0)
          .map((r) => BillItem(
                id: AppHelpers.generateId(),
                billId: billId,
                itemId: AppHelpers.generateId(),
                itemName: r.itemName,
                quantity: r.effectiveQty,
                rate: r.rate,
                total: r.effectiveTotal,
              ))
          .toList();

      final returnBill = Bill(
        id: billId,
        billType: widget.returnType,
        billNumber: '$_typeLabel #$billNo',
        partyName: widget.originalBill.partyName,
        items: billItems,
        subtotal: _subTotal,
        grandTotal: _totalAmount,
        paidAmount: _totalAmount,
        date: _date,
        createdAt: now,
        notes: 'Return for: ${widget.originalBill.billNumber}',
      );

      await billsProvider.addBill(returnBill);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$_typeLabel generated successfully!')),
      );
      Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: _headerColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Add $_typeLabel',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 17),
        ),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: const BoxDecoration(
                    border: Border(
                        bottom: BorderSide(color: Color(0xFFE0E0E0))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Return Number',
                              style: TextStyle(
                                  fontSize: 12, color: Color(0xFF9E9E9E))),
                          Row(
                            children: [
                              Text('$_returnNumber',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF212121))),
                              const SizedBox(width: 4),
                              Icon(Icons.edit,
                                  size: 14, color: _headerColor),
                            ],
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Date',
                              style: TextStyle(
                                  fontSize: 12, color: Color(0xFF9E9E9E))),
                          GestureDetector(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _date,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null && mounted) {
                                setState(() => _date = picked);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                border:
                                    Border.all(color: _headerColor),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_today,
                                      size: 14, color: _headerColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    AppHelpers.formatDate(_date),
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: _headerColor,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: const BoxDecoration(
                    border: Border(
                        bottom: BorderSide(color: Color(0xFFE0E0E0))),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.description_outlined,
                          size: 20, color: Colors.grey.shade500),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Add Invoice Details',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF9E9E9E))),
                            Text(
                              '${widget.originalBill.billNumber} , Date ${AppHelpers.formatDate(widget.originalBill.date)}',
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF212121),
                                  fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                  child: Text(
                    '${_items.length} Item${_items.length != 1 ? 's' : ''}',
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF757575)),
                  ),
                ),

                ..._items.map((row) => _ReturnItemTile(
                      row: row,
                      headerColor: _headerColor,
                      onChanged: () => setState(() {}),
                    )),

                InkWell(
                  onTap: _openItemSearch,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: _headerColor.withValues(alpha: 0.06),
                      border: Border(
                        top: BorderSide(
                            color: _headerColor.withValues(alpha: 0.2)),
                        bottom: BorderSide(
                            color: _headerColor.withValues(alpha: 0.2)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.inventory_2_outlined,
                            size: 18, color: _headerColor),
                        const SizedBox(width: 10),
                        Text(
                          'EDIT OR ADD ITEMS',
                          style: TextStyle(
                              color: _headerColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              letterSpacing: 0.5),
                        ),
                      ],
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Item Sub-Total',
                          style: TextStyle(
                              fontSize: 14, color: Color(0xFF424242))),
                      Text(
                        '₹ ${_subTotal.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF212121)),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                InkWell(
                  onTap: _showAdditionalCharges,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 13),
                    child: Row(
                      children: [
                        const Icon(Icons.money_outlined,
                            color: Color(0xFF757575)),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text('Additional Charges',
                              style: TextStyle(fontSize: 14)),
                        ),
                        if (_additionalChargesTotal > 0)
                          Text(
                            '₹ ${_additionalChargesTotal.toStringAsFixed(0)}',
                            style: TextStyle(
                                color: _headerColor,
                                fontWeight: FontWeight.w600),
                          ),
                        const Icon(Icons.chevron_right,
                            color: Color(0xFF9E9E9E)),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),

                InkWell(
                  onTap: _showAddDiscount,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Text(
                          '+ ADD DISCOUNT',
                          style: TextStyle(
                              color: _headerColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              letterSpacing: 0.3),
                        ),
                        if (_discountAmount > 0) ...[
                          const Spacer(),
                          Text(
                            '- ₹ ${_discountAmount.toStringAsFixed(0)}',
                            style: const TextStyle(
                                color: Color(0xFF2E7D32),
                                fontWeight: FontWeight.w600,
                                fontSize: 13),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),

                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Amount',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF212121))),
                      Text(
                        '₹ ${_totalAmount.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF212121)),
                      ),
                    ],
                  ),
                ),

                CustomPaint(
                  size: const Size(double.infinity, 12),
                  painter: _WavyDividerPainter(),
                ),

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      _RefundModeOption(
                        label: 'Credit to party',
                        value: 'credit',
                        selected: _refundMode,
                        onTap: () =>
                            setState(() => _refundMode = 'credit'),
                        color: _headerColor,
                      ),
                      const SizedBox(width: 16),
                      _RefundModeOption(
                        label: 'Cash',
                        value: 'cash',
                        selected: _refundMode,
                        onTap: () =>
                            setState(() => _refundMode = 'cash'),
                        color: _headerColor,
                      ),
                      const SizedBox(width: 16),
                      _RefundModeOption(
                        label: 'Online',
                        value: 'online',
                        selected: _refundMode,
                        onTap: () =>
                            setState(() => _refundMode = 'online'),
                        color: _headerColor,
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Difference Amount',
                          style: TextStyle(
                              fontSize: 13, color: Color(0xFF757575))),
                      const Text('₹ 0',
                          style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF212121),
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),

          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(context).padding.bottom + 12,
            ),
            color: Colors.white,
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _generate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _refundMode.isEmpty
                      ? _headerColor.withValues(alpha: 0.4)
                      : _headerColor,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text(
                        'GENERATE RETURN ₹ ${_totalAmount.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: Colors.white),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Item Search Sheet ─────────────────────────────────────────────────────────
class _ItemSearchSheet extends StatefulWidget {
  final List<Item> availableItems;
  final List<_ReturnItemRow> selectedItems;
  final Color headerColor;
  final void Function(List<_ReturnItemRow>) onDone;

  const _ItemSearchSheet({
    required this.availableItems,
    required this.selectedItems,
    required this.headerColor,
    required this.onDone,
  });

  @override
  State<_ItemSearchSheet> createState() => _ItemSearchSheetState();
}

class _ItemSearchSheetState extends State<_ItemSearchSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  late List<_ReturnItemRow> _items;
  bool _showSelectedOnly = false;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.selectedItems);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Item> get _filteredItems {
    if (_query.isEmpty) return widget.availableItems;
    return widget.availableItems
        .where((i) =>
            i.name.toLowerCase().contains(_query.toLowerCase()))
        .toList();
  }

  bool _isSelected(Item item) =>
      _items.any((r) => r.itemName == item.name);

  _ReturnItemRow? _getRow(Item item) {
    try {
      return _items.firstWhere((r) => r.itemName == item.name);
    } catch (_) {
      return null;
    }
  }

  void _addItem(Item item) {
    if (!_isSelected(item)) {
      setState(() {
        _items.add(_ReturnItemRow(
          itemName: item.name,
          quantity: 1,
          rate: item.salePrice,
          total: item.salePrice,
          qtyCtrl: TextEditingController(text: '1'),
        ));
      });
    }
  }

  void _removeItem(Item item) {
    setState(() {
      _items.removeWhere((r) => r.itemName == item.name);
    });
  }

  double get _total =>
      _items.fold(0.0, (s, r) => s + r.effectiveTotal);

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            decoration: const BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: Color(0xFFE0E0E0))),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Add Items to your Invoice',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search for your created items',
                    prefixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                            })
                        : const Icon(Icons.search),
                    filled: true,
                    fillColor: const Color(0xFFF5F5F5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ],
            ),
          ),
          Expanded(
            child: _filteredItems.isEmpty
                ? Center(
                    child: Text(
                      'No items found',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  )
                : ListView.separated(
                    controller: scrollCtrl,
                    itemCount: _filteredItems.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 16),
                    itemBuilder: (_, i) {
                      final item = _filteredItems[i];
                      final selected = _isSelected(item);
                      final row = _getRow(item);
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F5F5),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(
                                  Icons.inventory_2_outlined,
                                  color: Color(0xFF9E9E9E)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(item.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15)),
                                  Text(
                                    '₹ ${AppHelpers.formatCurrency(item.salePrice)}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            if (selected && row != null)
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle,
                                        color: Colors.red, size: 22),
                                    onPressed: () {
                                      final qty = double.tryParse(
                                              row.qtyCtrl.text) ??
                                          1;
                                      if (qty <= 1) {
                                        _removeItem(item);
                                      } else {
                                        row.qtyCtrl.text =
                                            (qty - 1).toStringAsFixed(0);
                                        setState(() {});
                                      }
                                    },
                                  ),
                                  Text(
                                    row.qtyCtrl.text,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.add_circle,
                                        color: widget.headerColor,
                                        size: 22),
                                    onPressed: () {
                                      final qty = double.tryParse(
                                              row.qtyCtrl.text) ??
                                          1;
                                      row.qtyCtrl.text =
                                          (qty + 1).toStringAsFixed(0);
                                      setState(() {});
                                    },
                                  ),
                                ],
                              )
                            else
                              OutlinedButton(
                                onPressed: () => _addItem(item),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                      color: widget.headerColor),
                                  foregroundColor: widget.headerColor,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(6)),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 8),
                                ),
                                child: const Text('ADD',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700)),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(context).padding.bottom + 12,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE0E0E0))),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Show selected items only',
                        style: TextStyle(fontSize: 14)),
                    Switch(
                      value: _showSelectedOnly,
                      onChanged: (v) =>
                          setState(() => _showSelectedOnly = v),
                      activeColor: widget.headerColor,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_items.length} ITEMS',
                            style: TextStyle(
                                color: widget.headerColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 13),
                          ),
                          Text(
                            '₹ ${_total.toStringAsFixed(0)}',
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF424242)),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        widget.onDone(_items);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.headerColor,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 14),
                      ),
                      child: const Text('CONTINUE',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Colors.white)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Additional Charges sheet ──────────────────────────────────────────────────
class _AdditionalCharge {
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController amountCtrl = TextEditingController();
  bool enabled = true;
}

class _AdditionalChargesSheet extends StatefulWidget {
  final List<_AdditionalCharge> charges;
  final VoidCallback onSave;

  const _AdditionalChargesSheet(
      {required this.charges, required this.onSave});

  @override
  State<_AdditionalChargesSheet> createState() =>
      _AdditionalChargesSheetState();
}

class _AdditionalChargesSheetState
    extends State<_AdditionalChargesSheet> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Additional Charges',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
                const Text(
                  'Add upto 3 types (Eg- Shipping Charges, Packaging Charges etc)',
                  style: TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ...widget.charges.asMap().entries.map((e) {
            final charge = e.value;
            return Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  Checkbox(
                    value: charge.enabled,
                    onChanged: (v) =>
                        setState(() => charge.enabled = v ?? true),
                  ),
                  Expanded(
                    child: TextField(
                      controller: charge.nameCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Name of charge',
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 10, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 100,
                    child: TextField(
                      controller: charge.amountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: 'Amount',
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 10, vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          if (widget.charges.length < 3)
            InkWell(
              onTap: () =>
                  setState(() => widget.charges.add(_AdditionalCharge())),
              child: const Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Icon(Icons.add, color: AppTheme.primaryColor, size: 18),
                    SizedBox(width: 6),
                    Text('ADD NEW CHARGE',
                        style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: MediaQuery.of(context).padding.bottom + 12,
            ),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  widget.onSave();
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('SAVE',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Add Discount sheet ────────────────────────────────────────────────────────
class _AddDiscountSheet extends StatefulWidget {
  final String discountType;
  final TextEditingController discountCtrl;
  final void Function(String type) onSave;

  const _AddDiscountSheet({
    required this.discountType,
    required this.discountCtrl,
    required this.onSave,
  });

  @override
  State<_AddDiscountSheet> createState() => _AddDiscountSheetState();
}

class _AddDiscountSheetState extends State<_AddDiscountSheet> {
  late String _type;

  @override
  void initState() {
    super.initState();
    _type = widget.discountType;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Add Discount',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text('Enter the discount to be applied on this Sale',
                style: TextStyle(fontSize: 13, color: Color(0xFF9E9E9E))),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _type,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'rupees', child: Text('Enter in rup...')),
                      DropdownMenuItem(
                          value: 'percent', child: Text('Percent (%)')),
                    ],
                    onChanged: (v) => setState(() => _type = v!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: widget.discountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'Enter the discount here',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: MediaQuery.of(context).padding.bottom + 16,
            ),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  widget.onSave(_type);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('SAVE',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Return item row ───────────────────────────────────────────────────────────
class _ReturnItemRow {
  final String itemName;
  final double quantity;
  final double rate;
  final double total;
  final TextEditingController qtyCtrl;

  _ReturnItemRow({
    required this.itemName,
    required this.quantity,
    required this.rate,
    required this.total,
    required this.qtyCtrl,
  });

  double get effectiveQty => double.tryParse(qtyCtrl.text) ?? quantity;
  double get effectiveTotal => effectiveQty * rate;
}

class _ReturnItemTile extends StatelessWidget {
  final _ReturnItemRow row;
  final Color headerColor;
  final VoidCallback onChanged;

  const _ReturnItemTile({
    required this.row,
    required this.headerColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE0E0E0))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.itemName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Color(0xFF212121))),
                Text(
                  '${row.effectiveQty.toStringAsFixed(row.effectiveQty % 1 == 0 ? 0 : 1)} x ₹ ${row.rate.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF9E9E9E)),
                ),
              ],
            ),
          ),
          Text('₹ ${row.effectiveTotal.toStringAsFixed(0)}',
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: Color(0xFF212121))),
        ],
      ),
    );
  }
}

class _RefundModeOption extends StatelessWidget {
  final String label;
  final String value;
  final String selected;
  final VoidCallback onTap;
  final Color color;

  const _RefundModeOption({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == value;
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: isSelected ? color : const Color(0xFF9E9E9E),
                  width: 2),
            ),
            child: isSelected
                ? Center(
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration:
                          BoxDecoration(shape: BoxShape.circle, color: color),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
                fontSize: 13,
                color: isSelected ? color : const Color(0xFF424242),
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.normal),
          ),
        ],
      ),
    );
  }
}

class _WavyDividerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE0E0E0)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final path = Path();
    path.moveTo(0, 6);
    double x = 0;
    const waveWidth = 12.0;
    const waveHeight = 4.0;
    while (x < size.width) {
      path.relativeQuadraticBezierTo(waveWidth / 2, -waveHeight, waveWidth, 0);
      path.relativeQuadraticBezierTo(waveWidth / 2, waveHeight, waveWidth, 0);
      x += waveWidth * 2;
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ══════════════════════════════════════════════════════════════════════════════
// THEME COLOR OPTIONS
// ══════════════════════════════════════════════════════════════════════════════
const List<Map<String, dynamic>> _kThemeColors = [
  {'name': 'Blue', 'color': Color(0xFF1565C0)},
  {'name': 'Red', 'color': Color(0xFFB71C1C)},
  {'name': 'Green', 'color': Color(0xFF2E7D32)},
  {'name': 'Purple', 'color': Color(0xFF6A1B9A)},
  {'name': 'Orange', 'color': Color(0xFFE65100)},
  {'name': 'Teal', 'color': Color(0xFF00695C)},
  {'name': 'Pink', 'color': Color(0xFFAD1457)},
  {'name': 'Dark', 'color': Color(0xFF212121)},
];

// ══════════════════════════════════════════════════════════════════════════════
// BILL PDF SCREEN — Khatabook style
// ══════════════════════════════════════════════════════════════════════════════
class BillPdfScreen extends StatefulWidget {
  final Bill bill;
  final Color headerColor;

  const BillPdfScreen({
    super.key,
    required this.bill,
    required this.headerColor,
  });

  @override
  State<BillPdfScreen> createState() => _BillPdfScreenState();
}

class _BillPdfScreenState extends State<BillPdfScreen> {
  String _selectedFormat = 'Premium';
  late Color _themeColor;
  bool _isDownloading = false;
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    _themeColor = widget.headerColor;
  }

  // ── Theme picker ──────────────────────────────────────────────────────────
  void _openThemePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ThemePickerSheet(
        currentColor: _themeColor,
        onColorSelected: (color) {
          setState(() => _themeColor = color);
          Navigator.pop(context);
        },
      ),
    );
  }

  // ── PDF generation ────────────────────────────────────────────────────────
  Future<Uint8List> _generatePdfBytes(dynamic profile) async {
    final pdf = pw.Document();
    final businessName = profile?.businessName ?? 'My Business';
    final address = profile?.address ?? '';
    final phone = profile?.phone ?? '';
    final bill = widget.bill;
    final isPaid = bill.isPaid;

    // Convert Flutter Color to PdfColor
    final pdfColor = PdfColor(
      _themeColor.red / 255,
      _themeColor.green / 255,
      _themeColor.blue / 255,
    );
    final pdfGreen = PdfColor(0.18, 0.49, 0.20);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Top bar
              pw.Container(
                width: double.infinity,
                height: 6,
                color: pdfColor,
              ),
              pw.SizedBox(height: 16),
              // Header row
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Business logo placeholder
                  pw.Container(
                    width: 40,
                    height: 40,
                    color: pdfColor,
                    child: pw.Center(
                      child: pw.Text(
                        businessName.isNotEmpty
                            ? businessName[0].toUpperCase()
                            : 'M',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 12),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(businessName,
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 14)),
                        if (address.isNotEmpty)
                          pw.Text(address,
                              style: const pw.TextStyle(
                                  fontSize: 10,
                                  color: PdfColors.grey700)),
                        if (phone.isNotEmpty)
                          pw.Text('Phone: $phone',
                              style: const pw.TextStyle(
                                  fontSize: 10,
                                  color: PdfColors.grey700)),
                      ],
                    ),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                          'Invoice No. ${bill.billNumber.replaceAll(RegExp(r'[^0-9]'), '').trim()}',
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 12)),
                      pw.Text(
                          'Date: ${AppHelpers.formatDate(bill.date)}',
                          style: const pw.TextStyle(
                              fontSize: 10,
                              color: PdfColors.grey700)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 16),
              // Bill To + Paid stamp
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey300),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Bill To',
                              style: const pw.TextStyle(
                                  fontSize: 10,
                                  color: PdfColors.grey600)),
                          pw.Text(
                            bill.partyName ?? '— —',
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (isPaid) ...[
                    pw.SizedBox(width: 16),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(
                                color: pdfGreen, width: 2),
                          ),
                          child: pw.Column(
                            children: [
                              pw.Text('THANK YOU',
                                  style: pw.TextStyle(
                                      color: pdfGreen,
                                      fontSize: 8,
                                      fontWeight: pw.FontWeight.bold,
                                      letterSpacing: 1)),
                              pw.Text('PAID',
                                  style: pw.TextStyle(
                                      color: pdfGreen,
                                      fontSize: 20,
                                      fontWeight: pw.FontWeight.bold,
                                      letterSpacing: 2)),
                            ],
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text('Total amount',
                            style: const pw.TextStyle(
                                fontSize: 10,
                                color: PdfColors.grey600)),
                        pw.Text(
                          bill.grandTotal.toStringAsFixed(0),
                          style: pw.TextStyle(
                              fontSize: 24,
                              fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text(
                          _amountInWords(bill.grandTotal),
                          style: const pw.TextStyle(
                              fontSize: 9,
                              color: PdfColors.grey600),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              pw.SizedBox(height: 16),
              // Items table header
              pw.Container(
                color: PdfColors.grey100,
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 8, vertical: 6),
                child: pw.Row(
                  children: [
                    pw.SizedBox(
                        width: 24,
                        child: pw.Text('#',
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 10))),
                    pw.Expanded(
                        flex: 3,
                        child: pw.Text('Item Details',
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 10))),
                    pw.SizedBox(
                        width: 60,
                        child: pw.Text('Price/Unit',
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 10))),
                    pw.SizedBox(
                        width: 40,
                        child: pw.Text('Qty',
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 10))),
                    pw.SizedBox(
                        width: 60,
                        child: pw.Text('Total',
                            textAlign: pw.TextAlign.right,
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 10))),
                  ],
                ),
              ),
              // Items rows
              ...bill.items.asMap().entries.map((e) {
                final idx = e.key + 1;
                final item = e.value;
                return pw.Container(
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                        bottom: pw.BorderSide(
                            color: PdfColors.grey200)),
                  ),
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 8, vertical: 7),
                  child: pw.Row(
                    children: [
                      pw.SizedBox(
                          width: 24,
                          child: pw.Text(
                              idx.toString().padLeft(2, '0'),
                              style:
                                  const pw.TextStyle(fontSize: 11))),
                      pw.Expanded(
                          flex: 3,
                          child: pw.Text(item.itemName,
                              style:
                                  const pw.TextStyle(fontSize: 11))),
                      pw.SizedBox(
                          width: 60,
                          child: pw.Text(
                              '${item.rate.toStringAsFixed(0)}/PCS',
                              textAlign: pw.TextAlign.center,
                              style:
                                  const pw.TextStyle(fontSize: 10))),
                      pw.SizedBox(
                          width: 40,
                          child: pw.Text(
                              item.quantity.toStringAsFixed(0),
                              textAlign: pw.TextAlign.center,
                              style:
                                  const pw.TextStyle(fontSize: 11))),
                      pw.SizedBox(
                          width: 60,
                          child: pw.Text(
                              item.total.toStringAsFixed(0),
                              textAlign: pw.TextAlign.right,
                              style: pw.TextStyle(
                                  fontSize: 11,
                                  fontWeight: pw.FontWeight.bold))),
                    ],
                  ),
                );
              }),
              // Sub-total
              pw.Container(
                color: PdfColors.grey100,
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 8, vertical: 6),
                child: pw.Row(
                  children: [
                    pw.SizedBox(width: 24),
                    pw.Expanded(
                        flex: 3,
                        child: pw.Text('Sub-total Amount',
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 10))),
                    pw.SizedBox(
                        width: 60,
                        child: pw.Text(
                            bill.items
                                .fold(0.0,
                                    (s, i) => s + i.quantity)
                                .toStringAsFixed(0),
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 10))),
                    pw.SizedBox(width: 40),
                    pw.SizedBox(
                        width: 60,
                        child: pw.Text(
                            bill.subtotal.toStringAsFixed(0),
                            textAlign: pw.TextAlign.right,
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 10))),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),
              // Total
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Total Amount',
                          style: const pw.TextStyle(
                              fontSize: 13,
                              color: PdfColors.grey600)),
                      pw.Text(
                        bill.grandTotal.toStringAsFixed(0),
                        style: pw.TextStyle(
                            fontSize: 28,
                            fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        _amountInWords(bill.grandTotal),
                        style: const pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.grey600),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Divider(),
              pw.SizedBox(height: 6),
              pw.Center(
                child: pw.Text(
                  '~ THIS IS A DIGITALLY CREATED INVOICE ~',
                  style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey500,
                      letterSpacing: 0.5),
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text('AUTHORISED SIGNATURE',
                      style: const pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.grey600)),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Text('Thank you for the business.',
                  style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey700)),
              pw.SizedBox(height: 16),
              // Bottom bar
              pw.Container(
                width: double.infinity,
                height: 6,
                color: pdfColor,
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  Future<File> _savePdfToFile(dynamic profile) async {
    final bytes = await _generatePdfBytes(profile);
    final dir = await getTemporaryDirectory();
    final fileName =
        'invoice_${widget.bill.billNumber.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}.pdf';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);
    return file;
  }

  // ── Download Invoice ──────────────────────────────────────────────────────
  Future<void> _downloadInvoice(dynamic profile) async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);
    try {
      final file = await _savePdfToFile(profile);

      // Try to save to Downloads directory (Android)
      File? savedFile;
      if (Platform.isAndroid) {
        try {
          final downloadsDir = Directory('/storage/emulated/0/Download');
          if (await downloadsDir.exists()) {
            final fileName =
                'invoice_${widget.bill.billNumber.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}.pdf';
            savedFile = await file.copy('${downloadsDir.path}/$fileName');
          }
        } catch (_) {
          savedFile = file;
        }
      } else {
        // For iOS, use the temp file and open it
        savedFile = file;
      }

      if (mounted) {
        // Open the PDF so user can view/save it
        final result = await OpenFile.open(savedFile?.path ?? file.path);
        if (result.type != ResultType.done && mounted) {
          // Fallback: share the file
          await Share.shareXFiles(
            [XFile(file.path, mimeType: 'application/pdf')],
            subject:
                'Invoice ${widget.bill.billNumber}',
          );
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Invoice saved: ${savedFile?.path.split('/').last ?? file.path.split('/').last}'),
              action: SnackBarAction(
                label: 'OPEN',
                onPressed: () =>
                    OpenFile.open(savedFile?.path ?? file.path),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to download: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  // ── Share on WhatsApp ─────────────────────────────────────────────────────
  Future<void> _shareOnWhatsApp(dynamic profile) async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    try {
      final file = await _savePdfToFile(profile);

      // Try to open WhatsApp directly with the file
      final whatsappUri = Uri.parse('whatsapp://send');
      final canOpenWhatsApp = await canLaunchUrl(whatsappUri);

      if (canOpenWhatsApp) {
        // Share the PDF file — WhatsApp will be suggested
        await Share.shareXFiles(
          [XFile(file.path, mimeType: 'application/pdf')],
          subject: 'Invoice ${widget.bill.billNumber}',
          text:
              'Invoice ${widget.bill.billNumber} - Total: ₹${widget.bill.grandTotal.toStringAsFixed(0)}',
        );
      } else {
        // WhatsApp not installed, share via general share sheet
        await Share.shareXFiles(
          [XFile(file.path, mimeType: 'application/pdf')],
          subject: 'Invoice ${widget.bill.billNumber}',
          text:
              'Invoice ${widget.bill.billNumber} - Total: ₹${widget.bill.grandTotal.toStringAsFixed(0)}',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'WhatsApp not found. Use the share sheet to send.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  // ── Navigate to add a new bill ────────────────────────────────────────────
  void _createNew(BuildContext context) {
    // Pop back to BillPdfScreen, then pop again to BillDetailScreen,
    // then pop to HomeScreen bills tab — the cleanest UX is to pop
    // until we reach the route before BillDetailScreen.
    Navigator.of(context).popUntil((route) {
      return route.settings.name == '/' || route.isFirst;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = auth.profile;

    return Scaffold(
      backgroundColor: const Color(0xFFE0E0E0),
      appBar: AppBar(
        backgroundColor: _themeColor,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Invoice #${widget.bill.billNumber}',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 17),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.edit, color: Colors.white, size: 16),
            label: const Text('Edit',
                style: TextStyle(color: Colors.white, fontSize: 14)),
          ),
        ],
        elevation: 0,
      ),
      body: Column(
        children: [
          // ── Invoice Preview ───────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: _buildInvoicePreview(profile),
            ),
          ),

          // ── Format selector ───────────────────────────────────────────────
          Container(
            color: const Color(0xFFF5F5F5),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _FormatTab(
                  label: 'Premium',
                  isNew: true,
                  selected: _selectedFormat == 'Premium',
                  onTap: () => setState(() => _selectedFormat = 'Premium'),
                  activeColor: _themeColor,
                ),
                const SizedBox(width: 10),
                _FormatTab(
                  label: 'Thermal',
                  isNew: false,
                  selected: _selectedFormat == 'Thermal',
                  onTap: () => setState(() => _selectedFormat = 'Thermal'),
                  activeColor: _themeColor,
                ),
                const SizedBox(width: 10),
                _FormatTab(
                  label: 'Basic',
                  isNew: false,
                  selected: _selectedFormat == 'Basic',
                  onTap: () => setState(() => _selectedFormat = 'Basic'),
                  activeColor: _themeColor,
                ),
              ],
            ),
          ),

          // ── Action buttons ────────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(context).padding.bottom + 12,
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // THEME button — opens color picker
                    _ActionIcon(
                      icon: Icons.palette_outlined,
                      label: 'Theme',
                      color: _themeColor,
                      onTap: _openThemePicker,
                    ),
                    // DOWNLOAD INVOICE button
                    _isDownloading
                        ? _ActionIcon(
                            icon: Icons.hourglass_top,
                            label: 'Downloading...',
                            color: _themeColor,
                            onTap: () {},
                          )
                        : _ActionIcon(
                            icon: Icons.download_outlined,
                            label: 'Download\nInvoice',
                            color: _themeColor,
                            onTap: () => _downloadInvoice(profile),
                          ),
                    // SHARE ON WHATSAPP button
                    _isSharing
                        ? _ActionIcon(
                            icon: Icons.hourglass_top,
                            label: 'Sharing...',
                            color: const Color(0xFF25D366),
                            iconColor: const Color(0xFF25D366),
                            onTap: () {},
                          )
                        : _ActionIcon(
                            icon: Icons.chat_outlined,
                            label: 'Share on\nWhatsApp',
                            color: const Color(0xFF25D366),
                            iconColor: const Color(0xFF25D366),
                            onTap: () => _shareOnWhatsApp(profile),
                          ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    // CREATE NEW — goes back to bills screen to add new bill
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _createNew(context),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: _themeColor),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text('CREATE NEW',
                            style: TextStyle(
                                color: _themeColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                letterSpacing: 1)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _themeColor,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('DONE',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                letterSpacing: 1)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoicePreview(dynamic profile) {
    if (_selectedFormat == 'Premium') {
      return _buildPremiumInvoice(profile);
    } else if (_selectedFormat == 'Thermal') {
      return _buildThermalInvoice(profile);
    } else {
      return _buildBasicInvoice(profile);
    }
  }

  // ── PREMIUM invoice ───────────────────────────────────────────────────────
  Widget _buildPremiumInvoice(dynamic profile) {
    final businessName = profile?.businessName ?? 'My Business';
    final address = profile?.address ?? '';
    final phone = profile?.phone ?? '';
    final invoiceNo = widget.bill.billNumber
        .replaceAll(RegExp(r'[^0-9]'), '')
        .trim();
    final isPaid = widget.bill.isPaid;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
              width: double.infinity, height: 6, color: _themeColor),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _themeColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Center(
                        child: Text(
                          businessName.isNotEmpty
                              ? businessName[0].toUpperCase()
                              : 'M',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 18),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(businessName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: Color(0xFF212121))),
                          if (address.isNotEmpty)
                            Text(address,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF757575))),
                          if (phone.isNotEmpty)
                            Text('Phone: $phone',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF757575))),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Invoice No.$invoiceNo',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF212121))),
                        Text(
                            'Invoice Date: ${AppHelpers.formatDate(widget.bill.date)}',
                            style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF757575))),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border:
                              Border.all(color: const Color(0xFFE0E0E0)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Bill To',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF9E9E9E))),
                            Text(
                              widget.bill.partyName ?? '— —',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (isPaid) ...[
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: const Color(0xFF2E7D32),
                                  width: 2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Column(
                              children: [
                                const Text('THANK YOU',
                                    style: TextStyle(
                                        fontSize: 8,
                                        color: Color(0xFF2E7D32),
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1)),
                                const Text('PAID',
                                    style: TextStyle(
                                        fontSize: 18,
                                        color: Color(0xFF2E7D32),
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 2)),
                                const Icon(Icons.star,
                                    size: 10,
                                    color: Color(0xFF2E7D32)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text('Total amount',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF757575))),
                          Text(
                            widget.bill.grandTotal.toStringAsFixed(0),
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF212121)),
                          ),
                          Text(
                            _amountInWords(widget.bill.grandTotal),
                            style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF757575)),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  color: const Color(0xFFF5F5F5),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 6),
                  child: Row(
                    children: const [
                      SizedBox(
                          width: 24,
                          child: Text('#',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700))),
                      Expanded(
                          flex: 3,
                          child: Text('Item Details',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700))),
                      Expanded(
                          child: Text('Price/Unit',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700))),
                      SizedBox(
                          width: 40,
                          child: Text('Qty',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700))),
                      SizedBox(
                          width: 40,
                          child: Text('Rate',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700))),
                      SizedBox(
                          width: 48,
                          child: Text('Total',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700))),
                    ],
                  ),
                ),
                ...widget.bill.items.asMap().entries.map((e) {
                  final idx = e.key + 1;
                  final item = e.value;
                  return Container(
                    decoration: const BoxDecoration(
                      border: Border(
                          bottom: BorderSide(
                              color: Color(0xFFEEEEEE))),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 24,
                          child: Text(
                            idx.toString().padLeft(2, '0'),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(item.itemName,
                              style:
                                  const TextStyle(fontSize: 12)),
                        ),
                        Expanded(
                          child: Text(
                            '${item.rate.toStringAsFixed(0)}/PCS',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                        SizedBox(
                          width: 40,
                          child: Text(
                            item.quantity.toStringAsFixed(0),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        SizedBox(
                          width: 40,
                          child: Text(
                            item.rate.toStringAsFixed(0),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        SizedBox(
                          width: 48,
                          child: Text(
                            item.total.toStringAsFixed(0),
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                Container(
                  color: const Color(0xFFF5F5F5),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 6),
                  child: Row(
                    children: [
                      const SizedBox(width: 24),
                      const Expanded(
                          flex: 3,
                          child: Text('Sub-total Amount',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600))),
                      const Expanded(child: SizedBox()),
                      SizedBox(
                        width: 40,
                        child: Text(
                          widget.bill.items
                              .fold(0.0,
                                  (s, i) => s + i.quantity)
                              .toStringAsFixed(0),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      SizedBox(
                        width: 40,
                        child: Text(
                          widget.bill.subtotal.toStringAsFixed(0),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      SizedBox(
                        width: 48,
                        child: Text(
                          widget.bill.subtotal.toStringAsFixed(0),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Total amount',
                            style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF757575))),
                        Text(
                          widget.bill.grandTotal.toStringAsFixed(0),
                          style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF212121)),
                        ),
                        Text(
                          _amountInWords(widget.bill.grandTotal),
                          style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF757575)),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 6),
                const Center(
                  child: Text(
                    '~ THIS IS A DIGITALLY CREATED INVOICE ~',
                    style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFF9E9E9E),
                        letterSpacing: 0.5),
                  ),
                ),
                const SizedBox(height: 8),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('AUTHORISED SIGNATURE',
                        style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF757575))),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('Thank you for the business.',
                    style: TextStyle(
                        fontSize: 11, color: Color(0xFF424242))),
              ],
            ),
          ),
          Container(
              width: double.infinity, height: 6, color: _themeColor),
        ],
      ),
    );
  }

  // ── THERMAL invoice ───────────────────────────────────────────────────────
  Widget _buildThermalInvoice(dynamic profile) {
    final businessName = profile?.businessName ?? 'My Business';
    final address = profile?.address ?? '';
    final phone = profile?.phone ?? '';
    final invoiceNo = widget.bill.billNumber
        .replaceAll(RegExp(r'[^0-9]'), '')
        .trim();

    return Center(
      child: Container(
        width: 280,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: _themeColor, width: 2),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(businessName.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 14)),
              if (address.isNotEmpty)
                Text(address.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 10)),
              if (phone.isNotEmpty)
                Text('PHONE: $phone',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 10)),
              const Divider(thickness: 1),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('BILL TO',
                    style: TextStyle(
                        fontSize: 10, color: Color(0xFF757575))),
              ),
              Align(
                alignment: Alignment.center,
                child: Column(
                  children: [
                    Text(
                      '${_billTypeName(widget.bill.billType)}\nInvoice No.$invoiceNo',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11),
                    ),
                    Text(
                      'Invoice Date: ${AppHelpers.formatDate(widget.bill.date)}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
              const Divider(thickness: 1),
              Row(
                children: const [
                  Expanded(
                      flex: 3,
                      child: Text('Item',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700))),
                  Expanded(
                      child: Text('Qty',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700))),
                  Expanded(
                      child: Text('Amount',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700))),
                ],
              ),
              const Divider(thickness: 0.5),
              ...widget.bill.items.map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Expanded(
                            flex: 3,
                            child: Text(item.itemName,
                                style:
                                    const TextStyle(fontSize: 11))),
                        Expanded(
                            child: Text(
                                '${item.quantity.toStringAsFixed(item.quantity % 1 == 0 ? 0 : 1)}',
                                textAlign: TextAlign.center,
                                style:
                                    const TextStyle(fontSize: 11))),
                        Expanded(
                            child: Text(
                                '₹${item.total.toStringAsFixed(0)}',
                                textAlign: TextAlign.right,
                                style:
                                    const TextStyle(fontSize: 11))),
                      ],
                    ),
                  )),
              const Divider(thickness: 0.5),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Item Total',
                      style: TextStyle(fontSize: 11)),
                  Text(
                      '₹${widget.bill.subtotal.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 11)),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Net Amount',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                  Text(
                      '${widget.bill.grandTotal.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ],
              ),
              const Divider(thickness: 1),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('RECEIVED',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                  Text(
                      '₹${widget.bill.paidAmount.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Balance',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                  Text(widget.bill.balanceDue.toStringAsFixed(2),
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── BASIC invoice ─────────────────────────────────────────────────────────
  Widget _buildBasicInvoice(dynamic profile) {
    final businessName = profile?.businessName ?? 'My Business';
    final address = profile?.address ?? '';
    final phone = profile?.phone ?? '';
    final billTypeName = _billTypeName(widget.bill.billType);
    final invoiceNo = widget.bill.billNumber
        .replaceAll(RegExp(r'[^0-9]'), '')
        .trim();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _themeColor, width: 1.5),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(businessName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14)),
                      if (address.isNotEmpty)
                        Text(address,
                            style: const TextStyle(fontSize: 11)),
                      if (phone.isNotEmpty)
                        Text('Phone: $phone',
                            style: const TextStyle(fontSize: 11)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Invoice No. $invoiceNo',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                    Text(
                        'Invoice Date: ${AppHelpers.formatDate(widget.bill.date)}',
                        style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF757575))),
                    Text(
                      'Original • #$billTypeName no. $invoiceNo',
                      style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF9E9E9E)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: _themeColor.withValues(alpha: 0.3)),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('BILL TO',
                    style: TextStyle(
                        fontSize: 11, color: Color(0xFF9E9E9E))),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              color: const Color(0xFFF5F5F5),
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 6),
              child: Row(
                children: const [
                  SizedBox(
                      width: 30,
                      child: Text('S.No',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700))),
                  Expanded(
                      flex: 3,
                      child: Text('ITEMS',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700))),
                  SizedBox(
                      width: 50,
                      child: Text('QTY',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700))),
                  SizedBox(
                      width: 50,
                      child: Text('RATE',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700))),
                  SizedBox(
                      width: 36,
                      child: Text('DISC.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700))),
                  SizedBox(
                      width: 56,
                      child: Text('AMOUNT',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700))),
                ],
              ),
            ),
            ...widget.bill.items.asMap().entries.map((e) {
              final item = e.value;
              final idx = e.key + 1;
              return Container(
                decoration: const BoxDecoration(
                    border: Border(
                        bottom: BorderSide(
                            color: Color(0xFFEEEEEE)))),
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 7),
                child: Row(
                  children: [
                    SizedBox(
                        width: 30,
                        child: Text('$idx',
                            style: const TextStyle(fontSize: 11))),
                    Expanded(
                        flex: 3,
                        child: Text(item.itemName,
                            style: const TextStyle(fontSize: 11))),
                    SizedBox(
                        width: 50,
                        child: Text(
                            '${item.quantity.toStringAsFixed(1)} PCS',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 11))),
                    SizedBox(
                        width: 50,
                        child: Text(
                            item.rate.toStringAsFixed(2),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 11))),
                    SizedBox(
                        width: 36,
                        child: Text(
                            item.discount.toStringAsFixed(2),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 11))),
                    SizedBox(
                        width: 56,
                        child: Text(
                            item.total.toStringAsFixed(2),
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600))),
                  ],
                ),
              );
            }),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 6),
              decoration: const BoxDecoration(
                  border: Border(
                      bottom: BorderSide(
                          color: Color(0xFFE0E0E0)))),
              child: Row(
                children: [
                  const SizedBox(width: 30),
                  const Expanded(
                      flex: 3,
                      child: Text('Subtotal',
                          style: TextStyle(
                              fontSize: 11,
                              fontStyle: FontStyle.italic))),
                  SizedBox(
                      width: 50,
                      child: Text('-',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 11))),
                  const SizedBox(width: 50),
                  const SizedBox(width: 36),
                  SizedBox(
                      width: 56,
                      child: Text(
                          widget.bill.subtotal.toStringAsFixed(2),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              fontSize: 11,
                              fontStyle: FontStyle.italic))),
                ],
              ),
            ),
            _buildBasicTotalRow('Round Off', '-'),
            _buildBasicTotalRow(
                'TOTAL',
                widget.bill.grandTotal.toStringAsFixed(2),
                bold: true),
            _buildBasicTotalRow('RECEIVED AMOUNT',
                widget.bill.paidAmount.toStringAsFixed(2)),
            _buildBasicTotalRow('INVOICE BALANCE',
                widget.bill.balanceDue.toStringAsFixed(2)),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  border: Border.all(
                      color:
                          _themeColor.withValues(alpha: 0.3))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('TOTAL AMOUNT IN WORDS',
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5)),
                  const SizedBox(height: 3),
                  Text(_amountInWords(widget.bill.grandTotal),
                      style: const TextStyle(fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicTotalRow(String label, String value,
      {bool bold = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: const BoxDecoration(
          border: Border(
              bottom: BorderSide(color: Color(0xFFEEEEEE)))),
      child: Row(
        children: [
          const SizedBox(width: 30),
          Expanded(
            flex: 3,
            child: Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight:
                        bold ? FontWeight.w700 : FontWeight.normal)),
          ),
          const SizedBox(width: 50),
          const SizedBox(width: 50),
          const SizedBox(width: 36),
          SizedBox(
            width: 56,
            child: Text(value,
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight:
                        bold ? FontWeight.w700 : FontWeight.normal)),
          ),
        ],
      ),
    );
  }

  String _billTypeName(BillType type) {
    switch (type) {
      case BillType.sale:
        return 'Sale Bill';
      case BillType.purchase:
        return 'Purchase Bill';
      case BillType.expense:
        return 'Expense';
      default:
        return 'Bill';
    }
  }

  String _amountInWords(double amount) {
    final int rupees = amount.toInt();
    final ones = [
      '',
      'One',
      'Two',
      'Three',
      'Four',
      'Five',
      'Six',
      'Seven',
      'Eight',
      'Nine',
      'Ten',
      'Eleven',
      'Twelve',
      'Thirteen',
      'Fourteen',
      'Fifteen',
      'Sixteen',
      'Seventeen',
      'Eighteen',
      'Nineteen'
    ];
    final tens = [
      '',
      '',
      'Twenty',
      'Thirty',
      'Forty',
      'Fifty',
      'Sixty',
      'Seventy',
      'Eighty',
      'Ninety'
    ];

    if (rupees == 0) return 'Zero rupees only';

    String words = '';
    if (rupees >= 10000000) {
      words +=
          '${_convertHundreds((rupees ~/ 10000000) % 100, ones, tens)} Crore ';
    }
    if (rupees >= 100000) {
      words +=
          '${_convertHundreds((rupees ~/ 100000) % 100, ones, tens)} Lakh ';
    }
    if (rupees >= 1000) {
      words +=
          '${_convertHundreds((rupees ~/ 1000) % 100, ones, tens)} Thousand ';
    }
    if (rupees >= 100) {
      words += '${ones[(rupees ~/ 100) % 10]} Hundred ';
    }
    words += _convertHundreds(rupees % 100, ones, tens);

    return '${words.trim()} rupees only';
  }

  String _convertHundreds(
      int n, List<String> ones, List<String> tens) {
    if (n == 0) return '';
    if (n < 20) return ones[n];
    return '${tens[n ~/ 10]}${n % 10 != 0 ? ' ${ones[n % 10]}' : ''}';
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// THEME PICKER SHEET
// ══════════════════════════════════════════════════════════════════════════════
class _ThemePickerSheet extends StatelessWidget {
  final Color currentColor;
  final void Function(Color) onColorSelected;

  const _ThemePickerSheet({
    required this.currentColor,
    required this.onColorSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Choose Theme Color',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF212121)),
          ),
          const SizedBox(height: 6),
          const Text(
            'The selected color will appear as the border and header color of the bill.',
            style: TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: _kThemeColors.map((theme) {
              final color = theme['color'] as Color;
              final name = theme['name'] as String;
              final isSelected = currentColor.value == color.value;
              return GestureDetector(
                onTap: () => onColorSelected(color),
                child: Column(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? Colors.black
                              : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color:
                                      color.withValues(alpha: 0.5),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : [],
                      ),
                      child: isSelected
                          ? const Icon(Icons.check,
                              color: Colors.white, size: 26)
                          : null,
                    ),
                    const SizedBox(height: 4),
                    Text(name,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.normal,
                            color: isSelected
                                ? color
                                : const Color(0xFF424242))),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ── PDF format tab ────────────────────────────────────────────────────────────
class _FormatTab extends StatelessWidget {
  final String label;
  final bool isNew;
  final bool selected;
  final VoidCallback onTap;
  final Color activeColor;

  const _FormatTab({
    required this.label,
    required this.isNew,
    required this.selected,
    required this.onTap,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected ? activeColor : const Color(0xFFE0E0E0),
                  width: selected ? 2 : 1,
                ),
              ),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? activeColor
                        : const Color(0xFF424242),
                  ),
                ),
              ),
            ),
            if (isNew)
              Positioned(
                top: -8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text('New',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Action icon ───────────────────────────────────────────────────────────────
class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color? iconColor;
  final VoidCallback onTap;

  const _ActionIcon({
    required this.icon,
    required this.label,
    required this.color,
    this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: (iconColor ?? color).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor ?? color, size: 22),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
                fontSize: 11,
                color: iconColor ?? color,
                fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}