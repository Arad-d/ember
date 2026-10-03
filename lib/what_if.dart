import 'dart:math' as math;
import 'forecast.dart';
import 'models.dart';

enum ScenarioKind { purchase, income, bill }

/// A temporary adjustment. Existing items use their original ID so editing
/// replaces an adjustment rather than counting the same bill twice.
class ScenarioChange {
  const ScenarioChange({
    required this.id,
    required this.kind,
    required this.title,
    required this.accountId,
    required this.amount,
    required this.date,
  });
  final String id, title, accountId;
  final ScenarioKind kind;
  final int amount;
  final DateTime date;
  String get key => '${kind.name}:$id';
}

class ScenarioDay {
  const ScenarioDay(this.date, this.lowest, this.closing, this.events);
  final DateTime date;
  final int lowest, closing;
  final List<ForecastEvent> events;
}

class ScenarioProjection {
  ScenarioProjection(this.forecast) {
    var running = forecast.opening;
    var cursor = 0;
    for (
      var date = forecast.today;
      !date.isAfter(forecast.end);
      date = DateTime(date.year, date.month, date.day + 1)
    ) {
      var low = running;
      final events = <ForecastEvent>[];
      while (cursor < forecast.events.length &&
          forecast.events[cursor].date == date) {
        final event = forecast.events[cursor++];
        running = event.after;
        low = math.min(low, running);
        events.add(event);
      }
      days.add(ScenarioDay(date, low, running, events));
    }
  }
  final CashForecast forecast;
  final List<ScenarioDay> days = [];
  int get daysBelowBuffer =>
      days.where((d) => d.lowest < forecast.reserve).length;
  DateTime? get firstShortfall =>
      days.where((d) => d.lowest < 0).firstOrNull?.date;
  DateTime? get firstBelowBuffer =>
      days.where((d) => d.lowest < forecast.reserve).firstOrNull?.date;
}

/// A fixed snapshot gives both plans identical inputs while the user explores.
/// This module has no persistence or ledger mutation methods.
class WhatIfSnapshot {
  WhatIfSnapshot({
    required List<Account> accounts,
    required List<Entry> entries,
    required List<ExpenseReminder> bills,
    required List<ExpenseReminder> income,
    required this.currency,
    required PlanSettings settings,
    required DateTime now,
  }) : accounts = List.unmodifiable(accounts),
       entries = List.unmodifiable(entries),
       bills = List.unmodifiable(bills),
       income = List.unmodifiable(income),
       settings = PlanSettings(
         reserve: settings.reserve,
         accountIds: settings.accountIds == null
             ? null
             : List.unmodifiable(settings.accountIds!),
       ),
       today = calendarDay(now);
  final List<Account> accounts;
  final List<Entry> entries;
  final List<ExpenseReminder> bills, income;
  final String currency;
  final PlanSettings settings;
  final DateTime today;
  List<Account> get includedAccounts => accounts
      .where(
        (a) =>
            a.currency == currency &&
            (settings.accountIds?.contains(a.id) ?? a.kind != 'Savings'),
      )
      .toList();
  List<ExpenseReminder> get editableBills => bills
      .where((r) => !r.paid && includedAccounts.any((a) => a.id == r.accountId))
      .toList();
  List<ExpenseReminder> get editableIncome => income
      .where((r) => !r.paid && includedAccounts.any((a) => a.id == r.accountId))
      .toList();

  ScenarioProjection project(List<ScenarioChange> changes, {int days = 30}) {
    if (days != 30 && days != 60) throw ArgumentError('Choose 30 or 60 days.');
    final adjustedBills = [...bills];
    final adjustedIncome = [...income];
    final seen = <String>{};
    for (final change in changes) {
      if (!seen.add(change.key)) {
        throw ArgumentError('An item can only be changed once.');
      }
      if (change.amount <= 0 ||
          change.amount > 9000000000000 ||
          calendarDay(change.date).isBefore(today) ||
          change.title.trim().isEmpty ||
          !includedAccounts.any((a) => a.id == change.accountId)) {
        throw ArgumentError(
          'Choose a valid amount, date, and included account.',
        );
      }
      if (change.kind == ScenarioKind.purchase) {
        adjustedBills.add(
          ExpenseReminder(
            id: 'scenario:${change.id}',
            title: change.title,
            category: 'Other',
            accountId: change.accountId,
            amount: change.amount,
            dueDate: change.date,
          ),
        );
        continue;
      }
      final source = change.kind == ScenarioKind.bill
          ? editableBills
          : editableIncome;
      final original = source.where((r) => r.id == change.id).firstOrNull;
      if (original == null || original.accountId != change.accountId) {
        throw ArgumentError('This planned item is unavailable.');
      }
      if (change.kind == ScenarioKind.income &&
          (change.amount != original.amount ||
              !calendarDay(
                change.date,
              ).isAfter(calendarDay(original.dueDate)))) {
        throw ArgumentError('Choose a later income date.');
      }
      final target = change.kind == ScenarioKind.bill
          ? adjustedBills
          : adjustedIncome;
      final index = target.indexWhere((r) => r.id == change.id);
      target[index] = ExpenseReminder(
        id: original.id,
        title: original.title,
        category: original.category,
        accountId: original.accountId,
        amount: change.amount,
        dueDate: change.date,
        note: original.note,
      );
    }
    return ScenarioProjection(
      CashForecast(
        accounts: accounts,
        entries: entries,
        bills: adjustedBills,
        income: adjustedIncome,
        currency: currency,
        settings: settings,
        now: today,
        through: DateTime(today.year, today.month, today.day + days - 1),
      ),
    );
  }
}
