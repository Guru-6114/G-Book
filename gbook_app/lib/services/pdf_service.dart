// lib/services/pdf_service.dart
//
// FIX 3 — all ₹ replaced with Rs. inside PDF content because the default
// base-14 PDF fonts don't contain U+20B9 (Rupee sign).

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/models.dart';
import '../utils/helpers.dart';

class PdfService {
  PdfService._();
  static final PdfService instance = PdfService._();

  /// Format for PDF — Rs. instead of ₹
  String _pdfAmt(double v) => 'Rs. ${v.toStringAsFixed(2)}';

  Future<Uint8List> _buildPdf({
    required String partyName,
    String? phone,
    required double balance,
    required List<CustomerTransaction> transactions,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final pdf = pw.Document();

    final totalGiven = transactions
        .where((t) => t.isGiven)
        .fold(0.0, (s, t) => s + t.amount);
    final totalGot = transactions
        .where((t) => !t.isGiven)
        .fold(0.0, (s, t) => s + t.amount);

    final dateRange = (startDate != null || endDate != null)
        ? '${startDate != null ? AppHelpers.formatDate(startDate) : "All"} - ${endDate != null ? AppHelpers.formatDate(endDate) : "All"}'
        : 'All dates';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          // Header
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFF1A6B3C),
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'GBook - Account Statement',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Party: $partyName${phone != null && phone.isNotEmpty ? "  |  $phone" : ""}',
                  style: pw.TextStyle(color: PdfColors.white, fontSize: 12),
                ),
                pw.Text(
                  'Period: $dateRange',
                  style: pw.TextStyle(color: PdfColors.white, fontSize: 11),
                ),
                pw.Text(
                  'Generated: ${AppHelpers.formatDate(DateTime.now())}',
                  style: pw.TextStyle(color: PdfColors.white, fontSize: 11),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // Summary — FIX: Rs. not ₹
          pw.Row(
            children: [
              _summaryBox('Net Balance',
                  _pdfAmt(balance.abs()),
                  balance >= 0 ? PdfColors.green800 : PdfColors.red800),
              pw.SizedBox(width: 8),
              _summaryBox('You Gave', _pdfAmt(totalGiven), PdfColors.red800),
              pw.SizedBox(width: 8),
              _summaryBox('You Got', _pdfAmt(totalGot), PdfColors.green800),
            ],
          ),
          pw.SizedBox(height: 16),

          pw.Text('${transactions.length} Entries',
              style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold, fontSize: 12)),
          pw.SizedBox(height: 8),

          pw.Table(
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(1.5),
              3: const pw.FlexColumnWidth(1.5),
            },
            children: [
              // Header
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _cell('DATE', isHeader: true),
                  _cell('NOTE', isHeader: true),
                  // FIX: column headers don't use rupee symbol — just labels
                  _cell('YOU GAVE',
                      isHeader: true, align: pw.TextAlign.right),
                  _cell('YOU GOT',
                      isHeader: true, align: pw.TextAlign.right),
                ],
              ),
              // Data rows — FIX: Rs. not ₹
              ...transactions.map((t) => pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: transactions.indexOf(t) % 2 == 0
                          ? PdfColors.white
                          : PdfColors.grey50,
                    ),
                    children: [
                      _cell(AppHelpers.formatDate(t.date)),
                      _cell(t.note ?? t.paymentMode.toUpperCase()),
                      _cell(
                        t.isGiven ? _pdfAmt(t.amount) : '',
                        color: PdfColors.red700,
                        align: pw.TextAlign.right,
                      ),
                      _cell(
                        !t.isGiven ? _pdfAmt(t.amount) : '',
                        color: PdfColors.green700,
                        align: pw.TextAlign.right,
                      ),
                    ],
                  )),
              // Totals — FIX: Rs. not ₹
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _cell('TOTAL', isHeader: true),
                  _cell(''),
                  _cell(_pdfAmt(totalGiven),
                      isHeader: true,
                      color: PdfColors.red700,
                      align: pw.TextAlign.right),
                  _cell(_pdfAmt(totalGot),
                      isHeader: true,
                      color: PdfColors.green700,
                      align: pw.TextAlign.right),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 24),
          pw.Divider(),
          pw.SizedBox(height: 8),
          pw.Text(
            'Generated by GBook - Digital Khata for Your Business',
            style: pw.TextStyle(color: PdfColors.grey500, fontSize: 10),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _summaryBox(String label, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label,
                style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
            pw.SizedBox(height: 3),
            pw.Text(value,
                style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: color)),
          ],
        ),
      ),
    );
  }

  pw.Widget _cell(
    String text, {
    bool isHeader = false,
    PdfColor? color,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: isHeader ? 10 : 11,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color ?? PdfColors.black,
        ),
      ),
    );
  }

  Future<File> _saveToTemp(Uint8List bytes, String partyName) async {
    final dir = await getTemporaryDirectory();
    final safeName = partyName.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/GBook_${safeName}_$timestamp.pdf');
    await file.writeAsBytes(bytes);
    return file;
  }

  Future<void> downloadPdf(
    BuildContext context, {
    required String partyName,
    String? phone,
    required double balance,
    required List<CustomerTransaction> transactions,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final bytes = await _buildPdf(
        partyName: partyName,
        phone: phone,
        balance: balance,
        transactions: transactions,
        startDate: startDate,
        endDate: endDate,
      );

      if (!context.mounted) return;

      final file = await _saveToTemp(bytes, partyName);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf')],
        subject: 'GBook Report - $partyName',
        text: 'Account statement for $partyName',
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate PDF: $e')),
      );
    }
  }

  Future<void> shareOnWhatsApp(
    BuildContext context, {
    required String partyName,
    String? phone,
    required double balance,
    required List<CustomerTransaction> transactions,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final bytes = await _buildPdf(
        partyName: partyName,
        phone: phone,
        balance: balance,
        transactions: transactions,
        startDate: startDate,
        endDate: endDate,
      );

      if (!context.mounted) return;

      final file = await _saveToTemp(bytes, partyName);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf')],
        subject: 'GBook Report - $partyName',
        text: 'Hi $partyName, please find your account statement attached.\n'
            'Net Balance: ${_pdfAmt(balance.abs())}\n'
            'Sent via GBook',
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to share: $e')),
      );
    }
  }
}