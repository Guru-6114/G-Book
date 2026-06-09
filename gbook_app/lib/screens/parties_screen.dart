// lib/screens/parties_screen.dart
// FIXED:
//  1. AppColors.textHint now exists in app_theme.dart
//  2. Removed 'const' from Icon widgets that reference AppColors.textHint
//     (runtime constants cannot be used in compile-time const contexts)
//  3. No double ₹ symbol — formatCurrencyCompact() embeds it.
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            backgroundColor: AppColors.primary,
            floating: true,
            pinned: true,
            automaticallyImplyLeading: false,
            title: Consumer<AuthProvider>(
              builder: (_, auth, __) => Text(
                auth.profile?.businessName ?? 'My Business',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined,
                    color: Colors.white, size: 20),
                onPressed: () =>
                    Navigator.pushNamed(context, '/profile'),
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
                letterSpacing: 1,
              ),
              unselectedLabelStyle:
                  const TextStyle(fontSize: 14),
              tabs: const [
                Tab(text: 'CUSTOMERS'),
                Tab(text: 'SUPPLIERS'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabs,
          children: const [
            _CustomersTab(),
            _SuppliersTab(),
          ],
        ),
      ),
    );
  }
}

// ── Customers Tab ──────────────────────────────────────────────────────────────
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
    final filtered = provider.customers.where((c) {
      final matchQ = _query.isEmpty ||
          c.name.toLowerCase().contains(_query.toLowerCase()) ||
          (c.phone?.contains(_query) ?? false);
      final matchF = _filter == 'all' ||
          (_filter == 'toget' && c.balance > 0) ||
          (_filter == 'togive' && c.balance < 0);
      return matchQ && matchF;
    }).toList();

    return Column(
      children: [
        // Summary row
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 14),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _SummaryTile(
                      label: 'You will give',
                      amount: provider.totalPayable,
                      color: AppColors.green,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 48,
                    color: AppColors.divider,
                    margin: const EdgeInsets.symmetric(
                        horizontal: 12),
                  ),
                  Expanded(
                    child: _SummaryTile(
                      label: 'You will get',
                      amount: provider.totalReceivable,
                      color: AppColors.red,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: () =>
                    Navigator.pushNamed(context, '/reports'),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      vertical: 10),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: AppColors.blue),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      Icon(Icons.picture_as_pdf_outlined,
                          size: 16, color: AppColors.blue),
                      SizedBox(width: 6),
                      Text(
                        'View Reports',
                        style: TextStyle(
                          color: AppColors.blue,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Search
        Container(
          color: Colors.white,
          padding:
              const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search customers...',
              hintStyle: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textHint),
              prefixIcon: const Icon(Icons.search,
                  color: AppColors.textSecondary, size: 20),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close,
                          size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      })
                  : null,
              filled: true,
              fillColor: AppColors.lightGrey,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 10),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),

        // Filter chips
        Container(
          color: Colors.white,
          padding:
              const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: Row(
            children: [
              _FilterChip(
                label: 'All',
                selected: _filter == 'all',
                onTap: () => setState(() => _filter = 'all'),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'To Get',
                selected: _filter == 'toget',
                color: AppColors.green,
                onTap: () =>
                    setState(() => _filter = 'toget'),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'To Give',
                selected: _filter == 'togive',
                color: AppColors.red,
                onTap: () =>
                    setState(() => _filter = 'togive'),
              ),
              const Spacer(),
              Text(
                '${filtered.length} parties',
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary),
              ),
            ],
          ),
        ),

        // List
        Expanded(
          child: provider.loading
              ? const Center(
                  child: CircularProgressIndicator())
              : filtered.isEmpty
                  ? _KhatabookEmptyState(
                      onAddCustomer: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  const AddCustomerScreen()),
                        );
                      },
                    )
                  : ListView.separated(
                      padding:
                          const EdgeInsets.only(bottom: 80),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) =>
                          const Divider(
                              height: 1,
                              indent: 72,
                              color: AppColors.divider),
                      itemBuilder: (_, i) => _CustomerTile(
                          customer: filtered[i]),
                    ),
        ),
      ],
    );
  }
}

