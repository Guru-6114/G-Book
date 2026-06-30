// lib/screens/sales_report_screen.dart
//
// FIX 4 — Correct Net Sale / Net Purchase and Unpaid Balance:
//
// NET SALE / NET PURCHASE:
//   = Sum of original bills - Sum of returns
//   e.g. 3 sales (₹50 each = ₹150) - 6 returns (₹30 each = ₹180) = -₹30
//   This is mathematically correct and matches real Khatabook behavior.
//
// UNPAID BALANCE:
//   Only considers ORIGINAL bills (sale/purchase), NOT returns.
//   Returns are always recorded as fully paid (paidAmount == grandTotal)
//   so they never contribute to unpaid balance.
//   Formula: sum of balanceDue for non-return bills only.
//
// FIX 3 — PDF currency: uses "Rs." instead of "₹" inside generated PDFs
// because base-14 PDF fonts lack U+20B9.

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/helpers.dart';
import '../theme/app_theme.dart';

// ─── Period helper ────────────────────────────────────────────────────────────
enum _Period { thisMonth, lastMonth, thisYear, custom }

extension _PeriodLabel on _Period {
  String get label {
    switch (this) {
      case _Period.thisMonth:
        return 'This Month';
      case _Period.lastMonth:
        return 'Last Month';
      case _Period.thisYear:
        return 'This Year';
      case _Period.custom:
        return 'Custom';
    }
  }
}

DateTimeRange _rangeFor(_Period p, {DateTimeRange? custom}) {
  final now = DateTime.now();
  switch (p) {
    case _Period.thisMonth:
      return DateTimeRange(
        start: DateTime(now.year, now.month, 1),
        end: DateTime(now.year, now.month + 1, 0, 23, 59, 59),
      );
    case _Period.lastMonth:
      final first = DateTime(now.year, now.month - 1, 1);
      final last = DateTime(now.year, now.month, 0, 23, 59, 59);
      return DateTimeRange(start: first, end: last);
    case _Period.thisYear:
      return DateTimeRange(
        start: DateTime(now.year, 1, 1),
        end: DateTime(now.year, 12, 31, 23, 59, 59),
      );
    case _Period.custom:
      return custom ??
          DateTimeRange(
            start: DateTime(now.year, now.month, 1),
            end: now,
          );
  }
}

// ─── Main screen ─────────────────────────────────────────────────────────────
class SalesReportScreen extends StatefulWidget {
  final bool isSales;
  const SalesReportScreen({super.key, required this.isSales});

