// lib/screens/parties_screen.dart
import 'package:flutter/material.dart';
import '../providers/providers.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/helpers.dart';
import '../widgets/widgets.dart';
import 'add_customer_screen.dart';
import 'add_party_screen.dart';
import 'customer_screen.dart';
import 'reports_screen.dart';
import 'collection_screen.dart';
import 'profile_screen.dart';

class PartiesScreen extends StatefulWidget {
  const PartiesScreen({super.key});

  @override
  State<PartiesScreen> createState() => _PartiesScreenState();
}

class _PartiesScreenState extends State<PartiesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _showEditBusinessSheet(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final nameCtrl =
        TextEditingController(text: auth.profile?.businessName ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Edit Business',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Business Name',
                  prefixIcon:
                      const Icon(Icons.store_outlined, size: 20),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                        color: AppTheme.primaryColor, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;
                    Navigator.pop(ctx);
                    await auth.updateBusiness({'name': name});
                    if (mounted) {
                      AppHelpers.showSuccessSnackBar(
                          context, 'Business name updated!');
                    }
                  },
                  child: const Text('Save Changes',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.person_outline,
                      color: AppTheme.primaryColor, size: 18),
                  label: const Text('Edit Full Profile',
                      style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.primaryColor),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ProfileScreen()),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
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
        backgroundColor: AppTheme.primaryColor,
        automaticallyImplyLeading: false,
        title: Consumer<AuthProvider>(
          builder: (_, auth, __) => Text(
            auth.profile?.businessName ?? 'My Business',
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 17),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined,
                color: Colors.white, size: 20),
            tooltip: 'Edit Business',
            onPressed: () => _showEditBusinessSheet(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              letterSpacing: 1),
          unselectedLabelStyle: const TextStyle(fontSize: 14),
          tabs: const [
            Tab(text: 'CUSTOMERS'),
            Tab(text: 'SUPPLIERS'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _CustomersTab(),
          _SuppliersTab(),
        ],
      ),
    );
  }
}

// ── Customers Tab ─────────────────────────────────────────────────────────────
class _CustomersTab extends StatefulWidget {
  const _CustomersTab();

  @override
  State<_CustomersTab> createState() => _CustomersTabState();
}

class _CustomersTabState extends State<_CustomersTab> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String _filter = 'all';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CustomerProvider>();
    final allCustomers = provider.customers
        .where((c) =>
            _query.isEmpty ||
            c.name.toLowerCase().contains(_query.toLowerCase()) ||
            (c.phone?.contains(_query) ?? false))
        .toList();

    final customers = allCustomers.where((c) {
      if (_filter == 'toGet') return c.balance > 0;
      if (_filter == 'toGive') return c.balance < 0;
      return true;
    }).toList();

    return Column(
      children: [
        // Summary cards
        Container(
          color: Colors.white,
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      label: 'You will give',
                      amount: provider.totalPayable,
                      color: const Color(0xFF00796B),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 50,
                    color: const Color(0xFFE0E0E0),
                    margin:
                        const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  Expanded(
                    child: _SummaryCard(
                      label: 'You will get',
                      amount: provider.totalReceivable,
                      color: const Color(0xFFB71C1C),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _OutlineButton(
                      icon: Icons.picture_as_pdf_outlined,
                      label: 'View Reports',
                      color: const Color(0xFF1565C0),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ReportsScreen()),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _OutlineButton(
                      icon: Icons.calendar_month_outlined,
                      label: 'Collection',
                      color: const Color(0xFF2E7D32),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const CollectionScreen()),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Search + filter chips
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: Column(
            children: [
              TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search customers...',
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
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _FilterChip(
                      label: 'All',
                      selected: _filter == 'all',
                      onTap: () => setState(() => _filter = 'all')),
                  const SizedBox(width: 8),
                  _FilterChip(
                      label: 'To Get',
                      selected: _filter == 'toGet',
                      onTap: () =>
                          setState(() => _filter = 'toGet')),
                  const SizedBox(width: 8),
                  _FilterChip(
                      label: 'To Give',
                      selected: _filter == 'toGive',
                      onTap: () =>
                          setState(() => _filter = 'toGive')),
                  const Spacer(),
                  Text(
                    '${customers.length} ${customers.length == 1 ? 'party' : 'parties'}',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF9E9E9E)),
                  ),
                ],
              ),
            ],
          ),
        ),

        const Divider(height: 1),

        Expanded(
          child: provider.loading
              ? const Center(child: CircularProgressIndicator())
              : customers.isEmpty
                  ? _CustomerEmptyState(
                      onAddCustomer: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                const AddCustomerScreen()),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () => context
                          .read<CustomerProvider>()
                          .loadCustomers(),
                      child: ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: customers.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, indent: 68),
                        itemBuilder: (_, i) =>
                            _CustomerTile(customer: customers[i]),
                      ),
                    ),
        ),
      ],
    );
  }
}

