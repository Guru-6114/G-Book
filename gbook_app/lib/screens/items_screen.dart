// lib/screens/items_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../utils/helpers.dart';
import '../widgets/widgets.dart';
import '../l10n/app_localizations.dart';
import 'reports_screen.dart';

class ItemsScreen extends StatefulWidget {
  final bool fromMore;
  final VoidCallback? onBackToMore;

  const ItemsScreen({
    super.key,
    this.fromMore = false,
    this.onBackToMore,
  });

  @override
  State<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends State<ItemsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _searchCtrl = TextEditingController();
  String _query = '';

  // Tracks which book's items are currently loaded so we know when the
  // active khatabook has changed underneath us and need to reload — this
  // is what fixes "Items page still shows old/global data after switching
  // books" (Parties already does this; Items did not).
  String? _loadedForBookId;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadItemsForActiveBook();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Loads items scoped to whichever khatabook is currently active. Always
  /// reads the freshest [AuthProvider] value at call time (via `read`, not
  /// `watch`) so this can safely be called from places like
  /// [WidgetsBinding.addPostFrameCallback] and `.then()` callbacks.
  Future<void> _loadItemsForActiveBook() async {
    final bookId = context.read<AuthProvider>().activeBookId;
    _loadedForBookId = bookId;
    await context.read<ItemProvider>().loadItems(bookId: bookId);
  }

