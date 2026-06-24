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

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ItemProvider>().loadItems();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openAddItem({Item? existing, bool isService = false}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddItemScreen(
          existing: existing,
          isService: isService || _tabs.index == 1,
        ),
      ),
    ).then((_) {
      if (mounted) context.read<ItemProvider>().loadItems();
    });
  }

  @override
  Widget build(BuildContext context) {
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
        title: const Text('Items',
            style: TextStyle(
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
          tabs: const [
            Tab(text: 'PRODUCTS'),
            Tab(text: 'SERVICES'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: _tabs.index == 0
                    ? 'Search products...'
                    : 'Search services...',
                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFBDBDBD)),
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
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),

          // Low stock alert banner (only for Products tab) — test report item 8
          if (_tabs.index == 0 && lowStockProducts.isNotEmpty)
            Container(
              color: const Color(0xFFFFF3E0),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_outlined,
                      color: Color(0xFFE65100), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${lowStockProducts.length} item${lowStockProducts.length > 1 ? 's' : ''} '
                      'running low on stock. Reorder soon!',
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFFE65100)),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _showLowStockItems(lowStockProducts),
                    child: const Text('View',
                        style: TextStyle(color: Color(0xFFE65100))),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddItem(isService: _tabs.index == 1),
        icon: const Icon(Icons.add),
        label: Text(_tabs.index == 0 ? 'Add Product' : 'Add Service'),
      ),
    );
  }

  void _showLowStockItems(List<Item> items) {
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
                const Text('Low Stock Items',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
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
                subtitle: Text(
                    'Stock: ${item.stock?.toStringAsFixed(0) ?? 0}  •  Alert below ${item.lowStockThreshold.toStringAsFixed(0)}'),
                trailing: TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _openAddItem(existing: item);
                  },
                  child: const Text('Update'),
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
    if (items.isEmpty) {
      return EmptyState(
        title: isService ? 'No services yet' : 'No products yet',
        subtitle: isService
            ? 'Add your services to include in bills'
            : 'Add your products to manage stock & billing',
        icon: isService
            ? Icons.miscellaneous_services_outlined
            : Icons.inventory_2_outlined,
        actionLabel: isService ? 'Add Service' : 'Add Product',
        onAction: onAdd,
      );
    }

    return RefreshIndicator(
      onRefresh: () => context.read<ItemProvider>().loadItems(),
      child: ListView.separated(
        padding: EdgeInsets.zero,
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
    final isLowStock = item.isLowStock;
    final hasImage = item.imagePath != null && item.imagePath!.isNotEmpty;

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
              child: const Text('Low Stock',
                  style: TextStyle(fontSize: 10, color: Color(0xFFE65100))),
            ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sale: ${AppHelpers.formatCurrency(item.salePrice)}'
            '${item.purchasePrice != null ? '  |  Purchase: ${AppHelpers.formatCurrency(item.purchasePrice!)}' : ''}'
            '${item.gstRate > 0 ? '  |  GST: ${item.gstRate.toStringAsFixed(0)}%' : ''}',
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
                  title: const Text('Delete Item'),
                  content: Text('Delete "${item.name}"?'),
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

  const AddItemScreen({super.key, this.existing, this.isService = false});

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
      _category = widget.existing?.category ?? 'Other';
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
        ));
      }
      if (mounted) {
        AppHelpers.showSuccessSnackBar(
            context, widget.existing != null ? 'Item updated!' : 'Item added!');
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing != null
            ? (_isService ? 'Edit Service' : 'Edit Product')
            : (_isService ? 'Add Service' : 'Add Product')),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Type toggle
            Row(
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
                          Text('Product',
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
                          Text('Service',
                              style: TextStyle(
                                  color:
                                      _isService ? Colors.white : Colors.grey,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
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
                  _imagePath != null ? 'Tap to change photo' : 'Add a photo',
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
                      _isService ? 'Service Details' : 'Item Details',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: '${_isService ? 'Service' : 'Item'} Name *',
                        prefixIcon: Icon(
                            _isService
                                ? Icons.miscellaneous_services_outlined
                                : Icons.inventory_2_outlined,
                            size: 18),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Name is required'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _salePriceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: _isService ? 'Rate / Price (₹) *' : 'Sale Price (₹) *',
                        prefixIcon: const Icon(Icons.currency_rupee, size: 18),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Price is required';
                        if (double.tryParse(v) == null) return 'Enter valid price';
                        return null;
                      },
                      onChanged: (_) => setState(() {}),
                    ),
                    if (!_isService) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _purchasePriceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Purchase Price (₹)',
                          prefixIcon: Icon(Icons.shopping_cart_outlined, size: 18),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _stockCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Current Stock',
                                prefixIcon: Icon(Icons.warehouse_outlined, size: 18),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<ItemUnit>(
                              initialValue: _unit,
                              decoration: const InputDecoration(
                                labelText: 'Unit',
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
                        decoration: const InputDecoration(
                          labelText: 'Low Stock Alert (qty)',
                          prefixIcon: Icon(Icons.warning_amber_outlined, size: 18),
                          helperText: 'Alert when stock falls below this quantity',
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    if (!_isService)
                      DropdownButtonFormField<String>(
                        initialValue: _category,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          prefixIcon: Icon(Icons.category_outlined, size: 18),
                        ),
                        items: _categories.map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(c),
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
                        labelText: '${_isService ? 'Service' : 'Item'} Description',
                        prefixIcon: const Icon(Icons.description_outlined, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // HSN & GST Card (for products) — test report item 8
            if (!_isService)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Tax Details (GST)',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _hsnCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'HSN Code (optional)',
                          prefixIcon: Icon(Icons.tag_outlined, size: 18),
                          helperText: 'Harmonized System of Nomenclature code',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _gstRate,
                        decoration: const InputDecoration(
                          labelText: 'GST Rate (%)',
                          prefixIcon: Icon(Icons.percent, size: 18),
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
                                    const Text('Base Price:', style: TextStyle(fontSize: 12)),
                                    Text(AppHelpers.formatCurrency(price),
                                        style: const TextStyle(fontSize: 12)),
                                  ],
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('GST ($_gstRate%):', style: const TextStyle(fontSize: 12)),
                                    Text(AppHelpers.formatCurrency(taxAmt),
                                        style: const TextStyle(fontSize: 12)),
                                  ],
                                ),
                                const Divider(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Price with GST:',
                                        style: TextStyle(
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
                        widget.existing != null ? 'Update' : 'Save',
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