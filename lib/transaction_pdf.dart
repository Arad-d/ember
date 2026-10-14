import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shamsi_date/shamsi_date.dart';
import 'models.dart';
import 'preferences.dart';
import 'transaction_export.dart';

String exportDate(DateTime date, AppCalendar calendar) {
  if (calendar == AppCalendar.shamsi) {
    final j = Jalali.fromDateTime(date);
    return '${j.day} ${shamsiMonths[j.month - 1]} ${j.year}';
  }
  return DateFormat('MMM d, yyyy', 'en_US').format(date);
}

String exportFilterLabel(
  ExportSnapshot snapshot,
  ExportFilter filter,
  AppCalendar calendar,
) {
  final period = filter.start == null && filter.end == null
      ? 'All dates'
      : '${filter.start == null ? 'Beginning' : exportDate(filter.start!, calendar)} – ${filter.end == null ? 'Latest' : exportDate(filter.end!, calendar)}';
  final account = filter.accountId == null
      ? 'All accounts'
      : snapshot.accounts
                .where((a) => a.id == filter.accountId)
                .firstOrNull
                ?.name ??
            'Selected account';
  return '$period · $account · ${filter.currency ?? 'All currencies'}';
}

Future<Uint8List> buildTransactionPdf(
  ExportSnapshot snapshot,
  ExportFilter filter,
  AppCalendar calendar,
) async {
  final rows = snapshot.rows(filter);
  final sums = snapshot.summaries(rows);
  final font = pw.Font.ttf(
    await rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
  );
  final arabic = pw.Font.ttf(
    await rootBundle.load('assets/fonts/NotoNaskhArabic-Regular.ttf'),
  );
  final symbols = pw.Font.ttf(
    await rootBundle.load('assets/fonts/NotoSansSymbols2-Regular.ttf'),
  );
  final doc = pw.Document(
    title: 'Ember transaction report',
    author: 'Ember',
    compress: true,
  );
  final ink = PdfColor.fromHex('#283124'),
      muted = PdfColor.fromHex('#616B58'),
      green = PdfColor.fromHex('#E5EED6'),
      line = PdfColor.fromHex('#DADFCC');
  pw.Text text(String value, {double size = 9, PdfColor? color}) => pw.Text(
    value,
    style: pw.TextStyle(fontSize: size, color: color ?? ink),
    textDirection: RegExp(r'[\u0600-\u06FF]').hasMatch(value)
        ? pw.TextDirection.rtl
        : pw.TextDirection.ltr,
  );
  pw.Widget cell(pw.Widget child, {bool numeric = false}) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 9),
    child: pw.Align(
      alignment: numeric ? pw.Alignment.topRight : pw.Alignment.topLeft,
      child: child,
    ),
  );
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      maxPages: 100000,
      theme: pw.ThemeData.withFont(
        base: font,
        bold: font,
        fontFallback: [arabic, symbols],
      ),
      header: (context) => pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 15),
        padding: const pw.EdgeInsets.only(bottom: 12),
        decoration: pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: line)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            text('ember', size: 22),
            text('TRANSACTION REPORT', size: 9, color: muted),
          ],
        ),
      ),
      footer: (context) => pw.Container(
        margin: const pw.EdgeInsets.only(top: 12),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            text(
              'Generated ${exportDate(snapshot.now, calendar)}',
              size: 8,
              color: muted,
            ),
            text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              size: 8,
              color: muted,
            ),
          ],
        ),
      ),
      build: (context) => [
        text('Your transactions', size: 20),
        pw.SizedBox(height: 8),
        text(exportFilterLabel(snapshot, filter, calendar), color: muted),
        pw.SizedBox(height: 6),
        text(
          '${rows.length} transactions · ${calendar == AppCalendar.shamsi ? 'Solar Hijri (Shamsi)' : 'Gregorian'} calendar',
          color: muted,
        ),
        pw.SizedBox(height: 5),
        text(
          snapshot.connected
              ? 'Last synced: ${snapshot.lastSync == null ? 'Not synced yet' : '${exportDate(snapshot.lastSync!, calendar)} at ${DateFormat('HH:mm', 'en_US').format(snapshot.lastSync!)}'}'
              : 'Demo records',
          size: 8,
          color: muted,
        ),
        pw.SizedBox(height: 20),
        text('Recorded totals', size: 12),
        pw.SizedBox(height: 8),
        pw.Table(
          columnWidths: {
            0: const pw.FlexColumnWidth(1),
            1: const pw.FlexColumnWidth(2),
            2: const pw.FlexColumnWidth(2),
            3: const pw.FlexColumnWidth(2),
          },
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: green),
              children: [
                for (final label in ['Currency', 'Income', 'Expenses', 'Net'])
                  cell(text(label), numeric: label != 'Currency'),
              ],
            ),
            for (final code in currencies.keys.where(sums.containsKey))
              pw.TableRow(
                children: [
                  cell(text(code)),
                  cell(
                    text(currencyMoney(sums[code]!.income, code)),
                    numeric: true,
                  ),
                  cell(
                    text(currencyMoney(sums[code]!.expenses, code)),
                    numeric: true,
                  ),
                  cell(
                    text(currencyMoney(sums[code]!.net, code)),
                    numeric: true,
                  ),
                ],
              ),
          ],
        ),
        pw.SizedBox(height: 8),
        text(
          'Transfers and planned transactions are excluded from these totals. Currencies are kept separate.',
          size: 8,
          color: muted,
        ),
        pw.SizedBox(height: 20),
        pw.Table(
          columnWidths: {
            0: const pw.FlexColumnWidth(1.3),
            1: const pw.FlexColumnWidth(2.8),
            2: const pw.FlexColumnWidth(1.8),
            3: const pw.FlexColumnWidth(1.8),
            4: const pw.FlexColumnWidth(1.25),
            5: const pw.FlexColumnWidth(1.1),
          },
          border: pw.TableBorder(
            horizontalInside: pw.BorderSide(color: line, width: .4),
          ),
          children: [
            pw.TableRow(
              repeat: true,
              decoration: pw.BoxDecoration(color: green),
              children: [
                for (final label in [
                  'Date',
                  'Transaction',
                  'Accounts',
                  'Amount',
                  'Currency',
                  'Status',
                ])
                  cell(text(label), numeric: label == 'Amount'),
              ],
            ),
            for (final row in rows)
              pw.TableRow(
                verticalAlignment: pw.TableCellVerticalAlignment.top,
                children: [
                  cell(text(exportDate(row.entry.date, calendar), size: 8)),
                  cell(
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        text(row.entry.title),
                        pw.SizedBox(height: 4),
                        text(
                          '${row.entry.type[0].toUpperCase()}${row.entry.type.substring(1)} · ${row.entry.category}',
                          size: 8,
                          color: muted,
                        ),
                      ],
                    ),
                  ),
                  cell(
                    text(
                      row.destination == null
                          ? row.source.name
                          : '${row.source.name}\nTo ${row.destination!.name}',
                      size: 8,
                    ),
                  ),
                  cell(
                    text(currencyMoney(row.entry.amount, row.currency)),
                    numeric: true,
                  ),
                  cell(text(row.currency, size: 8)),
                  cell(
                    text(
                      row.planned ? 'Planned' : 'Recorded',
                      size: 8,
                      color: muted,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    ),
  );
  return doc.save();
}