// ── Suppliers Tab ─────────────────────────────────────────────────────────────
class _SuppliersTab extends StatefulWidget {
  const _SuppliersTab();

  @override
  State<_SuppliersTab> createState() => _SuppliersTabState();
}

class _SuppliersTabState extends State<_SuppliersTab> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SupplierProvider>();
    final suppliers = provider.suppliers
        .where((s) =>
            _query.isEmpty ||
            s.name.toLowerCase().contains(_query.toLowerCase()) ||
            (s.phone?.contains(_query) ?? false))
        .toList();

    final toGet = suppliers.where((s) => s.balance > 0).toList();
    final toGive = suppliers.where((s) => s.balance < 0).toList();
    final totalToGet =
        toGet.fold(0.0, (sum, s) => sum + s.balance);
    final totalToGive =
        toGive.fold(0.0, (sum, s) => sum + s.balance.abs());

    return Column(
      children: [
        // Summary
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      label: 'You will give',
                      amount: totalToGive,
                      color: const Color(0xFF00796B),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 50,
                    color: const Color(0xFFE0E0E0),
                    margin:
                        const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  Expanded(
                    child: _SummaryCard(
                      label: 'You will get',
                      amount: totalToGet,
                      color: const Color(0xFFB71C1C),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _OutlineButton(
                icon: Icons.picture_as_pdf_outlined,
                label: 'View Reports',
                color: const Color(0xFF1565C0),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ReportsScreen()),
                ),
              ),
            ],
          ),
        ),

        // Search
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search suppliers...',
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
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        const Divider(height: 1),

        Expanded(
          child: provider.loading
              ? const Center(child: CircularProgressIndicator())
              : suppliers.isEmpty
                  ? _SupplierEmptyState(
                      onAddSupplier: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const AddPartyScreen(
                                isSupplier: true)),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () => context
                          .read<SupplierProvider>()
                          .loadSuppliers(),
                      child: ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: suppliers.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, indent: 68),
                        itemBuilder: (_, i) =>
                            _SupplierTile(supplier: suppliers[i]),
                      ),
                    ),
        ),
      ],
    );
  }
}

// ── Supplier Tile ─────────────────────────────────────────────────────────────
class _SupplierTile extends StatelessWidget {
  final Supplier supplier;
  const _SupplierTile({required this.supplier});