  @override
  State<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends State<SalesReportScreen> {
  _Period _period = _Period.thisMonth;
  DateTimeRange? _customRange;
  bool _isDownloading = false;
  bool _isSharing = false;

  static final _dateFmt = DateFormat('dd MMM yy');
  static final _fullDateFmt = DateFormat('dd MMM yyyy');

  String get _title => widget.isSales ? 'Sales Report' : 'Purchase Report';

  DateTimeRange get _range => _rangeFor(_period, custom: _customRange);

  List<Bill> _filteredBills(List<Bill> all) {
    final types = widget.isSales
        ? [BillType.sale, BillType.saleReturn]
        : [BillType.purchase, BillType.purchaseReturn];
    return all
        .where((b) =>
            types.contains(b.billType) &&
            !b.date.isBefore(_range.start) &&
            !b.date.isAfter(_range.end))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  // ── FIX 4: Net Sale / Net Purchase ────────────────────────────────────────
  // Net = (sum of original bills) - (sum of return bills)
  // This gives a negative number when returns exceed sales — which is correct.
  double _netAmount(List<Bill> bills) {
    double total = 0;
    for (final b in bills) {
      final isReturn = b.billType == BillType.saleReturn ||
          b.billType == BillType.purchaseReturn;
      if (isReturn) {
        total -= b.grandTotal;
      } else {
        total += b.grandTotal;
      }
    }
    return total;
  }

  // ── FIX 4: Unpaid Balance ─────────────────────────────────────────────────
  // Only counts balanceDue on ORIGINAL bills (sale/purchase).
  // Returns are always created with paidAmount == grandTotal, so they
  // contribute 0 to balanceDue — but we explicitly skip them to be safe.
  // Never goes below 0.
  double _unpaidBalance(List<Bill> bills) {
    double total = 0;
    for (final b in bills) {
      final isReturn = b.billType == BillType.saleReturn ||
          b.billType == BillType.purchaseReturn;
      if (!isReturn) {
        total += b.balanceDue;
      }
    }
    return total < 0 ? 0 : total;
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _customRange ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 30)),
            end: DateTime.now(),
          ),
    );
    if (picked != null && mounted) {
      setState(() {
        _period = _Period.custom;
        _customRange = DateTimeRange(
          start: picked.start,
          end: DateTime(
              picked.end.year, picked.end.month, picked.end.day, 23, 59, 59),
        );
      });
    }
  }

  void _showPeriodPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Select Period',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
          ..._Period.values.map((p) => ListTile(
                title: Text(p.label),
                trailing: _period == p
                    ? Icon(Icons.check, color: AppTheme.primaryColor)
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  if (p == _Period.custom) {
                    _pickCustomRange();
                  } else {
                    setState(() => _period = p);
                  }
                },
              )),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── FIX 3: PDF amount formatter uses "Rs." not "₹" ─────────────────────
  String _fmtAmtPdf(double v) {
    final sign = v < 0 ? '-' : '';
    final av = v.abs();
    if (av >= 10000000) {
      return 'Rs. $sign${(av / 10000000).toStringAsFixed(2)} Cr';
    }
    if (av >= 100000) {
      return 'Rs. $sign${(av / 100000).toStringAsFixed(2)} L';
    }
    return 'Rs. $sign${av.toStringAsFixed(2)}';
  }

  // On-screen amount formatter — keeps ₹ (Flutter renders it fine)
  String _fmtAmt(double v) {
    final sign = v < 0 ? '-' : '';
    final av = v.abs();
    if (av >= 10000000) return '${sign}₹${(av / 10000000).toStringAsFixed(2)} Cr';
    if (av >= 100000) return '${sign}₹${(av / 100000).toStringAsFixed(2)} L';
    return '${sign}₹${av.toStringAsFixed(2)}';
  }

  Future<Uint8List> _buildPdf(List<Bill> bills, dynamic profile) async {
    final pdf = pw.Document();
    final businessName = profile?.businessName ?? 'My Business';
    final address = profile?.address ?? '';
    final phone = profile?.phone ?? '';
    final net = _netAmount(bills);
    final unpaid = _unpaidBalance(bills);
    final label = widget.isSales ? 'NET SALE' : 'NET PURCHASE';
    final rangeStr =
        '${_fullDateFmt.format(_range.start)} - ${_fullDateFmt.format(_range.end)}';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(14),
              decoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFF1A6B3C),
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(businessName,
                      style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold)),
                  if (address.isNotEmpty)
                    pw.Text(address,
                        style: const pw.TextStyle(
                            color: PdfColors.white, fontSize: 10)),
                  if (phone.isNotEmpty)
                    pw.Text('Phone: $phone',
                        style: const pw.TextStyle(
                            color: PdfColors.white, fontSize: 10)),
                ],
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(_title,
                    style: pw.TextStyle(
                        fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.Text('Period: $rangeStr',
                    style: const pw.TextStyle(
                        fontSize: 10, color: PdfColors.grey700)),
              ],
            ),
            pw.SizedBox(height: 8),
            // FIX 3: all amounts use Rs. not ₹
            pw.Row(
              children: [
                _pdfStat('TRANSACTIONS', '${bills.length}', PdfColors.grey800),
                pw.SizedBox(width: 12),
                _pdfStat(label, _fmtAmtPdf(net), PdfColors.green800),
                pw.SizedBox(width: 12),
                _pdfStat('UNPAID BALANCE', _fmtAmtPdf(unpaid),
                    PdfColors.green800),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Divider(),
            pw.SizedBox(height: 4),
          ],
        ),
        footer: (ctx) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              style: const pw.TextStyle(
                  fontSize: 9, color: PdfColors.grey500)),
        ),
        build: (ctx) => [
          // Table header
          pw.Container(
            color: PdfColors.grey200,
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: pw.Row(children: [
              pw.Expanded(
                  flex: 2,
                  child: _pdfCell('PARTY / BILL NO', bold: true)),
              pw.Expanded(child: _pdfCell('DATE', bold: true)),
              pw.Expanded(
                  child: _pdfCell('AMOUNT',
                      bold: true, align: pw.TextAlign.right)),
              pw.SizedBox(
                  width: 64,
                  child: _pdfCell('STATUS',
                      bold: true, align: pw.TextAlign.center)),
            ]),
          ),
          // Rows — FIX 3: use _fmtAmtPdf
          ...bills.map((b) {
            final isReturn = b.billType == BillType.saleReturn ||
                b.billType == BillType.purchaseReturn;
            final statusColor =
                b.isPaid ? PdfColors.green800 : PdfColors.red700;
            final statusLabel = b.isPaid
                ? 'Fully Paid'
                : b.paidAmount > 0
                    ? 'Partial'
                    : 'Unpaid';
            return pw.Container(
              decoration: const pw.BoxDecoration(
                  border: pw.Border(
                      bottom: pw.BorderSide(color: PdfColors.grey300))),
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              child: pw.Row(children: [
                pw.Expanded(
                  flex: 2,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        b.partyName?.isNotEmpty == true ? b.partyName! : '-',
                        style: pw.TextStyle(
                            fontSize: 11, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(b.billNumber,
                          style: const pw.TextStyle(
                              fontSize: 9, color: PdfColors.grey600)),
                      if (isReturn)
                        pw.Text('(Return)',
                            style: const pw.TextStyle(
                                fontSize: 9, color: PdfColors.orange700)),
                    ],
                  ),
                ),
                pw.Expanded(
                    child: _pdfCell(_dateFmt.format(b.date), size: 10)),
                pw.Expanded(
                  child: _pdfCell(
                    _fmtAmtPdf(b.grandTotal),
                    align: pw.TextAlign.right,
                    bold: true,
                    size: 11,
                  ),
                ),
                pw.SizedBox(
                  width: 64,
                  child: pw.Text(statusLabel,
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                          fontSize: 10,
                          color: statusColor,
                          fontWeight: pw.FontWeight.bold)),
                ),
              ]),
            );
          }),
          pw.SizedBox(height: 16),
          // Totals — FIX 3: Rs.
          pw.Container(
            color: PdfColors.grey100,
            padding: const pw.EdgeInsets.all(10),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('$label: ${_fmtAmtPdf(net)}',
                    style: pw.TextStyle(
                        fontSize: 12, fontWeight: pw.FontWeight.bold)),
                pw.Text('Unpaid: ${_fmtAmtPdf(unpaid)}',
                    style: pw.TextStyle(
                        fontSize: 12, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Divider(),
          pw.Text('Generated by GBook',
              style: const pw.TextStyle(
                  fontSize: 9, color: PdfColors.grey500)),
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _pdfStat(String label, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label,
                style: const pw.TextStyle(
                    fontSize: 8, color: PdfColors.grey600)),
            pw.SizedBox(height: 2),
            pw.Text(value,
                style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: color)),
          ],
        ),
      ),
    );
  }

  pw.Widget _pdfCell(String text,
      {bool bold = false,
      pw.TextAlign align = pw.TextAlign.left,
      double size = 11}) {
    return pw.Text(text,
        textAlign: align,
        style: pw.TextStyle(
            fontSize: size,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal));
  }

  Future<File> _savePdf(Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final name = widget.isSales ? 'Sales_Report' : 'Purchase_Report';
    final file = File(
        '${dir.path}/${name}_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(bytes);
    return file;
  }

  Future<void> _downloadPdf(List<Bill> bills, dynamic profile) async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);
    try {
      final bytes = await _buildPdf(bills, profile);
      final file = await _savePdf(bytes);
      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf')],
        subject: _title,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _shareWhatsApp(List<Bill> bills, dynamic profile) async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    try {
      final bytes = await _buildPdf(bills, profile);
      final file = await _savePdf(bytes);
      if (!mounted) return;

      final whatsappUri = Uri.parse('whatsapp://send?text=');
      final canWhatsApp = await canLaunchUrl(whatsappUri);

      if (canWhatsApp) {
        await Share.shareXFiles(
          [XFile(file.path, mimeType: 'application/pdf')],
          subject: _title,
          text:
              '$_title\nPeriod: ${_fullDateFmt.format(_range.start)} - ${_fullDateFmt.format(_range.end)}',
        );
      } else {
        await Share.shareXFiles(
          [XFile(file.path, mimeType: 'application/pdf')],
          subject: _title,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content:
                  Text('WhatsApp not found. Sharing via other apps.')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final billProvider = context.watch<BillProvider>();
    final auth = context.watch<AuthProvider>();
    final bills = _filteredBills(billProvider.bills);
    // FIX 4: use corrected calculation methods
    final net = _netAmount(bills);
    final unpaid = _unpaidBalance(bills);
    final label = widget.isSales ? 'NET SALE' : 'NET PURCHASE';
    final rangeStart =
        _fullDateFmt.format(_range.start).toUpperCase();
    final rangeEnd = _fullDateFmt.format(_range.end).toUpperCase();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(_title,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 17)),
        elevation: 0,
      ),
      body: Column(
        children: [
          // ── Period selector row ──────────────────────────────────────────
          Container(
            color: Colors.white,
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: GestureDetector(
                    onTap: _showPeriodPicker,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE0E0E0)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              _period.label,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.keyboard_arrow_down, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: GestureDetector(
                    onTap: _pickCustomRange,
                    child: _DateBox(label: 'Start Date', date: rangeStart),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: GestureDetector(
                    onTap: _pickCustomRange,
                    child: _DateBox(label: 'End Date', date: rangeEnd),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // ── Stats row — FIX 4: uses corrected _fmtAmt ──────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: _StatChip(
                      label: 'TRANSACTIONS',
                      value: '${bills.length}',
                      valueColor: Colors.black87),
                ),
                Expanded(
                  child: _StatChip(
                    label: label,
                    value: _fmtAmt(net),
                    // FIX 4: show red when net is negative (more returns than sales)
                    valueColor: net < 0
                        ? const Color(0xFFB71C1C)
                        : const Color(0xFF2E7D32),
                  ),
                ),
                Expanded(
                  child: _StatChip(
                      label: 'UNPAID BALANCE',
                      value: _fmtAmt(unpaid),
                      valueColor: unpaid > 0
                          ? const Color(0xFFB71C1C)
                          : const Color(0xFF2E7D32)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // ── Bill list ────────────────────────────────────────────────────
          Expanded(
            child: bills.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.isSales
                              ? Icons.receipt_long_outlined
                              : Icons.shopping_cart_outlined,
                          size: 56,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No ${widget.isSales ? "sales" : "purchases"} in this period',
                          style: const TextStyle(
                              fontSize: 14, color: Color(0xFF9E9E9E)),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: bills.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 72),
                    itemBuilder: (_, i) =>
                        _ReportBillTile(bill: bills[i]),
                  ),
          ),

          // ── Bottom buttons ───────────────────────────────────────────────
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
                  child: ElevatedButton.icon(
                    onPressed: _isDownloading
                        ? null
                        : () => _downloadPdf(bills, auth.profile),
                    icon: _isDownloading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.download, size: 18),
                    label: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text('DOWNLOAD',
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                letterSpacing: 0.5)),
                        Text('PDF, EXCEL',
                            style: TextStyle(fontSize: 10)),
                      ],
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      foregroundColor: Colors.white,
                      padding:
                          const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSharing
                        ? null
                        : () => _shareWhatsApp(bills, auth.profile),
                    icon: _isSharing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.share, size: 18),
                    label: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text('SHARE',
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                letterSpacing: 0.5)),
                        Text('WHATSAPP & OTHERS',
                            style: TextStyle(fontSize: 10)),
                      ],
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      foregroundColor: Colors.white,
                      padding:
                          const EdgeInsets.symmetric(vertical: 13),
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

