// lib/screens/parties_screen.dart
// Matches Khatabook Customers/Suppliers UI (Image 1)
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
      backgroundColor: AppTheme.backgroundGrey,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        automaticallyImplyLeading: false,
        title: Consumer<AuthProvider>(
          builder: (_, auth, __) => Text(
            auth.profile?.businessName ?? 'My Business',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 17),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.white, size: 20),
            onPressed: () => Navigator.pushNamed(context, '/profile'),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(
              fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: 1),
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

// ── Customers Tab ──────────────────────────────────────────────────────────────
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
        // Summary cards - Khatabook style
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _KhatabookSummaryCard(
                      label: 'You will give',
                      amount: provider.totalPayable,
                      color: const Color(0xFF00796B), // teal/green
                      prefix: '₹',
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 50,
                    color: const Color(0xFFE0E0E0),
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  Expanded(
                    child: _KhatabookSummaryCard(
                      label: 'You will get',
                      amount: provider.totalReceivable,
                      color: const Color(0xFFB71C1C), // dark red
                      prefix: '₹',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // View Reports button
              InkWell(
                onTap: () => Navigator.pushNamed(context, '/reports'),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF1565C0)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.picture_as_pdf_outlined,
                          size: 16, color: Color(0xFF1565C0)),
                      SizedBox(width: 6),
                      Text(
                        'View Reports',
                        style: TextStyle(
                          color: Color(0xFF1565C0),
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

        // Search bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search customers...',
              hintStyle:
                  const TextStyle(fontSize: 13, color: Color(0xFFBDBDBD)),
              prefixIcon:
                  const Icon(Icons.search, size: 20, color: Color(0xFF9E9E9E)),
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
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),

        const Divider(height: 1),

        // List
        Expanded(
          child: provider.loading
              ? const Center(child: CircularProgressIndicator())
              : customers.isEmpty
                  ? _KhatabookEmptyState(
                      onAddCustomer: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const AddCustomerScreen()),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () =>
                          context.read<CustomerProvider>().loadCustomers(),
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

// ── Khatabook-style Summary Card ──────────────────────────────────────────────
class _KhatabookSummaryCard extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final String prefix;

  const _KhatabookSummaryCard({
    required this.label,
    required this.amount,
    required this.color,
    required this.prefix,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF757575)),
        ),
        const SizedBox(height: 4),
        Text(
          '$prefix ${AppHelpers.formatCurrencyCompact(amount)}',
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

// ── Khatabook-style Empty State ────────────────────────────────────────────────
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
              // Illustration placeholder
              Container(
                width: 200,
                height: 160,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.people_alt_outlined,
                        size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 8),
                    Text(
                      'Collect payments faster',
                      style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Add customers & maintain your Khata',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF424242),
                ),
              ),
            ],
          ),
        ),

        // Bottom action bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                label: const Text(
                  'ADD CUSTOMER',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentRed,
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

// ── Customer Tile ──────────────────────────────────────────────────────────────
class _CustomerTile extends StatelessWidget {
  final Customer customer;
  const _CustomerTile({required this.customer});

  @override
  Widget build(BuildContext context) {
    final balance = customer.balance;
    final hasBalance = balance != 0;
    // Khatabook: positive balance = green (you will get)
    // negative = red (you will give)
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar circle
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
                      color: Color(0xFF212121),
                    ),
                  ),
                  if (customer.phone != null)
                    Text(
                      customer.phone!,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF9E9E9E)),
                    ),
                ],
              ),
            ),
            if (hasBalance)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹ ${AppHelpers.formatCurrencyCompact(balance.abs())}',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(fontSize: 11, color: color),
                  ),
                ],
              )
            else
              const Text(
                'Settled',
                style: TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
              ),
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
    final suppliers = provider.suppliers
        .where((s) =>
            _query.isEmpty ||
            s.name.toLowerCase().contains(_query.toLowerCase()) ||
            (s.phone?.contains(_query) ?? false))
        .toList();

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(12),
          child: _KhatabookSummaryCard(
            label: 'Total Payable',
            amount: provider.totalPayable,
            color: const Color(0xFFB71C1C),
            prefix: '₹',
          ),
        ),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search suppliers...',
              prefixIcon:
                  const Icon(Icons.search, size: 20, color: Color(0xFF9E9E9E)),
              isDense: true,
              filled: true,
              fillColor: const Color(0xFFF5F5F5),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
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
                  ? EmptyState(
                      title: 'No suppliers yet',
                      subtitle: 'Add your suppliers here',
                      icon: Icons.local_shipping_outlined,
                      actionLabel: 'Add Supplier',
                      onAction: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                const AddPartyScreen(isSupplier: true)),
                      ),
                    )
                  : ListView.separated(
                      itemCount: suppliers.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, indent: 68),
                      itemBuilder: (_, i) {
                        final s = suppliers[i];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppHelpers.getAvatarColor(s.name)
                                .withValues(alpha: 0.15),
                            child: Text(
                              AppHelpers.initials(s.name),
                              style: TextStyle(
                                color: AppHelpers.getAvatarColor(s.name),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          title: Text(s.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                          subtitle: s.phone != null
                              ? Text(s.phone!,
                                  style: const TextStyle(fontSize: 12))
                              : null,
                          trailing: s.balance != 0
                              ? Text(
                                  '₹ ${AppHelpers.formatCurrencyCompact(s.balance.abs())}',
                                  style: const TextStyle(
                                    color: Color(0xFFB71C1C),
                                    fontWeight: FontWeight.w700,
                                  ),
                                )
                              : const Text('Settled',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey)),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}