  @override
  Widget build(BuildContext context) {
    final balance = supplier.balance;
    final hasBalance = balance != 0;
    final color = balance > 0
        ? const Color(0xFF00796B)
        : balance < 0
            ? const Color(0xFFB71C1C)
            : const Color(0xFF9E9E9E);
    final label = balance > 0
        ? 'You will get'
        : balance < 0
            ? 'You will give'
            : 'Settled';

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => SupplierScreen(supplier: supplier)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppHelpers.getAvatarColor(supplier.name)
                    .withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  AppHelpers.initials(supplier.name),
                  style: TextStyle(
                    color: AppHelpers.getAvatarColor(supplier.name),
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(supplier.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: Color(0xFF212121))),
                  if (supplier.phone != null &&
                      supplier.phone!.isNotEmpty)
                    Text(supplier.phone!,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF9E9E9E))),
                  Text(AppHelpers.timeAgo(supplier.createdAt),
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFFBDBDBD))),
                ],
              ),
            ),
            if (hasBalance)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // FIX: formatCurrencyCompact already includes ₹, no prefix needed
                  Text(
                    AppHelpers.formatCurrencyCompact(balance.abs()),
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 15),
                  ),
                  Text(label,
                      style: TextStyle(
                          fontSize: 11,
                          color: color,
                          fontWeight: FontWeight.w500)),
                ],
              )
            else
              const Text('Settled',
                  style: TextStyle(
                      fontSize: 12, color: Color(0xFF9E9E9E))),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right,
                color: Color(0xFFBDBDBD), size: 18),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SUPPLIER SCREEN
// ══════════════════════════════════════════════════════════════════════════════
class SupplierScreen extends StatefulWidget {
  final Supplier supplier;
  const SupplierScreen({super.key, required this.supplier});

  @override
  State<SupplierScreen> createState() => _SupplierScreenState();
}

class _SupplierScreenState extends State<SupplierScreen> {
  late Supplier _supplier;
  List<CustomerTransaction> _transactions = [];
  bool _loading = true;

  String get _supplierId => widget.supplier.id;

