import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'forecast.dart';
import 'models.dart';

class ForecastExplanationAction {
  const ForecastExplanationAction(this.kind, [this.id]);
  final String kind;
  final String? id;
}

class ForecastExplanation extends StatelessWidget {
  const ForecastExplanation({
    super.key,
    required this.forecast,
    required this.day,
    required this.currency,
    required this.accounts,
    required this.bills,
    required this.income,
    required this.stale,
  });
  final CashForecast forecast;
  final DateTime day;
  final String currency;
  final List<Account> accounts;
  final List<ExpenseReminder> bills, income;
  final bool stale;
  String money(int n) => '${currencyMoney(n, currency)} $currency';
  String date(DateTime d) => DateFormat.MMMd().format(d);
  @override
  Widget build(BuildContext context) {
    final f = forecast;
    final selected = day.isBefore(f.today)
        ? f.today
        : day.isAfter(f.end)
        ? f.end
        : day;
    final detail = ForecastDayBreakdown(f, selected);
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: .7);
    final included = accounts
        .where((a) => f.accountIds.contains(a.id))
        .toList();
    final excluded = accounts
        .where((a) => a.currency == currency && !f.accountIds.contains(a.id))
        .toList();
    final late = income
        .where(
          (i) =>
              !i.paid &&
              f.accountIds.contains(i.accountId) &&
              calendarDay(i.dueDate).isBefore(f.today),
        )
        .toList();
    void action(String kind, [String? id]) =>
        Navigator.pop(context, ForecastExplanationAction(kind, id));
    Widget figure(String label, int amount) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label, style: TextStyle(fontSize: 14, color: muted)),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              money(amount),
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
    final why = detail.lowestEvent == null
        ? 'The starting balance is the lowest point for this day.'
        : 'The balance reaches ${money(detail.lowest)} after ${detail.lowestEvent!.title}.';
    final buffer = detail.lowest < f.reserve
        ? 'That is ${money(f.reserve - detail.lowest)} below your safety buffer.'
        : 'That leaves ${money(detail.lowest - f.reserve)} above your safety buffer.';
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Why this balance?\n${DateFormat.yMMMd().format(selected)}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close explanation',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (included.isEmpty) ...[
              const Text(
                'Choose accounts to build your forecast.',
                style: TextStyle(fontSize: 16),
              ),
              TextButton(
                onPressed: () => action('settings'),
                child: const Text('Choose accounts'),
              ),
            ] else ...[
              Text(
                '$why $buffer',
                style: const TextStyle(fontSize: 16, height: 1.6),
              ),
              if (detail.nextIncome != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    '${detail.nextIncome!.title}: ${money(detail.nextIncome!.amount)} expected ${date(detail.nextIncome!.date)}.',
                    style: TextStyle(fontSize: 14, height: 1.5, color: muted),
                  ),
                ),
              if (stale)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    'Sync is unavailable. These are your last loaded records.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 14,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              figure(
                selected == f.today
                    ? 'Starting forecast balance'
                    : 'Balance carried into this day',
                detail.opening,
              ),
              figure('Lowest during the day', detail.lowest),
              figure('Projected end of day', detail.closing),
              figure('Safety buffer', f.reserve),
              const SizedBox(height: 12),
              ExpansionTile(
                key: ValueKey('breakdown-${selected.toIso8601String()}'),
                tilePadding: EdgeInsets.zero,
                title: const Text('See the calculation'),
                subtitle: Text(
                  '${detail.events.length} planned movements',
                  style: const TextStyle(fontSize: 14),
                ),
                children: [
                  figure('Starting balance', detail.opening),
                  if (detail.events.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'No planned movements on this day. The balance carries forward.',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ...detail.events.map((e) {
                    final account = accounts
                        .where((a) => a.id == e.accountId)
                        .firstOrNull;
                    final bill = e.kind == 'bill'
                        ? bills.where((b) => b.id == e.id).firstOrNull
                        : null;
                    final overdue =
                        bill != null &&
                        calendarDay(bill.dueDate).isBefore(f.today);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      onTap: () => action(e.kind, e.id),
                      title: Text(e.title),
                      subtitle: Text(
                        '${e.kind == 'bill'
                            ? 'Bill'
                            : e.kind == 'income'
                            ? 'Expected income'
                            : 'Recorded transaction'} · ${account?.name ?? 'Account'}${overdue ? '\nDue ${date(bill.dueDate)} · reserved today' : ''}\n${e.amount > 0 ? '+' : ''}${money(e.amount)}\nBalance after: ${money(e.after)}',
                        style: const TextStyle(fontSize: 14, height: 1.5),
                      ),
                      trailing: Icon(
                        e.kind == 'entry'
                            ? Icons.chevron_right
                            : Icons.edit_outlined,
                        size: 20,
                      ),
                    );
                  }),
                  const SizedBox(height: 10),
                  const Text(
                    'Bills are counted before income due on the same day. These are forecast steps, not exact payment times.',
                    style: TextStyle(fontSize: 14, height: 1.5),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('What’s included?'),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Accounts: ${included.isEmpty ? 'none selected' : included.map((a) => a.name).join(', ')}.\nThis forecast combines selected accounts in $currency.',
                    style: const TextStyle(fontSize: 14, height: 1.6),
                  ),
                ),
                if (excluded.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Excluded accounts: ${excluded.map((a) => a.name).join(', ')}.',
                        style: const TextStyle(fontSize: 14, height: 1.5),
                      ),
                    ),
                  ),
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text(
                    'Everyday spending you haven’t recorded is excluded. Paid bills and received income are reflected in your ledger balance. Accounts in other currencies are kept separate.',
                    style: TextStyle(fontSize: 14, height: 1.6),
                  ),
                ),
                if (late.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Late income excluded',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  ...late.map(
                    (i) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(i.title),
                      subtitle: Text(
                        '${money(i.amount)} · expected ${date(i.dueDate)}',
                        style: const TextStyle(fontSize: 14),
                      ),
                      trailing: const Icon(Icons.edit_outlined, size: 20),
                      onTap: () => action('income', i.id),
                    ),
                  ),
                ],
                TextButton(
                  onPressed: () => action('settings'),
                  child: const Text('Edit forecast settings'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
