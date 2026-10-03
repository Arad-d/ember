import 'package:flutter_test/flutter_test.dart';
import 'package:ember/models.dart';
import 'package:ember/forecast.dart';
import 'package:ember/what_if.dart';

void main() {
  final today = DateTime(2026, 9, 28);
  DateTime day(int n) => DateTime(today.year, today.month, today.day + n);
  const account = Account(
    id: 'bank',
    name: 'Bank',
    kind: 'Bank',
    opening: 100000,
    currency: 'USD',
  );
  ExpenseReminder item(
    String id,
    int amount,
    int n, {
    bool paid = false,
    String accountId = 'bank',
  }) => ExpenseReminder(
    id: id,
    title: id,
    category: 'Bills',
    accountId: accountId,
    amount: amount,
    dueDate: day(n),
    paidDate: paid ? today : null,
  );
  WhatIfSnapshot snapshot({
    List<ExpenseReminder>? bills,
    List<ExpenseReminder>? income,
    List<Entry> entries = const [],
    PlanSettings settings = const PlanSettings(reserve: 20000),
  }) => WhatIfSnapshot(
    accounts: const [
      account,
      Account(
        id: 'eur',
        name: 'Euro',
        kind: 'Bank',
        opening: 900000,
        currency: 'EUR',
      ),
      Account(
        id: 'savings',
        name: 'Savings',
        kind: 'Savings',
        opening: 900000,
        currency: 'USD',
      ),
    ],
    entries: entries,
    bills: bills ?? [item('Rent', 60000, 3)],
    income: income ?? [item('Salary', 200000, 7)],
    currency: 'USD',
    settings: settings,
    now: today,
  );
  ScenarioChange change(
    ScenarioKind kind,
    String id,
    int amount,
    int n, {
    String accountId = 'bank',
  }) => ScenarioChange(
    id: id,
    kind: kind,
    title: id,
    accountId: accountId,
    amount: amount,
    date: day(n),
  );

  test('Purchase compares fixed windows and counts low-balance days once', () {
    final data = snapshot();
    final current = data.project([]);
    final next = data.project([
      change(ScenarioKind.purchase, 'Laptop', 50000, 0),
    ]);
    expect(current.forecast.lowest, 40000);
    expect(next.forecast.lowest, -10000);
    expect(next.forecast.available, 0);
    expect(next.firstShortfall, day(3));
    expect(
      next.daysBelowBuffer,
      5,
    ); // Days 3 through payday 7, before its income arrives.
    expect(next.days.length, 30);
    expect(next.forecast.end, current.forecast.end);
    expect(next.forecast.end, day(29));
    expect(data.bills.length, 1);
    expect(data.bills.single.amount, 60000);
    expect(data.entries, isEmpty);
  });
  test(
    'Replacing a bill does not duplicate it and combines with purchases',
    () {
      final data = snapshot();
      final next = data.project([
        change(ScenarioKind.bill, 'Rent', 30000, 5),
        change(ScenarioKind.purchase, 'Laptop', 10000, 1),
      ]);
      expect(next.forecast.events.where((e) => e.id == 'Rent').length, 1);
      expect(
        next.forecast.events.firstWhere((e) => e.id == 'Rent').date,
        day(5),
      );
      expect(next.forecast.lowest, 60000);
      expect(data.project([]).forecast.lowest, 40000);
      expect(data.bills.single.dueDate, day(3));
    },
  );
  test(
    'Delayed income outside 30 days stays excluded and returns in 60 days',
    () {
      final data = snapshot(
        bills: [item('Rent', 150000, 12)],
        income: [item('Salary', 200000, 5)],
      );
      final delayed = change(ScenarioKind.income, 'Salary', 200000, 35);
      final a = data.project([delayed]), b = data.project([delayed], days: 60);
      expect(a.forecast.events.where((e) => e.kind == 'income'), isEmpty);
      expect(a.firstShortfall, day(12));
      expect(a.forecast.end, data.project([]).forecast.end);
      expect(b.days.length, 60);
      expect(b.forecast.events.where((e) => e.kind == 'income').length, 1);
      expect(b.days.last.closing, 150000);
      expect(a.daysBelowBuffer, 18);
      expect(b.daysBelowBuffer, 24);
    },
  );
  test(
    'Paid items, other currencies, savings, and late income stay excluded',
    () {
      final data = snapshot(
        bills: [
          item('paid', 500000, 1, paid: true),
          item('euro', 500000, 1, accountId: 'eur'),
          item('saved', 500000, 1, accountId: 'savings'),
          item('overdue', 10000, -3),
        ],
        income: [item('late', 100000, -2)],
      );
      final f = data.project([]);
      expect(f.forecast.opening, 100000);
      expect(f.forecast.lowest, 90000);
      expect(f.forecast.lateIncome, 1);
      expect(f.forecast.events.single.date, today);
      expect(
        () => data.project([change(ScenarioKind.bill, 'paid', 1000, 2)]),
        throwsArgumentError,
      );
      expect(
        () => data.project([
          change(ScenarioKind.purchase, 'foreign', 1000, 2, accountId: 'eur'),
        ]),
        throwsArgumentError,
      );
      final restored = data.project([
        change(ScenarioKind.income, 'late', 100000, 1),
      ]);
      expect(restored.forecast.lateIncome, 0);
      expect(restored.days.last.closing, 190000);
    },
  );
  test(
    'Boundary dates, duplicate edits, income amount changes, and invalid inputs',
    () {
      final data = snapshot();
      final purchase = change(ScenarioKind.purchase, 'Last day', 100000, 29);
      expect(
        data
            .project([purchase])
            .forecast
            .events
            .any((e) => e.title == 'Last day'),
        true,
      );
      expect(
        data
            .project([change(ScenarioKind.purchase, 'Outside', 100000, 30)])
            .forecast
            .lowest,
        data.project([]).forecast.lowest,
      );
      expect(() => data.project([purchase, purchase]), throwsArgumentError);
      expect(
        () => data.project([change(ScenarioKind.income, 'Salary', 1000, 10)]),
        throwsArgumentError,
      );
      expect(
        () => data.project([change(ScenarioKind.income, 'Salary', 200000, 7)]),
        throwsArgumentError,
      );
      expect(
        () => data.project([change(ScenarioKind.purchase, 'Past', 1000, -1)]),
        throwsArgumentError,
      );
      expect(
        () => data.project([change(ScenarioKind.purchase, 'Zero', 0, 1)]),
        throwsArgumentError,
      );
      expect(() => data.project([], days: 45), throwsArgumentError);
    },
  );
  test('Snapshot remains stable if the source lists change', () {
    final bills = [item('Rent', 60000, 3)];
    final data = snapshot(bills: bills);
    bills.clear();
    expect(data.project([]).forecast.lowest, 40000);
    final none = snapshot(settings: const PlanSettings(accountIds: []));
    expect(none.project([]).forecast.available, 0);
    expect(none.editableBills, isEmpty);
  });
}