  @override
  void initState() {
    super.initState();
    _supplier = widget.supplier;
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() => _loading = true);
    final list = await context
        .read<CustomerProvider>()
        .getTransactions(_supplierId);
    if (!mounted) return;
    setState(() {
      _transactions = list;
      _loading = false;
    });
  }

  Future<void> _showAddTransaction(bool isGave) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _SupplierTransactionSheet(
        supplierName: _supplier.name,
        isGave: isGave,
        onAdded: (tx) async {
          await context.read<CustomerProvider>().addTransaction(tx);
          if (!mounted) return;
          final double delta = tx.isGiven ? tx.amount : -tx.amount;
          final updated =
              _supplier.copyWith(balance: _supplier.balance + delta);
          await context.read<SupplierProvider>().updateSupplier(updated);
          if (!mounted) return;
          setState(() {
            _supplier = updated;
            _transactions.insert(0, tx);
          });
          AppHelpers.showSuccessSnackBar(context, 'Entry added');
        },
      ),
    );
  }

  void _deleteTransaction(String txId) async {
    final tx = _transactions.firstWhere(
      (t) => t.id == txId,
      orElse: () => CustomerTransaction(
          id: '',
          customerId: _supplierId,
          amount: 0,
          isGiven: false,
          date: DateTime.now()),
    );
    await context
        .read<CustomerProvider>()
        .deleteTransaction(txId, _supplierId);
    if (!mounted) return;
    if (tx.id.isNotEmpty) {
      final double delta = tx.isGiven ? -tx.amount : tx.amount;
      final updated =
          _supplier.copyWith(balance: _supplier.balance + delta);
      await context.read<SupplierProvider>().updateSupplier(updated);
      if (!mounted) return;
      setState(() {
        _supplier = updated;
        _transactions.removeWhere((t) => t.id == txId);
      });
    }
    if (!mounted) return;
    AppHelpers.showSuccessSnackBar(context, 'Entry deleted');
  }

  Future<void> _deleteSupplier() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Supplier'),
        content:
            Text('Delete ${_supplier.name} and all their transactions?'),
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
    if (confirmed == true && mounted) {
      await context
          .read<SupplierProvider>()
          .deleteSupplier(_supplier.id);
      if (!mounted) return;
      AppHelpers.showSuccessSnackBar(context, 'Supplier deleted');
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final balance = _supplier.balance;
    final balanceLabel = balance > 0
        ? 'You will get'
        : balance < 0
            ? 'You will give'
            : 'Settled';
    final balanceColor = balance > 0
        ? const Color(0xFF00796B)
        : balance < 0
            ? const Color(0xFFB71C1C)
            : Colors.grey;

    final grouped = <String, List<CustomerTransaction>>{};
    for (final tx in _transactions) {
      final key = AppHelpers.formatDate(tx.date);
      grouped.putIfAbsent(key, () => []).add(tx);
    }
    final dateKeys = grouped.keys.toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white.withValues(alpha: 0.3),
              child: Text(
                AppHelpers.initials(_supplier.name),
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(_supplier.name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15),
                            overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('Supplier',
                            style: TextStyle(
                                color: Colors.white, fontSize: 10)),
                      ),
                    ],
                  ),
                  const Text('View settings',
                      style: TextStyle(
                          color: Colors.white70, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call, color: Colors.white),
            onPressed: _supplier.phone != null ? () {} : null,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white),
            onPressed: _deleteSupplier,
          ),
        ],
      ),
      body: Column(
        children: [
          // Balance banner
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(balanceLabel,
                    style: TextStyle(
                        color: balanceColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 15)),
                // FIX: formatCurrencyCompact already includes ₹
                Text(
                  AppHelpers.formatCurrencyCompact(balance.abs()),
                  style: TextStyle(
                      color: balanceColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 18),
                ),
              ],
            ),
          ),
          // PDF Report shortcut
          Container(
            color: const Color(0xFFF5F5F5),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {},
                  child: const Row(
                    children: [
                      Icon(Icons.picture_as_pdf_outlined,
                          size: 18, color: Color(0xFF555555)),
                      SizedBox(width: 6),
                      Text('Report',
                          style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF555555),
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Transactions
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _transactions.isEmpty
                    ? EmptyState(
                        title: 'No transactions yet',
                        subtitle:
                            'Add a payment or entry to get started',
                        icon: Icons.receipt_long_outlined,
                        actionLabel: 'Add Entry',
                        onAction: () => _showAddTransaction(true),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadTransactions,
                        child: ListView.builder(
                          padding: const EdgeInsets.only(bottom: 16),
                          itemCount: dateKeys.length,
                          itemBuilder: (_, di) {
                            final dateKey = dateKeys[di];
                            final txs = grouped[dateKey]!;
                            return Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.center,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius:
                                          BorderRadius.circular(20),
                                      border: Border.all(
                                          color: const Color(
                                              0xFFDDDDDD)),
                                    ),
                                    child: Text(
                                      '$dateKey${_isToday(txs.first.date) ? " • Today" : ""}',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF555555)),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 4),
                                  child: Row(
                                    children: const [
                                      Expanded(
                                        flex: 3,
                                        child: Text('ENTRIES',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF9E9E9E),
                                                fontWeight:
                                                    FontWeight.w600,
                                                letterSpacing: 0.5)),
                                      ),
                                      Expanded(
                                        child: Text('YOU GAVE',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF9E9E9E),
                                                fontWeight:
                                                    FontWeight.w600,
                                                letterSpacing: 0.5)),
                                      ),
                                      Expanded(
                                        child: Text('YOU GOT',
                                            textAlign: TextAlign.end,
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF9E9E9E),
                                                fontWeight:
                                                    FontWeight.w600,
                                                letterSpacing: 0.5)),
                                      ),
                                    ],
                                  ),
                                ),
                                ...txs.map((tx) => _SupplierTxRow(
                                    tx: tx,
                                    onDelete: () =>
                                        _deleteTransaction(tx.id))),
                              ],
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD32F2F),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _showAddTransaction(true),
                  child: const Text('YOU GAVE  ₹',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          letterSpacing: 0.5)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B5E20),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _showAddTransaction(false),
                  child: const Text('YOU GOT  ₹',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          letterSpacing: 0.5)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isToday(DateTime dt) {
    final now = DateTime.now();
    return dt.year == now.year &&
        dt.month == now.month &&
        dt.day == now.day;
  }
}

