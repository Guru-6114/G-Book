// lib/screens/items_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../utils/helpers.dart';
import '../widgets/widgets.dart';
import 'add_item_screen.dart';

class ItemsScreen extends StatefulWidget {
  const ItemsScreen({super.key});

  @override
  State<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends State<ItemsScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ItemProvider>();
    final items = provider.items
        .where((i) =>
            _query.isEmpty ||
            i.name.toLowerCase().contains(_query.toLowerCase()) ||
            (i.category?.toLowerCase().contains(_query.toLowerCase()) ??
                false))
        .toList();

    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      appBar: AppBar(
        title: const Text('Items'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddItemScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search items...',
                hintStyle:
                    const TextStyle(fontSize: 13, color: Color(0xFFBDBDBD)),
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
                : items.isEmpty
                    ? EmptyState(
                        title: _query.isEmpty
                            ? 'No items yet'
                            : 'No items found',
                        subtitle: _query.isEmpty
                            ? 'Add items to use them in bills'
                            : 'Try a different search',
                        icon: Icons.inventory_2_outlined,
                        // FIX: only show the "Add Item" action button on the
                        // truly-empty state (no items at all). When the user
                        // is searching and just gets no results, we don't
                        // want a second Add Item button competing with the
                        // AppBar's "+" — this was the duplicate-button bug.
                        actionLabel: _query.isEmpty ? 'Add Item' : null,
                        onAction: _query.isEmpty
                            ? () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const AddItemScreen()),
                                )
                            : null,
                      )
                    : RefreshIndicator(
                        onRefresh: () =>
                            context.read<ItemProvider>().loadItems(),
                        child: ListView.separated(
                          padding: EdgeInsets.zero,
                          itemCount: items.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, indent: 68),
                          itemBuilder: (_, i) =>
                              _ItemTile(item: items[i]),
                        ),
                      ),
          ),
        ],
      ),
      // FIX: removed the FloatingActionButton.extended("Add Item") that used
      // to render at the same time as the EmptyState's own "Add Item"
      // button, causing two overlapping "Add Item" buttons on screen
      // (as seen in the bug screenshot). Khatabook only has the single "+"
      // in the AppBar plus the one button in the empty state — no FAB here.
    );
  }
}

class _ItemTile extends StatelessWidget {
  final Item item;
  const _ItemTile({required this.item});

  static const List<String> _unitLabels = [
    'pc', 'kg', 'g', 'L', 'mL', 'm', 'box', 'pack', 'doz'
  ];

  String get _unitLabel {
    final idx = ItemUnit.values.indexOf(item.unit);
    if (idx >= 0 && idx < _unitLabels.length) return _unitLabels[idx];
    return 'pc';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => AddItemScreen(item: item)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.inventory_2_outlined,
                  color: AppTheme.primaryColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: Color(0xFF212121))),
                  if (item.category != null)
                    Text(item.category!,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF9E9E9E))),
                  if (item.stock != null)
                    Text(
                      'Stock: ${item.stock!.toStringAsFixed(item.stock! % 1 == 0 ? 0 : 2)} $_unitLabel',
                      style: TextStyle(
                          fontSize: 11,
                          color: item.stock! > 0
                              ? Colors.green.shade700
                              : Colors.red),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  AppHelpers.formatCurrency(item.salePrice),
                  style: const TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 15),
                ),
                if (item.purchasePrice != null)
                  Text(
                    'Cost: ${AppHelpers.formatCurrency(item.purchasePrice!)}',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF9E9E9E)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}