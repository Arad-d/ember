import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'export_download.dart';
import 'models.dart';
import 'preferences.dart';
import 'transaction_export.dart';
import 'transaction_pdf.dart';

typedef ExportDownload =
    Future<void> Function(Uint8List bytes, String mime, String filename);
Future<void> showTransactionExport(
  BuildContext context, {
  required ExportSnapshot snapshot,
  required AppCalendar calendar,
}) {
  final child = TransactionExportView(snapshot: snapshot, calendar: calendar);
  if (MediaQuery.sizeOf(context).width < 600) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(ctx).height * .88,
        ),
        child: child,
      ),
    );
  }
  return showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 800),
        child: child,
      ),
    ),
  );
}

class TransactionExportView extends StatefulWidget {
  const TransactionExportView({
    super.key,
    required this.snapshot,
    required this.calendar,
    this.download,
  });
  final ExportSnapshot snapshot;
  final AppCalendar calendar;
  final ExportDownload? download;
  @override
  State<TransactionExportView> createState() => _TransactionExportViewState();
}

class _TransactionExportViewState extends State<TransactionExportView> {
  bool pdf = false, busy = false, customDates = false;
  String? accountId, currency, error;
  DateTime? start, end;
  ExportFilter get filter => ExportFilter(
    start: customDates ? start : null,
    end: customDates ? end : null,
    accountId: accountId,
    currency: currency,
  );
  void change(VoidCallback mutation) {
    setState(() {
      mutation();
      error = null;
    });
  }

  Future<void> date(bool first) async {
    final picked = await pickAppDate(
      context: context,
      initialDate: (first ? start : end) ?? exportDay(widget.snapshot.now),
      firstDate: DateTime(1900),
      lastDate: DateTime(2200, 12, 31),
    );
    if (picked != null && mounted) {
      change(() => first ? start = picked : end = picked);
    }
  }

  Future<void> download() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      // Capture options too: filters cannot change while generation is underway.
      final selected = filter, asPdf = pdf;
      final bytes = asPdf
          ? await buildTransactionPdf(
              widget.snapshot,
              selected,
              widget.calendar,
            )
          : widget.snapshot.csv(widget.snapshot.rows(selected));
      final filename =
          'ember-transactions-${DateFormat('yyyy-MM-dd', 'en_US').format(widget.snapshot.now)}.${asPdf ? 'pdf' : 'csv'}';
      await (widget.download ?? downloadExportFile)(
        bytes,
        asPdf ? 'application/pdf' : 'text/csv;charset=utf-8',
        filename,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Your download is ready. Check your browser’s downloads.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e
              .toString()
              .replaceFirst('Exception: ', '')
              .replaceFirst('Bad state: ', '')
              .replaceFirst('Invalid argument(s): ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), s = widget.snapshot;
    List<ExportRow> rows = [];
    String? problem;
    try {
      rows = s.rows(filter);
    } catch (e) {
      problem = e
          .toString()
          .replaceFirst('Invalid argument(s): ', '')
          .replaceFirst('Bad state: ', '');
    }
    final sums = s.summaries(rows);
    final accounts = s.accounts
        .where((a) => currency == null || a.currency == currency)
        .toList();
    final supported = widget.download != null || exportDownloadSupported;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Export transactions',
                  style: theme.textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: 'Close export',
                onPressed: busy ? null : () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Save your records as a spreadsheet file or a readable report.',
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  label: Text('CSV'),
                  icon: Icon(Icons.table_chart_outlined, size: 18),
                ),
                ButtonSegment(
                  value: true,
                  label: Text('PDF'),
                  icon: Icon(Icons.picture_as_pdf_outlined, size: 18),
                ),
              ],
              selected: {pdf},
              onSelectionChanged: busy
                  ? null
                  : (value) => change(() => pdf = value.single),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            pdf
                ? 'A printable report with separate currency totals. Dates follow your selected calendar.'
                : 'For spreadsheets and data transfer. Dates use Gregorian YYYY-MM-DD.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<bool>(
            initialValue: customDates,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Date range'),
            items: const [
              DropdownMenuItem(value: false, child: Text('All dates')),
              DropdownMenuItem(value: true, child: Text('Choose dates')),
            ],
            onChanged: busy
                ? null
                : (value) => change(() => customDates = value!),
          ),
          if (customDates) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : () => date(true),
                    child: Column(
                      children: [
                        const Text('From'),
                        Text(
                          start == null
                              ? 'Beginning'
                              : exportDate(start!, widget.calendar),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : () => date(false),
                    child: Column(
                      children: [
                        const Text('To'),
                        Text(
                          end == null
                              ? 'Latest'
                              : exportDate(end!, widget.calendar),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          DropdownButtonFormField<String>(
            key: ValueKey('export-account-${currency ?? 'all'}'),
            initialValue: accountId ?? 'all',
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Account'),
            items: [
              const DropdownMenuItem(value: 'all', child: Text('All accounts')),
              for (final a in accounts)
                DropdownMenuItem(
                  value: a.id,
                  child: Text(
                    '${a.name} · ${a.currency}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: busy
                ? null
                : (value) =>
                      change(() => accountId = value == 'all' ? null : value),
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<String>(
            key: const ValueKey('export-currency'),
            initialValue: currency ?? 'all',
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Currency'),
            items: [
              const DropdownMenuItem(
                value: 'all',
                child: Text('All currencies'),
              ),
              for (final c in currencies.entries)
                DropdownMenuItem(value: c.key, child: Text(c.value)),
            ],
            onChanged: busy
                ? null
                : (value) => change(() {
                    currency = value == 'all' ? null : value;
                    if (accountId != null &&
                        !s.accounts.any(
                          (a) =>
                              a.id == accountId &&
                              (currency == null || a.currency == currency),
                        )) {
                      accountId = null;
                    }
                  }),
          ),
          const SizedBox(height: 22),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: .07),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${rows.length} ${rows.length == 1 ? 'transaction' : 'transactions'}',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                if (rows.isEmpty && problem == null)
                  const Text('No transactions match these filters.')
                else if (rows.any((row) => row.planned))
                  Text(
                    '${rows.where((row) => row.planned).length} planned · excluded from recorded totals',
                  ),
                if (pdf && sums.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  for (final code in currencies.keys.where(sums.containsKey))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '$code · Income ${currencyMoney(sums[code]!.income, code)} · Expenses ${currencyMoney(sums[code]!.expenses, code)}\nNet ${currencyMoney(sums[code]!.net, code)}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                ],
                const SizedBox(height: 8),
                Text(
                  s.connected
                      ? 'Last synced: ${s.lastSync == null ? 'Not synced yet' : '${exportDate(s.lastSync!, widget.calendar)} at ${DateFormat('HH:mm', 'en_US').format(s.lastSync!)}'}'
                      : 'Demo records',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Generated on your device from the records loaded when you opened this sheet.',
            style: theme.textTheme.bodySmall,
          ),
          if (problem != null || error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                problem ?? error!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          if (!supported)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text('Open Ember in your browser to download files.'),
            ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: busy || rows.isEmpty || problem != null || !supported
                  ? null
                  : download,
              icon: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      pdf
                          ? Icons.picture_as_pdf_outlined
                          : Icons.download_outlined,
                      size: 18,
                    ),
              label: Text(
                busy
                    ? 'Preparing file…'
                    : pdf
                    ? 'Download PDF'
                    : 'Download CSV',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
