import 'dart:math' as math;
import 'package:intl/intl.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'models.dart';
import 'preferences.dart';
import 'forecast.dart';

class SavingsGoal {
  const SavingsGoal({
    required this.id,
    required this.name,
    required this.target,
    required this.currency,
    required this.deadline,
    required this.accountId,
  });
  final String id, name, currency, accountId;
  final int target;
  final DateTime deadline;
  factory SavingsGoal.fromJson(Map<String, dynamic> j) => SavingsGoal(
    id: j['id'],
    name: j['name'],
    target: (j['target'] as num).toInt(),
    currency: j['currency'],
    deadline: DateTime.parse(j['deadline']),
    accountId: j['account_id'],
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'target': target,
    'currency': currency,
    'deadline': DateFormat('yyyy-MM-dd').format(deadline),
    'account_id': accountId,
  };
}

class GoalProgress {
  const GoalProgress(
    this.saved,
    this.remaining,
    this.fraction,
    this.monthlySuggestion,
    this.overdue,
  );
  final int saved, remaining;
  final double fraction;
  final int? monthlySuggestion;
  final bool overdue;
  bool get reached => remaining == 0;
}

GoalProgress calculateGoalProgress(
  SavingsGoal goal,
  Account account,
  Iterable<Entry> entries,
  DateTime now,
  AppCalendar calendar,
) {
  final today = calendarDay(now);
  final saved = math.max(
    0,
    balance(account, entries.where((e) => !calendarDay(e.date).isAfter(today))),
  );
  final remaining = math.max(0, goal.target - saved);
  final overdue = calendarDay(goal.deadline).isBefore(today) && remaining > 0;
  int months;
  if (calendar == AppCalendar.shamsi) {
    final a = Jalali.fromDateTime(today),
        b = Jalali.fromDateTime(goal.deadline);
    months = (b.year - a.year) * 12 + b.month - a.month + 1;
  } else {
    months =
        (goal.deadline.year - today.year) * 12 +
        goal.deadline.month -
        today.month +
        1;
  }
  return GoalProgress(
    saved,
    remaining,
    goal.target <= 0 ? 0 : (saved / goal.target).clamp(0, 1).toDouble(),
    overdue
        ? null
        : (remaining + math.max(1, months) - 1) ~/ math.max(1, months),
    overdue,
  );
}
