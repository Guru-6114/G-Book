// lib/services/statement_pdf_service.dart
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

class StatementRow {
  final DateTime date;
  final double youGave;
  final double youGot;
  final String paymentMode;
  final String? note;

  StatementRow({
    required this.date,
    required this.youGave,
    required this.youGot,
    required this.paymentMode,
    this.note,
  });
}

class StatementPdfService {
  StatementPdfService._();

  static final _dateFmt = DateFormat('dd MMM yyyy');

  static Future<List<int>> buildPdf({
    required String businessName,
    String? businessAddress,
    String? businessPhone,
    required String partyName,
    String? partyPhone,
    required double netBalance,
    required bool partyWillGive,
    required List<StatementRow> rows,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final doc = pw.Document();

    final totalGiven = rows.fold(0.0, (s, r) => s + r.youGave);
    final totalReceived = rows.fold(0.0, (s, r) => s + r.youGot);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              businessName,
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            if (businessAddress != null && businessAddress.isNotEmpty)
              pw.Text(businessAddress, style: const pw.TextStyle(fontSize: 10)),
            if (businessPhone != null && businessPhone.isNotEmpty)
              pw.Text('Phone: $businessPhone', style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: 12),
            pw.Divider(),
            pw.SizedBox(height: 6),
            pw.Text(
              'Statement of Account',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Text('Party: $partyName', style: const pw.TextStyle(fontSize: 11)),
            if (partyPhone != null && partyPhone.isNotEmpty)
              pw.Text('Phone: $partyPhone', style: const pw.TextStyle(fontSize: 11)),
            if (startDate != null || endDate != null)
              pw.Text(
                'Period: ${startDate != null ? _dateFmt.format(startDate) : 'Start'} '
                '- ${endDate != null ? _dateFmt.format(endDate) : 'Today'}',
                style: const pw.TextStyle(fontSize: 10),
              ),
            pw.SizedBox(height: 10),
          ],
        ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ),
        build: (context) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Net Balance',
                    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                pw.Text(
                  '₹ ${netBalance.abs().toStringAsFixed(2)} '
                  '(${partyWillGive ? "Party will give" : "Party will get"})',
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 14),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            columnWidths: const {
              0: pw.FlexColumnWidth(2.2),
              1: pw.FlexColumnWidth(1.5),
              2: pw.FlexColumnWidth(1.5),
              3: pw.FlexColumnWidth(1.6),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  _cell('Date', bold: true),
                  _cell('You Gave', bold: true, align: pw.TextAlign.right),
                  _cell('You Got', bold: true, align: pw.TextAlign.right),
                  _cell('Mode / Note', bold: true),
                ],
              ),
              ...rows.map((r) => pw.TableRow(
                    children: [
                      _cell(_dateFmt.format(r.date)),
                      _cell(r.youGave > 0 ? r.youGave.toStringAsFixed(2) : '-',
                          align: pw.TextAlign.right),
                      _cell(r.youGot > 0 ? r.youGot.toStringAsFixed(2) : '-',
                          align: pw.TextAlign.right),
                      _cell(
                        r.note != null && r.note!.isNotEmpty
                            ? '${r.paymentMode.toUpperCase()} • ${r.note}'
                            : r.paymentMode.toUpperCase(),
                      ),
                    ],
                  )),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Total You Gave: ₹ ${totalGiven.toStringAsFixed(2)}',
                  style: const pw.TextStyle(fontSize: 11)),
              pw.Text('Total You Got: ₹ ${totalReceived.toStringAsFixed(2)}',
                  style: const pw.TextStyle(fontSize: 11)),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            'Generated via GBook',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _cell(String text,
      {bool bold = false, pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 9.5,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static String _safeFileName(String partyName) {
    final cleaned = partyName.replaceAll(RegExp(r'[^A-Za-z0-9_\-]+'), '_');
    final stamp = DateTime.now().millisecondsSinceEpoch;
    return 'Statement_${cleaned}_$stamp.pdf';
  }

  /// Saves the PDF bytes to the device's app documents directory and
  /// returns the full file path.
  static Future<String> downloadPdf({
    required List<int> bytes,
    required String partyName,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final fileName = _safeFileName(partyName);
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  /// Writes the PDF to a temp file and opens the OS share sheet so the
  /// user can send it via WhatsApp, email, etc.
  static Future<void> sharePdf({
    required List<int> bytes,
    required String partyName,
    String? captionText,
  }) async {
    final dir = await getTemporaryDirectory();
    final fileName = _safeFileName(partyName);
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      text: captionText,
    );
  }
}