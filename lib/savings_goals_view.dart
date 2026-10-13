import 'package:flutter/material.dart';
import 'amount_input.dart';
import 'forecast.dart';
import 'models.dart';
import 'preferences.dart';
import 'savings_goal.dart';
import 'savings_goal_preview.dart';
import 'store.dart';
import 'what_if.dart';

class SavingsGoalsView extends StatelessWidget {
  const SavingsGoalsView({
    super.key,
    required this.store,
    required this.currency,
    required this.openAccounts,
    required this.openForecastSettings,
  });
  final LedgerStore store;
  final String currency;
  final VoidCallback openAccounts, openForecastSettings;
  @override
  Widget build(BuildContext context) {
    final goals = store.savingsGoals
        .where((g) => g.currency == currency)
        .toList();
    final free = store.accounts
        .where(
          (a) =>
              a.currency == currency &&
              a.kind == 'Savings' &&
              !store.savingsGoals.any((g) => g.accountId == a.id),
        )
        .toList();
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Text('Savings goals', style: theme.textTheme.titleLarge),
            ),
            if (store.savingsGoalsAvailable && free.isNotEmpty)
              TextButton.icon(
                onPressed: () => _edit(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add goal'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (!store.savingsGoalsAvailable)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Savings goals need a database update. Your existing plan is still available.',
              ),
            ),
          )
        else if (goals.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.savings_outlined,
                    color: theme.colorScheme.primary,
                    size: 28,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    free.isEmpty
                        ? 'Add a savings account first'
                        : 'Give your savings a goal',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    free.isEmpty
                        ? 'Link a savings account in ${currencies[currency]} to track your progress.'
                        : 'Plan something worth saving for, and see how each contribution fits your bills.',
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: free.isEmpty
                        ? openAccounts
                        : () => _edit(context),
                    icon: Icon(
                      free.isEmpty ? Icons.account_balance_outlined : Icons.add,
                    ),
                    label: Text(
                      free.isEmpty ? 'Add a savings account' : 'Create a goal',
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth >= 850
                  ? (constraints.maxWidth - 16) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: goals
                    .map(
                      (g) => SizedBox(width: width, child: _card(context, g)),
                    )
                    .toList(),
              );
            },
          ),
        if (goals.isNotEmpty && free.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextButton.icon(
              onPressed: openAccounts,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add another savings account'),
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _card(BuildContext context, SavingsGoal goal) {
    final account = store.accounts
        .where((a) => a.id == goal.accountId)
        .firstOrNull;
    if (account == null) {
      return Card(
        child: ListTile(
          title: Text(goal.name),
          subtitle: const Text(
            'Savings account unavailable. Edit the goal to relink it.',
          ),
          onTap: () => _edit(context, goal),
        ),
      );
    }
    final p = calculateGoalProgress(
      goal,
      account,
      store.entries,
      DateTime.now(),
      calendarOf(context),
    );
    final theme = Theme.of(context);
    String money(int value) =>
        '${currencyMoney(value, goal.currency)} ${currencyLabel(goal.currency)}';
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(goal.name, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        'By ${displayDate(context, goal.deadline, year: true)}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Goal options',
                  onSelected: (action) => action == 'edit'
                      ? _edit(context, goal)
                      : _remove(context, goal),
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Text('Edit goal'),
                    ),
                    const PopupMenuItem(
                      value: 'remove',
                      child: Text('Remove goal'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              money(p.saved),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'saved of ${money(goal.target)}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Semantics(
              label: '${(p.fraction * 100).round()} percent saved',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(value: p.fraction, minHeight: 8),
              ),
            ),
            const SizedBox(height: 12),
            if (p.reached)
              Text(
                'Goal reached',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              )
            else
              Text('${money(p.remaining)} remaining'),
            const SizedBox(height: 12),
            if (p.overdue)
              Row(
                children: [
                  const Expanded(child: Text('Deadline passed')),
                  TextButton(
                    onPressed: () => _edit(context, goal),
                    child: const Text('Edit date'),
                  ),
                ],
              )
            else if (!p.reached)
              Text(
                'Save about ${money(p.monthlySuggestion!)} each month',
                style: theme.textTheme.bodyMedium,
              ),
            const SizedBox(height: 10),
            Text(
              'Progress follows ${account.name}’s balance.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _preview(context, goal, p),
                icon: const Icon(Icons.trending_up, size: 18),
                label: const Text('Try in forecast'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context, [SavingsGoal? goal]) async {
    final eligible = store.accounts
        .where(
          (a) =>
              a.currency == currency &&
              a.kind == 'Savings' &&
              !store.savingsGoals.any(
                (g) => g.id != goal?.id && g.accountId == a.id,
              ),
        )
        .toList();
    if (eligible.isEmpty) {
      openAccounts();
      return;
    }
    await _surface(
      context,
      GoalEditor(
        store: store,
        currency: currency,
        goal: goal,
        accounts: eligible,
      ),
    );
  }

  Future<void> _remove(BuildContext context, SavingsGoal goal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove this goal?'),
        content: const Text(
          'Your savings account and its transactions will stay in place.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove goal'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await store.removeSavingsGoal(goal.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_message(e))));
      }
    }
  }

  Future<void> _preview(
    BuildContext context,
    SavingsGoal goal,
    GoalProgress progress,
  ) async {
    final snapshot = WhatIfSnapshot(
      accounts: store.accounts,
      entries: store.entries,
      bills: store.reminders,
      income: store.expectedIncome,
      currency: goal.currency,
      settings: store.planSettings[goal.currency] ?? const PlanSettings(),
      now: DateTime.now(),
    );
    final sources = snapshot.includedAccounts
        .where((a) => a.id != goal.accountId)
        .toList();
    if (sources.isEmpty) {
      final settings = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Choose a spending account'),
          content: const Text(
            'Include a different account in your forecast to preview a contribution.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Forecast settings'),
            ),
          ],
        ),
      );
      if (settings == true) openForecastSettings();
      return;
    }
    await _surface(
      context,
      ContributionPreview(
        snapshot: snapshot,
        goal: goal,
        sources: sources,
        suggestion: progress.monthlySuggestion ?? progress.remaining,
      ),
    );
  }
}

