import 'dart:convert';
import 'package:intl/intl.dart';
import 'models.dart';

String _calendarText(String value) => value
    .replaceAll('\r\n', '\n')
    .replaceAll('\r', '\n')
    .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '')
    .replaceAll('\\', '\\\\')
    .replaceAll('\n', r'\n')
    .replaceAll(';', r'\;')
    .replaceAll(',', r'\,');

// RFC 5545 folds at 75 UTF-8 octets without splitting a character.
String _foldCalendarLine(String line) {
  final result = StringBuffer();
  var bytes = 0;
  for (final rune in line.runes) {
    final character = String.fromCharCode(rune);
    final length = utf8.encode(character).length;
    if (bytes + length > 75) {
      result.write('\r\n ');
      bytes = 1;
    }
    result.write(character);
    bytes += length;
  }
  return result.toString();
}

String reminderCalendarFile(
  ExpenseReminder reminder,
  Account account, {
  int? alertDays = 2,
  DateTime? generatedAt,
}) {
  if (reminder.paid || reminder.accountId != account.id) {
    throw ArgumentError('Choose an unpaid reminder and its account.');
  }
  if (alertDays != null && ![0, 1, 2, 7].contains(alertDays)) {
    throw ArgumentError('Unsupported calendar alert.');
  }
  final date = DateFormat('yyyyMMdd').format(reminder.dueDate);
  final stamp = DateFormat(
    "yyyyMMdd'T'HHmmss'Z'",
  ).format((generatedAt ?? DateTime.now()).toUtc());
  // A floating 09:00 event follows the importing calendar's local timezone.
  final description = [
    'Amount: ${currencyMoney(reminder.amount, account.currency)} ${currencyLabel(account.currency)}',
    'Account: ${account.name}',
    'Category: ${reminder.category}',
    if (reminder.note.isNotEmpty) 'Note: ${reminder.note}',
    'Manage this bill in your Ember app.',
    'This is a calendar copy. Changes or payments in Ember do not update it.',
  ].join('\n');
  final uid = base64Url.encode(utf8.encode(reminder.id)).replaceAll('=', '');
  final lines = [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//Ember//Expense Reminders//EN',
    'CALSCALE:GREGORIAN',
    'BEGIN:VEVENT',
    'UID:$uid@ember-reminders',
    'DTSTAMP:$stamp',
    'DTSTART:${date}T090000',
    'DTEND:${date}T091500',
    'SUMMARY:${_calendarText(reminder.title)}',
    'DESCRIPTION:${_calendarText(description)}',
    'STATUS:CONFIRMED',
    'TRANSP:TRANSPARENT',
    if (alertDays != null) ...[
      'BEGIN:VALARM',
      'ACTION:DISPLAY',
      'TRIGGER:${alertDays == 0 ? 'PT0S' : '-P${alertDays}D'}',
      'DESCRIPTION:${_calendarText(reminder.title)}',
      'END:VALARM',
    ],
    'END:VEVENT',
    'END:VCALENDAR',
  ];
  return '${lines.map(_foldCalendarLine).join('\r\n')}\r\n';
}
