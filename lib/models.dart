import 'package:intl/intl.dart';

const categories = [
  'Food & drink',
  'Groceries',
  'Transport',
  'Shopping',
  'Home',
  'Health',
  'Leisure',
  'Bills',
  'Other',
];
const incomeCategories = ['Salary', 'Freelance', 'Gift', 'Other'];
const currencies = {
  'IRT': 'Iranian toman',
  'USD': 'US dollar (\$)',
  'EUR': 'Euro (€)',
  'GBP': 'British pound (£)',
};
String currencyLabel(String code) =>
    {'IRT': 'toman', 'USD': 'USD \$', 'EUR': 'EUR €', 'GBP': 'GBP £'}[code]!;
String currencyMoney(int amount, String code) => code == 'IRT'
    ? money(amount)
    : NumberFormat('#,##0.00', 'en_US').format(amount / 100);
int? parseCurrencyAmount(String input, String code) {
  if (code == 'IRT') return parseAmount(input);
  var value = input
      .trim()
      .replaceAll(',', '')
      .replaceAll('٬', '')
      .replaceAll(' ', '')
      .replaceAll('٫', '.');
  for (var i = 0; i < 10; i++) {
    value = value
        .replaceAll('۰۱۲۳۴۵۶۷۸۹'[i], '$i')
        .replaceAll('٠١٢٣٤٥٦٧٨٩'[i], '$i');
  }
  if (!RegExp(r'^-?\d+(\.\d{1,2})?$').hasMatch(value)) return null;
  final parts = value.replaceFirst('-', '').split('.');
  final whole = int.tryParse(parts[0]);
  if (whole == null || whole > 90000000000) return null;
  final result =
      (whole * 100 +
          (parts.length == 2 ? int.parse(parts[1].padRight(2, '0')) : 0)) *
      (value.startsWith('-') ? -1 : 1);
  return result.abs() <= 9000000000000 ? result : null;
}

String money(int amount) => NumberFormat.decimalPattern('en_US').format(amount);
int? parseAmount(String input) {
  var value = input.trim();
  const persian = '۰۱۲۳۴۵۶۷۸۹';
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  for (var i = 0; i < 10; i++) {
    value = value.replaceAll(persian[i], '$i').replaceAll(arabic[i], '$i');
  }
  value = value.replaceAll(',', '').replaceAll('٬', '').replaceAll(' ', '');
  if (!RegExp(r'^-?\d+$').hasMatch(value)) return null;
  final result = int.tryParse(value);
  return result != null && result.abs() <= 9000000000000 ? result : null;
}

class Account {
  final String id, name, kind, currency;
  final int opening;
  const Account({
    required this.id,
    required this.name,
    required this.kind,
    required this.opening,
    this.currency = 'IRT',
  });
  factory Account.fromJson(Map<String, dynamic> j) => Account(
    id: j['id'],
    name: j['name'],
    kind: j['kind'],
    currency: j['currency'] ?? 'IRT',
    opening: (j['opening'] as num).toInt(),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'kind': kind,
    'currency': currency,
    'opening': opening,
  };
}

class Entry {
  final String id, title, type, category, accountId;
  final String? destinationId;
  final int amount;
  final DateTime date;
  const Entry({
    required this.id,
    required this.title,
    required this.type,
    required this.category,
    required this.accountId,
    this.destinationId,
    required this.amount,
    required this.date,
  });
  factory Entry.fromJson(Map<String, dynamic> j) => Entry(
    id: j['id'],
    title: j['title'],
    type: j['type'],
    category: j['category'],
    accountId: j['account_id'],
    destinationId: j['destination_id'],
    amount: (j['amount'] as num).toInt(),
    date: DateTime.parse(j['date']),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'type': type,
    'category': category,
    'account_id': accountId,
    'destination_id': destinationId,
    'amount': amount,
    'date': DateFormat('yyyy-MM-dd').format(date),
  };
}

class ExpenseReminder {
  final String id, title, category, accountId, note;
  final int amount;
  final DateTime dueDate;
  final DateTime? paidDate;
  const ExpenseReminder({
    required this.id,
    required this.title,
    required this.category,
    required this.accountId,
    required this.amount,
    required this.dueDate,
    this.note = '',
    this.paidDate,
  });
  bool get paid => paidDate != null;
  int daysUntil(DateTime now) => DateTime.utc(
    dueDate.year,
    dueDate.month,
    dueDate.day,
  ).difference(DateTime.utc(now.year, now.month, now.day)).inDays;
  factory ExpenseReminder.fromJson(Map<String, dynamic> j) => ExpenseReminder(
    id: j['id'],
    title: j['title'],
    category: j['category'],
    accountId: j['account_id'],
    amount: (j['amount'] as num).toInt(),
    dueDate: DateTime.parse(j['due_date']),
    note: j['note'] ?? '',
    paidDate: j['paid_date'] == null ? null : DateTime.parse(j['paid_date']),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'category': category,
    'account_id': accountId,
    'amount': amount,
    'due_date': DateFormat('yyyy-MM-dd').format(dueDate),
    'note': note,
    'paid_date': paidDate == null
        ? null
        : DateFormat('yyyy-MM-dd').format(paidDate!),
  };
}

int balance(Account a, Iterable<Entry> entries) => entries.fold(
  a.opening,
  (total, e) =>
      total +
      (e.accountId == a.id ? (e.type == 'income' ? e.amount : -e.amount) : 0) +
      (e.type == 'transfer' && e.destinationId == a.id ? e.amount : 0),
);
int totalOf(Iterable<Entry> entries, String type) =>
    entries.where((e) => e.type == type).fold(0, (a, e) => a + e.amount);
