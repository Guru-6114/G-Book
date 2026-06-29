// lib/services/pdf_service.dart
// Full working PDF generation and share for supplier/customer reports
// Uses only packages already available or easily added: pdf + path_provider + share_plus
// pubspec.yaml additions needed:
//   pdf: ^3.11.1
//   path_provider: ^2.1.4
//   share_plus: ^10.1.2

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

  // ── Build PDF bytes ──────────────────────────────────────────────────────
  Future<Uint8List> _buildPdf({
    required String partyName,
    String? phone,
    required double balance,
    required List<CustomerTransaction> transactions,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final pdf = pw.Document();

    final totalGiven =
        transactions.where((t) => t.isGiven).fold(0.0, (s, t) => s + t.amount);
    final totalGot = transactions
        .where((t) => !t.isGiven)
        .fold(0.0, (s, t) => s + t.amount);

    final dateRange = (startDate != null || endDate != null)
        ? '${startDate != null ? AppHelpers.formatDate(startDate) : "All"} — ${endDate != null ? AppHelpers.formatDate(endDate) : "All"}'
        : 'All dates';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          // ── Header ──────────────────────────────────────────────────────
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
                  'GBook — Account Statement',
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

          // ── Summary ──────────────────────────────────────────────────────
          pw.Row(
            children: [
              _summaryBox('Net Balance',
                  'Rs. ${balance.abs().toStringAsFixed(2)}',
                  balance >= 0 ? PdfColors.green800 : PdfColors.red800),
              pw.SizedBox(width: 8),
              _summaryBox(
                  'You Gave', 'Rs. ${totalGiven.toStringAsFixed(2)}', PdfColors.red800),
              pw.SizedBox(width: 8),
              _summaryBox(
                  'You Got', 'Rs. ${totalGot.toStringAsFixed(2)}', PdfColors.green800),
            ],
          ),
          pw.SizedBox(height: 16),

          // ── Table header ─────────────────────────────────────────────────
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
              // Header row
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _cell('DATE', isHeader: true),
                  _cell('NOTE', isHeader: true),
                  _cell('YOU GAVE', isHeader: true, align: pw.TextAlign.right),
                  _cell('YOU GOT', isHeader: true, align: pw.TextAlign.right),
                ],
              ),
              // Data rows
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
                        t.isGiven
                            ? 'Rs. ${t.amount.toStringAsFixed(2)}'
                            : '',
                        color: PdfColors.red700,
                        align: pw.TextAlign.right,
                      ),
                      _cell(
                        !t.isGiven
                            ? 'Rs. ${t.amount.toStringAsFixed(2)}'
                            : '',
                        color: PdfColors.green700,
                        align: pw.TextAlign.right,
                      ),
                    ],
                  )),
              // Totals row
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _cell('TOTAL', isHeader: true),
                  _cell(''),
                  _cell('Rs. ${totalGiven.toStringAsFixed(2)}',
                      isHeader: true,
                      color: PdfColors.red700,
                      align: pw.TextAlign.right),
                  _cell('Rs. ${totalGot.toStringAsFixed(2)}',
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
            'Generated by GBook — Digital Khata for Your Business',
            style: pw.TextStyle(
                color: PdfColors.grey500, fontSize: 10),
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

  // ── Save to temp file ────────────────────────────────────────────────────
  Future<File> _saveToTemp(Uint8List bytes, String partyName) async {
    final dir = await getTemporaryDirectory();
    final safeName = partyName.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/GBook_${safeName}_$timestamp.pdf');
    await file.writeAsBytes(bytes);
    return file;
  }

  // ── Public: Download PDF ─────────────────────────────────────────────────
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

      // Save + share so user can save to Downloads via OS share sheet
      final file = await _saveToTemp(bytes, partyName);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf')],
        subject: 'GBook Report — $partyName',
        text: 'Account statement for $partyName',
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate PDF: $e')),
      );
    }
  }

  // ── Public: Share on WhatsApp / any app ─────────────────────────────────
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
        subject: 'GBook Report — $partyName',
        text: 'Hi $partyName, please find your account statement attached.\n'
            'Net Balance: Rs. ${balance.abs().toStringAsFixed(2)}\n'
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