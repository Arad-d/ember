import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'models.dart';
import 'amount_input.dart';
import 'store.dart';
import 'forecast.dart';
import 'forecast_explanation.dart';
import 'what_if.dart';
import 'what_if_page.dart';

class PlanView extends StatefulWidget {
  const PlanView({
    super.key,
    required this.store,
    required this.currency,
    required this.bills,
    required this.addBill,
    required this.editBill,
    required this.openEntry,
  });
  final LedgerStore store;
  final String currency;
  final Widget bills;
  final VoidCallback addBill;
  final Future<void> Function(ExpenseReminder) editBill;
  final Future<void> Function(Entry) openEntry;
  @override
  State<PlanView> createState() => _PlanViewState();
}

CashForecast forecastFor(LedgerStore s, String currency) => CashForecast(
  accounts: s.accounts,
  entries: s.entries,
  bills: s.reminders,
  income: s.expectedIncome,
  currency: currency,
  settings: s.planSettings[currency] ?? const PlanSettings(),
  now: DateTime.now(),
);

class ForecastSummary extends StatelessWidget {
  const ForecastSummary({
    super.key,
    required this.store,
    required this.currency,
    this.onOpen,
    this.onExplain,
  });
  final LedgerStore store;
  final String currency;
  final VoidCallback? onOpen;
  final VoidCallback? onExplain;
  @override
  Widget build(BuildContext context) {
    final f = forecastFor(store, currency);
    String money(int v) => '${currencyMoney(v, currency)} $currency';
    if (onOpen != null) {
      return Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 22,
            vertical: 12,
          ),
          onTap: onOpen,
          title: Text(
            f.payday == null
                ? 'Plan the next 30 days'
                : 'Until payday · ${DateFormat.MMMd().format(f.end)}',
          ),
          subtitle: Text(
            '${f.accountIds.isEmpty ? "Choose forecast accounts" : "${money(f.available)} estimated available"}\n${store.syncError != null
                ? "Using last synced records"
                : f.lowest < f.reserve
                ? "Projected balance below your buffer"
                : "After planned bills and your buffer"}',
            style: const TextStyle(fontSize: 14, height: 1.6),
          ),
          trailing: const Icon(Icons.chevron_right),
        ),
      );
    }
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              f.payday == null
                  ? 'Next 30 days · add your payday'
                  : 'Until payday · ${DateFormat.MMMd().format(f.end)}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            const Text(
              'Estimated available after bills',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 6),
            Text(
              f.accountIds.isEmpty ? 'Choose accounts' : money(f.available),
              style: TextStyle(
                fontSize: onOpen == null ? 30 : 24,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onExplain,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
              ),
              icon: const Icon(Icons.info_outline, size: 18),
              label: Text(
                'Lowest balance: ${money(f.lowest)} · ${DateFormat.MMMMd().format(f.lowestDate)}\nTap to see why',
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
            ),
            if (f.lowest < f.reserve)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'Below your safety buffer by ${money(f.reserve - f.lowest)}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 14,
                  ),
                ),
              ),
            if (f.lateIncome > 0)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  '${f.lateIncome} late income item(s) excluded. Update the date or record receipt.',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            if (onOpen == null) ...[
              const SizedBox(height: 10),
              Text(
                'Buffer: ${money(f.reserve)} · ${f.accountIds.length} accounts',
                style: const TextStyle(fontSize: 14),
              ),
            ],
            const SizedBox(height: 10),
            const Text(
              'Estimate only. Unrecorded everyday spending is not included.',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFFA9A5A5),
                height: 1.5,
              ),
            ),
            if (store.syncError != null)
              Text(
                'Sync is unavailable. This estimate uses the last loaded records.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (onOpen != null)
              TextButton(onPressed: onOpen, child: const Text('Open Plan →')),
          ],
        ),
      ),
    );
  }
}

