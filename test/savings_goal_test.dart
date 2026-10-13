import 'package:flutter_test/flutter_test.dart';
import 'package:ember/savings_goal.dart';
import 'package:ember/models.dart';
import 'package:ember/preferences.dart';

void main() {
  SavingsGoal goal(DateTime deadline, {int target = 300}) => SavingsGoal(
    id: 'g',
    name: 'Laptop',
    target: target,
    currency: 'IRT',
    deadline: deadline,
    accountId: 's',
  );
  Account account(int opening) =>
      Account(id: 's', name: 'Savings', kind: 'Savings', opening: opening);
  final today = DateTime(2026, 10, 13);
  test('progress clamps balance and bar while preserving remaining', () {
    for (final value in [120, -20, 400]) {
      final p = calculateGoalProgress(
        goal(DateTime(2026, 12, 1)),
        account(value),
        [],
        today,
        AppCalendar.gregorian,
      );
      expect(p.saved, value < 0 ? 0 : value);
      expect(
        p.remaining,
        value == 120
            ? 180
            : value < 0
            ? 300
            : 0,
      );
      expect(
        p.fraction,
        value == 120
            ? .4
            : value < 0
            ? 0
            : 1,
      );
      expect(p.reached, value >= 300);
    }
  });
  test('future transfers are excluded and withdrawals lower progress', () {
    final entries = [
      Entry(
        id: 'e',
        title: 'Save',
        type: 'transfer',
        category: 'Transfer',
        accountId: 'b',
        destinationId: 's',
        amount: 100,
        date: DateTime(2026, 10, 14),
      ),
      Entry(
        id: 'w',
        title: 'Withdraw',
        type: 'transfer',
        category: 'Transfer',
        accountId: 's',
        destinationId: 'b',
        amount: 20,
        date: today,
      ),
    ];
    expect(
      calculateGoalProgress(
        goal(today),
        account(120),
        entries,
        today,
        AppCalendar.gregorian,
      ).saved,
      100,
    );
  });
  test('inclusive months round up and overdue suggestion is absent', () {
    expect(
      calculateGoalProgress(
        goal(DateTime(2026, 12, 1), target: 10),
        account(0),
        [],
        today,
        AppCalendar.gregorian,
      ).monthlySuggestion,
      4,
    );
    final p = calculateGoalProgress(
      goal(DateTime(2026, 10, 12)),
      account(0),
      [],
      today,
      AppCalendar.gregorian,
    );
    expect(p.overdue, true);
    expect(p.monthlySuggestion, isNull);
  });
  test('Shamsi months follow Nowruz rather than Gregorian months', () {
    final g = goal(DateTime(2024, 4, 20), target: 10);
    expect(
      calculateGoalProgress(
        g,
        account(0),
        [],
        DateTime(2024, 3, 20),
        AppCalendar.shamsi,
      ).monthlySuggestion,
      5,
    );
    expect(
      calculateGoalProgress(
        g,
        account(0),
        [],
        DateTime(2024, 3, 19),
        AppCalendar.shamsi,
      ).monthlySuggestion,
      4,
    );
  });
  test('goal JSON round trip', () {
    final g = goal(today);
    expect(SavingsGoal.fromJson(g.toJson()).toJson(), g.toJson());
  });
}
