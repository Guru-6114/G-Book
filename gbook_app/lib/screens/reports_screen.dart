// lib/screens/reports_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Reports Screen — Khatabook-style with proper PDF / Excel / Share export
// Uses flutter 'pdf' package for generating real PDFs matching Image 2 format
// Add to pubspec.yaml:
//   pdf: ^3.11.1
//   printing: ^5.13.2
//   path_provider: ^2.1.4
//   share_plus: ^10.1.4
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

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
    // Capture provider data before async gaps
    final customers = context.read<CustomerProvider>().customers;
    final suppliers = context.read<SupplierProvider>().suppliers;
    final bills = context.read<BillProvider>().bills;
    final cashbook = context.read<CashbookProvider>().entries;
    final items = context.read<ItemProvider>().items;
    final auth = context.read<AuthProvider>();
    final businessName = auth.profile?.businessName ?? 'My Business';
    final businessPhone = auth.profile?.phone ?? '';

    // Date range label
    final now = DateTime.now();
    final dateRangeLabel =
        '01 ${_monthName(now.month)} ${now.year} to ${_lastDayOf(now.month, now.year)} ${_monthName(now.month)} ${now.year}';

    if (format == 'Excel') {
      // Build CSV and save/share
      final csvContent = _buildCsvForReport(
          item, customers, suppliers, bills, cashbook, items);
      final fileName =
          '${item.reportKey}_${_dateStamp()}.csv';
      await _saveCsvFile(context, csvContent, fileName, item.title);
      return;
    }

    if (format == 'Share') {
      final csvContent = _buildCsvForReport(
          item, customers, suppliers, bills, cashbook, items);
      try {
        await Share.share(csvContent, subject: item.title);
      } catch (_) {
        await Clipboard.setData(ClipboardData(text: csvContent));
        if (context.mounted) {
          AppHelpers.showSuccessSnackBar(context, 'Report copied to clipboard');
        }
      }
      return;
    }

    // PDF generation
    final pdfBytes = await _buildPdfForReport(
      item: item,
      customers: customers,
      suppliers: suppliers,
      bills: bills,
      cashbook: cashbook,
      items: items,
      businessName: businessName,
      businessPhone: businessPhone,
      dateRangeLabel: dateRangeLabel,
    );

    if (!context.mounted) return;

    final fileName =
        '${item.reportKey}_${_dateStamp()}.pdf';

    if (kIsWeb) {
      // On web: use printing package to trigger browser print/save
      await Printing.layoutPdf(onLayout: (_) async => pdfBytes);
      return;
    }

    // Show PDF preview using printing package (native)
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PdfPreviewScreen(
          title: item.title,
          pdfBytes: pdfBytes,
          fileName: fileName,
        ),
      ),
    );
  }

  // ── PDF Builder ───────────────────────────────────────────────────────────
  Future<Uint8List> _buildPdfForReport({
    required _ReportItem item,
    required List<Customer> customers,
    required List<Supplier> suppliers,
    required List<Bill> bills,
    required List<CashbookEntry> cashbook,
    required List<Item> items,
    required String businessName,
    required String businessPhone,
    required String dateRangeLabel,
  }) async {
    final pdf = pw.Document();

    switch (item.reportKey) {
      case 'sales':
      case 'sales_daywise':
        final saleBills =
            bills.where((b) => b.billType == BillType.sale).toList();
        pdf.addPage(_buildSalesReportPage(
          bills: saleBills,
          title: 'Sales Report',
          businessName: businessName,
          businessPhone: businessPhone,
          dateRangeLabel: dateRangeLabel,
        ));
        break;

      case 'purchases':
      case 'purchase_daywise':
        final purchaseBills =
            bills.where((b) => b.billType == BillType.purchase).toList();
        pdf.addPage(_buildSalesReportPage(
          bills: purchaseBills,
          title: 'Purchase Report',
          businessName: businessName,
          businessPhone: businessPhone,
          dateRangeLabel: dateRangeLabel,
        ));
        break;

      case 'customer_list':
      case 'customer_transactions':
        pdf.addPage(_buildCustomerReportPage(
          customers: customers,
          title: item.title,
          businessName: businessName,
          businessPhone: businessPhone,
          dateRangeLabel: dateRangeLabel,
        ));
        break;

      case 'supplier_list':
      case 'supplier_transactions':
        pdf.addPage(_buildSupplierReportPage(
          suppliers: suppliers,
          title: item.title,
          businessName: businessName,
          businessPhone: businessPhone,
          dateRangeLabel: dateRangeLabel,
        ));
        break;

      case 'cashbook':
        pdf.addPage(_buildCashbookReportPage(
          entries: cashbook,
          businessName: businessName,
          businessPhone: businessPhone,
          dateRangeLabel: dateRangeLabel,
        ));
        break;

      case 'stock_summary':
      case 'low_stock':
      case 'profit_loss':
        pdf.addPage(_buildItemsReportPage(
          items: items,
          reportKey: item.reportKey,
          title: item.title,
          businessName: businessName,
          businessPhone: businessPhone,
          dateRangeLabel: dateRangeLabel,
        ));
        break;

      case 'gstr1':
        final saleBills =
            bills.where((b) => b.billType == BillType.sale).toList();
        pdf.addPage(_buildGstReportPage(
          bills: saleBills,
          title: 'GSTR-1 Outward Supplies',
          businessName: businessName,
          businessPhone: businessPhone,
          dateRangeLabel: dateRangeLabel,
        ));
        break;

      case 'gstr2':
        final purchaseBills =
            bills.where((b) => b.billType == BillType.purchase).toList();
        pdf.addPage(_buildGstReportPage(
          bills: purchaseBills,
          title: 'GSTR-2 Inward Supplies',
          businessName: businessName,
          businessPhone: businessPhone,
          dateRangeLabel: dateRangeLabel,
        ));
        break;

      case 'gstr3b':
        pdf.addPage(_buildGstr3bPage(
          bills: bills,
          businessName: businessName,
          businessPhone: businessPhone,
          dateRangeLabel: dateRangeLabel,
        ));
        break;

      default:
        final saleBills =
            bills.where((b) => b.billType == BillType.sale).toList();
        pdf.addPage(_buildSalesReportPage(
          bills: saleBills,
          title: item.title,
          businessName: businessName,
          businessPhone: businessPhone,
          dateRangeLabel: dateRangeLabel,
        ));
    }

    return pdf.save();
  }

  // ── Sales / Purchase Report Page (matches Image 2 format exactly) ─────────
  pw.Page _buildSalesReportPage({
    required List<Bill> bills,
    required String title,
    required String businessName,
    required String businessPhone,
    required String dateRangeLabel,
  }) {
    final totalAmount =
        bills.fold(0.0, (s, b) => s + b.grandTotal);
    final totalReceived =
        bills.fold(0.0, (s, b) => s + b.paidAmount);
    final totalBalance =
        bills.fold(0.0, (s, b) => s + b.balanceDue);

    return pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      header: (context) => _pdfHeader(
        businessName: businessName,
        businessPhone: businessPhone,
        title: title,
        dateRangeLabel: dateRangeLabel,
        totalAmount: totalAmount,
        entryCount: bills.length,
      ),
      footer: (context) => _pdfFooter(context),
      build: (context) => [
        // Main table header
        pw.Table(
          border: pw.TableBorder.all(
              color: PdfColors.grey300, width: 0.5),
          columnWidths: {
            0: const pw.FixedColumnWidth(25),
            1: const pw.FixedColumnWidth(48),
            2: const pw.FixedColumnWidth(25),
            3: const pw.FlexColumnWidth(1.5),
            4: const pw.FixedColumnWidth(55),
            5: const pw.FixedColumnWidth(42),
            6: const pw.FixedColumnWidth(42),
            7: const pw.FixedColumnWidth(48),
            8: const pw.FixedColumnWidth(40),
            9: const pw.FixedColumnWidth(35),
          },
          children: [
            // Header row
            pw.TableRow(
              decoration:
                  const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _th('S.No'),
                _th('Date'),
                _th('Inv No.'),
                _th('Name'),
                _th('Txn Type'),
                _th('Due Date'),
                _th('Status'),
                _th('Total'),
                _th('Received'),
                _th('Bal'),
              ],
            ),
            // Data rows
            ...bills.asMap().entries.expand((entry) {
              final i = entry.key;
              final b = entry.value;
              final rows = <pw.TableRow>[];

              // Main bill row
              rows.add(pw.TableRow(
                children: [
                  _td('${i + 1}'),
                  _td(AppHelpers.formatDate(b.date)),
                  _td(b.billNumber.replaceAll(RegExp(r'[^0-9]'), '')),
                  _td(b.partyName ?? ''),
                  _td(b.billType == BillType.sale
                      ? 'SALE_INVO\nICE'
                      : 'PURCH_INV\nOICE'),
                  _td('-'),
                  _td(b.paidAmount >= b.grandTotal
                      ? 'CASH'
                      : 'PARTIAL'),
                  _td('Rs.${b.grandTotal.toStringAsFixed(0)}'),
                  _td('Rs.${b.paidAmount.toStringAsFixed(0)}'),
                  _td('Rs.${b.balanceDue.toStringAsFixed(0)}'),
                ],
              ));

              // Item detail rows (sub-table style)
              if (b.items.isNotEmpty) {
                // Item header
                rows.add(pw.TableRow(
                  decoration:
                      const pw.BoxDecoration(color: PdfColors.grey100),
                  children: [
                    _thSmall('#'),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(3),
                      child: pw.Text('Item Name',
                          style: _smallBoldStyle()),
                    ),
                    _thSmall(''),
                    _thSmall('Quantity'),
                    _thSmall('Price/Unit'),
                    _thSmall('Discount'),
                    _thSmall('Tax'),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(3),
                      child: pw.Text('Amount',
                          style: _smallBoldStyle(),
                          textAlign: pw.TextAlign.right),
                    ),
                    _thSmall(''),
                    _thSmall(''),
                  ],
                ));

                for (int j = 0; j < b.items.length; j++) {
                  final it = b.items[j];
                  rows.add(pw.TableRow(
                    children: [
                      _tdSmall('${j + 1}'),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(3),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(it.itemName,
                                style: _smallStyle()),
                            pw.Text('Unit PCS',
                                style: pw.TextStyle(fontSize: 6)),
                          ],
                        ),
                      ),
                      _tdSmall(''),
                      _tdSmall(it.quantity
                          .toStringAsFixed(
                              it.quantity % 1 == 0 ? 0 : 1)),
                      _tdSmall(
                          'Rs.${it.rate.toStringAsFixed(0)}'),
                      _tdSmall(
                          'Rs.${it.discount.toStringAsFixed(0)}'),
                      _tdSmall(
                          'Rs.${it.taxPercent.toStringAsFixed(0)}'),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(3),
                        child: pw.Text(
                            'Rs.${it.total.toStringAsFixed(0)}',
                            style: _smallStyle(),
                            textAlign: pw.TextAlign.right),
                      ),
                      _tdSmall(''),
                      _tdSmall(''),
                    ],
                  ));
                }

                // Item total row
                rows.add(pw.TableRow(
                  decoration:
                      const pw.BoxDecoration(color: PdfColors.grey100),
                  children: [
                    _tdSmall(''),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(3),
                      child: pw.Text('Total',
                          style: _smallBoldStyle()),
                    ),
                    _tdSmall(''),
                    _tdSmall(b.items
                        .fold(0.0, (s, it) => s + it.quantity)
                        .toStringAsFixed(1)),
                    _tdSmall(''),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(3),
                      child: pw.Text(
                          'Rs.${b.taxTotal.toStringAsFixed(0)}',
                          style: _smallStyle()),
                    ),
                    _tdSmall(''),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(3),
                      child: pw.Text(
                          'Rs.${b.grandTotal.toStringAsFixed(0)}',
                          style: _smallBoldStyle(),
                          textAlign: pw.TextAlign.right),
                    ),
                    _tdSmall(''),
                    _tdSmall(''),
                  ],
                ));
              }

              return rows;
            }),

            // Total row
            pw.TableRow(
              decoration:
                  const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text('Total',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 8)),
                ),
                _td(''),
                _td(''),
                _td(''),
                _td(''),
                _td(''),
                _td(''),
                _tdBold(
                    'Rs.${totalAmount.toStringAsFixed(0)}'),
                _tdBold(
                    'Rs.${totalReceived.toStringAsFixed(0)}'),
                _tdBold(
                    'Rs.${totalBalance.toStringAsFixed(0)}'),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // ── Customer Report Page ──────────────────────────────────────────────────
  pw.Page _buildCustomerReportPage({
    required List<Customer> customers,
    required String title,
    required String businessName,
    required String businessPhone,
    required String dateRangeLabel,
  }) {
    final totalReceivable = customers
        .where((c) => c.balance > 0)
        .fold(0.0, (s, c) => s + c.balance);

    return pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      header: (ctx) => _pdfHeader(
        businessName: businessName,
        businessPhone: businessPhone,
        title: title,
        dateRangeLabel: dateRangeLabel,
        totalAmount: totalReceivable,
        entryCount: customers.length,
      ),
      footer: (ctx) => _pdfFooter(ctx),
      build: (_) => [
        pw.Table(
          border: pw.TableBorder.all(
              color: PdfColors.grey300, width: 0.5),
          columnWidths: {
            0: const pw.FixedColumnWidth(28),
            1: const pw.FlexColumnWidth(2),
            2: const pw.FlexColumnWidth(1.5),
            3: const pw.FlexColumnWidth(2),
            4: const pw.FlexColumnWidth(1.5),
            5: const pw.FixedColumnWidth(55),
            6: const pw.FixedColumnWidth(50),
          },
          children: [
            pw.TableRow(
              decoration:
                  const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _th('S.No'),
                _th('Name'),
                _th('Phone'),
                _th('Email'),
                _th('Address'),
                _th('Balance'),
                _th('Status'),
              ],
            ),
            ...customers.asMap().entries.map((e) {
              final i = e.key;
              final c = e.value;
              final status = c.balance > 0
                  ? 'Will Give'
                  : c.balance < 0
                      ? 'Will Get'
                      : 'Settled';
              return pw.TableRow(children: [
                _td('${i + 1}'),
                _td(c.name),
                _td(c.phone ?? ''),
                _td(c.email ?? ''),
                _td(c.address ?? ''),
                _td('Rs.${c.balance.abs().toStringAsFixed(0)}'),
                _td(status),
              ]);
            }),
            pw.TableRow(
              decoration:
                  const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _tdBold('Total'),
                _tdBold('${customers.length}'),
                _td(''), _td(''), _td(''),
                _tdBold(
                    'Rs.${totalReceivable.toStringAsFixed(0)}'),
                _td(''),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // ── Supplier Report Page ──────────────────────────────────────────────────
  pw.Page _buildSupplierReportPage({
    required List<Supplier> suppliers,
    required String title,
    required String businessName,
    required String businessPhone,
    required String dateRangeLabel,
  }) {
    final total =
        suppliers.fold(0.0, (s, e) => s + e.balance);

    return pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      header: (ctx) => _pdfHeader(
        businessName: businessName,
        businessPhone: businessPhone,
        title: title,
        dateRangeLabel: dateRangeLabel,
        totalAmount: total,
        entryCount: suppliers.length,
      ),
      footer: (ctx) => _pdfFooter(ctx),
      build: (_) => [
        pw.Table(
          border: pw.TableBorder.all(
              color: PdfColors.grey300, width: 0.5),
          columnWidths: {
            0: const pw.FixedColumnWidth(28),
            1: const pw.FlexColumnWidth(2),
            2: const pw.FlexColumnWidth(1.5),
            3: const pw.FlexColumnWidth(2),
            4: const pw.FlexColumnWidth(1.5),
            5: const pw.FlexColumnWidth(1.5),
            6: const pw.FixedColumnWidth(55),
          },
          children: [
            pw.TableRow(
              decoration:
                  const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _th('S.No'), _th('Name'), _th('Phone'),
                _th('Email'), _th('Address'), _th('GSTIN'),
                _th('Balance'),
              ],
            ),
            ...suppliers.asMap().entries.map((e) {
              final i = e.key;
              final s = e.value;
              return pw.TableRow(children: [
                _td('${i + 1}'),
                _td(s.name),
                _td(s.phone ?? ''),
                _td(s.email ?? ''),
                _td(s.address ?? ''),
                _td(s.gstin ?? ''),
                _td('Rs.${s.balance.abs().toStringAsFixed(0)}'),
              ]);
            }),
            pw.TableRow(
              decoration:
                  const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _tdBold('Total'),
                _tdBold('${suppliers.length}'),
                _td(''), _td(''), _td(''), _td(''),
                _tdBold('Rs.${total.toStringAsFixed(0)}'),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // ── Cashbook Report Page ──────────────────────────────────────────────────
  pw.Page _buildCashbookReportPage({
    required List<CashbookEntry> entries,
    required String businessName,
    required String businessPhone,
    required String dateRangeLabel,
  }) {
    final totalIn = entries
        .where((e) => e.isCashIn)
        .fold(0.0, (s, e) => s + e.amount);
    final totalOut = entries
        .where((e) => !e.isCashIn)
        .fold(0.0, (s, e) => s + e.amount);

    return pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      header: (ctx) => _pdfHeader(
        businessName: businessName,
        businessPhone: businessPhone,
        title: 'Cashbook Report',
        dateRangeLabel: dateRangeLabel,
        totalAmount: totalIn - totalOut,
        entryCount: entries.length,
      ),
      footer: (ctx) => _pdfFooter(ctx),
      build: (_) => [
        pw.Table(
          border: pw.TableBorder.all(
              color: PdfColors.grey300, width: 0.5),
          columnWidths: {
            0: const pw.FixedColumnWidth(28),
            1: const pw.FixedColumnWidth(60),
            2: const pw.FixedColumnWidth(55),
            3: const pw.FlexColumnWidth(2),
            4: const pw.FixedColumnWidth(60),
            5: const pw.FixedColumnWidth(55),
          },
          children: [
            pw.TableRow(
              decoration:
                  const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _th('S.No'), _th('Date'), _th('Type'),
                _th('Description'), _th('Mode'), _th('Amount'),
              ],
            ),
            ...entries.asMap().entries.map((e) {
              final i = e.key;
              final entry = e.value;
              return pw.TableRow(children: [
                _td('${i + 1}'),
                _td(AppHelpers.formatDate(entry.date)),
                _td(entry.isCashIn ? 'Cash In' : 'Cash Out'),
                _td(entry.description ?? ''),
                _td(entry.paymentMode.toUpperCase()),
                _td('Rs.${entry.amount.toStringAsFixed(0)}'),
              ]);
            }),
            pw.TableRow(
              decoration:
                  const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _tdBold(''), _tdBold(''),
                _tdBold('Cash In'), _tdBold(''),
                _tdBold(''),
                _tdBold('Rs.${totalIn.toStringAsFixed(0)}'),
              ],
            ),
            pw.TableRow(
              decoration:
                  const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _tdBold(''), _tdBold(''),
                _tdBold('Cash Out'), _tdBold(''),
                _tdBold(''),
                _tdBold('Rs.${totalOut.toStringAsFixed(0)}'),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // ── Items Report Page ─────────────────────────────────────────────────────
  pw.Page _buildItemsReportPage({
    required List<Item> items,
    required String reportKey,
    required String title,
    required String businessName,
    required String businessPhone,
    required String dateRangeLabel,
  }) {
    final filteredItems = reportKey == 'low_stock'
        ? items.where((i) => (i.stock ?? 0) <= 5).toList()
        : items;

    return pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      header: (ctx) => _pdfHeader(
        businessName: businessName,
        businessPhone: businessPhone,
        title: title,
        dateRangeLabel: dateRangeLabel,
        totalAmount: null,
        entryCount: filteredItems.length,
      ),
      footer: (ctx) => _pdfFooter(ctx),
      build: (_) => [
        pw.Table(
          border: pw.TableBorder.all(
              color: PdfColors.grey300, width: 0.5),
          columnWidths: {
            0: const pw.FixedColumnWidth(28),
            1: const pw.FlexColumnWidth(2),
            2: const pw.FlexColumnWidth(1.5),
            3: const pw.FixedColumnWidth(55),
            4: const pw.FixedColumnWidth(55),
            5: const pw.FixedColumnWidth(40),
            6: const pw.FixedColumnWidth(40),
            if (reportKey == 'profit_loss') 7: const pw.FixedColumnWidth(55),
          },
          children: [
            pw.TableRow(
              decoration:
                  const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _th('S.No'), _th('Name'), _th('Category'),
                _th('Sale Price'), _th('Purchase Price'),
                _th('Stock'), _th('Unit'),
                if (reportKey == 'profit_loss') _th('Profit/Unit'),
              ],
            ),
            ...filteredItems.asMap().entries.map((e) {
              final i = e.key;
              final item = e.value;
              final profit =
                  item.salePrice - (item.purchasePrice ?? 0);
              return pw.TableRow(children: [
                _td('${i + 1}'),
                _td(item.name),
                _td(item.category ?? ''),
                _td('Rs.${item.salePrice.toStringAsFixed(0)}'),
                _td('Rs.${(item.purchasePrice ?? 0).toStringAsFixed(0)}'),
                _td((item.stock ?? 0).toStringAsFixed(0)),
                _td(item.unit.name),
                if (reportKey == 'profit_loss')
                  _td('Rs.${profit.toStringAsFixed(0)}'),
              ]);
            }),
          ],
        ),
      ],
    );
  }

  // ── GST Report Page ───────────────────────────────────────────────────────
  pw.Page _buildGstReportPage({
    required List<Bill> bills,
    required String title,
    required String businessName,
    required String businessPhone,
    required String dateRangeLabel,
  }) {
    final totalTax =
        bills.fold(0.0, (s, b) => s + b.taxTotal);

    return pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      header: (ctx) => _pdfHeader(
        businessName: businessName,
        businessPhone: businessPhone,
        title: title,
        dateRangeLabel: dateRangeLabel,
        totalAmount: totalTax,
        entryCount: bills.length,
      ),
      footer: (ctx) => _pdfFooter(ctx),
      build: (_) => [
        pw.Table(
          border: pw.TableBorder.all(
              color: PdfColors.grey300, width: 0.5),
          columnWidths: {
            0: const pw.FixedColumnWidth(28),
            1: const pw.FlexColumnWidth(1.5),
            2: const pw.FlexColumnWidth(1.5),
            3: const pw.FixedColumnWidth(52),
            4: const pw.FixedColumnWidth(50),
            5: const pw.FixedColumnWidth(44),
            6: const pw.FixedColumnWidth(44),
            7: const pw.FixedColumnWidth(44),
            8: const pw.FixedColumnWidth(52),
          },
          children: [
            pw.TableRow(
              decoration:
                  const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _th('S.No'), _th('Inv No.'), _th('Party'),
                _th('Date'), _th('Taxable'), _th('IGST'),
                _th('CGST'), _th('SGST'), _th('Total'),
              ],
            ),
            ...bills.asMap().entries.map((e) {
              final i = e.key;
              final b = e.value;
              final taxable =
                  b.subtotal - b.discountTotal;
              return pw.TableRow(children: [
                _td('${i + 1}'),
                _td(b.billNumber),
                _td(b.partyName ?? ''),
                _td(AppHelpers.formatDate(b.date)),
                _td('Rs.${taxable.toStringAsFixed(0)}'),
                _td('Rs.${b.taxTotal.toStringAsFixed(0)}'),
                _td('Rs.${(b.taxTotal / 2).toStringAsFixed(0)}'),
                _td('Rs.${(b.taxTotal / 2).toStringAsFixed(0)}'),
                _td('Rs.${b.grandTotal.toStringAsFixed(0)}'),
              ]);
            }),
            pw.TableRow(
              decoration:
                  const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _tdBold('Total'), _tdBold(''), _tdBold(''),
                _tdBold(''),
                _tdBold('Rs.${bills.fold(0.0, (s, b) => s + b.subtotal - b.discountTotal).toStringAsFixed(0)}'),
                _tdBold('Rs.${totalTax.toStringAsFixed(0)}'),
                _tdBold('Rs.${(totalTax / 2).toStringAsFixed(0)}'),
                _tdBold('Rs.${(totalTax / 2).toStringAsFixed(0)}'),
                _tdBold('Rs.${bills.fold(0.0, (s, b) => s + b.grandTotal).toStringAsFixed(0)}'),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // ── GSTR-3B Summary Page ──────────────────────────────────────────────────
  pw.Page _buildGstr3bPage({
    required List<Bill> bills,
    required String businessName,
    required String businessPhone,
    required String dateRangeLabel,
  }) {
    final sales = bills.where((b) => b.billType == BillType.sale);
    final purchases =
        bills.where((b) => b.billType == BillType.purchase);
    final outwardTaxable =
        sales.fold(0.0, (s, b) => s + b.subtotal - b.discountTotal);
    final outwardTax = sales.fold(0.0, (s, b) => s + b.taxTotal);
    final inwardTaxable = purchases
        .fold(0.0, (s, b) => s + b.subtotal - b.discountTotal);
    final inwardTax =
        purchases.fold(0.0, (s, b) => s + b.taxTotal);
    final netTax = outwardTax - inwardTax;

    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _pdfHeaderWidget(
            businessName: businessName,
            businessPhone: businessPhone,
            title: 'GSTR-3B Monthly Summary',
            dateRangeLabel: dateRangeLabel,
            totalAmountLabel: null,
            entryCount: null,
          ),
          pw.SizedBox(height: 12),
          pw.Table(
            border: pw.TableBorder.all(
                color: PdfColors.grey300, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FixedColumnWidth(100),
            },
            children: [
              pw.TableRow(
                decoration:
                    const pw.BoxDecoration(color: PdfColors.grey200),
                children: [_th('Section'), _th('Amount')],
              ),
              _gstr3bRow('3.1 Outward Taxable Supplies',
                  'Rs.${outwardTaxable.toStringAsFixed(2)}'),
              _gstr3bRow('3.1 Output Tax (GST on Sales)',
                  'Rs.${outwardTax.toStringAsFixed(2)}'),
              _gstr3bRow('4A Inward Supplies (Purchases)',
                  'Rs.${inwardTaxable.toStringAsFixed(2)}'),
              _gstr3bRow('4A Input Tax Credit',
                  'Rs.${inwardTax.toStringAsFixed(2)}'),
              pw.TableRow(
                decoration:
                    const pw.BoxDecoration(color: PdfColors.grey100),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text('Net Tax Payable',
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 9)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(
                        'Rs.${netTax.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 9,
                            color: netTax > 0
                                ? PdfColors.red
                                : PdfColors.green)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.TableRow _gstr3bRow(String label, String value) {
    return pw.TableRow(children: [
      pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(label, style: pw.TextStyle(fontSize: 9))),
      pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(value, style: pw.TextStyle(fontSize: 9))),
    ]);
  }

  // ── PDF Header (MultiPage context) ────────────────────────────────────────
  pw.Widget _pdfHeader({
    required String businessName,
    required String businessPhone,
    required String title,
    required String dateRangeLabel,
    required double? totalAmount,
    required int entryCount,
  }) {
    return _pdfHeaderWidget(
      businessName: businessName,
      businessPhone: businessPhone,
      title: title,
      dateRangeLabel: dateRangeLabel,
      totalAmountLabel: totalAmount != null
          ? 'Total ${title.split(' ').first} Amount: Rs. ${totalAmount.toStringAsFixed(0)}'
          : null,
      entryCount: entryCount,
    );
  }

  pw.Widget _pdfHeaderWidget({
    required String businessName,
    required String businessPhone,
    required String title,
    required String dateRangeLabel,
    required String? totalAmountLabel,
    required int? entryCount,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(businessName,
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 14)),
                pw.SizedBox(height: 4),
                pw.Text('Phone Number: $businessPhone',
                    style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(title,
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 13)),
                pw.SizedBox(height: 4),
                pw.Text(dateRangeLabel,
                    style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
          ],
        ),
        if (totalAmountLabel != null) ...[
          pw.SizedBox(height: 8),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(totalAmountLabel,
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold, fontSize: 11)),
          ),
        ],
        if (entryCount != null) ...[
          pw.SizedBox(height: 4),
          pw.Text('No. of entries: $entryCount',
              style: const pw.TextStyle(fontSize: 10)),
        ],
        pw.SizedBox(height: 8),
        pw.Divider(thickness: 0.5),
        pw.SizedBox(height: 4),
      ],
    );
  }

  // ── PDF Footer ────────────────────────────────────────────────────────────
  pw.Widget _pdfFooter(pw.Context context) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Text('Page ${context.pageNumber}',
            style: const pw.TextStyle(
                fontSize: 9, color: PdfColors.grey)),
      ],
    );
  }

  // ── Table cell helpers ────────────────────────────────────────────────────
  static pw.Widget _th(String text) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(
            horizontal: 4, vertical: 4),
        child: pw.Text(text,
            style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold, fontSize: 8)),
      );

  static pw.Widget _thSmall(String text) => pw.Padding(
        padding: const pw.EdgeInsets.all(2),
        child: pw.Text(text, style: _smallBoldStyle()),
      );

  static pw.Widget _td(String text) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(
            horizontal: 4, vertical: 4),
        child: pw.Text(text,
            style: const pw.TextStyle(fontSize: 8)),
      );

  static pw.Widget _tdSmall(String text) => pw.Padding(
        padding: const pw.EdgeInsets.all(2),
        child: pw.Text(text, style: _smallStyle()),
      );

  static pw.Widget _tdBold(String text) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(
            horizontal: 4, vertical: 4),
        child: pw.Text(text,
            style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold)),
      );

  static pw.TextStyle _smallStyle() =>
      const pw.TextStyle(fontSize: 7);

  static pw.TextStyle _smallBoldStyle() =>
      pw.TextStyle(
          fontSize: 7, fontWeight: pw.FontWeight.bold);

  // ── CSV builders ──────────────────────────────────────────────────────────
  String _buildCsvForReport(
    _ReportItem item,
    List<Customer> customers,
    List<Supplier> suppliers,
    List<Bill> bills,
    List<CashbookEntry> cashbook,
    List<Item> items,
  ) {
    switch (item.reportKey) {
      case 'customer_list':
      case 'customer_transactions':
        return _buildCustomerCsv(customers);
      case 'supplier_list':
      case 'supplier_transactions':
        return _buildSupplierCsv(suppliers);
      case 'sales':
      case 'sales_daywise':
        return _buildBillsCsv(
            bills.where((b) => b.billType == BillType.sale).toList(),
            'Sales');
      case 'purchases':
      case 'purchase_daywise':
        return _buildBillsCsv(
            bills
                .where((b) => b.billType == BillType.purchase)
                .toList(),
            'Purchases');
      case 'cashbook':
        return _buildCashbookCsv(cashbook);
      case 'stock_summary':
      case 'low_stock':
      case 'profit_loss':
        return _buildItemsCsv(items, item.reportKey);
      default:
        return _buildCustomerCsv(customers);
    }
  }

  String _buildCustomerCsv(List<Customer> customers) {
    final sb = StringBuffer();
    sb.writeln('Customer Report - Generated ${AppHelpers.formatDateTime(DateTime.now())}');
    sb.writeln('');
    sb.writeln('Name,Phone,Email,Address,Balance,Status');
    for (final c in customers) {
      final status = c.balance > 0
          ? 'Will Give'
          : c.balance < 0
              ? 'Will Get'
              : 'Settled';
      sb.writeln('"${c.name}","${c.phone ?? ''}","${c.email ?? ''}","${c.address ?? ''}",${c.balance},"$status"');
    }
    sb.writeln('');
    sb.writeln('Total Customers,${customers.length}');
    return sb.toString();
  }

  String _buildSupplierCsv(List<Supplier> suppliers) {
    final sb = StringBuffer();
    sb.writeln('Supplier Report - Generated ${AppHelpers.formatDateTime(DateTime.now())}');
    sb.writeln('');
    sb.writeln('Name,Phone,Email,Address,GSTIN,Balance');
    for (final s in suppliers) {
      sb.writeln('"${s.name}","${s.phone ?? ''}","${s.email ?? ''}","${s.address ?? ''}","${s.gstin ?? ''}",${s.balance}');
    }
    return sb.toString();
  }

  String _buildBillsCsv(List<Bill> bills, String type) {
    final sb = StringBuffer();
    sb.writeln('$type Report - Generated ${AppHelpers.formatDateTime(DateTime.now())}');
    sb.writeln('');
    sb.writeln('Bill Number,Party,Date,Subtotal,Discount,Tax,Grand Total,Paid,Balance Due,Status');
    for (final b in bills) {
      sb.writeln('"${b.billNumber}","${b.partyName ?? ''}","${AppHelpers.formatDate(b.date)}",${b.subtotal},${b.discountTotal},${b.taxTotal},${b.grandTotal},${b.paidAmount},${b.balanceDue},"${b.paymentStatus}"');
    }
    sb.writeln('');
    final total = bills.fold(0.0, (s, b) => s + b.grandTotal);
    sb.writeln('Total Bills,${bills.length}');
    sb.writeln('Total Amount,${total.toStringAsFixed(2)}');
    return sb.toString();
  }

  String _buildCashbookCsv(List<CashbookEntry> entries) {
    final sb = StringBuffer();
    sb.writeln('Cashbook Report - Generated ${AppHelpers.formatDateTime(DateTime.now())}');
    sb.writeln('');
    sb.writeln('Date,Type,Description,Payment Mode,Amount');
    for (final e in entries) {
      sb.writeln('"${AppHelpers.formatDate(e.date)}","${e.isCashIn ? 'Cash In' : 'Cash Out'}","${e.description ?? ''}","${e.paymentMode}",${e.amount}');
    }
    return sb.toString();
  }

  String _buildItemsCsv(List<Item> items, String reportKey) {
    final sb = StringBuffer();
    sb.writeln('Inventory Report - Generated ${AppHelpers.formatDateTime(DateTime.now())}');
    sb.writeln('');
    final filtered = reportKey == 'low_stock'
        ? items.where((i) => (i.stock ?? 0) <= 5).toList()
        : items;
    sb.writeln('Name,Category,Sale Price,Purchase Price,Stock,Unit');
    for (final item in filtered) {
      sb.writeln('"${item.name}","${item.category ?? ''}",${item.salePrice},${item.purchasePrice ?? 0},${item.stock ?? 0},"${item.unit.name}"');
    }
    return sb.toString();
  }

  Future<void> _saveCsvFile(BuildContext context, String content,
      String fileName, String title) async {
    if (kIsWeb) {
      await Clipboard.setData(ClipboardData(text: content));
      if (context.mounted) {
        AppHelpers.showSuccessSnackBar(
            context, 'Excel data copied to clipboard');
      }
      return;
    }
    try {
      Directory dir;
      try {
        if (Platform.isAndroid) {
          final ext = await getExternalStorageDirectory();
          dir = ext ?? await getApplicationDocumentsDirectory();
        } else {
          dir = await getApplicationDocumentsDirectory();
        }
      } catch (_) {
        dir = await getTemporaryDirectory();
      }
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(content);
      if (context.mounted) {
        _showFileSavedDialog(context, file.path, 'Excel');
      }
    } catch (e) {
      await Clipboard.setData(ClipboardData(text: content));
      if (context.mounted) {
        AppHelpers.showSuccessSnackBar(
            context, 'Copied to clipboard');
      }
    }
  }

  void _showFileSavedDialog(
      BuildContext context, String path, String format) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
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
        ]),
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
              child: Text(path,
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF616161))),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Clipboard.setData(ClipboardData(text: path));
              AppHelpers.showSuccessSnackBar(
                  context, 'Path copied');
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
    return '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
  }

  String _monthName(int month) {
    const names = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return names[month];
  }

  String _lastDayOf(int month, int year) {
    final d = DateTime(year, month + 1, 0);
    return d.day.toString();
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// PDF PREVIEW SCREEN — uses printing package for native preview + share
// ══════════════════════════════════════════════════════════════════════════════
class _PdfPreviewScreen extends StatelessWidget {
  final String title;
  final Uint8List pdfBytes;
  final String fileName;

  const _PdfPreviewScreen({
    required this.title,
    required this.pdfBytes,
    required this.fileName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        title: Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () async {
              try {
                final dir = await getTemporaryDirectory();
                final file = File('${dir.path}/$fileName');
                await file.writeAsBytes(pdfBytes);
                await Share.shareXFiles([XFile(file.path)],
                    subject: title);
              } catch (_) {
                if (context.mounted) {
                  AppHelpers.showErrorSnackBar(
                      context, 'Could not share PDF');
                }
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.download_outlined),
            onPressed: () async {
              try {
                Directory dir;
                if (Platform.isAndroid) {
                  final ext = await getExternalStorageDirectory();
                  dir = ext ?? await getApplicationDocumentsDirectory();
                } else {
                  dir = await getApplicationDocumentsDirectory();
                }
                final file = File('${dir.path}/$fileName');
                await file.writeAsBytes(pdfBytes);
                if (context.mounted) {
                  AppHelpers.showSuccessSnackBar(
                      context, 'Saved to ${file.path}');
                }
              } catch (_) {
                if (context.mounted) {
                  AppHelpers.showErrorSnackBar(
                      context, 'Could not save PDF');
                }
              }
            },
          ),
        ],
      ),
      body: PdfPreview(
        build: (_) async => pdfBytes,
        allowPrinting: true,
        allowSharing: true,
        canChangePageFormat: false,
        canDebug: false,
        pdfFileName: fileName,
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// UI COMPONENTS (unchanged from original)
// ══════════════════════════════════════════════════════════════════════════════

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
                  Text(item.title,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF212121))),
                  const SizedBox(height: 2),
                  Text(item.subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF9E9E9E))),
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

class _DownloadSheet extends StatefulWidget {
  final _ReportItem item;
  final void Function(String format) onDownload;

  const _DownloadSheet(
      {required this.item, required this.onDownload});

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
                    Text(widget.item.title,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF212121))),
                    Text(widget.item.subtitle,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF9E9E9E))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text('Select format to download',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF616161))),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _DownloadButton(
                  icon: Icons.picture_as_pdf_outlined,
                  label: 'PDF',
                  sublabel: 'Preview & Save',
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
            child: const Row(
              children: [
                Icon(Icons.calendar_today_outlined,
                    size: 16, color: Color(0xFF9E9E9E)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Date range: All time  •  Tap to filter',
                    style: TextStyle(
                        fontSize: 12, color: Color(0xFF757575)),
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
                        color: color, strokeWidth: 2.5),
                  )
                : Icon(icon, color: color, size: 26),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
            Text(sublabel,
                style: TextStyle(
                    color: color.withValues(alpha: 0.7),
                    fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

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