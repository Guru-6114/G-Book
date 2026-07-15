// lib/screens/collection_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../providers/locale_provider.dart';
import '../theme/app_theme.dart';
import '../utils/helpers.dart';
import 'customer_screen.dart';

class CollectionScreen extends StatefulWidget {
  const CollectionScreen({super.key});

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final Map<String, DateTime> _collectionDates = {};

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final customers = context.read<CustomerProvider>().customers;
      final today = DateTime.now();
      for (final c in customers) {
        if (c.balance > 0) {
          _collectionDates.putIfAbsent(c.id, () => today);
        }
      }
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  List<Customer> _debtors(List<Customer> all) =>
      all.where((c) => c.balance > 0).toList();

  List<Customer> _pendingList(List<Customer> all) {
    final today = _today;
    return _debtors(all).where((c) {
      final d = _collectionDates[c.id];
      return d == null || (d.isBefore(today) && !_sameDay(d, today));
    }).toList();
  }

  List<Customer> _todayList(List<Customer> all) {
    final today = _today;
    return _debtors(all).where((c) {
      final d = _collectionDates[c.id];
      return d != null && _sameDay(d, today);
    }).toList();
  }

  List<Customer> _upcomingList(List<Customer> all) {
    final today = _today;
    return _debtors(all).where((c) {
      final d = _collectionDates[c.id];
      return d != null && d.isAfter(today) && !_sameDay(d, today);
    }).toList();
  }

  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  double _totalForList(List<Customer> list) =>
      list.fold(0.0, (s, c) => s + c.balance);

  Future<void> _setNewDate(Customer customer) async {
    final loc = context.read<LocaleProvider>();
    final current = _collectionDates[customer.id] ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: loc.tr('set_collection_date_title'),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF1565C0),
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _collectionDates[customer.id] = picked);
      AppHelpers.showSuccessSnackBar(
        context,
        loc.trParams('collection_date_set_to',
            {'date': AppHelpers.formatDate(picked)}),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleProvider>();
    final provider = context.watch<CustomerProvider>();
    final all = provider.customers;

    final pending = _pendingList(all);
    final today = _todayList(all);
    final upcoming = _upcomingList(all);

    final pendingTotal = _totalForList(pending);
    final todayTotal = _totalForList(today);
    final upcomingTotal = _totalForList(upcoming);

    final List<Customer> activeList =
        [pending, today, upcoming][_tabs.index];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        title: Text(
          loc.tr('collection'),
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.white),
            onPressed: () => _showHelp(context, loc),
          ),
        ],
      ),
      body: Column(
        children: [
          // Hero banner
          Container(
            width: double.infinity,
            color: const Color(0xFF1565C0),
            padding: const EdgeInsets.fromLTRB(20, 10, 16, 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loc.tr('collect_money_faster'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        all.isEmpty
                            ? loc.tr('add_customers_track_collections')
                            : loc.tr('well_done_collection_set'),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.calendar_month_outlined,
                    color: Colors.amber,
                    size: 42,
                  ),
                ),
              ],
            ),
          ),

          // Tabs
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabs,
              labelColor: const Color(0xFF1565C0),
              unselectedLabelColor: const Color(0xFF757575),
              indicatorColor: const Color(0xFF1565C0),
              indicatorWeight: 2.5,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
              unselectedLabelStyle: const TextStyle(fontSize: 13),
              tabs: [
                Tab(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(loc.tr('tab_pending')),
                      if (pendingTotal > 0)
                        Text(
                          AppHelpers.formatCurrencyCompact(pendingTotal),
                          style: const TextStyle(
                            color: Color(0xFFB71C1C),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                Tab(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(loc.tr('tab_today')),
                      if (todayTotal > 0)
                        Text(
                          AppHelpers.formatCurrencyCompact(todayTotal),
                          style: const TextStyle(
                            color: Color(0xFF1565C0),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                Tab(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(loc.tr('tab_upcoming')),
                      if (upcomingTotal > 0)
                        Text(
                          AppHelpers.formatCurrencyCompact(upcomingTotal),
                          style: const TextStyle(
                            color: Color(0xFF2E7D32),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // List
          Expanded(
            child: provider.loading
                ? const Center(child: CircularProgressIndicator())
                : activeList.isEmpty
                    ? _EmptyCollection(tabIndex: _tabs.index)
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: activeList.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, indent: 72),
                        itemBuilder: (_, i) {
                          final c = activeList[i];
                          final date = _collectionDates[c.id];
                          return _CollectionTile(
                            customer: c,
                            collectionDate: date,
                            onSetDate: () => _setNewDate(c),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CustomerScreen(customer: c),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  void _showHelp(BuildContext context, LocaleProvider loc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.tr('about_collection')),
        content: Text(loc.tr('about_collection_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(loc.tr('got_it')),
          ),
        ],
      ),
    );
  }
}

// ── Collection Tile ─────────────────────────────────────────────────────
class _CollectionTile extends StatelessWidget {
  final Customer customer;
  final DateTime? collectionDate;
  final VoidCallback onSetDate;
  final VoidCallback onTap;

  const _CollectionTile({
    required this.customer,
    required this.collectionDate,
    required this.onSetDate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleProvider>();
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Color(0xFF1565C0),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  AppHelpers.initials(customer.name),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Name + date
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
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 12,
                        color: Color(0xFF9E9E9E),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        collectionDate != null
                            ? AppHelpers.formatDate(collectionDate!)
                            : loc.tr('no_date_set'),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF9E9E9E),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Amount + action
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  AppHelpers.formatCurrencyCompact(customer.balance),
                  style: const TextStyle(
                    color: Color(0xFFB71C1C),
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: onSetDate,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        loc.tr('set_new_date'),
                        style: const TextStyle(
                          color: Color(0xFF1565C0),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: Color(0xFF1565C0),
                      ),
                    ],
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

// ── Empty State ────────────────────────────────────────────────────────────────
class _EmptyCollection extends StatelessWidget {
  final int tabIndex;
  const _EmptyCollection({required this.tabIndex});

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleProvider>();
    final labels = [
      loc.tr('no_pending_collections'),
      loc.tr('no_collections_today'),
      loc.tr('no_upcoming_collections'),
    ];
    final subtitles = [
      loc.tr('all_dues_up_to_date'),
      loc.tr('nothing_scheduled_today'),
      loc.tr('set_dates_plan_ahead'),
    ];
    const icons = [
      Icons.check_circle_outline,
      Icons.today_outlined,
      Icons.event_available_outlined,
    ];

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF1565C0).withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icons[tabIndex],
                size: 38,
                color: const Color(0xFF1565C0).withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              labels[tabIndex],
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF424242),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitles[tabIndex],
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF9E9E9E),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}