  void _openAddItem({Item? existing, bool isService = false}) {
    final bookId = context.read<AuthProvider>().activeBookId;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddItemScreen(
          existing: existing,
          isService: isService || _tabs.index == 1,
          bookId: bookId,
        ),
      ),
    ).then((_) {
      if (mounted) _loadItemsForActiveBook();
    });
  }

  void _openReports() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ReportsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.l10n;
    // Watching AuthProvider here means that the moment the user switches
    // their active khatabook (e.g. selecting "Electrical" from the book
    // switcher), this build() re-runs, notices the bookId changed, and
    // triggers a reload scoped to the newly active book — instead of
    // silently continuing to show whatever was loaded for the previous
    // book.
    final activeBookId = context.watch<AuthProvider>().activeBookId;
    if (_loadedForBookId != activeBookId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadItemsForActiveBook();
      });
    }

    final provider = context.watch<ItemProvider>();
    // ── isService now comes from the dedicated field, not category=='service'
    final allItems = provider.items;

    final products = allItems
        .where((i) =>
            i.isService == false &&
            (_query.isEmpty ||
                i.name.toLowerCase().contains(_query.toLowerCase())))
        .toList();

    final services = allItems
        .where((i) =>
            i.isService == true &&
            (_query.isEmpty ||
                i.name.toLowerCase().contains(_query.toLowerCase())))
        .toList();

    final lowStockProducts = products.where((i) => i.isLowStock).toList();
    // Low stock should reflect ALL products regardless of search query,
    // matching the Khatabook "Low Stock Items" count in the header.
    final allLowStockProducts =
        allItems.where((i) => !i.isService && i.isLowStock).toList();

    final totalStockValue = allItems
        .where((i) => !i.isService)
        .fold<double>(0, (sum, i) => sum + (i.salePrice * (i.stock ?? 0)));

    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        automaticallyImplyLeading: false,
        leading: widget.fromMore
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: widget.onBackToMore,
              )
            : null,
        title: Text(loc.get('items'),
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 17)),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          tabs: [
            Tab(text: loc.get('items_tab_products')),
            Tab(text: loc.get('items_tab_services')),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Khatabook-style stats bar: Stock Value / Low Stock / View Reports
          if (_tabs.index == 0)
            Container(
              width: double.infinity,
              color: AppTheme.primaryColor,
              padding: const EdgeInsets.fromLTRB(16, 0, 12, 14),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppHelpers.formatCurrency(totalStockValue),
                            style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: Color(0xFF212121)),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(loc.get('total_stock_value'),
                              style: const TextStyle(
                                  fontSize: 11, color: Color(0xFF757575))),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 30,
                      color: const Color(0xFFE0E0E0),
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${allLowStockProducts.length}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: Color(0xFFD32F2F)),
                          ),
                          Text(loc.get('low_stock_items'),
                              style: const TextStyle(
                                  fontSize: 11, color: Color(0xFF757575))),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 30,
                      color: const Color(0xFFE0E0E0),
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    GestureDetector(
                      onTap: _openReports,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(loc.get('view_reports_caps'),
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                  letterSpacing: 0.3,
                                  height: 1.25)),
                          Icon(Icons.chevron_right,
                              color: AppTheme.primaryColor, size: 18),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Search bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: _tabs.index == 0
                          ? loc.get('search_items_hint')
                          : loc.get('search_services_hint'),
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
                if (_tabs.index == 0) ...[
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.sort, size: 16),
                    label: Text(loc.get('sort_label'),
                        style: const TextStyle(fontSize: 13)),
                  ),
                ],
              ],
            ),
          ),

          // Low stock alert banner (only for Products tab) — test report item 8
          if (_tabs.index == 0 && lowStockProducts.isNotEmpty)
            Container(
              color: const Color(0xFFFFF3E0),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_outlined,
                      color: Color(0xFFE65100), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      loc.getParams('low_stock_banner', {
                        'count': '${lowStockProducts.length}',
                        'itemWord': lowStockProducts.length > 1
                            ? loc.get('item_plural')
                            : loc.get('item_singular'),
                      }),
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFFE65100)),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _showLowStockItems(lowStockProducts),
                    child: Text(loc.get('view_label'),
                        style: const TextStyle(color: Color(0xFFE65100))),
                  ),
                ],
              ),
            ),

          const Divider(height: 1),

          // Tab content
          Expanded(
            child: provider.loading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabs,
                    children: [
                      _ItemList(
                        items: products,
                        isService: false,
                        onEdit: (item) => _openAddItem(existing: item),
                        onDelete: (id) =>
                            context.read<ItemProvider>().deleteItem(id),
                        onAdd: () => _openAddItem(isService: false),
                      ),
                      _ItemList(
                        items: services,
                        isService: true,
                        onEdit: (item) =>
                            _openAddItem(existing: item, isService: true),
                        onDelete: (id) =>
                            context.read<ItemProvider>().deleteItem(id),
                        onAdd: () => _openAddItem(isService: true),
                      ),
                    ],
                  ),
          ),
        ],
      ),
      // Single source of truth for the add button — the EmptyState widget
      // itself no longer renders its own action button (see _ItemList),
      // so there is only ever ONE "Add Product" / "Add Service" button
      // visible at a time, matching the Khatabook reference screenshot.
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddItem(isService: _tabs.index == 1),
        icon: const Icon(Icons.add),
        label: Text(_tabs.index == 0
            ? loc.get('add_product_label')
            : loc.get('add_service_label')),
      ),
    );
  }

  void _showLowStockItems(List<Item> items) {
    final loc = context.l10n;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_outlined,
                    color: Color(0xFFE65100)),
                const SizedBox(width: 8),
                Text(loc.get('low_stock_items'),
                    style:
                        const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const Spacer(),
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          ...items.map((item) => ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFFF3E0),
                  child: Icon(Icons.inventory_2_outlined,
                      color: Color(0xFFE65100), size: 18),
                ),
                title: Text(item.name,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(loc.getParams('stock_alert_below', {
                  'stock': item.stock?.toStringAsFixed(0) ?? '0',
                  'threshold': item.lowStockThreshold.toStringAsFixed(0),
                })),
                trailing: TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _openAddItem(existing: item);
                  },
                  child: Text(loc.get('update_label')),
                ),
              )),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _ItemList extends StatelessWidget {
  final List<Item> items;
  final bool isService;
  final void Function(Item) onEdit;
  final void Function(String) onDelete;
  final VoidCallback onAdd;

  const _ItemList({
    required this.items,
    required this.isService,
    required this.onEdit,
    required this.onDelete,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final loc = context.l10n;
    if (items.isEmpty) {
      // Scroll-safe empty state (fixes "BOTTOM OVERFLOWED" error that
      // happened when the keyboard was open while typing in the search
      // box) and intentionally has NO built-in action button — the
      // FloatingActionButton on ItemsScreen is the single "Add
      // Product"/"Add Service" entry point, matching the Khatabook
      // reference screenshot which only shows one such button.
      return LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(32, 32, 32, 100),
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
                        child: Icon(
                          isService
                              ? Icons.miscellaneous_services_outlined
                              : Icons.inventory_2_outlined,
                          size: 36,
                          color:
                              AppTheme.primaryColor.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        isService
                            ? loc.get('no_services_yet')
                            : loc.get('no_products_yet'),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isService
                            ? loc.get('add_services_hint_desc')
                            : loc.get('add_products_hint_desc'),
                        style: const TextStyle(
                            fontSize: 13, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    return RefreshIndicator(
      onRefresh: () => context.read<ItemProvider>().loadItems(),
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 90),
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 68),
        itemBuilder: (_, i) => _ItemTile(
          item: items[i],
          isService: isService,
          onEdit: onEdit,
          onDelete: onDelete,
        ),
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  final Item item;
  final bool isService;
  final void Function(Item) onEdit;
  final void Function(String) onDelete;

  const _ItemTile({
    required this.item,
    required this.isService,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final loc = context.l10n;
    final isLowStock = item.isLowStock;
    final hasImage = item.imagePath != null && item.imagePath!.isNotEmpty;

    final subtitleParts = <String>[
      '${loc.get('label_sale')}: ${AppHelpers.formatCurrency(item.salePrice)}',
      if (item.purchasePrice != null)
        '${loc.get('label_purchase')}: ${AppHelpers.formatCurrency(item.purchasePrice!)}',
      if (item.gstRate > 0)
        '${loc.get('label_gst')}: ${item.gstRate.toStringAsFixed(0)}%',
    ];

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: hasImage
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(item.imagePath!),
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _placeholderIcon(),
              ),
            )
          : _placeholderIcon(),
      title: Row(
        children: [
          Expanded(
            child: Text(item.name,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14)),
          ),
          if (isLowStock)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(loc.get('low_stock_badge'),
                  style: const TextStyle(fontSize: 10, color: Color(0xFFE65100))),
            ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            subtitleParts.join('  |  '),
            style: const TextStyle(fontSize: 12),
          ),
          if (!isService && item.stock != null)
            Text(
              'Stock: ${item.stock!.toStringAsFixed(0)} ${item.unit.name}',
              style: TextStyle(
                fontSize: 12,
                color: isLowStock
                    ? const Color(0xFFE65100)
                    : const Color(0xFF757575),
              ),
            ),
          if (!isService && item.hsnCode != null && item.hsnCode!.isNotEmpty)
            Text('HSN: ${item.hsnCode}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF9E9E9E))),
          if (item.description != null && item.description!.isNotEmpty)
            Text(item.description!,
                style:
                    const TextStyle(fontSize: 11, color: Color(0xFF9E9E9E)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF616161)),
            onPressed: () => onEdit(item),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(loc.get('delete_item_title')),
                  content: Text(
                      loc.getParams('delete_item_confirm', {'name': item.name})),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(loc.get('cancel'))),
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(loc.get('delete'),
                            style: const TextStyle(color: Colors.red))),
                  ],
                ),
              );
              if (ok == true) onDelete(item.id);
            },
          ),
        ],
      ),
      isThreeLine: true,
    );
  }

  Widget _placeholderIcon() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: isService
            ? const Color(0xFFE3F2FD)
            : AppTheme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        isService
            ? Icons.miscellaneous_services_outlined
            : Icons.inventory_2_outlined,
        color: isService ? const Color(0xFF1565C0) : AppTheme.primaryColor,
        size: 22,
      ),
    );
  }
}

