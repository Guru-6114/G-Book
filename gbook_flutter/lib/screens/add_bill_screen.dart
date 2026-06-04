// lib/screens/add_bill_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../utils/helpers.dart';

class AddBillScreen extends StatefulWidget {
  final BillType billType;
  const AddBillScreen({super.key, required this.billType});

  @override
  State<AddBillScreen> createState() => _AddBillScreenState();
}

class _AddBillScreenState extends State<AddBillScreen> {
  final _formKey = GlobalKey<FormState>();
  final _partyCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _paymentMode = 'Cash';
  DateTime _date = DateTime.now();
  bool _fullyPaid = true;
  final _paidCtrl = TextEditingController();
  bool _saving = false;

  final List<_BillItemRow> _items = [];

  String get _typeLabel {
    switch (widget.billType) {
      case BillType.sale:
        return 'Sale Bill';
      case BillType.purchase:
        return 'Purchase Bill';
      case BillType.expense:
        return 'Expense';
      case BillType.saleReturn:
        return 'Sale Return';
      case BillType.purchaseReturn:
        return 'Purchase Return';
    }
  }

  double get _totalAmount =>
      _items.fold(0.0, (sum, row) => sum + row.total);

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one item')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final billsProvider = context.read<BillProvider>();
      final billNo = await billsProvider.nextBillNumber(widget.billType);

      final paid =
          _fullyPaid ? _totalAmount : double.tryParse(_paidCtrl.text) ?? 0;

      final now = DateTime.now();
      final billId = AppHelpers.generateId();

      final billItems = _items.map((r) {
        final qty = double.tryParse(r.qtyCtrl.text) ?? 1;
        final price = double.tryParse(r.priceCtrl.text) ?? 0;
        final total = qty * price * (1 + r.taxPercent / 100);
        return BillItem(
          id: AppHelpers.generateId(),
          billId: billId,
          itemId: AppHelpers.generateId(), // placeholder if not linked
          itemName: r.nameCtrl.text.trim(),
          quantity: qty,
          rate: price,
          taxPercent: r.taxPercent,
          total: total,
        );
      }).toList();

      final bill = Bill(
        id: billId,
        billType: widget.billType,
        billNumber: '$_typeLabel #$billNo',
        partyName: _partyCtrl.text.trim().isEmpty
            ? null
            : _partyCtrl.text.trim(),
        items: billItems,
        subtotal: _totalAmount,
        grandTotal: _totalAmount,
        paidAmount: paid,
        date: _date,
        createdAt: now,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );

      await billsProvider.addBill(bill);

