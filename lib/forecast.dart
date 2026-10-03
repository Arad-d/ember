import 'dart:math' as math;
import 'models.dart';

DateTime calendarDay(DateTime d) => DateTime(d.year, d.month, d.day);

class PlanSettings {
  const PlanSettings({this.accountIds, this.reserve = 0});
  final List<String>? accountIds;
  final int reserve;
  factory PlanSettings.fromJson(Map<String, dynamic> j) => PlanSettings(
    accountIds: (j['account_ids'] as List?)?.cast<String>(),
    reserve: (j['reserve'] as num?)?.toInt() ?? 0,
  );
  Map<String, dynamic> toJson() => {
    'account_ids': accountIds,
    'reserve': reserve,
  };
}

class ForecastEvent {
  ForecastEvent(
    this.id,
    this.title,
    this.date,
    this.amount,
    this.accountId,
    this.kind,
  );
  final String id, title, accountId, kind;
  final DateTime date;
  final int amount;
  int after = 0;
}

class CashForecast {
  CashForecast({
    required List<Account> accounts,
    required List<Entry> entries,
    required List<ExpenseReminder> bills,
    required List<ExpenseReminder> income,
    required String currency,
    required PlanSettings settings,
    required DateTime now,
    DateTime? through,
  }) {
    today = calendarDay(now);
    final included = accounts
        .where(
          (a) =>
              a.currency == currency &&
              (settings.accountIds?.contains(a.id) ?? a.kind != 'Savings'),
        )
        .toList();
    accountIds = included.map((a) => a.id).toSet();
    reserve = settings.reserve;
    final actual = entries.where((e) => !calendarDay(e.date).isAfter(today));
    opening = included.fold(0, (v, a) => v + balance(a, actual));
    final pending = income
        .where((i) => !i.paid && accountIds.contains(i.accountId))
        .toList();
    lateIncome = pending
        .where((i) => calendarDay(i.dueDate).isBefore(today))
        .length;
    final future =
        pending.where((i) => !calendarDay(i.dueDate).isBefore(today)).toList()
          ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    payday = future.firstOrNull?.dueDate;
    end = through != null
        ? calendarDay(through)
        : payday == null
        ? DateTime(today.year, today.month, today.day + 30)
        : calendarDay(payday!);
    if (end.isBefore(today)) {
      throw ArgumentError('Forecast must end today or later.');
    }
    for (final b in bills.where(
      (b) => !b.paid && accountIds.contains(b.accountId),
    )) {
      final d = calendarDay(b.dueDate);
      if (!d.isAfter(end)) {
        events.add(
          ForecastEvent(
            b.id,
            b.title,
            d.isBefore(today) ? today : d,
            -b.amount,
            b.accountId,
            'bill',
          ),
        );
      }
    }
    for (final i in future) {
      if (!calendarDay(i.dueDate).isAfter(end)) {
        events.add(
          ForecastEvent(
            i.id,
            i.title,
            calendarDay(i.dueDate),
            i.amount,
            i.accountId,
            'income',
          ),
        );
      }
    }
    // Future-dated ledger entries are planned movements, not money available today.
    for (final e in entries.where(
      (e) =>
          calendarDay(e.date).isAfter(today) &&
          !calendarDay(e.date).isAfter(end),
    )) {
      final delta =
          (accountIds.contains(e.accountId)
              ? (e.type == 'income' ? e.amount : -e.amount)
              : 0) +
          (e.type == 'transfer' && accountIds.contains(e.destinationId)
              ? e.amount
              : 0);
      if (delta != 0) {
        events.add(
          ForecastEvent(
            e.id,
            e.title,
            calendarDay(e.date),
            delta,
            e.accountId,
            'entry',
          ),
        );
      }
    }
    events.sort((a, b) {
      final date = a.date.compareTo(b.date);
      if (date != 0) return date;
      final sign = a.amount.sign.compareTo(b.amount.sign);
      return sign != 0 ? sign : a.id.compareTo(b.id);
    });
    lowest = opening;
    lowestDate = today;
    var running = opening;
    for (final e in events) {
      running += e.amount;
      e.after = running;
      if (running < lowest) {
        lowest = running;
        lowestDate = e.date;
      }
    }
    available = math.max(0, lowest - reserve);
  }
  late final DateTime today, end;
  late DateTime lowestDate;
  DateTime? payday;
  late final Set<String> accountIds;
  late final int opening, reserve, available;
  late int lowest, lateIncome;
  final List<ForecastEvent> events = [];
}

/// Explains one day using the already ordered forecast, including temporary
/// dips before same-day income. Today's opening is the current ledger balance.
class ForecastDayBreakdown {
  ForecastDayBreakdown(CashForecast forecast, DateTime selected) {
    date = calendarDay(selected);
    if (date.isBefore(forecast.today) || date.isAfter(forecast.end)) {
      throw ArgumentError('Choose a day inside the forecast.');
    }
    opening = forecast.opening;
    for (final event in forecast.events) {
      if (event.date.isBefore(date)) opening = event.after;
      if (event.date == date) events.add(event);
    }
    lowest = opening;
    closing = opening;
    for (final event in events) {
      closing = event.after;
      if (closing < lowest) {
        lowest = closing;
        lowestEvent = event;
      }
    }
    nextIncome = forecast.events
        .where((e) => e.kind == 'income' && !e.date.isBefore(date))
        .firstOrNull;
  }
  late final DateTime date;
  late int opening, lowest, closing;
  ForecastEvent? lowestEvent, nextIncome;
  final List<ForecastEvent> events = [];
}