class _PlanViewState extends State<PlanView> {
  LedgerStore get s => widget.store;
  Future<void> explain(DateTime day) async {
    final result = await showModalBottomSheet<ForecastExplanationAction>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: BoxConstraints(
        maxWidth: 680,
        maxHeight: MediaQuery.sizeOf(context).height * .88,
      ),
      builder: (_) => AnimatedBuilder(
        animation: s,
        builder: (_, child) => ForecastExplanation(
          forecast: forecastFor(s, widget.currency),
          day: day,
          currency: widget.currency,
          accounts: s.accounts,
          bills: s.reminders,
          income: s.expectedIncome,
          stale: s.syncError != null,
        ),
      ),
    );
    if (!mounted || result == null) return;
    switch (result.kind) {
      case 'bill':
        final item = s.reminders
            .where((i) => i.id == result.id && !i.paid)
            .firstOrNull;
        if (item != null) await widget.editBill(item);
      case 'income':
        final item = s.expectedIncome
            .where((i) => i.id == result.id && !i.paid)
            .firstOrNull;
        if (item != null) await incomeForm(item);
      case 'entry':
        final item = s.entries.where((i) => i.id == result.id).firstOrNull;
        if (item != null) await widget.openEntry(item);
      case 'settings':
        await settings();
    }
  }

  String money(int v) =>
      '${currencyMoney(v, widget.currency)} ${widget.currency}';
  Future<void> dialog(
    String title,
    List<Widget> Function(StateSetter) fields,
    Future<void> Function() save, {
    String button = 'Save',
  }) async {
    String? error;
    bool saving = false;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...fields(set),
                  if (error != null)
                    Text(
                      error!,
                      style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      set(() => saving = true);
                      try {
                        await save();
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        if (ctx.mounted) {
                          set(() {
                            saving = false;
                            error = e.toString().replaceFirst(
                              'Exception: ',
                              '',
                            );
                          });
                        }
                      }
                    },
              child: Text(saving ? 'Saving…' : button),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> incomeForm([ExpenseReminder? item]) async {
    final accounts = s.accounts
        .where((a) => a.currency == widget.currency)
        .toList();
    if (accounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add an account in this currency first.')),
      );
      return;
    }
    var account = item?.accountId ?? accounts.first.id;
    var date = item?.dueDate ?? DateTime.now().add(const Duration(days: 7));
    var category = item?.category ?? 'Salary';
    final title = TextEditingController(text: item?.title ?? '');
    final amount = TextEditingController(
      text: item == null ? '' : currencyMoney(item.amount, widget.currency),
    );
    final id = item?.id ?? s.newId;
    await dialog(
      item == null ? 'Add expected income' : 'Edit expected income',
      (set) => [
        const Text(
          'This is a plan. Record it as received only when the money arrives.',
        ),
        const SizedBox(height: 16),
        TextField(
          controller: title,
          maxLength: 120,
          decoration: const InputDecoration(
            labelText: 'Income name',
            hintText: 'Next salary',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: amount,
          inputFormatters: [TomanAmountFormatter(() => widget.currency)],
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: 'Amount (${widget.currency})'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: account,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Into account'),
          items: accounts
              .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name)))
              .toList(),
          onChanged: (v) => set(() => account = v!),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: category,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Category'),
          items: incomeCategories
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: (v) => set(() => category = v!),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: date,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (d != null) set(() => date = d);
          },
          child: Text('Expected ${DateFormat.yMMMd().format(date)}'),
        ),
      ],
      () async {
        final value = parseCurrencyAmount(amount.text, widget.currency);
        if (value == null || value <= 0) {
          throw Exception('Enter a positive amount.');
        }
        await s.saveExpectedIncome(
          ExpenseReminder(
            id: id,
            title: title.text.trim(),
            category: category,
            accountId: account,
            amount: value,
            dueDate: date,
          ),
        );
      },
    );
  }

  Future<void> settings() async {
    final f = forecastFor(s, widget.currency);
    final selected = f.accountIds.toSet();
    final reserve = TextEditingController(
      text: currencyMoney(f.reserve, widget.currency),
    );
    await dialog(
      'Forecast settings',
      (set) => [
        const Text(
          'Choose money available for bills. Savings accounts are excluded by default.',
        ),
        const SizedBox(height: 12),
        ...s.accounts
            .where((a) => a.currency == widget.currency)
            .map(
              (a) => CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(a.name),
                value: selected.contains(a.id),
                onChanged: (v) => set(() {
                  if (v == true) {
                    selected.add(a.id);
                  } else {
                    selected.remove(a.id);
                  }
                }),
              ),
            ),
        const SizedBox(height: 12),
        TextField(
          controller: reserve,
          inputFormatters: [TomanAmountFormatter(() => widget.currency)],
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Safety buffer (${widget.currency})',
          ),
        ),
      ],
      () async {
        final value = parseCurrencyAmount(reserve.text, widget.currency);
        if (value == null || value < 0) {
          throw Exception('Enter zero or a positive buffer.');
        }
        await s.savePlanSettings(
          widget.currency,
          PlanSettings(accountIds: selected.toList(), reserve: value),
        );
      },
    );
  }

  Future<void> incomeAction(ExpenseReminder i, String action) async {
    if (action == 'edit') {
      await incomeForm(i);
      return;
    }
    var date = DateTime.now();
    await dialog(
      action == 'receive' ? 'Record income received' : 'Delete expected income',
      (set) => [
        Text(
          action == 'receive'
              ? '${i.title} · ${money(i.amount)}\nCreates one income transaction. If you already entered it in Activity, cancel and delete this plan instead.'
              : 'Remove ${i.title} from your plan?',
        ),
        if (action == 'receive')
          TextButton(
            onPressed: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: date,
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
              );
              if (d != null) set(() => date = d);
            },
            child: Text(DateFormat.yMMMd().format(date)),
          ),
      ],
      () => action == 'receive'
          ? s.receiveIncome(i.id, date)
          : s.removeExpectedIncome(i.id),
      button: action == 'receive' ? 'Record income' : 'Delete',
    );
  }

  @override
  Widget build(BuildContext context) {
    final f = forecastFor(s, widget.currency);
    final pending =
        s.expectedIncome
            .where(
              (i) =>
                  !i.paid &&
                  s.accounts.any(
                    (a) => a.id == i.accountId && a.currency == widget.currency,
                  ),
            )
            .toList()
          ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ForecastSummary(
          store: s,
          currency: widget.currency,
          onExplain: () => explain(f.lowestDate),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: () => incomeForm(),
              icon: const Icon(Icons.south_west),
              label: const Text('Add income'),
            ),
            OutlinedButton.icon(
              onPressed: widget.addBill,
              icon: const Icon(Icons.add),
              label: const Text('Add bill'),
            ),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => WhatIfPage(
                    snapshot: WhatIfSnapshot(
                      accounts: s.accounts,
                      entries: s.entries,
                      bills: s.reminders,
                      income: s.expectedIncome,
                      currency: widget.currency,
                      settings:
                          s.planSettings[widget.currency] ??
                          const PlanSettings(),
                      now: DateTime.now(),
                    ),
                    syncStale: s.syncError != null,
                  ),
                ),
              ),
              icon: const Icon(Icons.alt_route),
              label: const Text('What if?'),
            ),
            TextButton.icon(
              onPressed: settings,
              icon: const Icon(Icons.tune),
              label: const Text('Forecast settings'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('View forecast'),
          subtitle: Text('Today – ${DateFormat.MMMd().format(f.end)}'),
          children: [
            if (f.events.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Add bills and expected income to see your timeline.',
                ),
              ),
            if (f.events.isNotEmpty) ...[
              Text(
                'Projected balance · ${money(f.lowest)} lowest',
                style: const TextStyle(fontSize: 14),
              ),
              SizedBox(
                height: 150,
                width: double.infinity,
                child: CustomPaint(
                  painter: _ForecastPainter(
                    f,
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(DateFormat.MMMd().format(f.today)),
                  Text(DateFormat.MMMd().format(f.end)),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
        const SizedBox(height: 16),
        Text(
          f.payday == null ? 'Next 30 days' : 'Until payday timeline',
          style: const TextStyle(fontSize: 20),
        ),
        const SizedBox(height: 8),
        const Text(
          'Overdue bills are reserved today. Bills come before income on the same day.',
          style: TextStyle(fontSize: 14, color: Color(0xFFA9A5A5)),
        ),
        ...f.events.map(
          (e) => ListTile(
            onTap: () => explain(e.date),
            trailing: const Icon(Icons.chevron_right, size: 20),
            contentPadding: EdgeInsets.zero,
            leading: Icon(e.amount < 0 ? Icons.north_east : Icons.south_west),
            title: Text(e.title),
            subtitle: Text(
              '${DateFormat.MMMd().format(e.date)} · ${e.kind == "entry"
                  ? "Recorded future transaction"
                  : e.kind == "bill"
                  ? "Bill"
                  : "Expected income"}\n${e.amount > 0 ? "+" : ""}${money(e.amount)}\nProjected balance: ${money(e.after)}',
              style: TextStyle(
                fontSize: 14,
                color: e.after < f.reserve
                    ? Theme.of(context).colorScheme.error
                    : null,
              ),
            ),
            isThreeLine: true,
          ),
        ),
        const SizedBox(height: 24),
        const Text('Expected income', style: TextStyle(fontSize: 20)),
        const SizedBox(height: 8),
        if (pending.isEmpty)
          const Text(
            'Add your next payday to plan around it.',
            style: TextStyle(fontSize: 14),
          ),
        ...pending.map(
          (i) => ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(i.title),
            subtitle: Text(
              '${money(i.amount)} · ${DateFormat.MMMd().format(i.dueDate)}${i.daysUntil(DateTime.now()) < 0 ? " · Late, excluded" : ""}${f.accountIds.contains(i.accountId) ? "" : " · Account excluded"}',
              style: const TextStyle(fontSize: 14),
            ),
            trailing: PopupMenuButton<String>(
              tooltip: 'Income actions',
              onSelected: (a) => incomeAction(i, a),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'receive', child: Text('Record received')),
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text('Bills & reminders', style: TextStyle(fontSize: 20)),
        const SizedBox(height: 16),
        widget.bills,
      ],
    );
  }
}

class _ForecastPainter extends CustomPainter {
  _ForecastPainter(this.f, this.color);
  final CashForecast f;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final values = [f.opening, ...f.events.map((e) => e.after), f.reserve];
    final min = values.reduce((a, b) => a < b ? a : b),
        max = values.reduce((a, b) => a > b ? a : b);
    double y(int v) =>
        size.height -
        16 -
        (v - min) / (max == min ? 1 : max - min) * (size.height - 32);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(0, y(f.reserve)),
      Offset(size.width, y(f.reserve)),
      Paint()..color = color.withValues(alpha: .25),
    );
    final path = Path()..moveTo(0, y(f.opening));
    for (var i = 0; i < f.events.length; i++) {
      final days = f.end.difference(f.today).inDays;
      final x = days == 0
          ? size.width
          : f.events[i].date.difference(f.today).inDays / days * size.width;
      path.lineTo(x, y(i == 0 ? f.opening : f.events[i - 1].after));
      path.lineTo(x, y(f.events[i].after));
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ForecastPainter oldDelegate) => true;
}
