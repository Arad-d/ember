import 'preferences.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'models.dart';
import 'amount_input.dart';
import 'what_if.dart';

class WhatIfPage extends StatefulWidget {
  const WhatIfPage({super.key, required this.snapshot, this.syncStale = false});
  final WhatIfSnapshot snapshot;
  final bool syncStale;
  @override
  State<WhatIfPage> createState() => _WhatIfPageState();
}

class _WhatIfPageState extends State<WhatIfPage> with PaletteState<WhatIfPage> {
  final changes = <ScenarioChange>[];
  final scroll = ScrollController();
  final controlsAnchor = GlobalKey();
  int days = 30, nextId = 0;
  WhatIfSnapshot get data => widget.snapshot;
  String money(int amount) =>
      '${currencyMoney(amount, data.currency)} ${data.currency}';
  String date(DateTime value) => displayDate(context, value);
  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  Future<void> edit(ScenarioKind kind, [ScenarioChange? change]) async {
    final result = await showDialog<ScenarioChange>(
      context: context,
      builder: (_) => _ChangeEditor(
        snapshot: data,
        kind: kind,
        existing: change,
        changes: changes,
        purchaseId: change?.id ?? 'purchase-${nextId++}',
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      changes.removeWhere((c) => c.key == result.key || c.key == change?.key);
      changes.add(result);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && scroll.hasClients) {
        scroll.animateTo(
          0,
          duration: Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget scenarioPanel(Widget child, {Color? color}) => Container(
    width: double.infinity,
    padding: EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: color ?? palette.panel,
      border: Border.all(color: line),
      borderRadius: BorderRadius.circular(18),
    ),
    child: child,
  );

  Widget choice(
    String title,
    String detail,
    IconData icon,
    ScenarioKind kind,
    bool enabled,
  ) => Padding(
    padding: EdgeInsets.only(bottom: 10),
    child: OutlinedButton(
      onPressed: enabled ? () => edit(kind) : null,
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: EdgeInsets.all(16),
      ),
      child: Row(
        children: [
          Icon(icon),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 4),
                Text(
                  detail,
                  style: TextStyle(fontSize: 14, color: muted, height: 1.4),
                ),
              ],
            ),
          ),
          SizedBox(width: 8),
          Icon(Icons.chevron_right, size: 20),
        ],
      ),
    ),
  );

  Widget controls(ScenarioProjection proposed) => Column(
    key: controlsAnchor,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        changes.isEmpty ? 'What would you like to try?' : 'Try another change',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
      ),
      SizedBox(height: 14),
      choice(
        'Add a purchase',
        'Try an amount and a date.',
        Icons.shopping_bag_outlined,
        ScenarioKind.purchase,
        data.includedAccounts.isNotEmpty,
      ),
      choice(
        'Delay income',
        data.editableIncome.isEmpty
            ? 'Add expected income in Plan first.'
            : 'See what happens if payday arrives later.',
        Icons.schedule,
        ScenarioKind.income,
        data.editableIncome.isNotEmpty,
      ),
      choice(
        'Change a bill',
        data.editableBills.isEmpty
            ? 'Add a bill in Plan first.'
            : 'Try a different amount or payment date.',
        Icons.receipt_long_outlined,
        ScenarioKind.bill,
        data.editableBills.isNotEmpty,
      ),
      if (data.includedAccounts.isEmpty)
        Text(
          'Choose accounts in Plan → Forecast settings to start.',
          style: TextStyle(fontSize: 14, color: rose),
        ),
      if (changes.isNotEmpty) ...[
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text('Your changes', style: TextStyle(fontSize: 20)),
            ),
            TextButton(
              onPressed: () => setState(changes.clear),
              child: Text('Clear all'),
            ),
          ],
        ),
        ...changes.map(
          (c) => Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: scenarioPanel(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.title,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  SizedBox(height: 6),
                  Text(
                    '${c.kind == ScenarioKind.income
                        ? "Income moved to"
                        : c.kind == ScenarioKind.bill
                        ? "Bill on"
                        : "Purchase on"} ${date(c.date)} · ${money(c.amount)}',
                    style: TextStyle(fontSize: 14, height: 1.5),
                  ),
                  if (c.date.isAfter(proposed.forecast.end))
                    Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        'Outside this window. It is excluded from this comparison.',
                        style: TextStyle(fontSize: 14, color: rose),
                      ),
                    ),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: () => edit(c.kind, c),
                        child: Text('Edit'),
                      ),
                      TextButton(
                        onPressed: () => setState(() => changes.remove(c)),
                        child: Text('Remove'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ],
  );

  Widget metric(
    String label,
    String current,
    String proposed, {
    String? currentDetail,
    String? proposedDetail,
  }) => Padding(
    padding: EdgeInsets.only(top: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 14, color: muted)),
        SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(current, style: TextStyle(fontSize: 18)),
                  if (currentDetail != null)
                    Text(
                      currentDetail,
                      style: TextStyle(fontSize: 14, color: muted),
                    ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Icon(Icons.arrow_forward, size: 18, color: muted),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(proposed, style: TextStyle(fontSize: 18, color: rose)),
                  if (proposedDetail != null)
                    Text(
                      proposedDetail,
                      style: TextStyle(fontSize: 14, color: muted),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );

  String explanation(ScenarioProjection base, ScenarioProjection next) {
    final f = next.forecast;
    final difference = f.lowest - base.forecast.lowest;
    final change = difference == 0
        ? 'Your lowest balance stays the same.'
        : 'Your lowest balance is ${money(difference.abs())} ${difference < 0 ? "lower" : "higher"} than your current plan.';
    final cause = f.events
        .where((e) => e.after == f.lowest && e.date == f.lowestDate)
        .firstOrNull;
    final why = cause == null
        ? 'The starting balance is the lowest point in this window.'
        : 'The lowest point follows ${cause.title} on ${date(cause.date)}.';
    final impact = f.lowest < f.reserve
        ? 'You would be ${money(f.reserve - f.lowest)} below your ${money(f.reserve)} buffer at the lowest point.'
        : 'Your plan keeps at least ${money(f.lowest - f.reserve)} above your buffer.';
    return '$change $why $impact';
  }

  Widget results(ScenarioProjection base, ScenarioProjection next) {
    final f = next.forecast;
    final shortfall = f.lowest < 0;
    final below = f.lowest < f.reserve;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (changes.any((c) => c.date.isAfter(f.end)))
          Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Some changes fall after ${date(f.end)} and are excluded. Extend to 60 days or adjust their dates to see the impact.',
              style: TextStyle(fontSize: 14, color: rose, height: 1.5),
            ),
          ),
        scenarioPanel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    below ? Icons.info_outline : Icons.check_circle_outline,
                    color: below ? rose : green,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      shortfall
                          ? 'A shortfall is projected'
                          : below
                          ? 'Below your safety buffer'
                          : 'Stays above your buffer',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 14),
              Text(
                explanation(base, next),
                style: TextStyle(fontSize: 16, height: 1.6),
              ),
              SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Current plan',
                      style: TextStyle(fontSize: 14, color: muted),
                    ),
                  ),
                  SizedBox(width: 42),
                  Expanded(
                    child: Text(
                      'With changes',
                      style: TextStyle(fontSize: 14, color: rose),
                    ),
                  ),
                ],
              ),
              metric(
                'Lowest projected balance',
                money(base.forecast.lowest),
                money(f.lowest),
                currentDetail: date(base.forecast.lowestDate),
                proposedDetail: date(f.lowestDate),
              ),
              metric(
                'Available above your buffer',
                money(base.forecast.available),
                money(f.available),
              ),
              metric(
                'Days below your buffer',
                '${base.daysBelowBuffer} of $days',
                '${next.daysBelowBuffer} of $days',
              ),
              metric(
                'First negative balance',
                base.firstShortfall == null
                    ? 'None'
                    : date(base.firstShortfall!),
                next.firstShortfall == null
                    ? 'None'
                    : date(next.firstShortfall!),
              ),
            ],
          ),
        ),
        SizedBox(height: 12),
        if (f.lateIncome > 0)
          Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              '${f.lateIncome} late income item(s) are excluded from this scenario until a future date is chosen.',
              style: TextStyle(fontSize: 14, color: rose, height: 1.5),
            ),
          ),
        Text(
          'Based on recorded plans only. Unrecorded everyday spending is excluded. Bills count before income on the same day. A day counts as below the buffer if its balance drops below it at any point.',
          style: TextStyle(fontSize: 14, color: muted, height: 1.5),
        ),
        SizedBox(height: 12),
        scenarioPanel(
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.only(top: 16),
            title: Text('Chart & daily details'),
            children: [
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _legend('Current', muted),
                  _legend('With changes', rose),
                  _legend('Buffer', green),
                ],
              ),
              SizedBox(height: 16),
              Text(
                'Daily lowest balance',
                style: TextStyle(fontSize: 14, color: muted),
              ),
              SizedBox(height: 8),
              Semantics(
                label: 'Daily lowest balances. Exact values are listed below.',
                child: SizedBox(
                  height: 150,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _ComparisonPainter(base, next, palette),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [Text(date(f.today)), Text(date(f.end))],
              ),
              SizedBox(height: 16),
              ...List.generate(next.days.length, (i) {
                final a = base.days[i], b = next.days[i];
                if (i != 0 &&
                    a.events.isEmpty &&
                    b.events.isEmpty &&
                    i != next.days.length - 1) {
                  return SizedBox.shrink();
                }
                final labels = {
                  ...a.events.map((e) => e.title),
                  ...b.events.map((e) => e.title),
                };
                return Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        date(b.date),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (labels.isNotEmpty)
                        Text(
                          labels.join(' · '),
                          style: TextStyle(fontSize: 14, color: muted),
                        ),
                      Text(
                        'Current low: ${money(a.lowest)}\nWith changes: ${money(b.lowest)}',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: b.lowest < f.reserve ? rose : null,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _legend(String label, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 16, height: 3, color: color),
      SizedBox(width: 6),
      Text(label, style: TextStyle(fontSize: 14)),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final base = data.project([], days: days),
        next = data.project(changes, days: days);
    return Scaffold(
      bottomNavigationBar:
          changes.isNotEmpty && MediaQuery.sizeOf(context).width < 890
          ? SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 10, 20, 10),
                child: FilledButton.icon(
                  onPressed: () {
                    final target = controlsAnchor.currentContext;
                    if (target != null) {
                      Scrollable.ensureVisible(
                        target,
                        duration: Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                      );
                    }
                  },
                  icon: Icon(Icons.add),
                  label: Text('Add or edit changes'),
                ),
              ),
            )
          : null,
      appBar: AppBar(
        title: Text('What if?'),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Chip(label: Text('Simulation')),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          controller: scroll,
          padding: EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 1160),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Try a change. See the impact.',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w500),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Your real records stay unchanged. This simulation clears when you leave.',
                    style: TextStyle(fontSize: 16, color: muted, height: 1.5),
                  ),
                  SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ChoiceChip(
                        label: Text('30 days'),
                        selected: days == 30,
                        onSelected: (_) => setState(() => days = 30),
                      ),
                      ChoiceChip(
                        label: Text('60 days'),
                        selected: days == 60,
                        onSelected: (_) => setState(() => days = 60),
                      ),
                      Text(
                        '${date(data.today)} – ${date(next.forecast.end)} · ${data.currency}',
                        style: TextStyle(fontSize: 14, color: muted),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Buffer ${money(data.settings.reserve)} · ${data.includedAccounts.length} accounts from your Plan settings',
                    style: TextStyle(fontSize: 14, color: muted),
                  ),
                  if (widget.syncStale)
                    Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: Text(
                        'Using your last loaded records because sync is unavailable.',
                        style: TextStyle(fontSize: 14, color: rose),
                      ),
                    ),
                  SizedBox(height: 24),
                  LayoutBuilder(
                    builder: (context, c) {
                      if (changes.isEmpty) {
                        return ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: 560),
                          child: controls(next),
                        );
                      }
                      if (c.maxWidth >= 850) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 4, child: controls(next)),
                            SizedBox(width: 24),
                            Expanded(flex: 6, child: results(base, next)),
                          ],
                        );
                      }
                      return Column(
                        children: [
                          results(base, next),
                          SizedBox(height: 28),
                          controls(next),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChangeEditor extends StatefulWidget {
  const _ChangeEditor({
    required this.snapshot,
    required this.kind,
    required this.existing,
    required this.changes,
    required this.purchaseId,
  });
  final WhatIfSnapshot snapshot;
  final ScenarioKind kind;
  final ScenarioChange? existing;
  final List<ScenarioChange> changes;
  final String purchaseId;
  @override
  State<_ChangeEditor> createState() => _ChangeEditorState();
}

class _ChangeEditorState extends State<_ChangeEditor>
    with PaletteState<_ChangeEditor> {
  final title = TextEditingController(), amount = TextEditingController();
  late String account, id;
  late DateTime selectedDate;
  String? error;
  WhatIfSnapshot get data => widget.snapshot;
  bool get purchase => widget.kind == ScenarioKind.purchase;
  bool get income => widget.kind == ScenarioKind.income;
  List<ExpenseReminder> get items =>
      income ? data.editableIncome : data.editableBills;
  ExpenseReminder get original => items.firstWhere((r) => r.id == id);
  DateTime later(DateTime a, DateTime b) => a.isAfter(b) ? a : b;
  @override
  void initState() {
    super.initState();
    account = data.includedAccounts.first.id;
    id = widget.purchaseId;
    selectedDate = data.today;
    if (!purchase) {
      loadItem(widget.existing?.id ?? items.first.id);
    } else {
      title.text = widget.existing?.title ?? '';
      amount.text = widget.existing == null
          ? ''
          : currencyMoney(widget.existing!.amount, data.currency);
      account = widget.existing?.accountId ?? account;
      selectedDate = widget.existing?.date ?? data.today;
    }
  }

  void loadItem(String value) {
    id = value;
    final item = original;
    final prior = widget.changes
        .where((c) => c.id == id && c.kind == widget.kind)
        .firstOrNull;
    title.text = item.title;
    account = item.accountId;
    amount.text = currencyMoney(prior?.amount ?? item.amount, data.currency);
    selectedDate =
        prior?.date ??
        later(
          data.today,
          income
              ? DateTime(
                  item.dueDate.year,
                  item.dueDate.month,
                  item.dueDate.day + 7,
                )
              : item.dueDate,
        );
  }

  @override
  void dispose() {
    title.dispose();
    amount.dispose();
    super.dispose();
  }

  void submit() {
    final value = income
        ? original.amount
        : parseCurrencyAmount(amount.text, data.currency);
    if (value == null || value <= 0 || value > 9000000000000) {
      setState(() => error = 'Enter an amount greater than zero.');
      return;
    }
    final change = ScenarioChange(
      id: id,
      kind: widget.kind,
      title: purchase
          ? (title.text.trim().isEmpty ? 'New purchase' : title.text.trim())
          : original.title,
      accountId: account,
      amount: value,
      date: selectedDate,
    );
    try {
      data.project([
        ...widget.changes.where(
          (c) => c.key != change.key && c.key != widget.existing?.key,
        ),
        change,
      ]);
      Navigator.pop(context, change);
    } catch (_) {
      setState(
        () => error = income
            ? 'Choose a date after the original income date.'
            : 'Check the amount, date, and account.',
      );
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    insetPadding: EdgeInsets.all(16),
    title: Text(
      purchase
          ? 'Try a purchase'
          : income
          ? 'Delay income'
          : 'Change a bill',
    ),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!purchase) ...[
              DropdownButtonFormField<String>(
                initialValue: id,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: income ? 'Expected income' : 'Upcoming bill',
                ),
                items: items
                    .map(
                      (r) => DropdownMenuItem(
                        value: r.id,
                        child: Text(r.title, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => loadItem(v!)),
              ),
              SizedBox(height: 12),
              Text(
                'Currently ${displayDate(context, original.dueDate, year: true)} · ${currencyMoney(original.amount, data.currency)} ${data.currency}',
                style: TextStyle(fontSize: 14, color: muted),
              ),
              if (income && original.dueDate.isBefore(data.today))
                Text(
                  'This income is late and excluded from the current plan. Choosing a future date includes it in the simulation.',
                  style: TextStyle(fontSize: 14, color: rose),
                ),
              SizedBox(height: 16),
            ],
            if (!income) ...[
              TextField(
                key: Key('scenario-amount'),
                controller: amount,
                inputFormatters: [TomanAmountFormatter(() => data.currency)],
                autofocus: purchase,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Amount (${data.currency})',
                  hintText: '0',
                ),
              ),
              SizedBox(height: 16),
            ],
            if (purchase) ...[
              TextField(
                key: Key('scenario-title'),
                controller: title,
                maxLength: 120,
                decoration: InputDecoration(
                  labelText: 'Name (optional)',
                  hintText: 'Laptop, trip, or something else',
                ),
              ),
              SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: account,
                isExpanded: true,
                decoration: InputDecoration(labelText: 'Pay from'),
                items: data.includedAccounts
                    .map(
                      (a) => DropdownMenuItem(
                        value: a.id,
                        child: Text(a.name, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => account = v!),
              ),
              SizedBox(height: 16),
            ],
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final minimum = income
                      ? later(
                          data.today,
                          DateTime(
                            original.dueDate.year,
                            original.dueDate.month,
                            original.dueDate.day + 1,
                          ),
                        )
                      : data.today;
                  final d = await pickAppDate(
                    context: context,
                    initialDate: later(selectedDate, minimum),
                    firstDate: minimum,
                    lastDate: DateTime(2200),
                  );
                  if (d != null && mounted) setState(() => selectedDate = d);
                },
                icon: Icon(Icons.calendar_today_outlined),
                label: Text(
                  '${income ? "Arrives" : "On"} ${displayDate(context, selectedDate, year: true)}',
                ),
              ),
            ),
            if (income) ...[
              SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [7, 14]
                    .map(
                      (days) => ActionChip(
                        label: Text('$days days later'),
                        onPressed: () => setState(
                          () => selectedDate = later(
                            data.today,
                            DateTime(
                              original.dueDate.year,
                              original.dueDate.month,
                              original.dueDate.day + days,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
            if (error != null)
              Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text('Cancel'),
      ),
      FilledButton(onPressed: submit, child: Text('See impact')),
    ],
  );
}

class _ComparisonPainter extends CustomPainter {
  _ComparisonPainter(this.base, this.next, this.palette);
  final EmberPalette palette;
  final ScenarioProjection base, next;
  @override
  void paint(Canvas canvas, Size size) {
    final values = [
      ...base.days.map((d) => d.lowest),
      ...next.days.map((d) => d.lowest),
      next.forecast.reserve,
    ];
    final low = values.reduce(math.min), high = values.reduce(math.max);
    double y(int value) =>
        size.height -
        12 -
        (value - low) / (high == low ? 1 : high - low) * (size.height - 24);
    final buffer = y(next.forecast.reserve);
    for (double x = 0; x < size.width; x += 10) {
      canvas.drawLine(
        Offset(x, buffer),
        Offset(math.min(x + 5, size.width), buffer),
        Paint()
          ..color = palette.green.withValues(alpha: .7)
          ..strokeWidth = 1,
      );
    }
    void line(ScenarioProjection p, Color color) {
      final path = Path();
      for (var i = 0; i < p.days.length; i++) {
        final x = i * size.width / (p.days.length - 1);
        if (i == 0) {
          path.moveTo(x, y(p.days[i].lowest));
        } else {
          path.lineTo(x, y(p.days[i - 1].lowest));
          path.lineTo(x, y(p.days[i].lowest));
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke,
      );
    }

    line(base, palette.muted);
    line(next, palette.rose);
  }

  @override
  bool shouldRepaint(covariant _ComparisonPainter oldDelegate) => true;
}