// ── Supplier Transaction Row ──────────────────────────────────────────────────
class _SupplierTxRow extends StatelessWidget {
  final CustomerTransaction tx;
  final VoidCallback onDelete;

  const _SupplierTxRow({required this.tx, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isGave = tx.isGiven;
    final color =
        isGave ? const Color(0xFFB71C1C) : const Color(0xFF1B5E20);
    final bgColor =
        isGave ? const Color(0xFFFFF0F0) : const Color(0xFFF0FFF4);

    return GestureDetector(
      onLongPress: () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Entry'),
            content:
                const Text('Are you sure you want to delete this entry?'),
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
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isGave ? const Color(0xFFFFF8F8) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: isGave
                  ? const Color(0xFFFFCDD2)
                  : const Color(0xFFE8F5E9)),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${AppHelpers.formatDate(tx.date)}  •  ${_timeStr(tx.date)}',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF555555)),
                  ),
                  if (tx.note != null && tx.note!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(tx.note!,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF757575))),
                  ],
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(4),
                      border:
                          Border.all(color: color.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      tx.paymentMode.toUpperCase(),
                      style: TextStyle(fontSize: 10, color: color),
                    ),
                  ),
                ],
              ),
            ),
            // YOU GAVE column
            Expanded(
              child: isGave
                  ? Text(
                      // FIX: formatCurrencyCompact already includes ₹
                      AppHelpers.formatCurrencyCompact(tx.amount),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Color(0xFFB71C1C),
                          fontWeight: FontWeight.w700,
                          fontSize: 14),
                    )
                  : const SizedBox(),
            ),
            // YOU GOT column
            Expanded(
              child: !isGave
                  ? Text(
                      // FIX: formatCurrencyCompact already includes ₹
                      AppHelpers.formatCurrencyCompact(tx.amount),
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                          color: Color(0xFF1B5E20),
                          fontWeight: FontWeight.w700,
                          fontSize: 14),
                    )
                  : const SizedBox(),
            ),
          ],
        ),
      ),
    );
  }

  String _timeStr(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }
}

// ── Supplier Transaction Sheet ────────────────────────────────────────────────
class _SupplierTransactionSheet extends StatefulWidget {
  final String supplierName;
  final bool isGave;
  final void Function(CustomerTransaction) onAdded;

  const _SupplierTransactionSheet({
    required this.supplierName,
    required this.isGave,
    required this.onAdded,
  });

  @override
  State<_SupplierTransactionSheet> createState() =>
      _SupplierTransactionSheetState();
}

