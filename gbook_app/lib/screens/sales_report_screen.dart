// lib/screens/sales_report_screen.dart
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
import '../providers/locale_provider.dart';
import '../utils/helpers.dart';
import '../theme/app_theme.dart';

// ─── Period helper ────────────────────────────────────────────────────────────
enum _Period { thisMonth, lastMonth, thisYear, custom }

extension _PeriodLabel on _Period {
  String label(LocaleProvider loc) {
    switch (this) {
      case _Period.thisMonth:
        return loc.tr('period_this_month');
      case _Period.lastMonth:
        return loc.tr('period_last_month');
      case _Period.thisYear:
        return loc.tr('period_this_year');
      case _Period.custom:
        return loc.tr('period_custom');
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

  String _title(LocaleProvider loc) =>
      widget.isSales ? loc.tr('sales_report') : loc.tr('purchase_report');

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
    final loc = context.read<LocaleProvider>();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(loc.tr('select_period'),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
          ..._Period.values.map((p) => ListTile(
                title: Text(p.label(loc)),
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

  String _fmtAmt(double v) {
    final sign = v < 0 ? '-' : '';
    final av = v.abs();
    if (av >= 10000000) return '${sign}₹${(av / 10000000).toStringAsFixed(2)} Cr';
    if (av >= 100000) return '${sign}₹${(av / 100000).toStringAsFixed(2)} L';
    return '${sign}₹${av.toStringAsFixed(2)}';
  }

  Future<Uint8List> _buildPdf(
      List<Bill> bills, dynamic profile, LocaleProvider loc) async {
    final pdf = pw.Document();
    final businessName = profile?.businessName ?? 'My Business';
    final address = profile?.address ?? '';
    final phone = profile?.phone ?? '';
    final net = _netAmount(bills);
    final unpaid = _unpaidBalance(bills);
    final label = widget.isSales ? loc.tr('net_sale') : loc.tr('net_purchase');
    final rangeStr =
        '${_fullDateFmt.format(_range.start)} - ${_fullDateFmt.format(_range.end)}';
    final title = _title(loc);

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
                pw.Text(title,
                    style: pw.TextStyle(
                        fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.Text('Period: $rangeStr',
                    style: const pw.TextStyle(
                        fontSize: 10, color: PdfColors.grey700)),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Row(
              children: [
                _pdfStat(loc.tr('transactions'), '${bills.length}',
                    PdfColors.grey800),
                pw.SizedBox(width: 12),
                _pdfStat(label, _fmtAmtPdf(net), PdfColors.green800),
                pw.SizedBox(width: 12),
                _pdfStat(loc.tr('unpaid_balance'), _fmtAmtPdf(unpaid),
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
          ...bills.map((b) {
            final isReturn = b.billType == BillType.saleReturn ||
                b.billType == BillType.purchaseReturn;
            final statusColor =
                b.isPaid ? PdfColors.green800 : PdfColors.red700;
            final statusLabel = b.isPaid
                ? loc.tr('fully_paid')
                : b.paidAmount > 0
                    ? loc.tr('partial')
                    : loc.tr('unpaid');
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
                        pw.Text(loc.tr('return_suffix'),
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
          pw.Container(
            color: PdfColors.grey100,
            padding: const pw.EdgeInsets.all(10),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('$label: ${_fmtAmtPdf(net)}',
                    style: pw.TextStyle(
                        fontSize: 12, fontWeight: pw.FontWeight.bold)),
                pw.Text('${loc.tr('unpaid_balance')}: ${_fmtAmtPdf(unpaid)}',
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
    final loc = context.read<LocaleProvider>();
    setState(() => _isDownloading = true);
    try {
      final bytes = await _buildPdf(bills, profile, loc);
      final file = await _savePdf(bytes);
      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf')],
        subject: _title(loc),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(loc.trParams('failed_with_error',
                {'error': e.toString()}))));
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _shareWhatsApp(List<Bill> bills, dynamic profile) async {
    if (_isSharing) return;
    final loc = context.read<LocaleProvider>();
    setState(() => _isSharing = true);
    try {
      final bytes = await _buildPdf(bills, profile, loc);
      final file = await _savePdf(bytes);
      if (!mounted) return;

      final whatsappUri = Uri.parse('whatsapp://send?text=');
      final canWhatsApp = await canLaunchUrl(whatsappUri);
      final title = _title(loc);

      if (canWhatsApp) {
        await Share.shareXFiles(
          [XFile(file.path, mimeType: 'application/pdf')],
          subject: title,
          text:
              '$title\nPeriod: ${_fullDateFmt.format(_range.start)} - ${_fullDateFmt.format(_range.end)}',
        );
      } else {
        await Share.shareXFiles(
          [XFile(file.path, mimeType: 'application/pdf')],
          subject: title,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(loc.tr('whatsapp_not_found'))));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(loc.trParams('failed_with_error',
                {'error': e.toString()}))));
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleProvider>();
    final billProvider = context.watch<BillProvider>();
    final auth = context.watch<AuthProvider>();
    final bills = _filteredBills(billProvider.bills);
    final net = _netAmount(bills);
    final unpaid = _unpaidBalance(bills);
    final label = widget.isSales ? loc.tr('net_sale') : loc.tr('net_purchase');
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
        title: Text(_title(loc),
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
                              _period.label(loc),
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
                    child: _DateBox(
                        label: loc.tr('start_date'), date: rangeStart),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: GestureDetector(
                    onTap: _pickCustomRange,
                    child:
                        _DateBox(label: loc.tr('end_date'), date: rangeEnd),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // ── Stats row ────────────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: _StatChip(
                      label: loc.tr('transactions'),
                      value: '${bills.length}',
                      valueColor: Colors.black87),
                ),
                Expanded(
                  child: _StatChip(
                    label: label,
                    value: _fmtAmt(net),
                    valueColor: net < 0
                        ? const Color(0xFFB71C1C)
                        : const Color(0xFF2E7D32),
                  ),
                ),
                Expanded(
                  child: _StatChip(
                      label: loc.tr('unpaid_balance'),
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
                          widget.isSales
                              ? loc.tr('no_sales_in_period')
                              : loc.tr('no_purchases_in_period'),
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
                      children: [
                        Text(loc.tr('download_label'),
                            style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                letterSpacing: 0.5)),
                        Text(loc.tr('download_sub'),
                            style: const TextStyle(fontSize: 10)),
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
                      children: [
                        Text(loc.tr('share_label'),
                            style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                letterSpacing: 0.5)),
                        Text(loc.tr('share_sub'),
                            style: const TextStyle(fontSize: 10)),
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

  String _typeLabel(LocaleProvider loc) {
    switch (bill.billType) {
      case BillType.sale:
        return loc.tr('sale_bill');
      case BillType.purchase:
        return loc.tr('purchase_bill');
      case BillType.saleReturn:
        return loc.tr('sale_return');
      case BillType.purchaseReturn:
        return loc.tr('purchase_return');
      default:
        return loc.tr('bill_label');
    }
  }

  static final _dateFmt = DateFormat('dd MMM yy');

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleProvider>();
    final isPaid = bill.isPaid;
    final isPartial = !isPaid && bill.paidAmount > 0;
    final statusColor = isPaid
        ? const Color(0xFF2E7D32)
        : isPartial
            ? const Color(0xFFF97316)
            : const Color(0xFFB71C1C);
    final statusLabel = isPaid
        ? loc.tr('fully_paid')
        : isPartial
            ? loc.tr('partial')
            : loc.tr('unpaid');

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
                      : _typeLabel(loc),
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