// lib/screens/reports_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Reports Screen — Khatabook-style with working PDF / Excel / Share export
// Uses dart:convert + Flutter's share mechanism via url_launcher or Clipboard
// For real file generation we build CSV (Excel-compatible) and plain-text
// summaries that can be shared or copied.
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart'; // requires: path_provider: ^2.1.4 in pubspec.yaml
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/helpers.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  static const _categories = [
    'All',
    'Customer',
    'Bills',
    'GST',
    'Day-wise',
  ];
  int _selectedCat = 0;

  static const _reports = [
    _ReportItem(
      category: 'Customer',
      icon: Icons.people_outline,
      title: 'Customer Transactions report',
      subtitle: 'Summary of all customer transactions',
      reportKey: 'customer_transactions',
    ),
    _ReportItem(
      category: 'Customer',
      icon: Icons.picture_as_pdf_outlined,
      title: 'Customer list pdf',
      subtitle: 'List of all Customers',
      reportKey: 'customer_list',
    ),
    _ReportItem(
      category: 'Bills',
      icon: Icons.receipt_long_outlined,
      title: 'Sales Report',
      subtitle: 'Summary of all Sales',
      reportKey: 'sales',
    ),
    _ReportItem(
      category: 'Bills',
      icon: Icons.shopping_cart_outlined,
      title: 'Purchase Report',
      subtitle: 'Summary of all Purchases',
      reportKey: 'purchases',
    ),
    _ReportItem(
      category: 'Bills',
      icon: Icons.account_balance_wallet_outlined,
      title: 'Cashbook Report',
      subtitle: 'Summary of all Cashflows',
      reportKey: 'cashbook',
    ),
    _ReportItem(
      category: 'GST',
      icon: Icons.receipt_outlined,
      title: 'GSTR 1 Report',
      subtitle: 'Outward supplies (sales)',
      reportKey: 'gstr1',
    ),
    _ReportItem(
      category: 'GST',
      icon: Icons.receipt_outlined,
      title: 'GSTR 2 Report',
      subtitle: 'Inward supplies (purchases)',
      reportKey: 'gstr2',
    ),
    _ReportItem(
      category: 'GST',
      icon: Icons.receipt_outlined,
      title: 'GSTR 3B Report',
      subtitle: 'Monthly summary return',
      reportKey: 'gstr3b',
    ),
    _ReportItem(
      category: 'Day-wise',
      icon: Icons.bar_chart_outlined,
      title: 'Sales Day-wise Report',
      subtitle: 'Daily Sales Summary',
      reportKey: 'sales_daywise',
    ),
    _ReportItem(
      category: 'Day-wise',
      icon: Icons.bar_chart_outlined,
      title: 'Purchase Day-wise Report',
      subtitle: 'Daily Purchases Summary',
      reportKey: 'purchase_daywise',
    ),
    _ReportItem(
      category: 'Inventory',
      icon: Icons.inventory_2_outlined,
      title: 'Stock Summary',
      subtitle: 'Summary of all items',
      reportKey: 'stock_summary',
    ),
    _ReportItem(
      category: 'Inventory',
      icon: Icons.warning_amber_outlined,
      title: 'Low Stock Summary Report',
      subtitle: 'Summary of all low stock items',
      reportKey: 'low_stock',
    ),
    _ReportItem(
      category: 'Inventory',
      icon: Icons.trending_up_outlined,
      title: 'Profit & Loss Report',
      subtitle: 'Summary of Item level profit & loss',
      reportKey: 'profit_loss',
    ),
    _ReportItem(
      category: 'Supplier',
      icon: Icons.local_shipping_outlined,
      title: 'Supplier Transactions report',
      subtitle: 'Summary of all supplier transactions',
      reportKey: 'supplier_transactions',
    ),
    _ReportItem(
      category: 'Supplier',
      icon: Icons.picture_as_pdf_outlined,
      title: 'Supplier list pdf',
      subtitle: 'List of all Suppliers',
      reportKey: 'supplier_list',
    ),
  ];

  List<_ReportItem> get _filtered {
    if (_selectedCat == 0) return _reports;
    final cat = _categories[_selectedCat];
    return _reports.where((r) => r.category == cat).toList();
  }

  Map<String, List<_ReportItem>> get _grouped {
    final map = <String, List<_ReportItem>>{};
    for (final r in _filtered) {
      map.putIfAbsent(r.category, () => []).add(r);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _grouped;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        title: const Text(
          'View Reports',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Category filter chips
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: List.generate(_categories.length, (i) {
                  final selected = _selectedCat == i;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedCat = i),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected
                              ? const Color(0xFF1565C0)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: selected
                                ? const Color(0xFF1565C0)
                                : const Color(0xFFDDDDDD),
                          ),
                        ),
                        child: Text(
                          _categories[i],
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: selected
                                ? Colors.white
                                : const Color(0xFF616161),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: grouped.entries.map((entry) {
                return _ReportGroup(
                  categoryName: '${entry.key} Reports',
                  items: entry.value,
                  onDownload: (item, format) =>
                      _handleDownload(context, item, format),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Download / export handler ─────────────────────────────────────────────
  Future<void> _handleDownload(
      BuildContext context, _ReportItem item, String format) async {
    // Capture provider data before any async gap
    final customers = context.read<CustomerProvider>().customers;
    final suppliers = context.read<SupplierProvider>().suppliers;
    final bills = context.read<BillProvider>().bills;
    final cashbook = context.read<CashbookProvider>().entries;
    final items = context.read<ItemProvider>().items;

    String content = '';
    String fileName = '';

    switch (item.reportKey) {
      case 'customer_list':
      case 'customer_transactions':
        content = _buildCustomerCsv(customers);
        fileName = 'customer_report';
        break;
      case 'supplier_list':
      case 'supplier_transactions':
        content = _buildSupplierCsv(suppliers);
        fileName = 'supplier_report';
        break;
      case 'sales':
      case 'sales_daywise':
        final sales =
            bills.where((b) => b.billType == BillType.sale).toList();
        content = _buildBillsCsv(sales, 'Sales');
        fileName = 'sales_report';
        break;
      case 'purchases':
      case 'purchase_daywise':
        final purchases =
            bills.where((b) => b.billType == BillType.purchase).toList();
        content = _buildBillsCsv(purchases, 'Purchases');
        fileName = 'purchase_report';
        break;
      case 'cashbook':
        content = _buildCashbookCsv(cashbook);
        fileName = 'cashbook_report';
        break;
      case 'stock_summary':
      case 'low_stock':
      case 'profit_loss':
        content = _buildItemsCsv(items, item.reportKey);
        fileName = 'inventory_report';
        break;
      case 'gstr1':
        final saleBills =
            bills.where((b) => b.billType == BillType.sale).toList();
        content = _buildGstrCsv(saleBills, 'GSTR-1 Outward Supplies');
        fileName = 'gstr1_report';
        break;
      case 'gstr2':
        final purchaseBills =
            bills.where((b) => b.billType == BillType.purchase).toList();
        content = _buildGstrCsv(purchaseBills, 'GSTR-2 Inward Supplies');
        fileName = 'gstr2_report';
        break;
      case 'gstr3b':
        content = _buildGstr3bCsv(bills);
        fileName = 'gstr3b_report';
        break;
      default:
        content = _buildCustomerCsv(customers);
        fileName = 'report';
    }

    final ext = format == 'Excel' ? 'csv' : 'txt';
    final fullFileName = '${fileName}_${_dateStamp()}.$ext';

    if (format == 'Share') {
      await _shareText(context, content, item.title);
      return;
    }

    // Web: copy to clipboard only (no file system access)
    if (kIsWeb) {
      await Clipboard.setData(ClipboardData(text: content));
      if (context.mounted) {
        AppHelpers.showSuccessSnackBar(
          context,
          '$format data copied to clipboard (Web)',
        );
      }
      return;
    }

    // Mobile / desktop: write file then show path dialog
    try {
      final dir = await _getExportDir();
      final file = File('${dir.path}/$fullFileName');
      await file.writeAsString(content, encoding: utf8);

      if (context.mounted) {
        _showFileSavedDialog(context, file.path, format);
      }
    } catch (e) {
      // Fallback: copy to clipboard if file save fails
      await Clipboard.setData(ClipboardData(text: content));
      if (context.mounted) {
        AppHelpers.showSuccessSnackBar(
          context,
          'Copied to clipboard (file save failed: $e)',
        );
      }
    }
  }

  Future<Directory> _getExportDir() async {
    try {
      if (Platform.isAndroid) {
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) return extDir;
      }
      return await getApplicationDocumentsDirectory();
    } catch (_) {
      return await getTemporaryDirectory();
    }
  }

  Future<void> _shareText(
      BuildContext context, String text, String title) async {
    try {
      const channel = MethodChannel('flutter/share');
      await channel.invokeMethod('share', {
        'text': text,
        'subject': title,
      });
    } catch (_) {
      // Fallback to clipboard if share channel not available
      await Clipboard.setData(ClipboardData(text: text));
      if (context.mounted) {
        AppHelpers.showSuccessSnackBar(
          context,
          'Report copied to clipboard',
        );
      }
    }
  }

  void _showFileSavedDialog(
      BuildContext context, String path, String format) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              format == 'PDF'
                  ? Icons.picture_as_pdf_outlined
                  : Icons.table_chart_outlined,
              color: format == 'PDF'
                  ? const Color(0xFFE53935)
                  : const Color(0xFF2E7D32),
            ),
            const SizedBox(width: 8),
            Text('$format Saved'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('File saved successfully!',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                path,
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFF616161)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Clipboard.setData(ClipboardData(text: path));
              AppHelpers.showSuccessSnackBar(
                  context, 'File path copied to clipboard');
            },
            child: const Text('Copy Path'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _dateStamp() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';
  }

  // ── CSV builders ──────────────────────────────────────────────────────────
  String _buildCustomerCsv(List<Customer> customers) {
    final sb = StringBuffer();
    sb.writeln(
        'Customer Report - Generated ${AppHelpers.formatDateTime(DateTime.now())}');
    sb.writeln('');
    sb.writeln('Name,Phone,Email,Address,Balance,Status');
    for (final c in customers) {
      final status = c.balance > 0
          ? 'Will Give'
          : c.balance < 0
              ? 'Will Get'
              : 'Settled';
      sb.writeln(
          '"${c.name}","${c.phone ?? ''}","${c.email ?? ''}",'
          '"${c.address ?? ''}",${c.balance},"$status"');
    }
    sb.writeln('');
    sb.writeln('Total Customers,${customers.length}');
    final totalReceivable = customers
        .where((c) => c.balance > 0)
        .fold(0.0, (s, c) => s + c.balance);
    final totalPayable = customers
        .where((c) => c.balance < 0)
        .fold(0.0, (s, c) => s + c.balance.abs());
    sb.writeln('Total Receivable,${totalReceivable.toStringAsFixed(2)}');
    sb.writeln('Total Payable,${totalPayable.toStringAsFixed(2)}');
    return sb.toString();
  }

  String _buildSupplierCsv(List<Supplier> suppliers) {
    final sb = StringBuffer();
    sb.writeln(
        'Supplier Report - Generated ${AppHelpers.formatDateTime(DateTime.now())}');
    sb.writeln('');
    sb.writeln('Name,Phone,Email,Address,GSTIN,Balance');
    for (final s in suppliers) {
      sb.writeln(
          '"${s.name}","${s.phone ?? ''}","${s.email ?? ''}",'
          '"${s.address ?? ''}","${s.gstin ?? ''}",${s.balance}');
    }
    sb.writeln('');
    sb.writeln('Total Suppliers,${suppliers.length}');
    final total = suppliers.fold(0.0, (s, e) => s + e.balance);
    sb.writeln('Total Payable,${total.toStringAsFixed(2)}');
    return sb.toString();
  }

  String _buildBillsCsv(List<Bill> bills, String type) {
    final sb = StringBuffer();
    sb.writeln(
        '$type Report - Generated ${AppHelpers.formatDateTime(DateTime.now())}');
    sb.writeln('');
    sb.writeln(
        'Bill Number,Party,Date,Subtotal,Discount,Tax,Grand Total,'
        'Paid,Balance Due,Status');
    for (final b in bills) {
      sb.writeln(
          '"${b.billNumber}","${b.partyName ?? ''}",'
          '"${AppHelpers.formatDate(b.date)}",'
          '${b.subtotal},${b.discountTotal},${b.taxTotal},'
          '${b.grandTotal},${b.paidAmount},${b.balanceDue},'
          '"${b.paymentStatus}"');
    }
    sb.writeln('');
    final total = bills.fold(0.0, (s, b) => s + b.grandTotal);
    final totalPaid = bills.fold(0.0, (s, b) => s + b.paidAmount);
    sb.writeln('Total Bills,${bills.length}');
    sb.writeln('Total Amount,${total.toStringAsFixed(2)}');
    sb.writeln('Total Paid,${totalPaid.toStringAsFixed(2)}');
    sb.writeln('Outstanding,${(total - totalPaid).toStringAsFixed(2)}');
    return sb.toString();
  }

  String _buildCashbookCsv(List<CashbookEntry> entries) {
    final sb = StringBuffer();
    sb.writeln(
        'Cashbook Report - Generated ${AppHelpers.formatDateTime(DateTime.now())}');
    sb.writeln('');
    sb.writeln('Date,Type,Description,Payment Mode,Amount');
    for (final e in entries) {
      sb.writeln(
          '"${AppHelpers.formatDate(e.date)}",'
          '"${e.isCashIn ? 'Cash In' : 'Cash Out'}",'
          '"${e.description ?? ''}","${e.paymentMode}",${e.amount}');
    }
    sb.writeln('');
    final totalIn = entries
        .where((e) => e.isCashIn)
        .fold(0.0, (s, e) => s + e.amount);
    final totalOut = entries
        .where((e) => !e.isCashIn)
        .fold(0.0, (s, e) => s + e.amount);
    sb.writeln('Total Cash In,${totalIn.toStringAsFixed(2)}');
    sb.writeln('Total Cash Out,${totalOut.toStringAsFixed(2)}');
    sb.writeln('Net Balance,${(totalIn - totalOut).toStringAsFixed(2)}');
    return sb.toString();
  }

  String _buildItemsCsv(List<Item> items, String reportKey) {
    final sb = StringBuffer();
    sb.writeln(
        'Inventory Report - Generated ${AppHelpers.formatDateTime(DateTime.now())}');
    sb.writeln('');

    if (reportKey == 'profit_loss') {
      sb.writeln(
          'Name,Category,Sale Price,Purchase Price,Stock,Unit,'
          'Estimated Profit/Unit,Total Profit Value');
      for (final item in items) {
        final profit = item.salePrice - (item.purchasePrice ?? 0);
        final totalProfit = profit * (item.stock ?? 0);
        sb.writeln(
            '"${item.name}","${item.category ?? ''}",'
            '${item.salePrice},${item.purchasePrice ?? 0},'
            '${item.stock ?? 0},"${item.unit.name}",'
            '$profit,$totalProfit');
      }
    } else {
      final filtered = reportKey == 'low_stock'
          ? items.where((i) => (i.stock ?? 0) <= 5).toList()
          : items;
      sb.writeln('Name,Category,Sale Price,Purchase Price,Stock,Unit');
      for (final item in filtered) {
        sb.writeln(
            '"${item.name}","${item.category ?? ''}",'
            '${item.salePrice},${item.purchasePrice ?? 0},'
            '${item.stock ?? 0},"${item.unit.name}"');
      }
      sb.writeln('');
      sb.writeln('Total Items,${filtered.length}');
    }
    return sb.toString();
  }

  String _buildGstrCsv(List<Bill> bills, String title) {
    final sb = StringBuffer();
    sb.writeln(
        '$title - Generated ${AppHelpers.formatDateTime(DateTime.now())}');
    sb.writeln('');
    sb.writeln(
        'Invoice Number,Party Name,Date,Taxable Amount,'
        'IGST,CGST,SGST,Total Tax,Invoice Total');
    for (final b in bills) {
      final taxable = b.subtotal - b.discountTotal;
      final igst = b.taxTotal;
      final cgst = b.taxTotal / 2;
      final sgst = b.taxTotal / 2;
      sb.writeln(
          '"${b.billNumber}","${b.partyName ?? ''}",'
          '"${AppHelpers.formatDate(b.date)}",'
          '$taxable,$igst,$cgst,$sgst,${b.taxTotal},${b.grandTotal}');
    }
    sb.writeln('');
    final totalTax = bills.fold(0.0, (s, b) => s + b.taxTotal);
    final totalTaxable = bills
        .fold(0.0, (s, b) => s + b.subtotal - b.discountTotal);
    sb.writeln(
        'Total Taxable Amount,${totalTaxable.toStringAsFixed(2)}');
    sb.writeln('Total Tax,${totalTax.toStringAsFixed(2)}');
    sb.writeln(
        'Total Invoice Value,${(totalTaxable + totalTax).toStringAsFixed(2)}');
    return sb.toString();
  }

  String _buildGstr3bCsv(List<Bill> bills) {
    final sb = StringBuffer();
    sb.writeln(
        'GSTR-3B Monthly Summary - Generated '
        '${AppHelpers.formatDateTime(DateTime.now())}');
    sb.writeln('');
    sb.writeln('Section,Amount');

    final sales = bills.where((b) => b.billType == BillType.sale);
    final purchases =
        bills.where((b) => b.billType == BillType.purchase);

    final outwardTaxable =
        sales.fold(0.0, (s, b) => s + b.subtotal - b.discountTotal);
    final outwardTax = sales.fold(0.0, (s, b) => s + b.taxTotal);
    final inwardTaxable =
        purchases.fold(0.0, (s, b) => s + b.subtotal - b.discountTotal);
    final inwardTax = purchases.fold(0.0, (s, b) => s + b.taxTotal);

    sb.writeln(
        '"3.1 Outward Taxable Supplies",${outwardTaxable.toStringAsFixed(2)}');
    sb.writeln(
        '"3.1 Output Tax (GST on Sales)",${outwardTax.toStringAsFixed(2)}');
    sb.writeln(
        '"4A Eligible ITC (Purchases)",${inwardTaxable.toStringAsFixed(2)}');
    sb.writeln(
        '"4A Input Tax Credit",${inwardTax.toStringAsFixed(2)}');
    sb.writeln(
        '"Net Tax Payable",${(outwardTax - inwardTax).toStringAsFixed(2)}');
    return sb.toString();
  }
}

// ── Report Group Card ─────────────────────────────────────────────────────────
class _ReportGroup extends StatelessWidget {
  final String categoryName;
  final List<_ReportItem> items;
  final void Function(_ReportItem item, String format) onDownload;

  const _ReportGroup({
    required this.categoryName,
    required this.items,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Text(
              categoryName,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF212121),
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Divider(height: 1),
          ...items.asMap().entries.map((e) {
            final isLast = e.key == items.length - 1;
            return Column(
              children: [
                _ReportRow(
                  item: e.value,
                  onDownload: (format) => onDownload(e.value, format),
                ),
                if (!isLast) const Divider(height: 1, indent: 56),
              ],
            );
          }),
        ],
      ),
    );
  }
}

// ── Single Report Row ─────────────────────────────────────────────────────────
class _ReportRow extends StatelessWidget {
  final _ReportItem item;
  final void Function(String format) onDownload;

  const _ReportRow({required this.item, required this.onDownload});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showDownloadSheet(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFE8EAF6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(item.icon,
                  size: 20, color: const Color(0xFF3949AB)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF212121),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9E9E9E),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: Color(0xFFBDBDBD), size: 20),
          ],
        ),
      ),
    );
  }

  void _showDownloadSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _DownloadSheet(
        item: item,
        onDownload: onDownload,
      ),
    );
  }
}