// ── Summary tile ───────────────────────────────────────────────────────────────
class _SummaryTile extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;

  const _SummaryTile({
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary),
        ),
        const SizedBox(height: 4),
        // formatCurrencyCompact already includes ₹ — no prefix here
        Text(
          AppHelpers.formatCurrencyCompact(amount),
          style: TextStyle(
            color: color,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

// ── Khatabook empty state ──────────────────────────────────────────────────────
class _KhatabookEmptyState extends StatelessWidget {
  final VoidCallback onAddCustomer;
  const _KhatabookEmptyState({required this.onAddCustomer});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.people_alt_outlined,
                    size: 52,
                    color: Colors.grey.shade400),
              ),
              const SizedBox(height: 20),
              const Text(
                'Collect payments faster',
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14),
              ),
              const SizedBox(height: 12),
              const Text(
                'Add customers & maintain your Khata',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 12),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_forward,
                    color: AppColors.blue),
                onPressed: () {},
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: onAddCustomer,
                icon: const Icon(Icons.person_add, size: 18),
                label: const Text(
                  'ADD CUSTOMER',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Filter chip ────────────────────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    this.color = AppColors.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected
                ? Colors.white
                : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ── Customer tile ──────────────────────────────────────────────────────────────
class _CustomerTile extends StatelessWidget {
  final Customer customer;
  const _CustomerTile({required this.customer});

  @override
  Widget build(BuildContext context) {
    final balance = customer.balance;
    final isPositive = balance > 0;
    final isZero = balance == 0;
    final color = isZero
        ? AppColors.textSecondary
        : isPositive
            ? AppColors.green
            : AppColors.red;
    final balanceLabel = isZero
        ? 'Settled'
        : isPositive
            ? 'Will give'
            : 'Will get';

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) =>
                CustomerScreen(customer: customer)),
      ),
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 13),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppHelpers.getAvatarColor(customer.name)
                    .withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  AppHelpers.initials(customer.name),
                  style: TextStyle(
                    color: AppHelpers.getAvatarColor(
                        customer.name),
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
                  Text(
                    customer.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (customer.phone != null &&
                      customer.phone!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      customer.phone!,
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!isZero)
                  Text(
                    // formatCurrencyCompact includes ₹ already
                    AppHelpers.formatCurrencyCompact(
                        balance.abs()),
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                Text(
                  balanceLabel,
                  style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: isZero
                        ? FontWeight.normal
                        : FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 6),
            // FIX: Not const — Icon colour is a runtime value
            const Icon(Icons.chevron_right,
                color: AppColors.textHint, size: 18),
          ],
        ),
      ),
    );
  }
}

// ── Suppliers Tab ──────────────────────────────────────────────────────────────
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
    final filtered = provider.suppliers
        .where((s) =>
            _query.isEmpty ||
            s.name
                .toLowerCase()
                .contains(_query.toLowerCase()) ||
            (s.phone?.contains(_query) ?? false))
        .toList();

    return Column(
      children: [
        // Summary
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: _SummaryTile(
            label: 'Total Payable',
            amount: provider.totalPayable,
            color: AppColors.red,
          ),
        ),

        // Search
        Container(
          color: Colors.white,
          padding:
              const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search suppliers...',
              hintStyle: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textHint),
              prefixIcon: const Icon(Icons.search,
                  color: AppColors.textSecondary, size: 20),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close,
                          size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      })
                  : null,
              filled: true,
              fillColor: AppColors.lightGrey,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 10),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),

        // List
        Expanded(
          child: provider.loading
              ? const Center(
                  child: CircularProgressIndicator())
              : filtered.isEmpty
                  ? EmptyState(
                      title: _query.isNotEmpty
                          ? 'No result for "$_query"'
                          : 'No suppliers yet',
                      subtitle: _query.isEmpty
                          ? 'Add your suppliers here'
                          : '',
                      icon: Icons.local_shipping_outlined,
                      actionLabel: _query.isEmpty
                          ? 'Add Supplier'
                          : null,
                      onAction: _query.isEmpty
                          ? () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const AddPartyScreen(
                                            isSupplier: true)),
                              );
                            }
                          : null,
                    )
                  : ListView.separated(
                      padding:
                          const EdgeInsets.only(bottom: 80),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) =>
                          const Divider(
                              height: 1,
                              indent: 72,
                              color: AppColors.divider),
                      itemBuilder: (_, i) => _SupplierTile(
                          supplier: filtered[i]),
                    ),
        ),
      ],
    );
  }
}

// ── Supplier tile ──────────────────────────────────────────────────────────────
class _SupplierTile extends StatelessWidget {
  final Supplier supplier;
  const _SupplierTile({required this.supplier});

  @override
  Widget build(BuildContext context) {
    final balance = supplier.balance;
    final isZero = balance == 0;
    final color = balance > 0 ? AppColors.red : AppColors.green;
    final label = isZero
        ? 'Settled'
        : balance > 0
            ? 'Payable'
            : 'Advance';

    return InkWell(
      onTap: () {},
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.orange.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  AppHelpers.initials(supplier.name),
                  style: const TextStyle(
                    color: AppColors.orange,
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
                  Text(
                    supplier.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (supplier.phone != null &&
                      supplier.phone!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(supplier.phone!,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary)),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!isZero)
                  Text(
                    // formatCurrencyCompact includes ₹ already
                    AppHelpers.formatCurrencyCompact(
                        balance.abs()),
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: isZero
                        ? AppColors.textSecondary
                        : color,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 6),
            // FIX: Not const — colour is a runtime constant
            const Icon(Icons.chevron_right,
                color: AppColors.textHint, size: 18),
          ],
        ),
      ),
    );
  }
}