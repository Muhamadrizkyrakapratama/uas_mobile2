import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/transaction_model.dart';

void printReport(List<Transaction> transactions) async {
  final formatCurrency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  final formatDate = DateFormat('dd MMM yyyy HH:mm', 'id_ID');
  final now = DateFormat('dd MMMM yyyy, HH:mm', 'id_ID').format(DateTime.now());

  // Load Unicode-compatible fonts — fallback to default if offline
  pw.Font? fontRegular, fontBold, fontItalic;
  try {
    fontRegular = await PdfGoogleFonts.nunitoRegular();
    fontBold = await PdfGoogleFonts.nunitoBold();
    fontItalic = await PdfGoogleFonts.nunitoItalic();
  } catch (_) {
    // Offline or failed — will use default PDF font
  }

  // Accent colors
  const green = PdfColor.fromInt(0xFF10B981);
  const red = PdfColor.fromInt(0xFFF43F5E);
  const headerBg = PdfColor.fromInt(0xFFF3F4F6);
  const textDark = PdfColor.fromInt(0xFF1F2937);
  const textGrey = PdfColor.fromInt(0xFF6B7280);
  const borderColor = PdfColor.fromInt(0xFFE5E7EB);

  double totalIncome = 0;
  double totalExpense = 0;

  final pdf = pw.Document();
  final theme = fontRegular != null
      ? pw.ThemeData.withFont(
          base: fontRegular,
          bold: fontBold,
          italic: fontItalic,
        )
      : pw.ThemeData();


  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      theme: theme,
      build: (context) {
        // Build table rows
        final rows = <pw.TableRow>[];

        // Header row
        rows.add(
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: headerBg),
            children: [
              _cell('Tanggal', isHeader: true),
              _cell('Tipe', isHeader: true),
              _cell('Kategori', isHeader: true),
              _cell('Catatan', isHeader: true),
              _cell('Nominal', isHeader: true, align: pw.TextAlign.right),
            ],
          ),
        );

        // Data rows
        for (final tx in transactions) {
          final isIncome = tx.type == 'income';
          if (isIncome) {
            totalIncome += tx.amount;
          } else {
            totalExpense += tx.amount;
          }

          rows.add(
            pw.TableRow(
              children: [
                _cell(formatDate.format(tx.date)),
                _cell(isIncome ? 'Pemasukan' : 'Pengeluaran',
                    color: isIncome ? green : red),
                _cell(tx.category),
                _cell(tx.description),
                _cell(
                  '${isIncome ? '+' : '-'} ${formatCurrency.format(tx.amount)}',
                  color: isIncome ? green : red,
                  align: pw.TextAlign.right,
                ),
              ],
            ),
          );
        }

        return [
          // Title
          pw.Text(
            'SimPay',
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
              color: green,
            ),
          ),
          pw.Text(
            '"Catat masuknya dikit, keluarnya banyak."',
            style: pw.TextStyle(fontSize: 11, color: textGrey, fontStyle: pw.FontStyle.italic),
          ),
          pw.Text(
            'Dicetak pada: $now',
            style: pw.TextStyle(fontSize: 9, color: textGrey),
          ),
          pw.SizedBox(height: 16),

          // Table
          pw.Table(
            border: pw.TableBorder.all(color: borderColor, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(2.5),
              1: const pw.FlexColumnWidth(1.5),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(3),
              4: const pw.FlexColumnWidth(2.5),
            },
            children: rows,
          ),
          pw.SizedBox(height: 20),

          // Summary
          pw.Divider(color: borderColor),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                _summaryRow('Total Pemasukan', formatCurrency.format(totalIncome), green),
                _summaryRow('Total Pengeluaran', formatCurrency.format(totalExpense), red),
                pw.Divider(color: borderColor),
                _summaryRow(
                  'Selisih (Saldo)',
                  formatCurrency.format(totalIncome - totalExpense),
                  textDark,
                  bold: true,
                ),
              ],
            ),
          ),
        ];
      },
    ),
  );

  await Printing.layoutPdf(
    onLayout: (format) async => pdf.save(),
    name: 'Laporan_SimPay_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
  );
}

// Helper: table cell
pw.Widget _cell(
  String text, {
  bool isHeader = false,
  PdfColor? color,
  pw.TextAlign align = pw.TextAlign.left,
}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
    child: pw.Text(
      text,
      textAlign: align,
      style: pw.TextStyle(
        fontSize: isHeader ? 10 : 9,
        fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: color ?? (isHeader ? const PdfColor.fromInt(0xFF374151) : const PdfColor.fromInt(0xFF1F2937)),
      ),
    ),
  );
}

// Helper: summary row
pw.Widget _summaryRow(String label, String value, PdfColor valueColor, {bool bold = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 3),
    child: pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Text(
          '$label:  ',
          style: pw.TextStyle(
            fontSize: 11,
            color: const PdfColor.fromInt(0xFF6B7280),
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: valueColor,
          ),
        ),
      ],
    ),
  );
}