// ── Download Options Bottom Sheet ─────────────────────────────────────────────
class _DownloadSheet extends StatefulWidget {
  final _ReportItem item;
  final void Function(String format) onDownload;

  const _DownloadSheet({required this.item, required this.onDownload});

  @override
  State<_DownloadSheet> createState() => _DownloadSheetState();
}

class _DownloadSheetState extends State<_DownloadSheet> {
  bool _loading = false;
  String _loadingFormat = '';

  Future<void> _trigger(String format) async {
    setState(() {
      _loading = true;
      _loadingFormat = format;
    });

    // Pop the sheet before heavy work so its context stays valid
    Navigator.pop(context);

    await Future.delayed(const Duration(milliseconds: 200));
    widget.onDownload(format);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
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
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8EAF6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(widget.item.icon,
                    size: 20, color: const Color(0xFF3949AB)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.item.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF212121),
                      ),
                    ),
                    Text(
                      widget.item.subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF9E9E9E)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Select format to download',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF616161),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _DownloadButton(
                  icon: Icons.picture_as_pdf_outlined,
                  label: 'PDF',
                  sublabel: 'Text format',
                  color: const Color(0xFFE53935),
                  bgColor: const Color(0xFFFFEBEE),
                  loading: _loading && _loadingFormat == 'PDF',
                  onTap: () => _trigger('PDF'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DownloadButton(
                  icon: Icons.table_chart_outlined,
                  label: 'Excel',
                  sublabel: 'CSV format',
                  color: const Color(0xFF2E7D32),
                  bgColor: const Color(0xFFE8F5E9),
                  loading: _loading && _loadingFormat == 'Excel',
                  onTap: () => _trigger('Excel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DownloadButton(
                  icon: Icons.share_outlined,
                  label: 'Share',
                  sublabel: 'via apps',
                  color: const Color(0xFF1565C0),
                  bgColor: const Color(0xFFE3F2FD),
                  loading: _loading && _loadingFormat == 'Share',
                  onTap: () => _trigger('Share'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 16, color: Color(0xFF9E9E9E)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Date range: All time  •  Tap to filter',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF757575),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {},
                  child: const Text(
                    'Change',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF1565C0),
                      fontWeight: FontWeight.w600,
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

// ── Download Button ───────────────────────────────────────────────────────────
class _DownloadButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;
  final Color bgColor;
  final bool loading;
  final VoidCallback onTap;

  const _DownloadButton({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
    required this.bgColor,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            loading
                ? SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      color: color,
                      strokeWidth: 2.5,
                    ),
                  )
                : Icon(icon, color: color, size: 26),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            Text(
              sublabel,
              style: TextStyle(
                color: color.withValues(alpha: 0.7),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Report Item data class ────────────────────────────────────────────────────
class _ReportItem {
  final String category;
  final IconData icon;
  final String title;
  final String subtitle;
  final String reportKey;

  const _ReportItem({
    required this.category,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.reportKey,
  });
}