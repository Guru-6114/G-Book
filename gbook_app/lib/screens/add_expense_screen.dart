// lib/screens/add_expense_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../utils/helpers.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  String? _category;
  bool _fullyPaid = true;
  final _paidCtrl = TextEditingController();
  bool _saving = false;
  int _expenseNo = 1;
  String? _partyName;

  // Expense items (optional)
  final List<_ExpenseItemRow> _expenseItems = [];

  static const List<String> _categories = [
    'Rent',
    'Salaries',
    'Electricity',
    'Raw Materials',
    'Transport',
    'Marketing',
    'Office Supplies',
    'Maintenance',
    'Utilities',
    'Insurance',
    'Taxes',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadExpenseNo();
  }

  Future<void> _loadExpenseNo() async {
    final provider = context.read<BillProvider>();
    final no = await provider.nextBillNumber(BillType.expense);
    if (mounted) setState(() => _expenseNo = no);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    _paidCtrl.dispose();
    for (final r in _expenseItems) {
      r.nameCtrl.dispose();
      r.amountCtrl.dispose();
    }
    super.dispose();
  }

  void _showCategorySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, scrollCtrl) => Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text('Select Category',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            Expanded(
              child: ListView.separated(
                controller: scrollCtrl,
                itemCount: _categories.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, indent: 20),
                itemBuilder: (_, i) => ListTile(
                  title: Text(_categories[i],
                      style: const TextStyle(fontSize: 15)),
                  onTap: () {
                    setState(() => _category = _categories[i]);
                    Navigator.pop(context);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showExpenseItemsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _ExpenseItemsSheet(
        items: _expenseItems,
        onSave: () => setState(() {}),
      ),
    );
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      AppHelpers.showErrorSnackBar(context, 'Please enter a valid amount');
      return;
    }

    setState(() => _saving = true);
    try {
      final billsProvider = context.read<BillProvider>();
      final paid = _fullyPaid ? amount : (double.tryParse(_paidCtrl.text) ?? 0);
      final now = DateTime.now();
      final billId = AppHelpers.generateId();

      final bill = Bill(
        id: billId,
        billType: BillType.expense,
        billNumber: 'Expense #$_expenseNo',
        partyName: _partyName?.isEmpty == true ? null : _partyName,
        items: [],
        subtotal: amount,
        grandTotal: amount,
        paidAmount: paid,
        date: _date,
        createdAt: now,
        notes: _notesCtrl.text.trim().isEmpty
            ? (_category != null ? 'Category: $_category' : null)
            : _notesCtrl.text.trim(),
      );

      await billsProvider.addBill(bill);
      if (!mounted) return;

      AppHelpers.showSuccessSnackBar(context, 'Expense saved!');
      Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Add Expense',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 17),
        ),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // ── Expense No + Date row ─────────────────────────────────
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Expense No.',
                                style: TextStyle(
                                    fontSize: 12, color: Color(0xFF9E9E9E))),
                            Row(
                              children: [
                                Text('$_expenseNo',
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF212121))),
                                const SizedBox(width: 4),
                                Icon(Icons.edit,
                                    size: 14,
                                    color: AppTheme.primaryColor),
                              ],
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('Date',
                                style: TextStyle(
                                    fontSize: 12, color: Color(0xFF9E9E9E))),
                            GestureDetector(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _date,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now(),
                                );
                                if (picked != null && mounted) {
                                  setState(() => _date = picked);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: AppTheme.primaryColor),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.calendar_today,
                                        size: 14,
                                        color: AppTheme.primaryColor),
                                    const SizedBox(width: 4),
                                    Text(
                                      AppHelpers.formatDate(_date),
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: AppTheme.primaryColor,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // ── Category ──────────────────────────────────────────────
                  InkWell(
                    onTap: _showCategorySheet,
                    child: Container(
                      color: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                      child: Row(
                        children: [
                          const Icon(Icons.grid_view_outlined,
                              size: 20, color: Color(0xFF757575)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _category ?? 'Category',
                              style: TextStyle(
                                fontSize: 15,
                                color: _category != null
                                    ? const Color(0xFF212121)
                                    : const Color(0xFF9E9E9E),
                              ),
                            ),
                          ),
                          const Icon(Icons.chevron_right,
                              color: Color(0xFF9E9E9E)),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1),

                  // ── Add Expense Items ─────────────────────────────────────
                  InkWell(
                    onTap: _showExpenseItemsSheet,
                    child: Container(
                      color: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                      child: Row(
                        children: [
                          const Icon(Icons.inventory_2_outlined,
                              size: 20, color: Color(0xFF757575)),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Add Expense Items (Optional)',
                              style: TextStyle(
                                  fontSize: 15, color: Color(0xFF212121)),
                            ),
                          ),
                          const Icon(Icons.chevron_right,
                              color: Color(0xFF9E9E9E)),
                        ],
                      ),
                    ),
                  ),

                  // ── Warning banner ────────────────────────────────────────
                  Container(
                    color: const Color(0xFFFFFDE7),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 16, color: Color(0xFFF9A825)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Expense items will not affect your inventory items',
                            style: TextStyle(
                                fontSize: 12, color: Color(0xFF795548)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // ── Expense Amount ────────────────────────────────────────
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    child: Row(
                      children: [
                        const Text(
                          'Expense Amount',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF212121)),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: _amountCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w600),
                            decoration: InputDecoration(
                              hintText: 'Enter Amount',
                              hintStyle: const TextStyle(
                                  color: Color(0xFFBDBDBD), fontSize: 15),
                              filled: true,
                              fillColor: const Color(0xFFF5F5F5),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // ── Payment status ────────────────────────────────────────
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Payment Status',
                            style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF757575),
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _fullyPaid = true),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 10),
                                  decoration: BoxDecoration(
                                    color: _fullyPaid
                                        ? AppColors.green
                                            .withValues(alpha: 0.1)
                                        : Colors.grey[100],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: _fullyPaid
                                          ? AppColors.green
                                          : Colors.grey[300]!,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(Icons.check_circle_outline,
                                          color: _fullyPaid
                                              ? AppColors.green
                                              : AppColors.grey,
                                          size: 20),
                                      const SizedBox(height: 4),
                                      Text('Fully Paid',
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: _fullyPaid
                                                  ? AppColors.green
                                                  : AppColors.grey)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _fullyPaid = false),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 10),
                                  decoration: BoxDecoration(
                                    color: !_fullyPaid
                                        ? AppColors.red.withValues(alpha: 0.1)
                                        : Colors.grey[100],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: !_fullyPaid
                                          ? AppColors.red
                                          : Colors.grey[300]!,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(Icons.pending_outlined,
                                          color: !_fullyPaid
                                              ? AppColors.red
                                              : AppColors.grey,
                                          size: 20),
                                      const SizedBox(height: 4),
                                      Text('Partial / Unpaid',
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: !_fullyPaid
                                                  ? AppColors.red
                                                  : AppColors.grey)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (!_fullyPaid) ...[
                          const SizedBox(height: 12),
                          TextField(
                            controller: _paidCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Amount Paid',
                              prefixIcon:
                                  Icon(Icons.currency_rupee, size: 18),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // ── Notes ─────────────────────────────────────────────────
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: _notesCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                        prefixIcon: Icon(Icons.note_outlined, size: 18),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // ── Save button ────────────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(context).padding.bottom + 12,
            ),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text(
                        'SAVE EXPENSE',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                            color: Colors.white),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Expense Items Sheet ───────────────────────────────────────────────────────
class _ExpenseItemRow {
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController amountCtrl = TextEditingController();
}

class _ExpenseItemsSheet extends StatefulWidget {
  final List<_ExpenseItemRow> items;
  final VoidCallback onSave;

  const _ExpenseItemsSheet({required this.items, required this.onSave});

  @override
  State<_ExpenseItemsSheet> createState() => _ExpenseItemsSheetState();
}

class _ExpenseItemsSheetState extends State<_ExpenseItemsSheet> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Expense Items',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.4,
            ),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                ...widget.items.asMap().entries.map((e) {
                  final i = e.key;
                  final row = e.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: row.nameCtrl,
                            decoration: const InputDecoration(
                              hintText: 'Item name',
                              border: OutlineInputBorder(),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 90,
                          child: TextField(
                            controller: row.amountCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              hintText: 'Amount',
                              border: OutlineInputBorder(),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 10),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: AppColors.red, size: 20),
                          onPressed: () =>
                              setState(() => widget.items.removeAt(i)),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          InkWell(
            onTap: () => setState(() => widget.items.add(_ExpenseItemRow())),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.add, color: AppTheme.primaryColor, size: 18),
                  SizedBox(width: 6),
                  Text('ADD ITEM',
                      style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 13)),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: MediaQuery.of(context).padding.bottom + 12,
            ),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  widget.onSave();
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('SAVE',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}