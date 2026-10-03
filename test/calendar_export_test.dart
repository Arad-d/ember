import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ember/calendar_export.dart';
import 'package:ember/models.dart';

void main() {
  const account = Account(
    id: 'a',
    name: 'Everyday bank',
    kind: 'Bank',
    currency: 'USD',
    opening: 0,
  );
  ExpenseReminder bill({String title = 'Loan payment', String note = ''}) =>
      ExpenseReminder(
        id: 'bill-123',
        title: title,
        note: note,
        category: 'Bills',
        accountId: 'a',
        amount: 12345,
        dueDate: DateTime(2027, 1, 1),
      );
  final stamp = DateTime.utc(2026, 9, 20, 14, 30);

  test('Calendar date stays local and two-day alert crosses year boundary', () {
    final file = reminderCalendarFile(bill(), account, generatedAt: stamp);
    expect(file, contains('DTSTART:20270101T090000\r\n'));
    expect(file, contains('DTEND:20270101T091500\r\n'));
    expect(file, contains('DTSTAMP:20260920T143000Z\r\n'));
    expect(file, contains('TRIGGER:-P2D\r\n'));
    expect(file, contains('Amount: 123.45 USD \$'));
    expect(file, endsWith('END:VCALENDAR\r\n'));
    final again = reminderCalendarFile(bill(), account);
    String uid(String text) =>
        text.split('\r\n').firstWhere((l) => l.startsWith('UID:'));
    expect(uid(file), uid(again));
  });
  test('Untrusted notes are escaped and cannot inject calendar properties', () {
    final file = reminderCalendarFile(
      bill(
        title: 'Loan, bank; \\ account',
        note: 'line1\r\nBEGIN:VEVENT\rSUMMARY:fake',
      ),
      account,
      generatedAt: stamp,
    );
    final unfolded = file.replaceAll('\r\n ', '');
    expect(unfolded, contains(r'SUMMARY:Loan\, bank\; \\ account'));
    expect(unfolded, contains(r'Note: line1\nBEGIN:VEVENT\nSUMMARY:fake'));
    expect(file.split('\r\n').where((l) => l == 'BEGIN:VEVENT'), hasLength(1));
  });
  test(
    'Long Persian and emoji text is folded by UTF-8 bytes without damage',
    () {
      final note = List.filled(40, 'قسط 🏠').join(' ');
      final file = reminderCalendarFile(bill(note: note), account);
      for (final line in file.split('\r\n')) {
        expect(utf8.encode(line).length, lessThanOrEqualTo(75));
      }
      expect(file.replaceAll('\r\n ', ''), contains(note));
      expect(utf8.decode(utf8.encode(file)), file);
    },
  );
  test('No-alert export and same-day alert are distinct', () {
    expect(
      reminderCalendarFile(bill(), account, alertDays: null),
      isNot(contains('BEGIN:VALARM')),
    );
    expect(
      reminderCalendarFile(bill(), account, alertDays: 0),
      contains('TRIGGER:PT0S'),
    );
    expect(
      () => reminderCalendarFile(bill(), account, alertDays: -4),
      throwsArgumentError,
    );
  });
}