// ── Add Item Screen ───────────────────────────────────────────────────────────
class AddItemScreen extends StatefulWidget {
  final Item? existing;
  final bool isService;
  // The khatabook this item belongs to. Passed in explicitly by
  // ItemsScreen (rather than read from a provider here) so this screen
  // stays usable from anywhere without depending on screen-specific
  // wiring. Defaults to '' (no specific book) to preserve old behavior
  // if this screen is ever opened without a book context.
  final String bookId;

  const AddItemScreen({
    super.key,
    this.existing,
    this.isService = false,
    this.bookId = '',
  });

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _salePriceCtrl;
  late final TextEditingController _purchasePriceCtrl;
  late final TextEditingController _stockCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _hsnCtrl;
  late final TextEditingController _lowStockCtrl;
  late bool _isService;
  ItemUnit _unit = ItemUnit.piece;
  String _gstRate = '0';
  String? _imagePath;
  bool _saving = false;

  static const List<String> _gstRates = ['0', '5', '12', '18', '28'];
  static const List<String> _categories = [
    'Electronics', 'Clothing', 'Food', 'Hardware', 'Medicine',
    'Stationery', 'Agriculture', 'Other',
  ];
  String _category = 'Other';

  // Maps the internal (English, stored-in-DB) category value to its
  // localized display label — same pattern used for expense categories,
  // so switching language never changes what's actually saved.
  String _categoryDisplay(String key, AppLocalizations loc) {
    if (key == 'Other') return loc.get('cat_other');
    final tKey = 'itemcat_${key.toLowerCase()}';
    return loc.get(tKey);
  }