// ── Helper widgets ────────────────────────────────────────────────────────────
class _DateBox extends StatelessWidget {
  final String label;
  final String date;
  const _DateBox({required this.label, required this.date});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE0E0E0)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_month_outlined,
                  size: 14, color: Color(0xFF9E9E9E)),
              const SizedBox(width: 4),
              Flexible(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 10, color: Color(0xFF9E9E9E)),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(date,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
              maxLines: 1),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  const _StatChip(
      {required this.label,
      required this.value,
      required this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF757575),
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3),
            overflow: TextOverflow.ellipsis,
            maxLines: 1),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: valueColor),
            overflow: TextOverflow.ellipsis,
            maxLines: 1),
      ],
    );
  }
}

class _ReportBillTile extends StatelessWidget {
  final Bill bill;
  const _ReportBillTile({required this.bill});

  IconData get _icon {
    switch (bill.billType) {
      case BillType.sale:
        return Icons.receipt_long;
      case BillType.purchase:
        return Icons.shopping_cart_outlined;
      case BillType.saleReturn:
      case BillType.purchaseReturn:
        return Icons.assignment_return_outlined;
      default:
        return Icons.receipt;
    }
  }

  Color get _iconColor {
    switch (bill.billType) {
      case BillType.saleReturn:
      case BillType.purchaseReturn:
        return const Color(0xFFF97316);
      default:
        return const Color(0xFF1565C0);
    }
  }

