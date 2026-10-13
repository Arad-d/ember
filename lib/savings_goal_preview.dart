import 'forecast.dart';
import 'models.dart';
import 'savings_goal.dart';
import 'what_if.dart';

class GoalContribution {
  const GoalContribution({
    required this.sourceAccountId,
    required this.amount,
    required this.date,
  });
  final String sourceAccountId;
  final int amount;
  final DateTime date;
}

class GoalForecastComparison {
  const GoalForecastComparison(this.before, this.after);
  final ScenarioProjection before, after;
}

GoalForecastComparison previewGoalContribution(
  WhatIfSnapshot snapshot,
  SavingsGoal goal,
  GoalContribution contribution,
) {
  final source = snapshot.accounts
      .where((a) => a.id == contribution.sourceAccountId)
      .firstOrNull;
  final destination = snapshot.accounts
      .where((a) => a.id == goal.accountId)
      .firstOrNull;
  final date = calendarDay(contribution.date);
  if (contribution.amount <= 0 ||
      contribution.amount > 9000000000000 ||
      date.isBefore(snapshot.today) ||
      source == null ||
      destination == null ||
      source.id == destination.id ||
      source.currency != goal.currency ||
      destination.currency != goal.currency ||
      snapshot.currency != goal.currency ||
      destination.kind != 'Savings') {
    throw ArgumentError(
      'Choose a positive amount, today or later, and a different account in this currency.',
    );
  }
  CashForecast build(
    List<Account> accounts,
    List<Entry> entries,
    DateTime? through,
  ) => CashForecast(
    accounts: accounts,
    entries: entries,
    bills: snapshot.bills,
    income: snapshot.income,
    currency: snapshot.currency,
    settings: snapshot.settings,
    now: snapshot.today,
    through: through,
  );
  final initial = build(snapshot.accounts, snapshot.entries, null);
  final end = date.isAfter(initial.end) ? date : initial.end;
  final before = build(snapshot.accounts, snapshot.entries, end);
  var accounts = snapshot.accounts;
  final entries = [...snapshot.entries];
  if (date == snapshot.today) {
    accounts = accounts
        .map(
          (a) => Account(
            id: a.id,
            name: a.name,
            kind: a.kind,
            currency: a.currency,
            opening:
                a.opening +
                (a.id == source.id
                    ? -contribution.amount
                    : a.id == destination.id
                    ? contribution.amount
                    : 0),
          ),
        )
        .toList();
  } else {
    entries.add(
      Entry(
        id: 'goal-preview:${goal.id}',
        title: 'Save for ${goal.name}',
        type: 'transfer',
        category: 'Transfer',
        accountId: source.id,
        destinationId: destination.id,
        amount: contribution.amount,
        date: date,
      ),
    );
  }
  return GoalForecastComparison(
    ScenarioProjection(before),
    ScenarioProjection(build(accounts, entries, end)),
  );
}