      // Adjust stock if sale or purchase
      if (widget.billType == BillType.sale ||
          widget.billType == BillType.purchase) {
        final itemsProvider = context.read<ItemProvider>();
        for (final row in _items) {
          final name = row.nameCtrl.text.trim().toLowerCase();
          try {
            final item = itemsProvider.items.firstWhere(
              (i) => i.name.toLowerCase() == name,
            );
            final qty = double.tryParse(row.qtyCtrl.text) ?? 0;
            await itemsProvider.adjustStock(
              item.id,
              widget.billType == BillType.sale ? -qty : qty,
            );
          } catch (_) {}
        }
      }

      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _partyCtrl.dispose();
    _notesCtrl.dispose();
    _paidCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Add $_typeLabel')),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                // Party & Date card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _partyCtrl,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            labelText: widget.billType == BillType.sale
                                ? 'Customer Name (optional)'
                                : 'Supplier Name (optional)',
                            prefixIcon:
                                const Icon(Icons.person_outline, size: 18),
                          ),
                        ),
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _date,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              setState(() => _date = picked);
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Bill Date',
                              prefixIcon:
                                  Icon(Icons.calendar_today, size: 16),
                            ),
                            child: Text(
                              AppHelpers.formatDate(_date),
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Items card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Items',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                            TextButton.icon(
                              onPressed: () =>
                                  setState(() => _items.add(_BillItemRow())),
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Add Item',
                                  style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                        if (_items.isEmpty)
                          Container(
                            width: double.infinity,
                            padding:
                                const EdgeInsets.symmetric(vertical: 20),
                            alignment: Alignment.center,
                            child: Column(
                              children: [
                                Icon(Icons.inventory_2_outlined,
                                    color: Colors.grey[300], size: 40),
                                const SizedBox(height: 8),
                                const Text(
                                  'No items added yet',
                                  style: TextStyle(
                                      color: AppColors.grey, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ..._items.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final row = entry.value;
                          return _ItemRowWidget(
                            key: ValueKey(idx),
                            row: row,
                            onDelete: () =>
                                setState(() => _items.removeAt(idx)),
                            onChanged: () => setState(() {}),
                            availableItems:
                                context.watch<ItemProvider>().items,
                          );
                        }),
                        if (_items.isNotEmpty) ...[
                          const Divider(),
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total Amount',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14),
                              ),
                              Text(
                                AppHelpers.formatCurrency(_totalAmount),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                    color: AppColors.primary),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Payment card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Payment Details',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _fullyPaid = true),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 10),
                                  decoration: BoxDecoration(
                                    color: _fullyPaid
                                        ? AppColors.green
                                            .withValues(alpha: 0.1)
                                        : Colors.grey[100],
                                    borderRadius:
                                        BorderRadius.circular(8),
                                    border: Border.all(
                                      color: _fullyPaid
                                          ? AppColors.green
                                          : Colors.grey[300]!,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.check_circle_outline,
                                        color: _fullyPaid
                                            ? AppColors.green
                                            : AppColors.grey,
                                        size: 20,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Fully Paid',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: _fullyPaid
                                              ? AppColors.green
                                              : AppColors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _fullyPaid = false),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 10),
                                  decoration: BoxDecoration(
                                    color: !_fullyPaid
                                        ? AppColors.red
                                            .withValues(alpha: 0.1)
                                        : Colors.grey[100],
                                    borderRadius:
                                        BorderRadius.circular(8),
                                    border: Border.all(
                                      color: !_fullyPaid
                                          ? AppColors.red
                                          : Colors.grey[300]!,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.pending_outlined,
                                        color: !_fullyPaid
                                            ? AppColors.red
                                            : AppColors.grey,
                                        size: 20,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Partial / Unpaid',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: !_fullyPaid
                                              ? AppColors.red
                                              : AppColors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (!_fullyPaid) ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _paidCtrl,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Amount Paid',
                              prefixIcon:
                                  Icon(Icons.currency_rupee, size: 18),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        const Text(
                          'Payment Mode',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.grey),
                        ),
                        const SizedBox(height: 6),
                        _PaymentModeSelector(
                          selected: _paymentMode,
                          onChanged: (m) =>
                              setState(() => _paymentMode = m),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Notes
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: TextFormField(
                      controller: _notesCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                        prefixIcon:
                            Icon(Icons.note_outlined, size: 18),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: Text(
                      'SAVE $_typeLabel'.toUpperCase(),
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
          if (_saving)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

// ── Payment mode selector ─────────────────────────────────────────────────────
class _PaymentModeSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _PaymentModeSelector({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const modes = ['Cash', 'UPI', 'Cheque', 'Bank Transfer', 'Credit'];
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: modes.map((m) {
        final isSelected = m == selected;
        return GestureDetector(
          onTap: () => onChanged(m),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : Colors.grey[100],
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? AppColors.primary : Colors.grey[300]!,
              ),
            ),
            child: Text(
              m,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.grey,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Bill item row state ───────────────────────────────────────────────────────
class _BillItemRow {
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController qtyCtrl =
      TextEditingController(text: '1');
  final TextEditingController priceCtrl = TextEditingController();
  String unit = 'PCS';
  double taxPercent = 0;

  double get total {
    final qty = double.tryParse(qtyCtrl.text) ?? 0;
    final price = double.tryParse(priceCtrl.text) ?? 0;
    return qty * price * (1 + taxPercent / 100);
  }
}

// ── Item row widget ───────────────────────────────────────────────────────────
class _ItemRowWidget extends StatefulWidget {
  final _BillItemRow row;
  final VoidCallback onDelete;
  final VoidCallback onChanged;
  final List<Item> availableItems;

  const _ItemRowWidget({
    super.key,
    required this.row,
    required this.onDelete,
    required this.onChanged,
    required this.availableItems,
  });

  @override
  State<_ItemRowWidget> createState() => _ItemRowWidgetState();
}

class _ItemRowWidgetState extends State<_ItemRowWidget> {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.lightGrey,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Autocomplete<String>(
                  optionsBuilder: (textValue) {
                    if (textValue.text.isEmpty) return const [];
                    return widget.availableItems
                        .where((i) => i.name
                            .toLowerCase()
                            .contains(textValue.text.toLowerCase()))
                        .map((i) => i.name);
                  },
                  onSelected: (name) {
                    widget.row.nameCtrl.text = name;
                    try {
                      final item = widget.availableItems
                          .firstWhere((i) => i.name == name);
                      widget.row.priceCtrl.text =
                          item.salePrice.toString();
                      widget.row.unit = item.unit.name.toUpperCase();
                    } catch (_) {}
                    widget.onChanged();
                  },
                  fieldViewBuilder:
                      (context, ctrl, focusNode, onSubmit) {
                    ctrl.text = widget.row.nameCtrl.text;
                    ctrl.addListener(() {
                      widget.row.nameCtrl.text = ctrl.text;
                      widget.onChanged();
                    });
                    return TextFormField(
                      controller: ctrl,
                      focusNode: focusNode,
                      textCapitalization: TextCapitalization.words,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                      decoration: const InputDecoration(
                        hintText: 'Item name',
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        isDense: true,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: AppColors.red, size: 20),
                onPressed: widget.onDelete,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: widget.row.qtyCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  onChanged: (_) => widget.onChanged(),
                  validator: (v) =>
                      double.tryParse(v ?? '') == null ? 'Invalid' : null,
                  decoration: const InputDecoration(
                    labelText: 'Qty',
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 80,
                child: DropdownButtonFormField<String>(
                  value: widget.row.unit,
                  isDense: true,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 8, vertical: 8),
                    isDense: true,
                  ),
                  items: ['PCS', 'KGS', 'LTR', 'MTR', 'BOX', 'PKT']
                      .map((u) =>
                          DropdownMenuItem(value: u, child: Text(u)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => widget.row.unit = v);
                      widget.onChanged();
                    }
                  },
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: TextFormField(
                  controller: widget.row.priceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  onChanged: (_) => widget.onChanged(),
                  validator: (v) =>
                      double.tryParse(v ?? '') == null ? 'Invalid' : null,
                  decoration: const InputDecoration(
                    labelText: 'Price ₹',
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text('Amount: ',
                  style:
                      TextStyle(fontSize: 12, color: AppColors.grey)),
              Text(
                AppHelpers.formatCurrency(widget.row.total),
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppColors.primary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}