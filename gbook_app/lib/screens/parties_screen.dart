// lib/screens/parties_screen.dart
import 'package:flutter/material.dart';
import '../providers/providers.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/helpers.dart';
import '../widgets/widgets.dart';
import '../providers/locale_provider.dart';
import 'add_customer_screen.dart';
import 'add_party_screen.dart';
import 'customer_screen.dart';
import 'reports_screen.dart';
import 'profile_screen.dart';
import 'cashbook_screen.dart';
import '../services/pdf_service.dart';
import '../services/local_database.dart';

class PartiesScreen extends StatefulWidget {
  final bool fromMore;
  final VoidCallback onBackToMore;

  const PartiesScreen(
      {super.key, required this.fromMore, required this.onBackToMore});

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

  // ── Khatabook switcher sheet ─────────────────────────────────────────────
  void _showKhatabookSwitcher(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final allBooks = await LocalDatabase.instance.getAllBusinessProfiles();

    if (!context.mounted) return;

    // Count customers per book
    final counts = <String, int>{};
    for (final b in allBooks) {
      counts[b.id] = await LocalDatabaseCustomerCount.count(b.id);
    }

    if (!context.mounted) return;
    final loc = context.read<LocaleProvider>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return _KhatabookSwitcherSheet(
          books: allBooks,
          counts: counts,
          activeId: auth.profile?.id ?? '',
          loc: loc,
          onSelect: (book) async {
            Navigator.pop(ctx);
            await LocalDatabase.instance.setActiveBusinessProfile(book.id);
            if (!context.mounted) return;
            // Reload profile
            await context.read<AuthProvider>().checkAuth();
            // Reload all providers with the new bookId
            final bookId = book.id;
            if (!context.mounted) return;
            context.read<CustomerProvider>().loadCustomers(bookId: bookId);
            context.read<SupplierProvider>().loadSuppliers(bookId: bookId);
            context.read<TransactionProvider>().loadTransactions(bookId: bookId);
            context.read<CashbookProvider>().loadEntries(bookId: bookId);
            context.read<BillProvider>().loadBills(bookId: bookId);
          },
          onCreateNew: () {
            Navigator.pop(ctx);
            _showCreateKhatabookSheet(context);
          },
        );
      },
    );
  }

  // ── Create new khatabook sheet ───────────────────────────────────────────
  void _showCreateKhatabookSheet(BuildContext context) {
    final nameCtrl = TextEditingController();
    final ownerCtrl = TextEditingController();
    bool saving = false;
    final loc = context.read<LocaleProvider>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSt) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 24,
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
                Text(loc.tr('create_new_khatabook_title'),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  loc.tr('create_new_khatabook_desc'),
                  style: const TextStyle(fontSize: 13, color: Color(0xFF9E9E9E)),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: loc.tr('business_khata_name'),
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
                const SizedBox(height: 12),
                TextField(
                  controller: ownerCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: loc.tr('owner_name'),
                    prefixIcon:
                        const Icon(Icons.person_outline, size: 20),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                          color: AppTheme.primaryColor, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: saving
                        ? null
                        : () async {
                            final name = nameCtrl.text.trim();
                            if (name.isEmpty) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        loc.tr('enter_business_name'))),
                              );
                              return;
                            }
                            setSt(() => saving = true);
                            final newBook = BusinessProfile(
                              id: AppHelpers.generateId(),
                              businessName: name,
                              ownerName: ownerCtrl.text.trim(),
                              phone: context
                                      .read<AuthProvider>()
                                      .profile
                                      ?.phone ??
                                  '',
                              createdAt: DateTime.now(),
                              isActive: false,
                            );
                            await LocalDatabase.instance
                                .createBusinessProfile(newBook);
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (context.mounted) {
                              AppHelpers.showSuccessSnackBar(
                                  context,
                                  loc.getParams('khatabook_created',
                                      {'name': name}));
                              // Re-open switcher so user can immediately switch
                              Future.delayed(
                                  const Duration(milliseconds: 300),
                                  () {
                                if (context.mounted) {
                                  _showKhatabookSwitcher(context);
                                }
                              });
                            }
                          },
                    child: saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Text(loc.tr('create_khatabook_caps'),
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        });
      },
    );
  }

  // ── Business name quick-edit sheet ──────────────────────────────────────
  void _showEditBusinessSheet(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final nameCtrl =
        TextEditingController(text: auth.profile?.businessName ?? '');
    final loc = context.read<LocaleProvider>();

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
              Text(loc.tr('edit_business_title'),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: loc.tr('business_name_label'),
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
                          context, loc.tr('business_name_updated'));
                    }
                  },
                  child: Text(loc.tr('save_changes'),
                      style: const TextStyle(
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
                  label: Text(loc.tr('edit_full_profile'),
                      style: const TextStyle(
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
    final loc = context.watch<LocaleProvider>();
    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        automaticallyImplyLeading: false,
        leading: widget.fromMore
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: widget.onBackToMore,
              )
            : null,
        // ── Business name tappable → opens khatabook switcher ────────────
        title: GestureDetector(
          onTap: () => _showKhatabookSwitcher(context),
          child: Consumer<AuthProvider>(
            builder: (_, auth, __) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    auth.profile?.businessName ?? 'My Business',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 17),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down,
                    color: Colors.white, size: 20),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined,
                color: Colors.white, size: 20),
            onPressed: () => _showEditBusinessSheet(context),
            tooltip: loc.tr('edit_business'),
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
          labelPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          tabs: [
            Tab(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  loc.tr('customers').toUpperCase(),
                  maxLines: 1,
                ),
              ),
            ),
            Tab(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  loc.tr('suppliers').toUpperCase(),
                  maxLines: 1,
                ),
              ),
            ),
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

