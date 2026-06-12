// lib/screens/add_item_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/helpers.dart';

class AddItemScreen extends StatefulWidget {
  final Item? item;
  const AddItemScreen({super.key, this.item});

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _salePriceCtrl;
  late final TextEditingController _purchasePriceCtrl;
  late final TextEditingController _stockCtrl;
  late final TextEditingController _categoryCtrl;
  late final TextEditingController _descCtrl;
  ItemUnit _unit = ItemUnit.piece;
  bool _saving = false;

  bool get _isEdit => widget.item != null;

  static const List<String> _unitLabels = [
    'Piece', 'Kg', 'Gram', 'Litre', 'mL', 'Metre', 'Box', 'Pack', 'Dozen'
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.item?.name ?? '');
    _salePriceCtrl = TextEditingController(
        text: widget.item?.salePrice != null
            ? widget.item!.salePrice.toString()
            : '');
    _purchasePriceCtrl = TextEditingController(
        text: widget.item?.purchasePrice != null
            ? widget.item!.purchasePrice.toString()
            : '');
    _stockCtrl = TextEditingController(
        text: widget.item?.stock != null
            ? widget.item!.stock.toString()
            : '');
    _categoryCtrl =
        TextEditingController(text: widget.item?.category ?? '');
    _descCtrl =
        TextEditingController(text: widget.item?.description ?? '');
    _unit = widget.item?.unit ?? ItemUnit.piece;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _salePriceCtrl.dispose();
    _purchasePriceCtrl.dispose();
    _stockCtrl.dispose();
    _categoryCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final provider = context.read<ItemProvider>();
    try {
      if (_isEdit) {
        final updated = widget.item!.copyWith(
          name: _nameCtrl.text.trim(),
          salePrice: double.parse(_salePriceCtrl.text.trim()),
          purchasePrice: _purchasePriceCtrl.text.trim().isEmpty
              ? null
              : double.tryParse(_purchasePriceCtrl.text.trim()),
          stock: _stockCtrl.text.trim().isEmpty
              ? null
              : double.tryParse(_stockCtrl.text.trim()),
          unit: _unit,
          category: _categoryCtrl.text.trim().isEmpty
              ? null
              : _categoryCtrl.text.trim(),
          description: _descCtrl.text.trim().isEmpty
              ? null
              : _descCtrl.text.trim(),
        );
        await provider.updateItem(updated);
      } else {
        final item = Item(
          id: AppHelpers.generateId(),
          name: _nameCtrl.text.trim(),
          salePrice: double.parse(_salePriceCtrl.text.trim()),
          purchasePrice: _purchasePriceCtrl.text.trim().isEmpty
              ? null
              : double.tryParse(_purchasePriceCtrl.text.trim()),
          stock: _stockCtrl.text.trim().isEmpty
              ? null
              : double.tryParse(_stockCtrl.text.trim()),
          unit: _unit,
          category: _categoryCtrl.text.trim().isEmpty
              ? null
              : _categoryCtrl.text.trim(),
          description: _descCtrl.text.trim().isEmpty
              ? null
              : _descCtrl.text.trim(),
          createdAt: DateTime.now(),
        );
        await provider.addItem(item);
      }
      if (!mounted) return;
      AppHelpers.showSuccessSnackBar(
          context, _isEdit ? 'Item updated' : 'Item added');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      AppHelpers.showErrorSnackBar(context, e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Item' : 'Add Item'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Item Details',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Item Name *',
                        prefixIcon:
                            Icon(Icons.inventory_2_outlined, size: 18),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _salePriceCtrl,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d+\.?\d{0,2}'))
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Sale Price ₹ *',
                              prefixIcon: Icon(Icons.currency_rupee,
                                  size: 18),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Required';
                              }
                              if (double.tryParse(v.trim()) == null) {
                                return 'Invalid';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _purchasePriceCtrl,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d+\.?\d{0,2}'))
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Purchase Price ₹',
                              prefixIcon: Icon(Icons.currency_rupee,
                                  size: 18),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _stockCtrl,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Opening Stock',
                              prefixIcon:
                                  Icon(Icons.warehouse_outlined, size: 18),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<ItemUnit>(
                            value: _unit,
                            decoration: const InputDecoration(
                              labelText: 'Unit',
                              prefixIcon:
                                  Icon(Icons.straighten, size: 18),
                            ),
                            items: ItemUnit.values.asMap().entries.map((e) {
                              return DropdownMenuItem(
                                value: e.value,
                                child: Text(_unitLabels[e.key]),
                              );
                            }).toList(),
                            onChanged: (v) {
                              if (v != null) setState(() => _unit = v);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _categoryCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Category (optional)',
                        prefixIcon:
                            Icon(Icons.category_outlined, size: 18),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Description (optional)',
                        prefixIcon:
                            Icon(Icons.notes_outlined, size: 18),
                      ),
                    ),
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
                        _isEdit ? 'Update Item' : 'Save Item',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}