void printMonthlyWrappedReport({
  required String monthLabel,
  required double totalIncome,
  required double totalExpense,
  required Map<String, double> incomeByCategory,
  required Map<String, double> expenseByCategory,
}) async {
  final formatCurrency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  final now = DateFormat('dd MMMM yyyy, HH:mm', 'id_ID').format(DateTime.now());

  pw.Font? fontRegular, fontBold, fontItalic;
  try {
    fontRegular = await PdfGoogleFonts.nunitoRegular();
    fontBold = await PdfGoogleFonts.nunitoBold();
    fontItalic = await PdfGoogleFonts.nunitoItalic();
  } catch (_) {}

  const green = PdfColor.fromInt(0xFF10B981);
  const red = PdfColor.fromInt(0xFFF43F5E);
  const headerBg = PdfColor.fromInt(0xFFF3F4F6);
  const textDark = PdfColor.fromInt(0xFF1F2937);
  const textGrey = PdfColor.fromInt(0xFF6B7280);
  const borderColor = PdfColor.fromInt(0xFFE5E7EB);

  final net = totalIncome - totalExpense;
  final pdf = pw.Document();
  final theme = fontRegular != null
      ? pw.ThemeData.withFont(
          base: fontRegular,
          bold: fontBold,
          italic: fontItalic,
        )
      : pw.ThemeData();

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      theme: theme,
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'SimPay - Monthly Wrapped',
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: green,
                      ),
                    ),
                    pw.Text(
                      'Ringkasan Keuangan Bulanan',
                      style: pw.TextStyle(fontSize: 10, color: textGrey),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      monthLabel,
                      style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: textDark),
                    ),
                    pw.Text(
                      'Dicetak pada: $now',
                      style: pw.TextStyle(fontSize: 8, color: textGrey),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Divider(color: borderColor),
            pw.SizedBox(height: 12),

            // Overview Card
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: headerBg,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                border: pw.Border.all(color: borderColor, width: 0.5),
              ),
              child: pw.Column(
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Total Pemasukan', style: const pw.TextStyle(fontSize: 11)),
                      pw.Text(formatCurrency.format(totalIncome), style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: green)),
                    ],
                  ),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Total Pengeluaran', style: const pw.TextStyle(fontSize: 11)),
                      pw.Text(formatCurrency.format(totalExpense), style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: red)),
                    ],
                  ),
                  pw.SizedBox(height: 8),
                  pw.Divider(color: borderColor),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        net >= 0 ? 'Surplus Bulanan' : 'Defisit Bulanan',
                        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: textDark),
                      ),
                      pw.Text(
                        formatCurrency.format(net),
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: net >= 0 ? green : red,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 24),

            // Breakdown Sections
            if (incomeByCategory.isNotEmpty) ...[
              pw.Text('Rincian Pemasukan per Kategori', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: textDark)),
              pw.SizedBox(height: 8),
              _buildPdfCategoryTable(incomeByCategory, totalIncome, green, formatCurrency),
              pw.SizedBox(height: 20),
            ],

            if (expenseByCategory.isNotEmpty) ...[
              pw.Text('Rincian Pengeluaran per Kategori', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: textDark)),
              pw.SizedBox(height: 8),
              _buildPdfCategoryTable(expenseByCategory, totalExpense, red, formatCurrency),
            ],
          ],
        );
      },
    ),
  );

  await Printing.layoutPdf(
    onLayout: (format) async => pdf.save(),
    name: 'Wrapped_SimPay_${monthLabel.replaceAll(' ', '_')}.pdf',
  );
}

pw.Widget _buildPdfCategoryTable(
  Map<String, double> categories,
  double total,
  PdfColor themeColor,
  NumberFormat formatter,
) {
  final sorted = categories.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  final headerStyle = pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF374151));
  final cellStyle = const pw.TextStyle(fontSize: 9);

  final rows = <pw.TableRow>[
    pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF9FAFB)),
      children: [
        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Kategori', style: headerStyle)),
        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Nominal', style: headerStyle, textAlign: pw.TextAlign.right)),
        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Persentase', style: headerStyle, textAlign: pw.TextAlign.right)),
      ],
    ),
  ];

  for (final entry in sorted) {
    final pct = total > 0 ? (entry.value / total * 100) : 0.0;
    rows.add(
      pw.TableRow(
        children: [
          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(entry.key, style: cellStyle)),
          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(formatter.format(entry.value), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: themeColor), textAlign: pw.TextAlign.right)),
          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${pct.toStringAsFixed(1)}%', style: cellStyle, textAlign: pw.TextAlign.right)),
        ],
      ),
    );
  }

  return pw.Table(
    border: pw.TableBorder.all(color: const PdfColor.fromInt(0xFFE5E7EB), width: 0.5),
    columnWidths: {
      0: const pw.FlexColumnWidth(4),
      1: const pw.FlexColumnWidth(3),
      2: const pw.FlexColumnWidth(2),
    },
    children: rows,
  );
}

