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
import 'sales_report_screen.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/locale_provider.dart';
import '../l10n/app_localizations.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  int _billsInitialSubTab = 0;
  bool _fromMore = false;

  void _switchTab(int index, {int? billSubTab, bool fromMore = false}) {
    setState(() {
      _tab = index;
      _fromMore = fromMore;
      if (index == 1 && billSubTab != null) {
        _billsInitialSubTab = billSubTab;
      }
    });
  }

  void _goBackToMore() {
    setState(() {
      _tab = 3;
      _fromMore = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.l10n;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: IndexedStack(
        index: _tab,
        children: [
          PartiesScreen(
            fromMore: _tab == 0 && _fromMore,
            onBackToMore: _goBackToMore,
          ),
          _BillsScreen(
            key: ValueKey(
                'bills_${_billsInitialSubTab}_${_tab == 1 && _fromMore}'),
            initialSubTab: _billsInitialSubTab,
            fromMore: _tab == 1 && _fromMore,
            onGoToReports: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const ReportsScreen()),
              );
            },
            onBackToMore: _goBackToMore,
          ),
          ItemsScreen(
            fromMore: _tab == 2 && _fromMore,
            onBackToMore: _goBackToMore,
          ),
          MoreScreen(
            onNavigateToTab: (index) =>
                _switchTab(index, fromMore: true),
            onNavigateToTabWithSubTab: (index, {billSubTab}) =>
                _switchTab(index,
                    billSubTab: billSubTab, fromMore: true),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) => setState(() {
          _tab = i;
          _fromMore = false;
          if (i == 1) _billsInitialSubTab = 0;
        }),
        items: [
          BottomNavigationBarItem(
              icon: const Icon(Icons.people_outline),
              activeIcon: const Icon(Icons.people),
              label: loc.get('parties')),
          BottomNavigationBarItem(
              icon: const Icon(Icons.receipt_long_outlined),
              activeIcon: const Icon(Icons.receipt_long),
              label: loc.get('bills')),
          BottomNavigationBarItem(
              icon: const Icon(Icons.inventory_2_outlined),
              activeIcon: const Icon(Icons.inventory_2),
              label: loc.get('items')),
          BottomNavigationBarItem(
              icon: const Icon(Icons.more_horiz_outlined),
              activeIcon: const Icon(Icons.more_horiz),
              label: loc.get('more')),
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
  final VoidCallback? onBackToMore;
  final int initialSubTab;
  final bool fromMore;

  const _BillsScreen({
    super.key,
    required this.onGoToReports,
    this.onBackToMore,
    this.initialSubTab = 0,
    this.fromMore = false,
  });

  @override
  State<_BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends State<_BillsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _searchCtrl = TextEditingController();
  String _query = '';

  // ── BOOK SCOPING FIX: tracks which khatabook's bills/cashbook entries are
  // currently loaded. Previously this screen loaded bills/cashbook entries
  // with no bookId at all (which the data layer treats as "no filter — show
  // everything from every book combined"), and never re-checked whether the
  // active khatabook had changed while this screen stayed mounted. Mirrors
  // the pattern already applied to parties_screen.dart's tabs.
  String? _loadedForBookId;

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
      if (mounted) _loadForActiveBook();
    });
  }

  Future<void> _loadForActiveBook() async {
    final bookId = context.read<AuthProvider>().activeBookId;
    _loadedForBookId = bookId;
    await context.read<BillProvider>().loadBills(bookId: bookId);
    await context.read<CashbookProvider>().loadEntries(bookId: bookId);
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

  List<BillType> get _currentTabBillTypes {
    switch (_tabs.index) {
      case 1:
        return [BillType.purchase, BillType.purchaseReturn];
      case 2:
        return [BillType.expense];
      default:
        return [BillType.sale, BillType.saleReturn];
    }
  }

  String _addBillLabel(AppLocalizations loc) {
    switch (_tabs.index) {
      case 1:
        return loc.get('add_purchase_caps');
      case 2:
        return loc.get('add_expense_caps');
      default:
        return loc.get('add_bill_caps');
    }
  }

  IconData get _addBillIcon {
    switch (_tabs.index) {
      case 1:
        return Icons.shopping_cart_outlined;
      case 2:
        return Icons.payments_outlined;
      default:
        return Icons.receipt_long;
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
        MaterialPageRoute(
            builder: (_) => AddBillScreen(billType: type)),
      );
    }
    if (result == true && mounted) {
      // ── BOOK SCOPING FIX: reload scoped to the active book, not global.
      final bookId = context.read<AuthProvider>().activeBookId;
      context.read<BillProvider>().loadBills(bookId: bookId);
    }
  }

  Future<void> _openReturnFlow(BillType returnType) async {
    final loc = context.l10n;
    final billProvider = context.read<BillProvider>();
    final sourceType = returnType == BillType.saleReturn
        ? BillType.sale
        : BillType.purchase;
    final sourceBills = billProvider.bills
        .where((b) => b.billType == sourceType)
        .toList();

    if (sourceBills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            sourceType == BillType.sale
                ? loc.get('no_sale_bills_yet')
                : loc.get('no_purchase_bills_yet'),
          ),
        ),
      );
      return;
    }

    final selectedBill = await showModalBottomSheet<Bill>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SelectBillSheet(
        bills: sourceBills,
        title: sourceType == BillType.sale
            ? 'Select Sale Bill to Return'
            : 'Select Purchase Bill to Return',
      ),
    );

    if (selectedBill == null || !mounted) return;

    final targetTabIndex = returnType == BillType.saleReturn ? 0 : 1;
    if (_tabs.index != targetTabIndex) {
      _tabs.animateTo(targetTabIndex);
    }

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddReturnScreen(
          originalBill: selectedBill,
          returnType: returnType,
        ),
      ),
    );

    if (result == true && mounted) {
      // ── BOOK SCOPING FIX: reload scoped to the active book.
      final bookId = context.read<AuthProvider>().activeBookId;
      context.read<BillProvider>().loadBills(bookId: bookId);
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
          _openReturnFlow(type);
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

  String _searchHint(AppLocalizations loc) {
    switch (_tabs.index) {
      case 1:
        return loc.get('search_purchase_transactions');
      case 2:
        return loc.get('search_expense_transactions');
      default:
        return loc.get('search_sales_transactions');
    }
  }

  @override
  Widget build(BuildContext context) {
    // ── BOOK SCOPING FIX: re-checked on every rebuild. If the active
    // khatabook changed underneath this screen (switched via the switcher
    // sheet on the Parties tab while this screen stayed mounted in the
    // IndexedStack, or the widget tree rebuilt after an app resume with a
    // different book active), reload immediately instead of continuing to
    // show stale/combined data.
    final activeBookId = context.watch<AuthProvider>().activeBookId;
    if (_loadedForBookId != activeBookId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadForActiveBook();
      });
    }

    final loc = context.l10n;
    final billProvider = context.watch<BillProvider>();
    final cashbook = context.watch<CashbookProvider>();
    final auth = context.watch<AuthProvider>();

    final tabTypes = _currentTabBillTypes;
    final allTabBills = billProvider.bills
        .where((b) => tabTypes.contains(b.billType))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
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

    // FIX (overflow on rotation): the header + tab bar + search row + bottom
    // action bar are fixed-height widgets. In landscape the available screen
    // height can be smaller than their combined height, which previously
    // caused a "RenderFlex overflowed" error because the bill list sat in an
    // Expanded that could not shrink below zero. Wrapping everything in a
    // LayoutBuilder + SingleChildScrollView (with a ConstrainedBox that keeps
    // the original full-height look when content fits) makes the whole
    // screen scroll instead of overflowing when space is tight, while still
    // looking identical to before whenever it fits.
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: AppTheme.backgroundGrey,
      body: RefreshIndicator(
        // ── BOOK SCOPING FIX: pull-to-refresh must reload scoped to the
        // active book, not every book combined.
        onRefresh: () => context
            .read<BillProvider>()
            .loadBills(bookId: context.read<AuthProvider>().activeBookId),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  children: [
                    _BillsHeader(
                      businessName: auth.profile?.businessName ?? 'My Business',
                      businessAddress: auth.profile?.address ?? '',
                      monthlySales: billProvider.monthlySales,
                      monthlyPurchases: billProvider.monthlyPurchases,
                      todayIn: todayIn,
                      todayOut: todayOut,
                      fromMore: widget.fromMore,
                      onBackToMore: widget.onBackToMore,
                      onViewReports: widget.onGoToReports,
                      onCashbook: _openCashbook,
                      onSettings: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ProfileScreen()),
                      ),
                      onMonthlySalesTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SalesReportScreen(isSales: true)),
                      ),
                      onMonthlyPurchasesTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SalesReportScreen(isSales: false)),
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
                        tabs: [
                          Tab(text: loc.get('sale_tab_label')),
                          Tab(text: loc.get('purchase_tab_label')),
                          Tab(text: loc.get('expense_tab_label')),
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
                                hintText: _searchHint(loc),
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
                    billProvider.loading
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : filteredBills.isEmpty
                            ? _EmptyBills(
                                tabIndex: _tabs.index,
                                onAddBill: () => _openAddBill(_currentBillType),
                              )
                            : ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                padding: EdgeInsets.zero,
                                itemCount: filteredBills.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1, indent: 70),
                                itemBuilder: (_, i) =>
                                    _BillTile(bill: filteredBills[i]),
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
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(loc.get('more_caps'),
                                      style: const TextStyle(
                                        color: AppTheme.primaryColor,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                        letterSpacing: 1,
                                      )),
                                  Text(loc.get('payment_return_label'),
                                      style: const TextStyle(
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
                              icon: Icon(_addBillIcon, size: 18),
                              label: Text(
                                _addBillLabel(loc),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    letterSpacing: 1),
                              ),
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
              ),
            );
          },
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
  final bool fromMore;
  final VoidCallback? onBackToMore;
  final VoidCallback onViewReports;
  final VoidCallback onCashbook;
  final VoidCallback onSettings;
  final VoidCallback onMonthlySalesTap;
  final VoidCallback onMonthlyPurchasesTap;

  const _BillsHeader({
    required this.businessName,
    required this.businessAddress,
    required this.monthlySales,
    required this.monthlyPurchases,
    required this.todayIn,
    required this.todayOut,
    required this.fromMore,
    this.onBackToMore,
    required this.onViewReports,
    required this.onCashbook,
    required this.onSettings,
    required this.onMonthlySalesTap,
    required this.onMonthlyPurchasesTap,
  });

  @override
  Widget build(BuildContext context) {
    final loc = context.l10n;
    return Container(
      color: AppTheme.primaryColor,
      padding: EdgeInsets.fromLTRB(
          14, MediaQuery.of(context).padding.top + 8, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (fromMore) ...[
                GestureDetector(
                  onTap: onBackToMore,
                  child: const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(Icons.arrow_back,
                        color: Colors.white, size: 22),
                  ),
                ),
              ],
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
                    // FIX: removed the pencil (edit) icon that was shown
                    // next to the business name on this header.
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.settings_outlined,
                          color: Colors.white, size: 15),
                      const SizedBox(width: 4),
                      Text(loc.get('settings'),
                          style:
                              const TextStyle(color: Colors.white, fontSize: 12)),
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
                child: GestureDetector(
                  onTap: onMonthlySalesTap,
                  child: _StatBox(
                    amount: monthlySales,
                    label: loc.get('monthly_sales_label'),
                    amountColor: const Color(0xFF4ADE80),
                    hasChevron: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: onMonthlyPurchasesTap,
                  child: _StatBox(
                    amount: monthlyPurchases,
                    label: loc.get('monthly_purchases_label'),
                    amountColor: const Color(0xFFFCA5A5),
                    hasChevron: true,
                  ),
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
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(loc.get('view_reports_short'),
                              style: const TextStyle(
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                  letterSpacing: 0.3,
                                  height: 1.3),
                              textAlign: TextAlign.center),
                        ),
                        const Icon(Icons.chevron_right,
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
                      Text(loc.get('todays_in'),
                          style: const TextStyle(
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
                        Text(loc.get('todays_out'),
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFF9E9E9E))),
                      ],
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: onCashbook,
                  child: Row(
                    children: [
                      Text(loc.get('cashbook').toUpperCase(),
                          style: const TextStyle(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              letterSpacing: 0.5)),
                      const Icon(Icons.chevron_right,
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
  final bool hasChevron;

  const _StatBox({
    required this.amount,
    required this.label,
    required this.amountColor,
    this.hasChevron = false,
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

  String _typeLabel(AppLocalizations loc) {
    switch (bill.billType) {
      case BillType.sale:
        return loc.get('sale_bill');
      case BillType.purchase:
        return loc.get('purchase_bill');
      case BillType.expense:
        return loc.get('add_expense_title').contains('Expense') ||
                loc.get('add_expense_title').isNotEmpty
            ? loc.get('label_purchase') == 'Purchase'
                ? 'Expense'
                : loc.get('expense_tab_label')
            : 'Expense';
      case BillType.saleReturn:
        return loc.get('sale_return');
      case BillType.purchaseReturn:
        return loc.get('purchase_return');
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.l10n;
    final isPaid = bill.isPaid;
    final isPartial = !isPaid && bill.paidAmount > 0;

    final Color statusColor;
    final String statusLabel;
    if (isPaid) {
      statusColor = AppTheme.creditColor;
      statusLabel = loc.get('fully_paid');
    } else if (isPartial) {
      statusColor = const Color(0xFFF97316);
      statusLabel = loc.get('partial');
    } else {
      statusColor = AppTheme.debitColor;
      statusLabel = loc.get('unpaid');
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
                  Text(_typeLabel(loc),
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

// ══════════════════════════════════════════════════════════════════════════════
// SELECT BILL SHEET
// ══════════════════════════════════════════════════════════════════════════════
class _SelectBillSheet extends StatefulWidget {
  final List<Bill> bills;
  final String title;

  const _SelectBillSheet({required this.bills, required this.title});

  @override
  State<_SelectBillSheet> createState() => _SelectBillSheetState();
}

class _SelectBillSheetState extends State<_SelectBillSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _query.isEmpty
        ? widget.bills
        : widget.bills
            .where((b) =>
                b.billNumber
                    .toLowerCase()
                    .contains(_query.toLowerCase()) ||
                (b.partyName ?? '')
                    .toLowerCase()
                    .contains(_query.toLowerCase()))
            .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(widget.title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search bill number or party',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text('No bills found',
                        style: TextStyle(color: Colors.grey.shade500)),
                  )
                : ListView.separated(
                    controller: scrollCtrl,
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 16),
                    itemBuilder: (_, i) {
                      final bill = filtered[i];
                      return ListTile(
                        leading: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.receipt_long,
                              color: AppTheme.primaryColor, size: 20),
                        ),
                        title: Text(bill.billNumber,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14)),
                        subtitle: Text(
                          '${bill.partyName ?? 'No party'} • ${AppHelpers.formatDate(bill.date)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Text(
                          AppHelpers.formatCurrencyCompact(bill.grandTotal),
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        onTap: () => Navigator.pop(context, bill),
                      );
                    },
                  ),
          ),
        ],
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

  String _typeLabel(AppLocalizations loc) {
    switch (bill.billType) {
      case BillType.sale:
        return loc.get('sale_bill');
      case BillType.purchase:
        return loc.get('purchase_bill');
      case BillType.expense:
        return loc.get('expense_tab_label');
      case BillType.saleReturn:
        return loc.get('sale_return');
      case BillType.purchaseReturn:
        return loc.get('purchase_return');
    }
  }

  String _returnLabel(AppLocalizations loc) {
    switch (bill.billType) {
      case BillType.sale:
        return loc.get('sale_return').toUpperCase();
      case BillType.purchase:
        return loc.get('purchase_return').toUpperCase();
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
    final loc = context.l10n;
    final isPaid = bill.isPaid;
    final isPartial = !isPaid && bill.paidAmount > 0;

    final Color statusColor;
    final String statusLabel;
    if (isPaid) {
      statusColor = const Color(0xFF2E7D32);
      statusLabel = loc.get('fully_paid');
    } else if (isPartial) {
      statusColor = const Color(0xFFF97316);
      statusLabel = loc.get('partial');
    } else {
      statusColor = const Color(0xFFB71C1C);
      statusLabel = loc.get('unpaid');
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
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 17),
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
                            loc.getParams('created_on', {
                              'date': AppHelpers.formatDate(bill.createdAt),
                            }),
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
                        Text(loc.get('amount_paid'),
                            style: const TextStyle(
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
                      '+ ${_returnLabel(loc)}',
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
                          value:
                              '₹ ${bill.subtotal.toStringAsFixed(0)}'),
                      const SizedBox(height: 6),
                      _TotalRow(
                          label: 'Taxes',
                          value:
                              '₹ ${bill.taxTotal.toStringAsFixed(0)}'),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: OutlinedButton.icon(
            onPressed: () => _openViewPdf(context),
            icon: Icon(Icons.picture_as_pdf_outlined, color: _headerColor),
            label: Text(loc.get('view_pdf_caps'),
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

  void _openAddReturn(BuildContext context) async {
    final returnType = bill.billType == BillType.sale
        ? BillType.saleReturn
        : BillType.purchaseReturn;
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddReturnScreen(
          originalBill: bill,
          returnType: returnType,
        ),
      ),
    );
    if (result == true && context.mounted) {
      // ── BOOK SCOPING FIX: reload scoped to the active book.
      final bookId = context.read<AuthProvider>().activeBookId;
      context.read<BillProvider>().loadBills(bookId: bookId);
    }
  }

  void _openViewPdf(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            BillPdfScreen(bill: bill, headerColor: _headerColor),
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
            style:
                const TextStyle(fontSize: 13, color: Color(0xFF757575))),
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
    final loc = context.l10n;
    final titles = [
      loc.get('no_sale_bills_yet'),
      loc.get('no_purchase_bills_yet'),
      loc.get('no_expenses_yet'),
    ];
    final itemWords = [
      loc.get('sale_bill'),
      loc.get('purchase_bill'),
      loc.get('expense_tab_label'),
    ];
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
          Text(titles[tabIndex],
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF424242))),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              loc.getParams('tap_create_first',
                  {'item': itemWords[tabIndex].toLowerCase()}),
              style: const TextStyle(fontSize: 13, color: Color(0xFF9E9E9E)),
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
    final loc = context.l10n;
    final options = [
      (BillType.saleReturn, Icons.assignment_return_outlined,
          loc.get('sale_return'), 'Customer returned goods'),
      (BillType.purchaseReturn, Icons.keyboard_return_outlined,
          loc.get('purchase_return'), 'Return goods to supplier'),
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
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(16))),
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
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(16))),
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
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(16))),
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

      // ── BOOK SCOPING FIX: return bills must be numbered and stamped
      // against the currently active khatabook, exactly like regular
      // bills. Without this, return numbers and the return itself would
      // be computed/saved across every book combined.
      final bookId = context.read<AuthProvider>().activeBookId;

      final billNo = await billsProvider.nextBillNumber(
        widget.returnType,
        bookId: bookId,
      );
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
        bookId: bookId,
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
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 17),
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
                              Icon(Icons.edit, size: 14, color: _headerColor),
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
                                border: Border.all(color: _headerColor),
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
                                    fontSize: 13, color: Color(0xFF9E9E9E))),
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
              border:
                  Border(bottom: BorderSide(color: Color(0xFFE0E0E0))),
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
                    child: Text('No items found',
                        style: TextStyle(color: Colors.grey.shade500)),
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
                                      final qty =
                                          double.tryParse(
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
                                      final qty =
                                          double.tryParse(
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
                                  padding:
                                      const EdgeInsets.symmetric(
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
              border:
                  Border(top: BorderSide(color: Color(0xFFE0E0E0))),
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

// ── Additional Charges ────────────────────────────────────────────────────────
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
              children: const [
                Text('Additional Charges',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
                Text(
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
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 6),
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
              onTap: () => setState(
                  () => widget.charges.add(_AdditionalCharge())),
              child: const Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Icon(Icons.add,
                        color: AppTheme.primaryColor, size: 18),
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

// ── Add Discount Sheet ────────────────────────────────────────────────────────
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
            child: Text(
                'Enter the discount to be applied on this Sale',
                style:
                    TextStyle(fontSize: 13, color: Color(0xFF9E9E9E))),
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
        border:
            Border(bottom: BorderSide(color: Color(0xFFE0E0E0))),
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
                      decoration: BoxDecoration(
                          shape: BoxShape.circle, color: color),
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
                fontWeight: isSelected
                    ? FontWeight.w600
                    : FontWeight.normal),
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
      path.relativeQuadraticBezierTo(
          waveWidth / 2, -waveHeight, waveWidth, 0);
      path.relativeQuadraticBezierTo(
          waveWidth / 2, waveHeight, waveWidth, 0);
      x += waveWidth * 2;
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ══════════════════════════════════════════════════════════════════════════════
// BILL PDF SCREEN — with Premium / Thermal / Basic format tabs
// ══════════════════════════════════════════════════════════════════════════════
enum _InvoiceFormat { premium, thermal, basic }

class BillPdfScreen extends StatefulWidget {
  final Bill bill;
  final Color headerColor;

  const BillPdfScreen(
      {super.key, required this.bill, required this.headerColor});

  @override
  State<BillPdfScreen> createState() => _BillPdfScreenState();
}

class _BillPdfScreenState extends State<BillPdfScreen> {
  _InvoiceFormat _format = _InvoiceFormat.premium;
  late Color _themeColor;
  bool _isDownloading = false;
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    _themeColor = widget.headerColor;
  }

  // ── PDF amount — Rs. not ₹ (base-14 fonts lack the glyph) ─────────────────
  String _pdfAmt(num v) => 'Rs. ${v.toStringAsFixed(0)}';

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

  // ── Generate PDF bytes based on selected format ────────────────────────────
  Future<Uint8List> _generatePdfBytes(dynamic profile) async {
    switch (_format) {
      case _InvoiceFormat.thermal:
        return _buildThermalPdf(profile);
      case _InvoiceFormat.basic:
        return _buildBasicPdf(profile);
      case _InvoiceFormat.premium:
      default:
        return _buildPremiumPdf(profile);
    }
  }

  // ── PREMIUM format (full A4 — landscape table with logo) ───────────────────
  Future<Uint8List> _buildPremiumPdf(dynamic profile) async {
    final pdf = pw.Document();
    final businessName = profile?.businessName ?? 'My Business';
    final address = profile?.address ?? '';
    final phone = profile?.phone ?? '';
    final bill = widget.bill;
    final isPaid = bill.isPaid;
    final pdfColor = PdfColor(
      _themeColor.red / 255,
      _themeColor.green / 255,
      _themeColor.blue / 255,
    );
    const pdfGreen = PdfColor.fromInt(0xFF2E7D32);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Top colour bar
              pw.Container(
                  width: double.infinity, height: 6, color: pdfColor),
              pw.SizedBox(height: 16),
              // Business header + invoice info
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
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
                            fontSize: 20),
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
                                  fontSize: 10, color: PdfColors.grey700)),
                        if (phone.isNotEmpty)
                          pw.Text('Phone: $phone',
                              style: const pw.TextStyle(
                                  fontSize: 10, color: PdfColors.grey700)),
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
                              fontSize: 10, color: PdfColors.grey700)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 16),
              if (isPaid)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: pdfGreen, width: 2),
                          ),
                          child: pw.Column(
                            children: [
                              pw.Text('THANK YOU',
                                  style: pw.TextStyle(
                                      color: pdfGreen,
                                      fontSize: 8,
                                      fontWeight: pw.FontWeight.bold)),
                              pw.Text('PAID',
                                  style: pw.TextStyle(
                                      color: pdfGreen,
                                      fontSize: 20,
                                      fontWeight: pw.FontWeight.bold)),
                            ],
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text('Total: ${_pdfAmt(bill.grandTotal)}',
                            style: pw.TextStyle(
                                fontSize: 16,
                                fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              pw.SizedBox(height: 12),
              // Items table
              pw.Container(
                color: PdfColors.grey100,
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 8, vertical: 6),
                child: pw.Row(children: [
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
                      width: 70,
                      child: pw.Text('Total',
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 10))),
                ]),
              ),
              ...bill.items.asMap().entries.map((e) {
                final idx = e.key + 1;
                final item = e.value;
                return pw.Container(
                  decoration: const pw.BoxDecoration(
                      border: pw.Border(
                          bottom: pw.BorderSide(
                              color: PdfColors.grey200))),
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 8, vertical: 7),
                  child: pw.Row(children: [
                    pw.SizedBox(
                        width: 24,
                        child: pw.Text(
                            idx.toString().padLeft(2, '0'),
                            style: const pw.TextStyle(fontSize: 11))),
                    pw.Expanded(
                        flex: 3,
                        child: pw.Text(item.itemName,
                            style: const pw.TextStyle(fontSize: 11))),
                    pw.SizedBox(
                        width: 60,
                        child: pw.Text(
                            '${item.rate.toStringAsFixed(0)}/PCS',
                            textAlign: pw.TextAlign.center,
                            style: const pw.TextStyle(fontSize: 10))),
                    pw.SizedBox(
                        width: 40,
                        child: pw.Text(
                            item.quantity.toStringAsFixed(0),
                            textAlign: pw.TextAlign.center,
                            style: const pw.TextStyle(fontSize: 11))),
                    pw.SizedBox(
                        width: 70,
                        child: pw.Text(
                            item.total.toStringAsFixed(0),
                            textAlign: pw.TextAlign.right,
                            style: pw.TextStyle(
                                fontSize: 11,
                                fontWeight: pw.FontWeight.bold))),
                  ]),
                );
              }),
              pw.SizedBox(height: 12),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text('Total: ${_pdfAmt(bill.grandTotal)}',
                      style: pw.TextStyle(
                          fontSize: 18, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Divider(),
              pw.Center(
                child: pw.Text(
                  '~ THIS IS A DIGITALLY CREATED INVOICE ~',
                  style: const pw.TextStyle(
                      fontSize: 9, color: PdfColors.grey500),
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Container(
                  width: double.infinity, height: 6, color: pdfColor),
            ],
          );
        },
      ),
    );
    return pdf.save();
  }

  // ── THERMAL format (narrow 80mm receipt style) ─────────────────────────────
  Future<Uint8List> _buildThermalPdf(dynamic profile) async {
    final pdf = pw.Document();
    final businessName = profile?.businessName ?? 'My Business';
    final address = profile?.address ?? '';
    final phone = profile?.phone ?? '';
    final bill = widget.bill;

    // Use narrow page (80mm wide — standard thermal receipt)
    final thermalFormat = PdfPageFormat(
      80 * PdfPageFormat.mm,
      297 * PdfPageFormat.mm,
      marginAll: 4 * PdfPageFormat.mm,
    );

    pdf.addPage(
      pw.Page(
        pageFormat: thermalFormat,
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Business name centred
              pw.Text(businessName.toUpperCase(),
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 11),
                  textAlign: pw.TextAlign.center),
              if (address.isNotEmpty)
                pw.Text(address,
                    style: const pw.TextStyle(fontSize: 8),
                    textAlign: pw.TextAlign.center),
              if (phone.isNotEmpty)
                pw.Text('PHONE: $phone',
                    style: const pw.TextStyle(fontSize: 8),
                    textAlign: pw.TextAlign.center),
              pw.SizedBox(height: 6),
              pw.Divider(),
              pw.SizedBox(height: 4),
              // Bill info left-aligned
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text('BILL TO',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 8)),
              ),
              if (bill.partyName != null && bill.partyName!.isNotEmpty)
                pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Text(bill.partyName!,
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 9)),
                ),
              pw.SizedBox(height: 6),
              pw.Divider(),
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      bill.billNumber
                          .replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), ' ')
                          .trim(),
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                    pw.Text('Invoice Date: ${AppHelpers.formatDate(bill.date)}',
                        style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Divider(),
              // Column headers
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Item',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 8)),
                  pw.Text('Qty',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 8)),
                  pw.Text('Amount',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 8)),
                ],
              ),
              pw.Divider(),
              // Items
              ...bill.items.map((item) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 3),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Expanded(
                          child: pw.Text(item.itemName,
                              style: const pw.TextStyle(fontSize: 9)),
                        ),
                        pw.Text(
                            '${item.quantity.toStringAsFixed(item.quantity % 1 == 0 ? 0 : 1).padLeft(4)}',
                            style: const pw.TextStyle(fontSize: 9)),
                        pw.SizedBox(width: 6),
                        pw.Text(
                          'Rs.${item.total.toStringAsFixed(0)}',
                          style: const pw.TextStyle(fontSize: 9),
                          textAlign: pw.TextAlign.right,
                        ),
                      ],
                    ),
                  )),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Item Total',
                      style: const pw.TextStyle(fontSize: 9)),
                  pw.Text('Rs.${bill.subtotal.toStringAsFixed(0)}',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 9)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Net Amount',
                      style: const pw.TextStyle(fontSize: 9)),
                  pw.Text(bill.grandTotal.toStringAsFixed(0),
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 9)),
                ],
              ),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('RECEIVED',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 9)),
                  pw.Text('Rs.${bill.paidAmount.toStringAsFixed(0)}',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 9)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Balance',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 9)),
                  pw.Text(bill.balanceDue.toStringAsFixed(2),
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 9)),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Divider(),
              pw.Center(
                child: pw.Text('Thank you for your business!',
                    style: const pw.TextStyle(fontSize: 8),
                    textAlign: pw.TextAlign.center),
              ),
            ],
          );
        },
      ),
    );
    return pdf.save();
  }

  // ── BASIC format (simple A4 with table) ────────────────────────────────────
  Future<Uint8List> _buildBasicPdf(dynamic profile) async {
    final pdf = pw.Document();
    final businessName = profile?.businessName ?? 'My Business';
    final address = profile?.address ?? '';
    final phone = profile?.phone ?? '';
    final bill = widget.bill;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Simple text header
              pw.Text(businessName.toUpperCase(),
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 14)),
              if (address.isNotEmpty)
                pw.Text(address,
                    style: const pw.TextStyle(fontSize: 10)),
              if (phone.isNotEmpty)
                pw.Text('Phone: $phone',
                    style: const pw.TextStyle(fontSize: 10)),
              pw.Divider(),
              pw.SizedBox(height: 6),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('BILL TO',
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 10)),
                      if (bill.partyName != null &&
                          bill.partyName!.isNotEmpty)
                        pw.Text(bill.partyName!,
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 11)),
                      if (address.isNotEmpty)
                        pw.Text(address,
                            style: const pw.TextStyle(fontSize: 9)),
                      if (phone.isNotEmpty)
                        pw.Text('Phone: $phone',
                            style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(bill.billNumber
                          .replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), ' ')
                          .trim(),
                          style: const pw.TextStyle(fontSize: 10)),
                      pw.Text(
                          'Invoice No.${bill.billNumber.replaceAll(RegExp(r'[^0-9]'), '').trim()}',
                          style: const pw.TextStyle(fontSize: 10)),
                      pw.Text(
                          'Invoice Date: ${AppHelpers.formatDate(bill.date)}',
                          style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Divider(),
              // Table header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Item',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  pw.Text('Qty',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  pw.Text('Amount',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 10)),
                ],
              ),
              pw.Divider(),
              ...bill.items.map((item) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 5),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Expanded(
                          child: pw.Text(item.itemName,
                              style: const pw.TextStyle(fontSize: 11)),
                        ),
                        pw.Text(
                            '${item.quantity.toStringAsFixed(item.quantity % 1 == 0 ? 0 : 1)} PCS',
                            style: const pw.TextStyle(fontSize: 11)),
                        pw.SizedBox(width: 8),
                        pw.Text(
                            'Rs.${item.total.toStringAsFixed(0)}',
                            style: const pw.TextStyle(fontSize: 11)),
                      ],
                    ),
                  )),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('',
                      style: const pw.TextStyle(fontSize: 9)),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                          'Item Total  Rs.${bill.subtotal.toStringAsFixed(0)}',
                          style: const pw.TextStyle(fontSize: 10)),
                      pw.Text(
                          'Net Amount  ${bill.grandTotal.toStringAsFixed(0)}',
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 10)),
                    ],
                  ),
                ],
              ),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(''),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                          'RECEIVED  Rs.${bill.paidAmount.toStringAsFixed(0)}',
                          style: const pw.TextStyle(fontSize: 10)),
                      pw.Text(
                          'Balance  ${bill.balanceDue.toStringAsFixed(2)}',
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 10)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.Center(
                child: pw.Text(
                    '~ THIS IS A DIGITALLY CREATED INVOICE ~',
                    style: const pw.TextStyle(
                        fontSize: 9, color: PdfColors.grey600),
                    textAlign: pw.TextAlign.center),
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
    final suffix =
        _format.name; // 'premium' | 'thermal' | 'basic'
    final fileName =
        'invoice_${widget.bill.billNumber.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}_$suffix.pdf';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);
    return file;
  }

  Future<void> _downloadInvoice(dynamic profile) async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);
    try {
      final file = await _savePdfToFile(profile);
      if (mounted) {
        await Share.shareXFiles(
          [XFile(file.path, mimeType: 'application/pdf')],
          subject: 'Invoice ${widget.bill.billNumber}',
        );
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

  Future<void> _shareOnWhatsApp(dynamic profile) async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    try {
      final file = await _savePdfToFile(profile);
      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf')],
        subject: 'Invoice ${widget.bill.billNumber}',
        text:
            'Invoice ${widget.bill.billNumber} - Total: ${_pdfAmt(widget.bill.grandTotal)}',
      );
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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = auth.profile;

    return Scaffold(
      backgroundColor: const Color(0xFFE8E8E8),
      appBar: AppBar(
        backgroundColor: _themeColor,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Invoice #${widget.bill.billNumber}',
          style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 17),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.white),
            onPressed: () {},
            tooltip: 'Edit',
          ),
        ],
        elevation: 0,
      ),
      body: Column(
        children: [
          // ── Invoice preview ───────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              child: _buildPreview(profile),
            ),
          ),

          // ── Format selector: Premium / Thermal / Basic ─────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                _FormatTab(
                  label: 'Premium',
                  isNew: true,
                  selected: _format == _InvoiceFormat.premium,
                  onTap: () =>
                      setState(() => _format = _InvoiceFormat.premium),
                  activeColor: _themeColor,
                ),
                const SizedBox(width: 10),
                _FormatTab(
                  label: 'Thermal',
                  isNew: false,
                  selected: _format == _InvoiceFormat.thermal,
                  onTap: () =>
                      setState(() => _format = _InvoiceFormat.thermal),
                  activeColor: _themeColor,
                ),
                const SizedBox(width: 10),
                _FormatTab(
                  label: 'Basic',
                  isNew: false,
                  selected: _format == _InvoiceFormat.basic,
                  onTap: () =>
                      setState(() => _format = _InvoiceFormat.basic),
                  activeColor: _themeColor,
                ),
              ],
            ),
          ),

          // ── Action icons row ──────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Print only shown for Thermal (bluetooth printer)
                if (_format == _InvoiceFormat.thermal)
                  _ActionIcon(
                    icon: Icons.print_outlined,
                    label: 'Print',
                    color: _themeColor,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content:
                                Text('Bluetooth printing not available')),
                      );
                    },
                  ),
                _ActionIcon(
                  icon: Icons.palette_outlined,
                  label: 'Theme',
                  color: _themeColor,
                  onTap: _openThemePicker,
                ),
                _isDownloading
                    ? _ActionIcon(
                        icon: Icons.hourglass_top,
                        label: 'Saving...',
                        color: _themeColor,
                        onTap: () {},
                      )
                    : _ActionIcon(
                        icon: Icons.download_outlined,
                        label: 'Download\nInvoice',
                        color: _themeColor,
                        onTap: () => _downloadInvoice(profile),
                      ),
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
                        label: 'Share on\nWhatsapp',
                        color: const Color(0xFF25D366),
                        iconColor: const Color(0xFF25D366),
                        onTap: () => _shareOnWhatsApp(profile),
                      ),
              ],
            ),
          ),

          // ── Bottom buttons: CREATE NEW + DONE ─────────────────────────
          Container(
            color: Colors.white,
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 8,
              bottom: MediaQuery.of(context).padding.bottom + 12,
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      // Pop back to bills list so user can tap ADD BILL again
                      Navigator.of(context).popUntil(
                        (route) =>
                            route.isFirst ||
                            route.settings.name == '/bills',
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: _themeColor),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text('CREATE NEW',
                        style: TextStyle(
                            color: _themeColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 14)),
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
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('DONE',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── On-screen preview — switches based on selected format ──────────────────
  Widget _buildPreview(dynamic profile) {
    switch (_format) {
      case _InvoiceFormat.thermal:
        return _buildThermalPreview(profile);
      case _InvoiceFormat.basic:
        return _buildBasicPreview(profile);
      case _InvoiceFormat.premium:
      default:
        return _buildPremiumPreview(profile);
    }
  }

  // PREMIUM on-screen preview
  Widget _buildPremiumPreview(dynamic profile) {
    final businessName = profile?.businessName ?? 'My Business';
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
          Container(width: double.infinity, height: 6, color: _themeColor),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                          color: _themeColor,
                          borderRadius: BorderRadius.circular(4)),
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
                        child: Text(businessName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14))),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(widget.bill.billNumber,
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600)),
                        Text(AppHelpers.formatDate(widget.bill.date),
                            style: const TextStyle(
                                fontSize: 10, color: Color(0xFF757575))),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Table header
                Container(
                  color: Colors.grey.shade100,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 5),
                  child: const Row(
                    children: [
                      SizedBox(width: 20, child: Text('#', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700))),
                      Expanded(flex: 3, child: Text('Item Details', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700))),
                      SizedBox(width: 60, child: Text('Price/Unit', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700))),
                      SizedBox(width: 30, child: Text('Qty', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700))),
                      SizedBox(width: 60, child: Text('Total', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700))),
                    ],
                  ),
                ),
                ...widget.bill.items.asMap().entries.map((e) {
                  final item = e.value;
                  final idx = e.key + 1;
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 6),
                    child: Row(
                      children: [
                        SizedBox(
                            width: 20,
                            child: Text('${idx.toString().padLeft(2, '0')}',
                                style: const TextStyle(fontSize: 11))),
                        Expanded(
                            flex: 3,
                            child: Text(item.itemName,
                                style: const TextStyle(fontSize: 11))),
                        SizedBox(
                          width: 60,
                          child: Text(
                              '${item.rate.toStringAsFixed(0)}/PCS',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 10)),
                        ),
                        SizedBox(
                          width: 30,
                          child: Text(
                              item.quantity.toStringAsFixed(0),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 11)),
                        ),
                        SizedBox(
                          width: 60,
                          child: Text(
                              item.total.toStringAsFixed(0),
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  );
                }),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    Text(
                      '₹ ${widget.bill.grandTotal.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text('~ DIGITALLY CREATED INVOICE ~',
                      style:
                          TextStyle(fontSize: 10, color: Color(0xFF9E9E9E))),
                ),
              ],
            ),
          ),
          Container(width: double.infinity, height: 6, color: _themeColor),
        ],
      ),
    );
  }

  // THERMAL on-screen preview (narrow receipt style)
  Widget _buildThermalPreview(dynamic profile) {
    final businessName = profile?.businessName ?? 'My Business';
    final address = profile?.address ?? '';
    final phone = profile?.phone ?? '';
    final bill = widget.bill;

    return Center(
      child: Container(
        width: 260,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(2),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(businessName.toUpperCase(),
                style: const TextStyle(
                    fontWeight: FontWeight.w900, fontSize: 13),
                textAlign: TextAlign.center),
            if (address.isNotEmpty)
              Text(address,
                  style: const TextStyle(fontSize: 9),
                  textAlign: TextAlign.center),
            if (phone.isNotEmpty)
              Text('PHONE: $phone',
                  style: const TextStyle(fontSize: 9),
                  textAlign: TextAlign.center),
            const SizedBox(height: 6),
            const Divider(height: 1),
            const SizedBox(height: 6),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('BILL TO',
                  style: TextStyle(
                      fontSize: 9, fontWeight: FontWeight.w700)),
            ),
            if (bill.partyName != null && bill.partyName!.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(bill.partyName!,
                    style: const TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w700)),
              ),
            const SizedBox(height: 4),
            Text(
              '${bill.billNumber}  Invoice No.${bill.billNumber.replaceAll(RegExp(r'[^0-9]'), '').trim()}',
              style: const TextStyle(fontSize: 8),
              textAlign: TextAlign.center,
            ),
            Text('Invoice Date: ${AppHelpers.formatDate(bill.date)}',
                style: const TextStyle(fontSize: 8),
                textAlign: TextAlign.center),
            const SizedBox(height: 4),
            const Divider(height: 1),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Item',
                    style: TextStyle(
                        fontSize: 9, fontWeight: FontWeight.w700)),
                Text('Qty',
                    style: TextStyle(
                        fontSize: 9, fontWeight: FontWeight.w700)),
                Text('Amount',
                    style: TextStyle(
                        fontSize: 9, fontWeight: FontWeight.w700)),
              ],
            ),
            const Divider(height: 1),
            ...bill.items.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                          child: Text(item.itemName,
                              style: const TextStyle(fontSize: 10))),
                      Text(
                          '${item.quantity.toStringAsFixed(item.quantity % 1 == 0 ? 0 : 1).padLeft(4)} PCS',
                          style: const TextStyle(fontSize: 9)),
                      const SizedBox(width: 4),
                      Text('₹${item.total.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 10)),
                    ],
                  ),
                )),
            const Divider(height: 1),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Item Total',
                    style: TextStyle(fontSize: 9)),
                Text('₹${bill.subtotal.toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w700)),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Net Amount',
                    style: TextStyle(fontSize: 9)),
                Text(bill.grandTotal.toStringAsFixed(0),
                    style: const TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w700)),
              ],
            ),
            const Divider(height: 1),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('RECEIVED',
                    style: TextStyle(
                        fontSize: 9, fontWeight: FontWeight.w700)),
                Text('₹${bill.paidAmount.toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w700)),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Balance',
                    style: TextStyle(
                        fontSize: 9, fontWeight: FontWeight.w700)),
                Text(bill.balanceDue.toStringAsFixed(2),
                    style: const TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 8),
            const Text('Thank you for your business!',
                style: TextStyle(fontSize: 8),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  // BASIC on-screen preview
  Widget _buildBasicPreview(dynamic profile) {
    final businessName = profile?.businessName ?? 'My Business';
    final address = profile?.address ?? '';
    final phone = profile?.phone ?? '';
    final bill = widget.bill;

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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Solid colour header bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            color: _themeColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(businessName.toUpperCase(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13)),
                if (address.isNotEmpty)
                  Text(address,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 9)),
                if (phone.isNotEmpty)
                  Text('PHONE: $phone',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 9)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('BILL TO',
                      style: TextStyle(
                          fontSize: 9, fontWeight: FontWeight.w700)),
                  if (bill.partyName != null &&
                      bill.partyName!.isNotEmpty)
                    Text(bill.partyName!,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 11)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(bill.billNumber
                      .replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), ' ')
                      .trim(),
                      style: const TextStyle(fontSize: 9)),
                  Text(
                      'Invoice No.${bill.billNumber.replaceAll(RegExp(r'[^0-9]'), '').trim()}',
                      style: const TextStyle(fontSize: 10)),
                  Text('Invoice Date: ${AppHelpers.formatDate(bill.date)}',
                      style: const TextStyle(fontSize: 9)),
                ],
              ),
            ],
          ),
          const Divider(height: 12),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                  flex: 3,
                  child: Text('Item',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 10))),
              Text('Qty',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 10)),
              SizedBox(width: 8),
              Text('Amount',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 10)),
            ],
          ),
          const Divider(height: 8),
          ...bill.items.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                        flex: 3,
                        child: Text(item.itemName,
                            style: const TextStyle(fontSize: 11))),
                    Text(
                        '${item.quantity.toStringAsFixed(item.quantity % 1 == 0 ? 0 : 1)} PCS',
                        style: const TextStyle(fontSize: 10)),
                    const SizedBox(width: 8),
                    Text('₹${item.total.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 11)),
                  ],
                ),
              )),
          const Divider(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Item Total  ₹${bill.subtotal.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 10)),
                Text('Net Amount  ${bill.grandTotal.toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 10)),
              ],
            ),
          ),
          const Divider(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('RECEIVED  ₹${bill.paidAmount.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 10)),
                Text('Balance  ${bill.balanceDue.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 10)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text('~ THIS IS A DIGITALLY CREATED INVOICE ~',
                style: TextStyle(fontSize: 9, color: Color(0xFF9E9E9E)),
                textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}

// ── Theme picker ──────────────────────────────────────────────────────────────
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

class _ThemePickerSheet extends StatelessWidget {
  final Color currentColor;
  final void Function(Color) onColorSelected;

  const _ThemePickerSheet(
      {required this.currentColor, required this.onColorSelected});

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
          const Text('Choose Theme Color',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: _kThemeColors.map((theme) {
              final color = theme['color'] as Color;
              final name = theme['name'] as String;
              final isSelected = currentColor.toARGB32() == color.toARGB32();
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
                          color: isSelected ? Colors.black : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white, size: 26)
                          : null,
                    ),
                    const SizedBox(height: 4),
                    Text(name,
                        style: TextStyle(
                            fontSize: 11,
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

// ── Format tab widget ─────────────────────────────────────────────────────────
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
                    color: selected ? activeColor : const Color(0xFF424242),
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