String _message(Object error) => error
    .toString()
    .replaceFirst('Exception: ', '')
    .replaceFirst('Invalid argument(s): ', '');
Future<void> _surface(BuildContext context, Widget child) {
  if (MediaQuery.sizeOf(context).width < 600) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(ctx).height * .86,
          ),
          child: child,
        ),
      ),
    );
  }
  return showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 800),
        child: child,
      ),
    ),
  );
}

class GoalEditor extends StatefulWidget {
  const GoalEditor({
    super.key,
    required this.store,
    required this.currency,
    required this.accounts,
    this.goal,
  });
  final LedgerStore store;
  final String currency;
  final List<Account> accounts;
  final SavingsGoal? goal;
  @override
  State<GoalEditor> createState() => _GoalEditorState();
}

class _GoalEditorState extends State<GoalEditor> {
  final form = GlobalKey<FormState>();
  late final TextEditingController name, amount;
  late String accountId;
  late DateTime deadline;
  bool saving = false;
  String? error;
  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.goal?.name ?? '');
    amount = TextEditingController(
      text: widget.goal == null
          ? ''
          : currencyMoney(widget.goal!.target, widget.currency),
    );
    accountId = widget.accounts.any((a) => a.id == widget.goal?.accountId)
        ? widget.goal!.accountId
        : widget.accounts.first.id;
    final now = DateTime.now();
    deadline =
        widget.goal?.deadline ?? DateTime(now.year, now.month + 3, now.day);
  }

  @override
  void dispose() {
    name.dispose();
    amount.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() => saving = true);
    try {
      await widget.store.saveSavingsGoal(
        SavingsGoal(
          id: widget.goal?.id ?? widget.store.newId,
          name: name.text.trim(),
          target: parseCurrencyAmount(amount.text, widget.currency)!,
          currency: widget.currency,
          deadline: deadline,
          accountId: accountId,
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          saving = false;
          error = _message(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Form(
      key: form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.goal == null ? 'Create a savings goal' : 'Edit savings goal',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          const Text(
            'Choose what you’re saving for. We’ll track the account balance.',
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: name,
            maxLength: 120,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Goal name',
              hintText: 'e.g. A new laptop',
            ),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Give your goal a name.' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [TomanAmountFormatter(() => widget.currency)],
            decoration: InputDecoration(
              labelText: 'Target amount',
              suffixText: widget.currency,
            ),
            validator: (v) {
              final value = parseCurrencyAmount(v ?? '', widget.currency);
              return value == null || value <= 0 || value > 9000000000000
                  ? 'Enter a positive target amount.'
                  : null;
            },
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            initialValue: accountId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Savings account'),
            items: widget.accounts
                .map(
                  (a) => DropdownMenuItem(
                    value: a.id,
                    child: Text(a.name, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: saving ? null : (id) => setState(() => accountId = id!),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Target date'),
            subtitle: Text(displayDate(context, deadline, year: true)),
            trailing: const Icon(Icons.calendar_today_outlined, size: 20),
            onTap: saving
                ? null
                : () async {
                    final today = calendarDay(DateTime.now());
                    final picked = await pickAppDate(
                      context: context,
                      initialDate: deadline.isBefore(today) ? today : deadline,
                      firstDate: today,
                      lastDate: DateTime(today.year + 50),
                    );
                    if (picked != null && mounted) {
                      setState(() => deadline = picked);
                    }
                  },
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: saving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: saving ? null : save,
                  child: Text(saving ? 'Saving…' : 'Save goal'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class ContributionPreview extends StatefulWidget {
  const ContributionPreview({
    super.key,
    required this.snapshot,
    required this.goal,
    required this.sources,
    required this.suggestion,
  });
  final WhatIfSnapshot snapshot;
  final SavingsGoal goal;
  final List<Account> sources;
  final int suggestion;
  @override
  State<ContributionPreview> createState() => _ContributionPreviewState();
}

class _ContributionPreviewState extends State<ContributionPreview> {
  late final TextEditingController amount;
  late String source;
  late DateTime date;
  GoalForecastComparison? result;
  String? error;
  @override
  void initState() {
    super.initState();
    amount = TextEditingController(
      text: widget.suggestion > 0
          ? currencyMoney(widget.suggestion, widget.goal.currency)
          : '',
    );
    source = widget.sources.first.id;
    final base = _base();
    date = base.payday == null
        ? widget.snapshot.today
        : calendarDay(base.payday!);
  }

  CashForecast _base() => CashForecast(
    accounts: widget.snapshot.accounts,
    entries: widget.snapshot.entries,
    bills: widget.snapshot.bills,
    income: widget.snapshot.income,
    currency: widget.snapshot.currency,
    settings: widget.snapshot.settings,
    now: widget.snapshot.today,
  );
  @override
  void dispose() {
    amount.dispose();
    super.dispose();
  }

  void preview() {
    try {
      final value = parseCurrencyAmount(amount.text, widget.goal.currency);
      if (value == null) {
        throw ArgumentError('Enter a positive contribution amount.');
      }
      final r = previewGoalContribution(
        widget.snapshot,
        widget.goal,
        GoalContribution(sourceAccountId: source, amount: value, date: date),
      );
      setState(() {
        result = r;
        error = null;
      });
    } catch (e) {
      setState(() {
        result = null;
        error = _message(e);
      });
    }
  }

  void clear() {
    setState(() => result = null);
  }

  String money(int value) =>
      '${currencyMoney(value, widget.goal.currency)} ${currencyLabel(widget.goal.currency)}';
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), r = result;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Save for ${widget.goal.name}',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text('See how a contribution fits around your upcoming bills.'),
          const SizedBox(height: 24),
          TextField(
            controller: amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [TomanAmountFormatter(() => widget.goal.currency)],
            onChanged: (_) => clear(),
            decoration: InputDecoration(
              labelText: 'Contribution amount',
              suffixText: widget.goal.currency,
            ),
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            initialValue: source,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'From account'),
            items: widget.sources
                .map(
                  (a) => DropdownMenuItem(
                    value: a.id,
                    child: Text(a.name, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (id) {
              setState(() {
                source = id!;
                result = null;
              });
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Contribution date'),
            subtitle: Text(displayDate(context, date, year: true)),
            trailing: const Icon(Icons.calendar_today_outlined, size: 20),
            onTap: () async {
              final picked = await pickAppDate(
                context: context,
                initialDate: date,
                firstDate: widget.snapshot.today,
                lastDate: DateTime(widget.snapshot.today.year + 50),
              );
              if (picked != null && mounted) {
                setState(() {
                  date = picked;
                  result = null;
                });
              }
            },
          ),
          if (error != null)
            Text(error!, style: TextStyle(color: theme.colorScheme.error)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: preview,
              child: const Text('Preview contribution'),
            ),
          ),
          if (r != null) ...[
            const SizedBox(height: 22),
            _result(context, 'Current plan', r.before.forecast),
            const SizedBox(height: 12),
            _result(context, 'After contribution', r.after.forecast),
            const SizedBox(height: 12),
            Text(
              r.after.forecast.lowest < r.after.forecast.reserve
                  ? 'This contribution would take your projected balance below your safety buffer.'
                  : r.after.forecast.accountIds.contains(source) &&
                        r.after.forecast.accountIds.contains(
                          widget.goal.accountId,
                        )
                  ? 'Both accounts are included in your forecast. This transfer keeps their combined balance the same.'
                  : 'Your planned bills and safety buffer are included in this estimate.',
              style: TextStyle(
                color: r.after.forecast.lowest < r.after.forecast.reserve
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurface,
              ),
            ),
          ],
          const SizedBox(height: 18),
          Text(
            'A preview only. Record the transfer when you move the money.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _result(
    BuildContext context,
    String title,
    CashForecast forecast,
  ) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primary.withValues(alpha: .07),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Text(
          '${money(forecast.available)} available',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        Text(
          'Lowest: ${money(forecast.lowest)} · ${displayDate(context, forecast.lowestDate)}',
        ),
        const SizedBox(height: 4),
        Text(
          'Through ${displayDate(context, forecast.end, year: true)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
}