// ══════════════════════════════════════════════════════════════════════════════
// KHATABOOK SWITCHER SHEET
// ══════════════════════════════════════════════════════════════════════════════
class _KhatabookSwitcherSheet extends StatelessWidget {
  final List<BusinessProfile> books;
  final Map<String, int> counts;
  final String activeId;
  final LocaleProvider loc;
  final void Function(BusinessProfile) onSelect;
  final VoidCallback onCreateNew;

  const _KhatabookSwitcherSheet({
    required this.books,
    required this.counts,
    required this.activeId,
    required this.loc,
    required this.onSelect,
    required this.onCreateNew,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Title
         // Title
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Text(
              loc.tr('select_khatabook'),
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Divider(height: 1),

          // Book list
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.5,
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: books.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, indent: 72),
              itemBuilder: (_, i) {
                final book = books[i];
                final isActive = book.id == activeId;
                final customerCount = counts[book.id] ?? 0;
                final initials = book.businessName.isNotEmpty
                    ? book.businessName[0].toUpperCase()
                    : '?';

                return InkWell(
                  onTap: () => onSelect(book),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        // Avatar
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppTheme.primaryColor
                                : AppHelpers.getAvatarColor(
                                        book.businessName)
                                    .withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              initials,
                              style: TextStyle(
                                color: isActive
                                    ? Colors.white
                                    : AppHelpers.getAvatarColor(
                                        book.businessName),
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                book.businessName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: isActive
                                      ? AppTheme.primaryColor
                                      : const Color(0xFF212121),
                                ),
                              ),
                              Text(
                                '$customerCount ${customerCount == 1 ? loc.tr('customers').replaceAll('s', '') : loc.tr('customers')}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF9E9E9E)),
                              ),
                            ],
                          ),
                        ),
                        if (isActive)
                          const Icon(Icons.check_circle,
                              color: AppTheme.primaryColor, size: 24),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),

          // Create new
         // Create new
          InkWell(
            onTap: onCreateNew,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 18),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 24,
                    backgroundColor: Color(0xFF1565C0),
                    child: Icon(Icons.add, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      loc.tr('create_new_khatabook_caps'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF1565C0),
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
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

  void _openCashbook() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CashbookScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleProvider>();
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      label: loc.tr('you_will_give'),
                      amount: provider.totalPayable,
                      color: const Color(0xFF00796B),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 50,
                    color: const Color(0xFFE0E0E0),
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  Expanded(
                    child: _SummaryCard(
                      label: loc.tr('you_will_get'),
                      amount: provider.totalReceivable,
                      color: const Color(0xFFB71C1C),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _OutlineButton(
                icon: Icons.picture_as_pdf_outlined,
                label: loc.tr('view_reports'),
                color: const Color(0xFF1565C0),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ReportsScreen()),
                ),
              ),
            ],
          ),
        ),

       Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: loc.tr('search_customer_hint'),
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
                  ),
                  const SizedBox(width: 8),
                  _CashbookButton(onTap: _openCashbook, label: loc.tr('cashbook')),
                ],
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                        label: loc.tr('filter_all'),
                        selected: _filter == 'all',
                        onTap: () => setState(() => _filter = 'all')),
                    const SizedBox(width: 8),
                    _FilterChip(
                        label: loc.tr('to_get_filter'),
                        selected: _filter == 'toGet',
                        onTap: () => setState(() => _filter = 'toGet')),
                    const SizedBox(width: 8),
                    _FilterChip(
                        label: loc.tr('to_give_filter'),
                        selected: _filter == 'toGive',
                        onTap: () => setState(() => _filter = 'toGive')),
                    const SizedBox(width: 16),
                    Text(
                      '${customers.length} ${customers.length == 1 ? loc.tr('party_singular') : loc.tr('party_plural')}',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF9E9E9E)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const Divider(height: 1),

        Expanded(
          child: provider.loading
              ? const Center(child: CircularProgressIndicator())
              : customers.isEmpty
                  ? _CustomerEmptyState(loc: loc)
                  : RefreshIndicator(
                      onRefresh: () =>
                          context.read<CustomerProvider>().loadCustomers(),
                      child: ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: customers.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, indent: 68),
                        itemBuilder: (_, i) =>
                            _CustomerTile(customer: customers[i], loc: loc),
                      ),
                    ),
        ),

        // Bottom ADD CUSTOMER bar
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
              const Icon(Icons.arrow_forward,
                  color: Color(0xFF1565C0), size: 22),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AddCustomerScreen()),
                ),
                icon: const Icon(Icons.person_add, size: 18),
                label: Text(loc.tr('add_customer_caps'),
                    style: const TextStyle(
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

  void _openCashbook() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CashbookScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleProvider>();
    final provider = context.watch<SupplierProvider>();
    final suppliers = provider.suppliers
        .where((s) =>
            _query.isEmpty ||
            s.name.toLowerCase().contains(_query.toLowerCase()) ||
            (s.phone?.contains(_query) ?? false))
        .toList();

    final toGet = suppliers.where((s) => s.balance > 0).toList();
    final toGive = suppliers.where((s) => s.balance < 0).toList();
    final totalToGet = toGet.fold(0.0, (sum, s) => sum + s.balance);
    final totalToGive =
        toGive.fold(0.0, (sum, s) => sum + s.balance.abs());

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      label: loc.tr('you_will_give'),
                      amount: totalToGive,
                      color: const Color(0xFF00796B),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 50,
                    color: const Color(0xFFE0E0E0),
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  Expanded(
                    child: _SummaryCard(
                      label: loc.tr('you_will_get'),
                      amount: totalToGet,
                      color: const Color(0xFFB71C1C),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _OutlineButton(
                icon: Icons.picture_as_pdf_outlined,
                label: loc.tr('view_reports'),
                color: const Color(0xFF1565C0),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ReportsScreen()),
                ),
              ),
            ],
          ),
        ),

        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: loc.tr('search_supplier_hint'),
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
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              const SizedBox(width: 8),
              _CashbookButton(onTap: _openCashbook, label: loc.tr('cashbook')),
            ],
          ),
        ),
        const Divider(height: 1),

        Expanded(
          child: provider.loading
              ? const Center(child: CircularProgressIndicator())
              : suppliers.isEmpty
                  ? _SupplierEmptyState(loc: loc)
                  : RefreshIndicator(
                      onRefresh: () =>
                          context.read<SupplierProvider>().loadSuppliers(),
                      child: ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: suppliers.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, indent: 68),
                        itemBuilder: (_, i) =>
                            _SupplierTile(supplier: suppliers[i], loc: loc),
                      ),
                    ),
        ),

        // Bottom ADD SUPPLIER bar
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
              const Icon(Icons.arrow_forward,
                  color: Color(0xFF1565C0), size: 22),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          const AddPartyScreen(isSupplier: true)),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: Text(loc.tr('add_supplier_caps'),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
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
      ],
    );
  }
}