  @override
  void initState() {
    super.initState();
    _isService = widget.isService || (widget.existing?.isService ?? false);
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _salePriceCtrl = TextEditingController(
        text: widget.existing?.salePrice.toString() ?? '');
    _purchasePriceCtrl = TextEditingController(
        text: widget.existing?.purchasePrice?.toString() ?? '');
    _stockCtrl = TextEditingController(
        text: widget.existing?.stock?.toString() ?? '');
    _descCtrl = TextEditingController(
        text: widget.existing?.description ?? '');
    _hsnCtrl = TextEditingController(text: widget.existing?.hsnCode ?? '');
    _lowStockCtrl = TextEditingController(
        text: (widget.existing?.lowStockThreshold ?? 5).toStringAsFixed(0));
    _gstRate = (widget.existing?.gstRate ?? 0).toStringAsFixed(0);
    if (!_gstRates.contains(_gstRate)) _gstRate = '0';
    _imagePath = widget.existing?.imagePath;
    if (widget.existing != null) {
      _unit = widget.existing!.unit;
      // ── CRASH FIX: a DropdownButtonFormField throws a hard assertion if
      // its current value isn't found among its `items` (this was the
      // "There should be exactly one item with [DropdownButton]'s value:
      // Fruit" crash you hit when opening an existing item). Items created
      // before the category list was fixed — or created through the
      // legacy free-text category screen — can have ANY string saved as
      // their category, not just one of the eight options below. So we
      // only accept the saved category if it's actually one of the
      // dropdown's known options; otherwise we safely fall back to
      // 'Other' instead of crashing.
      final savedCategory = widget.existing?.category;
      _category = (savedCategory != null && _categories.contains(savedCategory))
          ? savedCategory
          : 'Other';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _salePriceCtrl.dispose();
    _purchasePriceCtrl.dispose();
    _stockCtrl.dispose();
    _descCtrl.dispose();
    _hsnCtrl.dispose();
    _lowStockCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1024,
      );
      if (picked != null) {
        setState(() => _imagePath = picked.path);
      }
    } catch (e) {
      if (mounted) {
        AppHelpers.showErrorSnackBar(context, 'Could not open gallery: $e');
      }
    }
  }

  void _removeImage() => setState(() => _imagePath = null);

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final provider = context.read<ItemProvider>();
    final salePrice = double.parse(_salePriceCtrl.text.trim());
    final purchasePrice = _purchasePriceCtrl.text.trim().isEmpty
        ? null
        : double.tryParse(_purchasePriceCtrl.text.trim());
    final stock = _isService
        ? null
        : (_stockCtrl.text.trim().isEmpty
            ? null
            : double.tryParse(_stockCtrl.text.trim()));
    final lowStockThreshold =
        double.tryParse(_lowStockCtrl.text.trim()) ?? 5;
    final gstRate = double.tryParse(_gstRate) ?? 0;
    final hsn = _hsnCtrl.text.trim().isEmpty ? null : _hsnCtrl.text.trim();

    try {
      if (widget.existing != null) {
        await provider.updateItem(widget.existing!.copyWith(
          name: _nameCtrl.text.trim(),
          salePrice: salePrice,
          purchasePrice: purchasePrice,
          stock: stock,
          unit: _unit,
          category: _isService ? null : _category,
          description: _descCtrl.text.trim().isEmpty
              ? null
              : _descCtrl.text.trim(),
          isService: _isService,
          hsnCode: _isService ? null : hsn,
          gstRate: _isService ? 0 : gstRate,
          lowStockThreshold: lowStockThreshold,
          imagePath: _imagePath,
          clearImage: _imagePath == null,
          // Self-heal items that were created before per-book scoping
          // existed (bookId == ''): re-stamp them with the book they're
          // currently being edited from. If the item already belongs to
          // a book, keep it there.
          bookId: widget.existing!.bookId.isNotEmpty
              ? widget.existing!.bookId
              : widget.bookId,
        ));
      } else {
        await provider.addItem(Item(
          id: AppHelpers.generateId(),
          name: _nameCtrl.text.trim(),
          salePrice: salePrice,
          purchasePrice: purchasePrice,
          stock: stock,
          unit: _unit,
          category: _isService ? null : _category,
          description: _descCtrl.text.trim().isEmpty
              ? null
              : _descCtrl.text.trim(),
          createdAt: DateTime.now(),
          isService: _isService,
          hsnCode: _isService ? null : hsn,
          gstRate: _isService ? 0 : gstRate,
          lowStockThreshold: lowStockThreshold,
          imagePath: _imagePath,
          // ── BOOK SCOPING FIX: every new item is stamped with the
          // khatabook it was created in, so switching books (e.g. to
          // "Electrical") no longer shows items that belong to a
          // different book.
          bookId: widget.bookId,
        ));
      }
      if (mounted) {
        final loc = context.l10n;
        AppHelpers.showSuccessSnackBar(
            context, widget.existing != null ? loc.get('staff_updated_item_placeholder') : 'Item added!');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) AppHelpers.showErrorSnackBar(context, e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ── Khatabook-style "Add Service" layout for services: compact name +
    // photo row, "Service price" section with unit dropdown, tax toggle,
    // and an "ADD SAC CODE & GST %" expandable link — all wrapped in a
    // bottom-pinned full-width action button.
    if (_isService) {
      return _buildServiceLayout(context);
    }
    return _buildProductLayout(context);
  }

  // ── SERVICE layout (matches Khatabook "Add Services" screenshot) ─────────
  Widget _buildServiceLayout(BuildContext context) {
    final loc = context.l10n;
    final hasGstDetails = _hsnCtrl.text.trim().isNotEmpty || _gstRate != '0';
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.existing != null
            ? loc.get('edit_service_title')
            : loc.get('add_service_title')),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Type toggle (kept so users can switch between product/service
            // while creating a new item — hidden for edits to avoid
            // accidentally changing the type of an existing record).
            if (widget.existing == null) _buildTypeToggle(loc),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        hintText: loc.get('service_name_hint'),
                        isDense: true,
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? loc.get('name_required')
                          : null,
                    ),
                  ),
                  const SizedBox(width: 14),
                  _buildPhotoPicker(),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(color: const Color(0xFFEEEEEE), height: 8),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(loc.get('service_price_label'),
                      style: const TextStyle(fontSize: 14, color: Color(0xFF424242))),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _salePriceCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                            prefixText: '₹  ',
                            isDense: true,
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return loc.get('price_required');
                            }
                            if (double.tryParse(v) == null) {
                              return loc.get('enter_valid_price');
                            }
                            return null;
                          },
                        ),
                      ),
                      Container(
                        height: 24,
                        width: 1,
                        color: const Color(0xFFBDBDBD),
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<ItemUnit>(
                          value: _unit,
                          icon: Icon(Icons.keyboard_arrow_down,
                              color: AppTheme.primaryColor),
                          style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 14),
                          items: ItemUnit.values
                              .map((u) => DropdownMenuItem(
                                    value: u,
                                    child: Text(_unitShortLabel(u)),
                                  ))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _unit = v);
                          },
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                ],
              ),
            ),

            Container(
              color: const Color(0xFFF5F8FA),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(loc.get('tax_included_in_price'),
                        style: const TextStyle(fontSize: 14)),
                  ),
                  Switch(
                    value: true,
                    activeColor: AppTheme.primaryColor,
                    onChanged: (_) {},
                  ),
                ],
              ),
            ),
            Container(color: const Color(0xFFEEEEEE), height: 8),

            InkWell(
              onTap: () => setState(() {}),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    hasGstDetails
                        ? loc.get('sac_gst_added')
                        : loc.get('add_sac_gst'),
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ),

            // ── Expandable SAC/GST + description fields. These are kept so
            // existing functionality (HSN/GST tracking on the Item model,
            // description) is preserved exactly as before, just tucked
            // under the Khatabook-style expander instead of always shown.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _hsnCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: loc.get('sac_code_optional'),
                      prefixIcon: const Icon(Icons.tag_outlined, size: 18),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _gstRate,
                    decoration: InputDecoration(
                      labelText: loc.get('gst_rate_label'),
                      prefixIcon: const Icon(Icons.percent, size: 18),
                      isDense: true,
                    ),
                    items: _gstRates
                        .map((r) => DropdownMenuItem(
                              value: r,
                              child: Text('$r%'),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _gstRate = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: loc.get('service_description_optional'),
                      prefixIcon: const Icon(Icons.description_outlined, size: 18),
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 90),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                disabledBackgroundColor: Colors.grey.shade300,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Text(
                      widget.existing != null
                          ? loc.get('update_service_caps')
                          : loc.get('add_service_caps'),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          letterSpacing: 0.5,
                          color: Colors.white),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  String _unitShortLabel(ItemUnit u) {
    switch (u) {
      case ItemUnit.piece:
        return 'NOS';
      case ItemUnit.kg:
        return 'KG';
      case ItemUnit.gram:
        return 'GM';
      case ItemUnit.litre:
        return 'LTR';
      case ItemUnit.ml:
        return 'ML';
      case ItemUnit.metre:
        return 'MTR';
      case ItemUnit.box:
        return 'BOX';
      case ItemUnit.pack:
        return 'PACK';
      case ItemUnit.dozen:
        return 'DZN';
    }
  }

  Widget _buildPhotoPicker() {
    return GestureDetector(
      onTap: _pickImage,
      child: Stack(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFBDBDBD)),
            ),
            child: _imagePath != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(_imagePath!),
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                          Icons.camera_alt_outlined,
                          color: Colors.grey),
                    ),
                  )
                : const Icon(Icons.camera_alt_outlined,
                    color: Colors.grey, size: 26),
          ),
          Positioned(
            top: -6,
            right: -6,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Icon(
                  _imagePath != null ? Icons.close : Icons.add,
                  color: Colors.white,
                  size: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeToggle(AppLocalizations loc) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isService = false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: !_isService
                      ? AppTheme.primaryColor
                      : Colors.grey.shade100,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    bottomLeft: Radius.circular(8),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(Icons.inventory_2_outlined,
                        color: !_isService ? Colors.white : Colors.grey,
                        size: 20),
                    const SizedBox(height: 4),
                    Text(loc.get('type_product'),
                        style: TextStyle(
                            color: !_isService ? Colors.white : Colors.grey,
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isService = true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _isService
                      ? AppTheme.primaryColor
                      : Colors.grey.shade100,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(Icons.miscellaneous_services_outlined,
                        color: _isService ? Colors.white : Colors.grey,
                        size: 20),
                    const SizedBox(height: 4),
                    Text(loc.get('type_service'),
                        style: TextStyle(
                            color: _isService ? Colors.white : Colors.grey,
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── PRODUCT layout (kept close to original; unchanged feature set) ───────
  Widget _buildProductLayout(BuildContext context) {
    final loc = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing != null
            ? loc.get('edit_product_title')
            : loc.get('add_product_title')),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.existing == null) _buildTypeToggle(loc),
            const SizedBox(height: 16),

            // ── Item Image picker ──────────────────────────────────────────
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE0E0E0)),
                      ),
                      child: _imagePath != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                File(_imagePath!),
                                width: 96,
                                height: 96,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                    Icons.broken_image_outlined,
                                    color: Colors.grey,
                                    size: 32),
                              ),
                            )
                          : Icon(
                              Icons.add_a_photo_outlined,
                              color: Colors.grey.shade500,
                              size: 28,
                            ),
                    ),
                    if (_imagePath != null)
                      Positioned(
                        top: -6,
                        right: -6,
                        child: GestureDetector(
                          onTap: _removeImage,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close,
                                size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _imagePath != null
                      ? loc.get('tap_change_photo')
                      : loc.get('add_a_photo'),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc.get('item_details_title'),
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: loc.get('item_name_label'),
                        prefixIcon: const Icon(Icons.inventory_2_outlined, size: 18),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? loc.get('name_required')
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _salePriceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: loc.get('sale_price_label'),
                        prefixIcon: const Icon(Icons.currency_rupee, size: 18),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return loc.get('price_required');
                        if (double.tryParse(v) == null) return loc.get('enter_valid_price');
                        return null;
                      },
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _purchasePriceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: loc.get('purchase_price_label'),
                        prefixIcon: const Icon(Icons.shopping_cart_outlined, size: 18),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _stockCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: loc.get('current_stock_label'),
                              prefixIcon: const Icon(Icons.warehouse_outlined, size: 18),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<ItemUnit>(
                            initialValue: _unit,
                            decoration: InputDecoration(
                              labelText: loc.get('unit_label'),
                            ),
                            items: ItemUnit.values.map((u) => DropdownMenuItem(
                                  value: u,
                                  child: Text(u.name),
                                )).toList(),
                            onChanged: (v) {
                              if (v != null) setState(() => _unit = v);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _lowStockCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: loc.get('low_stock_alert_label'),
                        prefixIcon: const Icon(Icons.warning_amber_outlined, size: 18),
                        helperText: loc.get('low_stock_alert_helper'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _category,
                      decoration: InputDecoration(
                        labelText: loc.get('category_label'),
                        prefixIcon: const Icon(Icons.category_outlined, size: 18),
                      ),
                      items: _categories.map((c) => DropdownMenuItem(
                            value: c,
                            child: Text(_categoryDisplay(c, loc)),
                          )).toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _category = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: loc.get('item_description_label'),
                        prefixIcon: const Icon(Icons.description_outlined, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // HSN & GST Card (for products) — test report item 8
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(loc.get('tax_details_gst_title'),
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _hsnCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: loc.get('hsn_code_optional'),
                        prefixIcon: const Icon(Icons.tag_outlined, size: 18),
                        helperText: loc.get('hsn_helper'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _gstRate,
                      decoration: InputDecoration(
                        labelText: loc.get('gst_rate_label'),
                        prefixIcon: const Icon(Icons.percent, size: 18),
                      ),
                      items: _gstRates.map((r) => DropdownMenuItem(
                            value: r,
                            child: Text('$r%'),
                          )).toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _gstRate = v);
                      },
                    ),
                    if (_gstRate != '0') ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F4FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Builder(builder: (ctx) {
                          final price = double.tryParse(_salePriceCtrl.text) ?? 0;
                          final gst = int.tryParse(_gstRate) ?? 0;
                          final taxAmt = price * gst / 100;
                          final priceWithTax = price + taxAmt;
                          return Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(loc.get('base_price_label'),
                                      style: const TextStyle(fontSize: 12)),
                                  Text(AppHelpers.formatCurrency(price),
                                      style: const TextStyle(fontSize: 12)),
                                ],
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                      loc.getParams(
                                          'gst_percent_label', {'rate': '$gst'}),
                                      style: const TextStyle(fontSize: 12)),
                                  Text(AppHelpers.formatCurrency(taxAmt),
                                      style: const TextStyle(fontSize: 12)),
                                ],
                              ),
                              const Divider(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(loc.get('price_with_gst_label'),
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700)),
                                  Text(AppHelpers.formatCurrency(priceWithTax),
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.primaryColor)),
                                ],
                              ),
                            ],
                          );
                        }),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text(
                        widget.existing != null
                            ? loc.get('update_label')
                            : loc.get('save'),
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