class _SupplierTransactionSheetState
    extends State<_SupplierTransactionSheet> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String _paymentMode = 'cash';

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      AppHelpers.showErrorSnackBar(context, 'Enter a valid amount');
      return;
    }
    final tx = CustomerTransaction(
      id: AppHelpers.generateId(),
      customerId: '',
      amount: amount,
      isGiven: widget.isGave,
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      paymentMode: _paymentMode,
      date: DateTime.now(),
    );
    Navigator.pop(context);
    widget.onAdded(tx);
  }

  @override
  Widget build(BuildContext context) {
    final isGave = widget.isGave;
    final color = isGave
        ? const Color(0xFFD32F2F)
        : const Color(0xFF1B5E20);
    final label = isGave ? 'YOU GAVE' : 'YOU GOT';

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 8,
              height: 30,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 10),
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
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              prefixText: '₹ ',
              prefixStyle: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w700, color: color),
              hintText: '0',
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
            controller: _noteCtrl,
            decoration: const InputDecoration(
              labelText: 'Note / Remarks (optional)',
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
              style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              onPressed: _submit,
              child: Text('Save $label Entry',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Shared Widgets ────────────────────────────────────────────────────────────

/// FIX: _SummaryCard now uses formatCurrencyCompact directly (no extra ₹ prefix)
/// because formatCurrencyCompact already returns strings like "₹400", "₹1.2K" etc.
class _SummaryCard extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;

  const _SummaryCard(
      {required this.label, required this.amount, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style:
                const TextStyle(fontSize: 12, color: Color(0xFF757575))),
        const SizedBox(height: 4),
        Text(
          // FIX: was '₹${AppHelpers.formatCurrencyCompact(amount)}'
          // which caused double ₹ since formatCurrencyCompact already includes ₹
          AppHelpers.formatCurrencyCompact(amount),
          style: TextStyle(
              color: color, fontSize: 20, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _OutlineButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _OutlineButton(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 1.5),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip(
      {required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected
                  ? AppTheme.primaryColor
                  : const Color(0xFFDDDDDD)),
        ),
        child: Text(
          label,
          style: TextStyle(
              fontSize: 13,
              fontWeight:
                  selected ? FontWeight.w600 : FontWeight.w400,
              color:
                  selected ? Colors.white : const Color(0xFF616161)),
        ),
      ),
    );
  }
}

// ── Customer Tile ─────────────────────────────────────────────────────────────
class _CustomerTile extends StatelessWidget {
  final Customer customer;
  const _CustomerTile({required this.customer});

  @override
  Widget build(BuildContext context) {
    final balance = customer.balance;
    final hasBalance = balance != 0;
    final color = balance > 0
        ? const Color(0xFF00796B)
        : balance < 0
            ? const Color(0xFFB71C1C)
            : Colors.grey;
    final label = balance > 0 ? 'Will Give' : 'Will Get';

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => CustomerScreen(customer: customer)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppHelpers.getAvatarColor(customer.name)
                    .withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  AppHelpers.initials(customer.name),
                  style: TextStyle(
                      color: AppHelpers.getAvatarColor(customer.name),
                      fontWeight: FontWeight.w700,
                      fontSize: 15),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(customer.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: Color(0xFF212121))),
                  if (customer.phone != null)
                    Text(customer.phone!,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF9E9E9E))),
                ],
              ),
            ),
            if (hasBalance)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // FIX: formatCurrencyCompact already includes ₹
                  Text(
                    AppHelpers.formatCurrencyCompact(balance.abs()),
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 15),
                  ),
                  Text(label,
                      style: TextStyle(fontSize: 11, color: color)),
                ],
              )
            else
              const Text('Settled',
                  style: TextStyle(
                      fontSize: 12, color: Color(0xFF9E9E9E))),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right,
                color: Color(0xFFBDBDBD), size: 18),
          ],
        ),
      ),
    );
  }
}

// ── Empty States ──────────────────────────────────────────────────────────────
class _CustomerEmptyState extends StatelessWidget {
  final VoidCallback onAddCustomer;
  const _CustomerEmptyState({required this.onAddCustomer});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 180,
                  height: 140,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_alt_outlined,
                          size: 60, color: Colors.grey.shade400),
                      const SizedBox(height: 8),
                      Text('Collect payments faster',
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'Add customers & maintain your Khata',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF424242)),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 12),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_forward,
                      color: Color(0xFF1565C0)),
                  onPressed: () {},
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: onAddCustomer,
                  icon: const Icon(Icons.person_add, size: 18),
                  label: const Text('ADD CUSTOMER',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SupplierEmptyState extends StatelessWidget {
  final VoidCallback onAddSupplier;
  const _SupplierEmptyState({required this.onAddSupplier});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.local_shipping_outlined,
                      size: 36,
                      color:
                          AppTheme.primaryColor.withValues(alpha: 0.5)),
                ),
                const SizedBox(height: 16),
                const Text('No suppliers yet',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF424242))),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40),
                  child: Text('Add your suppliers to track payables',
                      style: TextStyle(
                          fontSize: 13, color: Color(0xFF9E9E9E)),
                      textAlign: TextAlign.center),
                ),
              ],
            ),
          ),
        ),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 12),
          child: SafeArea(
            top: false,
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onAddSupplier,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('ADD SUPPLIER',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24)),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}