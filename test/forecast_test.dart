import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ember/models.dart';
import 'package:ember/forecast.dart';
import 'package:ember/store.dart';

void main() {
  final today = DateTime(2026, 9, 24);
  const accounts = [
    Account(
      id: 'a',
      name: 'Bank',
      kind: 'Bank',
      opening: 10000,
      currency: 'USD',
    ),
    Account(
      id: 's',
      name: 'Savings',
      kind: 'Savings',
      opening: 50000,
      currency: 'USD',
    ),
    Account(
      id: 'e',
      name: 'Euro',
      kind: 'Bank',
      opening: 90000,
      currency: 'EUR',
    ),
  ];
  ExpenseReminder item(
    String id,
    int amount,
    int day, {
    String account = 'a',
    bool paid = false,
  }) => ExpenseReminder(
    id: id,
    title: id,
    category: 'Bills',
    accountId: account,
    amount: amount,
    dueDate: DateTime(2026, 9, day),
    paidDate: paid ? today : null,
  );
  CashForecast forecast({
    List<ExpenseReminder> bills = const [],
    List<ExpenseReminder> income = const [],
    List<Entry> entries = const [],
    PlanSettings settings = const PlanSettings(reserve: 1000),
  }) => CashForecast(
    accounts: accounts,
    entries: entries,
    bills: bills,
    income: income,
    currency: 'USD',
    settings: settings,
    now: today,
  );
  test(
    'Reserves overdue and payday bills before income; excludes currencies and savings',
    () {
      final f = forecast(
        bills: [
          item('overdue', 2000, 20),
          item('payday-bill', 5000, 28),
          item('later', 9000, 29),
          item('eur', 50000, 25, account: 'e'),
        ],
        income: [item('salary', 20000, 28), item('late', 50000, 23)],
      );
      expect(f.opening, 10000);
      expect(f.lowest, 3000);
      expect(f.available, 2000);
      expect(f.lowestDate, DateTime(2026, 9, 28));
      expect(f.lateIncome, 1);
      expect(f.events.map((e) => e.id), ['overdue', 'payday-bill', 'salary']);
      expect(f.events.last.after, 23000);
    },
  );
  test(
    'Negative balance never becomes spendable; paid bills and received income excluded',
    () {
      final f = forecast(
        bills: [item('large', 12000, 25), item('paid', 5000, 25, paid: true)],
        income: [item('received', 10000, 26, paid: true)],
      );
      expect(f.payday, isNull);
      expect(f.end, DateTime(2026, 10, 24));
      expect(f.lowest, -2000);
      expect(f.available, 0);
      expect(f.events.length, 1);
    },
  );
  test(
    'Future entries are counted on their date and transfers respect selected accounts',
    () {
      final f = forecast(
        entries: [
          Entry(
            id: 'transfer',
            title: 'save',
            type: 'transfer',
            category: 'Transfer',
            accountId: 'a',
            destinationId: 's',
            amount: 3000,
            date: DateTime(2026, 9, 26),
          ),
          Entry(
            id: 'future',
            title: 'income',
            type: 'income',
            category: 'Salary',
            accountId: 'a',
            amount: 10000,
            date: DateTime(2026, 9, 28),
          ),
        ],
      );
      expect(f.opening, 10000);
      expect(f.lowest, 7000);
      expect(f.events.last.after, 17000);
      final empty = forecast(settings: const PlanSettings(accountIds: []));
      expect(empty.accountIds, isEmpty);
      expect(empty.available, 0);
    },
  );
  test('Income receipt persists once and settings survive reload', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final s = LedgerStore(prefs)..loadDemo();
    final r = ExpenseReminder(
      id: 'expected',
      title: 'Salary',
      category: 'Salary',
      accountId: s.accounts.first.id,
      amount: 1000,
      dueDate: DateTime.now(),
    );
    final before = balance(s.accounts.first, s.entries);
    await s.saveExpectedIncome(r);
    expect(balance(s.accounts.first, s.entries), before);
    await s.receiveIncome(r.id, DateTime.now());
    await s.receiveIncome(r.id, DateTime.now());
    expect(balance(s.accounts.first, s.entries), before + 1000);
    expect(s.entries.where((e) => e.id == r.id).length, 1);
    await s.savePlanSettings(
      'IRT',
      const PlanSettings(accountIds: ['bank'], reserve: 300),
    );
    final restored = LedgerStore(prefs)..loadDemo();
    expect(restored.planSettings['IRT']!.reserve, 300);
    expect(restored.expectedIncome.firstWhere((i) => i.id == r.id).paid, true);
    await s.removeExpectedIncome(r.id);
    expect(s.entries.any((e) => e.id == r.id), true);
    s.dispose();
    restored.dispose();
  });
}
