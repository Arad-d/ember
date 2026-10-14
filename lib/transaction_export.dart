import 'dart:convert';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'models.dart';

DateTime exportDay(DateTime date) => DateTime(date.year, date.month, date.day);

class ExportFilter {
  const ExportFilter({this.start, this.end, this.accountId, this.currency});
  final DateTime? start, end;
  final String? accountId, currency;
}

class ExportRow {
  const ExportRow(this.entry, this.source, this.destination, this.planned);
  final Entry entry;
  final Account source;
  final Account? destination;
  final bool planned;
  String get currency => source.currency;
  String get amount => currency == 'IRT'
      ? entry.amount.toString()
      : '${entry.amount ~/ 100}.${(entry.amount % 100).toString().padLeft(2, '0')}';
}

class ExportSummary {
  int income = 0, expenses = 0;
  int get net => income - expenses;
}

class ExportSnapshot {
  ExportSnapshot({
    required List<Account> accounts,
    required List<Entry> entries,
    required this.now,
    this.lastSync,
    this.connected = false,
  }) : accounts = List.unmodifiable(accounts),
       entries = List.unmodifiable(entries);
  final List<Account> accounts;
  final List<Entry> entries;
  final DateTime now;
  final DateTime? lastSync;
  final bool connected;
  List<ExportRow> rows(ExportFilter filter) {
    if (filter.start != null &&
        filter.end != null &&
        exportDay(filter.start!).isAfter(exportDay(filter.end!))) {
      throw ArgumentError('Start date must be on or before end date.');
    }
    final lookup = {for (final a in accounts) a.id: a};
    final result = <ExportRow>[];
    for (final e in entries) {
      final date = exportDay(e.date);
      if (filter.start != null && date.isBefore(exportDay(filter.start!)) ||
          filter.end != null && date.isAfter(exportDay(filter.end!))) {
        continue;
      }
      final source = lookup[e.accountId];
      if (source == null) {
        throw StateError(
          'An account is missing from the loaded records. Sync again before exporting.',
        );
      }
      if (filter.currency != null && source.currency != filter.currency) {
        continue;
      }
      if (filter.accountId != null &&
          e.accountId != filter.accountId &&
          e.destinationId != filter.accountId) {
        continue;
      }
      final destination = e.destinationId == null
          ? null
          : lookup[e.destinationId];
      if (e.type == 'transfer' && destination == null) {
        throw StateError(
          'A transfer account is missing. Sync again before exporting.',
        );
      }
      result.add(
        ExportRow(e, source, destination, date.isAfter(exportDay(now))),
      );
    }
    result.sort((a, b) {
      final date = a.entry.date.compareTo(b.entry.date);
      return date == 0 ? a.entry.id.compareTo(b.entry.id) : date;
    });
    return result;
  }

  Map<String, ExportSummary> summaries(List<ExportRow> rows) {
    final result = <String, ExportSummary>{};
    for (final row in rows) {
      if (row.planned) continue;
      final sum = result.putIfAbsent(row.currency, ExportSummary.new);
      if (row.entry.type == 'income') sum.income += row.entry.amount;
      if (row.entry.type == 'expense') sum.expenses += row.entry.amount;
    }
    return result;
  }

  Uint8List csv(List<ExportRow> rows) {
    final out = StringBuffer(
      '\uFEFFDate,Title,Type,Category,Source account,Destination account,Amount,Currency,Status\r\n',
    );
    for (final row in rows) {
      final e = row.entry;
      out.write(
        [
          DateFormat('yyyy-MM-dd', 'en_US').format(e.date),
          e.title,
          e.type,
          e.category,
          row.source.name,
          row.destination?.name ?? '',
          row.amount,
          row.currency,
          row.planned ? 'Planned' : 'Recorded',
        ].map(csvCell).join(','),
      );
      out.write('\r\n');
    }
    return Uint8List.fromList(utf8.encode(out.toString()));
  }
}

String csvCell(String value) {
  // Prefix untrusted formula-like text before quoting; leading whitespace must not bypass this.
  if (RegExp(r'^[\s\uFEFF]*[=+\-@]').hasMatch(value)) value = "'$value";
  if (value.contains(RegExp('[,"\\r\\n]'))) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}