// ── Cashbook quick-access button ──────────────────────────────────────────────
class _CashbookButton extends StatelessWidget {
  final VoidCallback onTap;
  final String label;
  const _CashbookButton({required this.onTap, required this.label});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 42,
        constraints: const BoxConstraints(maxWidth: 110),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.primaryColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.menu_book_outlined,
                size: 18, color: AppTheme.primaryColor),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Supplier Tile ─────────────────────────────────────────────────────────────
class _SupplierTile extends StatelessWidget {
  final Supplier supplier;
  final LocaleProvider loc;
  const _SupplierTile({required this.supplier, required this.loc});

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
        ? loc.tr('you_will_get')
        : balance < 0
            ? loc.tr('you_will_give')
            : loc.tr('settled');

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => SupplierScreen(supplier: supplier)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  if (supplier.phone != null && supplier.phone!.isNotEmpty)
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
              Text(loc.tr('settled'),
                  style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E))),
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
    final list =
        await context.read<CustomerProvider>().getTransactions(_supplierId);
    if (!mounted) return;
    setState(() {
      _transactions = list;
      _loading = false;
    });
  }

  Future<void> _showAddTransaction(bool isGave) async {
    CustomerTransaction? newTx;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _SupplierTransactionSheet(
        supplierId: _supplier.id,
        supplierName: _supplier.name,
        isGave: isGave,
        onAdded: (tx) {
          newTx = tx;
        },
      ),
    );

    if (newTx != null && mounted) {
      final loc = context.read<LocaleProvider>();
      await context.read<CustomerProvider>().addTransaction(newTx!);
      if (!mounted) return;
      final double delta = newTx!.isGiven ? newTx!.amount : -newTx!.amount;
      final updated =
          _supplier.copyWith(balance: _supplier.balance + delta);
      await context.read<SupplierProvider>().updateSupplier(updated);
      if (!mounted) return;
      setState(() {
        _supplier = updated;
        _transactions.insert(0, newTx!);
      });
      AppHelpers.showSuccessSnackBar(context, loc.tr('entry_added'));
    }
  }

  void _deleteTransaction(String txId) async {
    final loc = context.read<LocaleProvider>();
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
    AppHelpers.showSuccessSnackBar(context, loc.tr('entry_deleted'));
  }

  Future<void> _deleteSupplier() async {
    final loc = context.read<LocaleProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.tr('delete_supplier_title')),
        content: Text(loc.getParams(
            'delete_supplier_confirm', {'name': _supplier.name})),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(loc.tr('cancel'))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(loc.tr('delete'),
                  style: const TextStyle(color: Colors.red))),
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

  void _openReport() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SupplierReportScreen(
          supplier: _supplier,
          transactions: _transactions,
        ),
      ),
    );
  }

  Future<void> _callSupplier() async {
    final loc = context.read<LocaleProvider>();
    if (_supplier.phone == null || _supplier.phone!.isEmpty) {
      AppHelpers.showErrorSnackBar(context, 'No phone number');
      return;
    }
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.tr('call_supplier_title')),
        content: Text('Phone: ${_supplier.phone}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(loc.tr('close_label')),
          ),
        ],
      ),
    );
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text('Dial: ${_supplier.phone}'),
        action: SnackBarAction(label: 'OK', onPressed: () {}),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleProvider>();
    final balance = _supplier.balance;
    final balanceLabel = balance > 0
        ? loc.tr('you_will_get')
        : balance < 0
            ? loc.tr('you_will_give')
            : loc.tr('settled');
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
      resizeToAvoidBottomInset: false,
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
                        child: Text(loc.tr('suppliers').replaceAll('s', ''),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 10)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call, color: Colors.white),
            onPressed: _callSupplier,
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
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(balanceLabel,
                    style: TextStyle(
                        color: balanceColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 15)),
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
          // Report shortcut
          Container(
            color: const Color(0xFFF5F5F5),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _openReport,
                  child: Row(
                    children: [
                      const Icon(Icons.picture_as_pdf_outlined,
                          size: 18, color: Color(0xFF555555)),
                      const SizedBox(width: 6),
                      Text(loc.tr('report_label'),
                          style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF555555),
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _transactions.isEmpty
                    ? EmptyState(
                        title: loc.tr('no_transactions_yet'),
                        subtitle: loc.tr('add_payment_entry_hint'),
                        icon: Icons.receipt_long_outlined,
                        actionLabel: loc.tr('add_entry'),
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
                              crossAxisAlignment: CrossAxisAlignment.center,
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
                                          color: const Color(0xFFDDDDDD)),
                                    ),
                                    child: Text(
                                      dateKey,
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
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: Text(loc.tr('entries_label').toUpperCase(),
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF9E9E9E),
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: 0.5)),
                                      ),
                                      Expanded(
                                        child: Text(loc.tr('you_gave_header'),
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF9E9E9E),
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: 0.5)),
                                      ),
                                      Expanded(
                                        child: Text(loc.tr('you_got_header'),
                                            textAlign: TextAlign.end,
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF9E9E9E),
                                                fontWeight: FontWeight.w600,
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
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD32F2F),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _showAddTransaction(true),
                    child: Text(loc.tr('you_gave_rs'),
                        style: const TextStyle(
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
                    child: Text(loc.tr('you_got_rs'),
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            letterSpacing: 0.5)),
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

// ── Supplier Transaction Row ──────────────────────────────────────────────────
class _SupplierTxRow extends StatelessWidget {
  final CustomerTransaction tx;
  final VoidCallback onDelete;

  const _SupplierTxRow({required this.tx, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isGave = tx.isGiven;
    final loc = context.watch<LocaleProvider>();

    return GestureDetector(
      onLongPress: () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(loc.tr('delete_entry')),
            content: Text(loc.tr('delete_entry_confirm')),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(loc.tr('cancel'))),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(loc.tr('delete'),
                      style: const TextStyle(color: Colors.red))),
            ],
          ),
        );
        if (confirmed == true) onDelete();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                      color: isGave
                          ? const Color(0xFFFFF0F0)
                          : const Color(0xFFF0FFF4),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color: isGave
                              ? const Color(0xFFFFCDD2)
                              : const Color(0xFFC8E6C9)),
                    ),
                    child: Text(
                      tx.paymentMode.toUpperCase(),
                      style: TextStyle(
                          fontSize: 10,
                          color: isGave
                              ? const Color(0xFFB71C1C)
                              : const Color(0xFF1B5E20)),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: isGave
                  ? Text(
                      AppHelpers.formatCurrencyCompact(tx.amount),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Color(0xFFB71C1C),
                          fontWeight: FontWeight.w700,
                          fontSize: 14),
                    )
                  : const SizedBox(),
            ),
            Expanded(
              child: !isGave
                  ? Text(
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
  final String supplierId;
  final String supplierName;
  final bool isGave;
  final void Function(CustomerTransaction) onAdded;

  const _SupplierTransactionSheet({
    required this.supplierId,
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
  bool _submitted = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _submit(LocaleProvider loc) {
    if (_submitted) return;
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      AppHelpers.showErrorSnackBar(context, loc.tr('enter_valid_amount'));
      return;
    }
    _submitted = true;
    final tx = CustomerTransaction(
      id: AppHelpers.generateId(),
      customerId: widget.supplierId,
      amount: amount,
      isGiven: widget.isGave,
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      paymentMode: _paymentMode,
      date: DateTime.now(),
    );
    widget.onAdded(tx);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleProvider>();
    final isGave = widget.isGave;
    final color =
        isGave ? const Color(0xFFD32F2F) : const Color(0xFF1B5E20);
    final label = isGave ? loc.tr('you_gave_header') : loc.tr('you_got_header');

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
            style: const TextStyle(
                fontSize: 24, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              prefixText: 'Rs. ',
              prefixStyle: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700, color: color),
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
            decoration: InputDecoration(
              labelText: loc.tr('note_remarks_optional'),
              prefixIcon: const Icon(Icons.note_outlined, size: 18),
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
              onPressed: _submitted ? null : () => _submit(loc),
              child: Text(loc.getParams('save_label_entry', {'label': label}),
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

// ══════════════════════════════════════════════════════════════════════════════
// SUPPLIER REPORT SCREEN — with working PDF download + share
// ══════════════════════════════════════════════════════════════════════════════
class SupplierReportScreen extends StatefulWidget {
  final Supplier supplier;
  final List<CustomerTransaction> transactions;

  const SupplierReportScreen({
    super.key,
    required this.supplier,
    required this.transactions,
  });

  @override
  State<SupplierReportScreen> createState() => _SupplierReportScreenState();
}

class _SupplierReportScreenState extends State<SupplierReportScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isDownloading = false;
  bool _isSharing = false;

  List<CustomerTransaction> get _filtered {
    return widget.transactions.where((t) {
      if (_startDate != null && t.date.isBefore(_startDate!)) return false;
      if (_endDate != null &&
          t.date.isAfter(_endDate!.add(const Duration(days: 1)))) {
        return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  double get _totalGiven =>
      _filtered.where((t) => t.isGiven).fold(0.0, (s, t) => s + t.amount);
  double get _totalReceived =>
      _filtered.where((t) => !t.isGiven).fold(0.0, (s, t) => s + t.amount);

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _endDate = picked);
  }

  Future<void> _download() async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);
    try {
      await PdfService.instance.downloadPdf(
        context,
        partyName: widget.supplier.name,
        phone: widget.supplier.phone,
        balance: widget.supplier.balance,
        transactions: _filtered,
        startDate: _startDate,
        endDate: _endDate,
      );
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _share() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    try {
      await PdfService.instance.shareOnWhatsApp(
        context,
        partyName: widget.supplier.name,
        phone: widget.supplier.phone,
        balance: widget.supplier.balance,
        transactions: _filtered,
        startDate: _startDate,
        endDate: _endDate,
      );
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleProvider>();
    final rows = _filtered;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('${loc.tr('report_label')} - ${widget.supplier.name}',
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 17)),
      ),
      body: Column(
        children: [
          // Date filter
          Container(
            color: const Color(0xFF1565C0),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Row(
              children: [
                Expanded(
                  child: _DateChip(
                    label: _startDate != null
                        ? AppHelpers.formatDate(_startDate!)
                        : loc.tr('start_date').toUpperCase(),
                    onTap: _pickStartDate,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DateChip(
                    label: _endDate != null
                        ? AppHelpers.formatDate(_endDate!)
                        : loc.tr('end_date').toUpperCase(),
                    onTap: _pickEndDate,
                  ),
                ),
              ],
            ),
          ),

          // Net balance
          Container(
            color: Colors.white,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(loc.tr('net_balance'),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
                Text(
                  'Rs. ${widget.supplier.balance.abs().toStringAsFixed(2)}',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: widget.supplier.balance >= 0
                          ? const Color(0xFF00796B)
                          : const Color(0xFFB71C1C)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Container(
            color: Colors.white,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text('${rows.length} ${loc.tr('entries_label')}',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700)),
                const Spacer(),
                Text(
                    '${loc.tr('you_gave_colon')}: Rs. ${_totalGiven.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF9E9E9E))),
                const SizedBox(width: 12),
                Text(
                    '${loc.tr('you_got_colon')}: Rs. ${_totalReceived.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF9E9E9E))),
              ],
            ),
          ),
          const Divider(height: 1),

          // Column headers
          Container(
            color: const Color(0xFFF5F5F5),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(loc.tr('date_label'),
                      style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF9E9E9E),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5)),
                ),
                Expanded(
                  child: Text(loc.tr('you_gave_header'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF9E9E9E),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5)),
                ),
                Expanded(
                  child: Text(loc.tr('you_got_header'),
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF9E9E9E),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: rows.isEmpty
                ? Center(
                    child: Text(loc.tr('no_entries_found'),
                        style: TextStyle(color: Colors.grey.shade500)),
                  )
                : ListView.separated(
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final t = rows[i];
                      return Container(
                        color: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(AppHelpers.formatDate(t.date),
                                      style: const TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF212121))),
                                  if (t.note != null &&
                                      t.note!.isNotEmpty)
                                    Text(t.note!,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF9E9E9E))),
                                  Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: t.isGiven
                                          ? const Color(0xFFFFF0F0)
                                          : const Color(0xFFF0FFF4),
                                      borderRadius:
                                          BorderRadius.circular(4),
                                      border: Border.all(
                                          color: t.isGiven
                                              ? const Color(0xFFFFCDD2)
                                              : const Color(0xFFC8E6C9)),
                                    ),
                                    child: Text(
                                      t.paymentMode.toUpperCase(),
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: t.isGiven
                                              ? const Color(0xFFB71C1C)
                                              : const Color(0xFF1B5E20)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Text(
                                t.isGiven
                                    ? 'Rs. ${t.amount.toStringAsFixed(2)}'
                                    : '',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: Color(0xFFB71C1C),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                !t.isGiven
                                    ? 'Rs. ${t.amount.toStringAsFixed(2)}'
                                    : '',
                                textAlign: TextAlign.end,
                                style: const TextStyle(
                                    color: Color(0xFF1B5E20),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Bottom — Download PDF + Share (WhatsApp)
          Container(
            color: Colors.white,
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(context).padding.bottom + 12,
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isDownloading ? null : _download,
                    icon: _isDownloading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2))
                        : const Icon(Icons.picture_as_pdf_outlined,
                            color: Color(0xFF1565C0)),
                    label: Text(
                        _isDownloading
                            ? loc.tr('preparing_dots')
                            : loc.tr('download_pdf_caps'),
                        style: const TextStyle(
                            color: Color(0xFF1565C0),
                            fontWeight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF1565C0)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSharing ? null : _share,
                    icon: _isSharing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.share, color: Colors.white),
                    label: Text(
                        _isSharing
                            ? loc.tr('sharing_dots')
                            : loc.tr('share_pdf_caps'),
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
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

class _DateChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _DateChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.calendar_today,
                size: 14, color: Color(0xFF1565C0)),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    color: Color(0xFF1565C0),
                    fontWeight: FontWeight.w700,
                    fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

// ── Shared small widgets ──────────────────────────────────────────────────────
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
            style: const TextStyle(
                fontSize: 12, color: Color(0xFF757575))),
        const SizedBox(height: 4),
        Text(
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
              color: selected ? Colors.white : const Color(0xFF616161)),
        ),
      ),
    );
  }
}

class _CustomerTile extends StatelessWidget {
  final Customer customer;
  final LocaleProvider loc;
  const _CustomerTile({required this.customer, required this.loc});

  @override
  Widget build(BuildContext context) {
    final balance = customer.balance;
    final hasBalance = balance != 0;
    final color = balance > 0
        ? const Color(0xFF00796B)
        : balance < 0
            ? const Color(0xFFB71C1C)
            : Colors.grey;
    final label = balance > 0 ? loc.tr('will_give') : loc.tr('will_get');

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
              Text(loc.tr('settled'),
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF9E9E9E))),
          ],
        ),
      ),
    );
  }
}

class _CustomerEmptyState extends StatelessWidget {
  final LocaleProvider loc;
  const _CustomerEmptyState({required this.loc});

  @override
  Widget build(BuildContext context) {
    return Center(
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
                Text(loc.tr('collect_payments_faster'),
                    style: TextStyle(
                        color: Colors.grey.shade500, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              loc.tr('add_customers_maintain_khata'),
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF424242)),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _SupplierEmptyState extends StatelessWidget {
  final LocaleProvider loc;
  const _SupplierEmptyState({required this.loc});

  @override
  Widget build(BuildContext context) {
    return Center(
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
                color: AppTheme.primaryColor.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 16),
          Text(loc.tr('no_suppliers_yet'),
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF424242))),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(loc.tr('add_suppliers_track_payables'),
                style:
                    const TextStyle(fontSize: 13, color: Color(0xFF9E9E9E)),
                textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}