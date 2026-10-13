import 'package:flutter_test/flutter_test.dart';
import 'package:ember/models.dart';
import 'package:ember/forecast.dart';
import 'package:ember/what_if.dart';
import 'package:ember/savings_goal.dart';
import 'package:ember/savings_goal_preview.dart';

void main() {
  final today = DateTime(2026, 10, 13);
  final goal = SavingsGoal(
    id: 'g',
    name: 'Laptop',
    target: 100,
    currency: 'IRT',
    deadline: DateTime(2027),
    accountId: 's',
  );
  WhatIfSnapshot snapshot(List<String> ids) => WhatIfSnapshot(
    accounts: [
      const Account(id: 'b', name: 'Bank', kind: 'Bank', opening: 200),
      const Account(id: 's', name: 'Savings', kind: 'Savings', opening: 100),
    ],
    entries: [],
    bills: [],
    income: [],
    currency: 'IRT',
    settings: PlanSettings(accountIds: ids, reserve: 20),
    now: today,
  );
  for (final ids in [
    <String>['b'],
    <String>['b', 's'],
    <String>['s'],
    <String>[],
  ]) {
    test('transfer net effect for $ids today and later', () {
      for (final date in [today, DateTime(2026, 12, 1)]) {
        final r = previewGoalContribution(
          snapshot(ids),
          goal,
          GoalContribution(sourceAccountId: 'b', amount: 50, date: date),
        );
        final delta =
            (ids.contains('s') ? 50 : 0) - (ids.contains('b') ? 50 : 0);
        expect(r.after.days.last.closing - r.before.days.last.closing, delta);
        expect(r.after.forecast.end, r.before.forecast.end);
        expect(r.after.forecast.end.isBefore(date), false);
        if (delta == 0) {
          expect(r.after.forecast.lowest, r.before.forecast.lowest);
        }
      }
    });
  }
  test('reject invalid contributions without changing snapshot', () {
    final snap = snapshot(['b']);
    for (final c in [
      GoalContribution(sourceAccountId: 'b', amount: 0, date: today),
      GoalContribution(sourceAccountId: 's', amount: 10, date: today),
      GoalContribution(
        sourceAccountId: 'b',
        amount: 10,
        date: DateTime(2026, 10, 12),
      ),
    ]) {
      expect(() => previewGoalContribution(snap, goal, c), throwsArgumentError);
    }
    expect(snap.entries, isEmpty);
  });
}
