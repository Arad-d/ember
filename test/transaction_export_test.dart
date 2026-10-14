import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ember/models.dart';
import 'package:ember/transaction_export.dart';

void main() {
  final now = DateTime(2026, 10, 13);
  final accounts = [
    const Account(id: 'a', name: 'Bank', kind: 'Bank', opening: 0),
    const Account(id: 'b', name: 'Savings', kind: 'Savings', opening: 0),
    const Account(
      id: 'u',
      name: 'Dollar',
      kind: 'Bank',
      currency: 'USD',
      opening: 0,
    ),
  ];
  Entry e(
    String id,
    String type,
    String account,
    int amount,
    DateTime date, {
    String? destination,
    String title = 'Example',
  }) => Entry(
    id: id,
    title: title,
    type: type,
    category: 'Other',
    accountId: account,
    destinationId: destination,
    amount: amount,
    date: date,
  );
  final entries = [
    e('income', 'income', 'a', 100, now),
    e('expense', 'expense', 'a', 30, now),
    e('transfer', 'transfer', 'a', 20, now, destination: 'b'),
    e('usd', 'expense', 'u', 1250, now),
    e('future', 'expense', 'a', 90, DateTime(2026, 10, 14)),
  ];
  ExportSnapshot snap() =>
      ExportSnapshot(accounts: accounts, entries: entries, now: now);
  test(
    'inclusive filters include transfer destination once and separate currencies',
    () {
      final s = snap();
      expect(s.rows(const ExportFilter()).length, 5);
      expect(
        s.rows(const ExportFilter(accountId: 'b')).single.entry.id,
        'transfer',
      );
      expect(
        s.rows(const ExportFilter(currency: 'USD')).single.entry.id,
        'usd',
      );
      expect(s.rows(ExportFilter(start: now, end: now)).length, 4);
    },
  );
  test('summary excludes transfers and planned entries', () {
    final s = snap();
    final sums = s.summaries(s.rows(const ExportFilter()));
    expect(sums['IRT']!.income, 100);
    expect(sums['IRT']!.expenses, 30);
    expect(sums['IRT']!.net, 70);
    expect(sums['USD']!.expenses, 1250);
    expect(s.rows(const ExportFilter()).last.planned, true);
  });
  test('snapshot stays consistent after loaded lists change', () {
    final a = [...accounts], es = [...entries];
    final s = ExportSnapshot(accounts: a, entries: es, now: now);
    a.clear();
    es.clear();
    expect(s.rows(const ExportFilter()), hasLength(5));
  });
  test(
    'CSV preserves Unicode, quotes and precise amounts and defuses formulas',
    () {
      final s = ExportSnapshot(
        accounts: accounts,
        entries: [
          e('x', 'expense', 'a', 1000, now, title: 'قهوه, "صبح"\nخانه'),
          e('y', 'expense', 'u', 1250, now, title: ' \t=HYPERLINK("bad")'),
        ],
        now: now,
      );
      final bytes = s.csv(s.rows(const ExportFilter()));
      expect(bytes.take(3), [239, 187, 191]);
      final csv = utf8.decode(bytes);
      expect(
        csv,
        startsWith(
          'Date,Title,Type,Category,Source account,Destination account,Amount,Currency,Status',
        ),
      );
      expect(csv, contains('"قهوه, ""صبح""\nخانه"'));
      expect(csv, contains("' \t=HYPERLINK"));
      expect(csv, contains(',1000,IRT,Recorded'));
      expect(csv, contains(',12.50,USD,Recorded'));
      expect(csv, contains('2026-10-13'));
    },
  );
  test('empty exports have only header and no summaries', () {
    final s = snap();
    final rows = s.rows(const ExportFilter(currency: 'EUR'));
    expect(s.summaries(rows), isEmpty);
    expect(utf8.decode(s.csv(rows)).split('\r\n').length, 2);
  });
}