  String get _typeLabel {
    switch (bill.billType) {
      case BillType.sale:
        return 'Sale Bill';
      case BillType.purchase:
        return 'Purchase Bill';
      case BillType.saleReturn:
        return 'Sale Return';
      case BillType.purchaseReturn:
        return 'Purchase Return';
      default:
        return 'Bill';
    }
  }

  static final _dateFmt = DateFormat('dd MMM yy');

  @override
  Widget build(BuildContext context) {
    final isPaid = bill.isPaid;
    final isPartial = !isPaid && bill.paidAmount > 0;
    final statusColor = isPaid
        ? const Color(0xFF2E7D32)
        : isPartial
            ? const Color(0xFFF97316)
            : const Color(0xFFB71C1C);
    final statusLabel =
        isPaid ? 'Fully Paid' : isPartial ? 'Partial' : 'Unpaid';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _iconColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(_icon, color: _iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bill.partyName?.isNotEmpty == true
                      ? bill.partyName!
                      : _typeLabel,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: Color(0xFF212121)),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F0F0),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(bill.billNumber,
                          style: const TextStyle(
                              fontSize: 10, color: Color(0xFF616161))),
                    ),
                    const SizedBox(width: 6),
                    Text(_dateFmt.format(bill.date),
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF9E9E9E))),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹ ${bill.grandTotal.toStringAsFixed(0)}',
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: Color(0xFF212121)),
              ),
              const SizedBox(height: 3),
              Text(statusLabel,
                  style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}