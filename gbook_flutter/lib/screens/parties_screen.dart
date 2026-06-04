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
      appBar: AppBar(
        title: const Text('Parties'),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'Customers'),
            Tab(text: 'Suppliers'),
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

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CustomerProvider>();
    final customers = provider.customers
        .where((c) =>
            _query.isEmpty ||
            c.name.toLowerCase().contains(_query.toLowerCase()) ||
            (c.phone?.contains(_query) ?? false))
        .toList();

    return Column(
      children: [
        // Summary row
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: SummaryCard(
                  label: 'You Will Get',
                  amount: provider.totalReceivable,
                  color: AppTheme.creditColor,
                  icon: Icons.arrow_downward,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SummaryCard(
                  label: 'You Will Give',
                  amount: provider.totalPayable,
                  color: AppTheme.debitColor,
                  icon: Icons.arrow_upward,
                ),
              ),
            ],
          ),
        ),
        // Search
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search customers...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      })
                  : null,
              isDense: true,
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        // List
        Expanded(
          child: provider.loading
              ? const Center(child: CircularProgressIndicator())
              : customers.isEmpty
                  ? EmptyState(
                      title: _query.isNotEmpty
                          ? 'No customers match "$_query"'
                          : 'No customers yet',
                      subtitle: _query.isEmpty
                          ? 'Add your first customer to start tracking'
                          : '',
                      icon: Icons.people_outline,
                      actionLabel:
                          _query.isEmpty ? 'Add Customer' : null,
                      onAction: _query.isEmpty
                          ? () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const AddCustomerScreen()),
                              )
                          : null,
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      itemCount: customers.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, indent: 68),
                      itemBuilder: (_, i) =>
                          _CustomerTile(customer: customers[i]),
                    ),
        ),
      ],
    );
  }
}

class _CustomerTile extends StatelessWidget {
  final Customer customer;
  const _CustomerTile({required this.customer});

  @override
  Widget build(BuildContext context) {
    final balance = customer.balance;
    final hasBalance = balance != 0;
    final color =
        balance >= 0 ? AppTheme.creditColor : AppTheme.debitColor;
    final label = balance >= 0 ? 'Will Give' : 'Will Get';

    return ListTile(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => CustomerScreen(customer: customer)),
      ),
      leading: CircleAvatar(
        backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
        child: Text(
          AppHelpers.initials(customer.name),
          style: TextStyle(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.w700,
              fontSize: 14),
        ),
      ),
      title: Text(customer.name,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: customer.phone != null
          ? Text(customer.phone!,
              style: const TextStyle(fontSize: 12))
          : null,
      trailing: hasBalance
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(AppHelpers.formatCurrency(balance.abs()),
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
                Text(label,
                    style:
                        TextStyle(fontSize: 10, color: color)),
              ],
            )
          : const Text('Settled',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
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

    return Column(
      children: [
        // Summary
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(12),
          child: SummaryCard(
            label: 'Total Payable',
            amount: provider.totalPayable,
            color: AppTheme.debitColor,
            icon: Icons.arrow_upward,
          ),
        ),
        // Search
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search suppliers...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      })
                  : null,
              isDense: true,
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        // List
        Expanded(
          child: provider.loading
              ? const Center(child: CircularProgressIndicator())
              : suppliers.isEmpty
                  ? EmptyState(
                      title: _query.isNotEmpty
                          ? 'No suppliers match "$_query"'
                          : 'No suppliers yet',
                      subtitle: _query.isEmpty
                          ? 'Add your suppliers here'
                          : '',
                      icon: Icons.local_shipping_outlined,
                      actionLabel:
                          _query.isEmpty ? 'Add Supplier' : null,
                      onAction: _query.isEmpty
                          ? () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const AddPartyScreen(
                                            isSupplier: true)),
                              )
                          : null,
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      itemCount: suppliers.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, indent: 68),
                      itemBuilder: (_, i) =>
                          _SupplierTile(supplier: suppliers[i]),
                    ),
        ),
      ],
    );
  }
}

class _SupplierTile extends StatelessWidget {
  final Supplier supplier;
  const _SupplierTile({required this.supplier});

  @override
  Widget build(BuildContext context) {
    final balance = supplier.balance;
    final hasBalance = balance != 0;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor:
            AppTheme.primaryColor.withValues(alpha: 0.12),
        child: Text(
          AppHelpers.initials(supplier.name),
          style: TextStyle(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.w700,
              fontSize: 14),
        ),
      ),
      title: Text(supplier.name,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: supplier.phone != null
          ? Text(supplier.phone!,
              style: const TextStyle(fontSize: 12))
          : null,
      trailing: hasBalance
          ? Text(
              AppHelpers.formatCurrency(balance.abs()),
              style: TextStyle(
                  color: AppTheme.debitColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 13),
            )
          : const Text('Settled',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
    );
  }
}