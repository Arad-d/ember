import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'amount_input.dart';
import 'store.dart';
import 'plan.dart';
import 'calendar_export.dart';
import 'calendar_download.dart';

const coal = Color(0xFF171719),
    panel = Color(0xFF202022),
    line = Color(0xFF343234),
    wine = Color(0xFF8E3D56),
    rose = Color(0xFFDAA5B5),
    cream = Color(0xFFF4EFEA),
    muted = Color(0xFFA9A5A5),
    green = Color(0xFFACC7B5);
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = LedgerStore(await SharedPreferences.getInstance());
  await store.initialize();
  runApp(EmberApp(store: store));
}

class EmberApp extends StatelessWidget {
  const EmberApp({super.key, required this.store, this.initialPage = 0});
  final LedgerStore store;
  final int initialPage;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Ember · Personal finance',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: coal,
      fontFamily: "EmberSans",
      colorScheme: const ColorScheme.dark(
        primary: rose,
        onPrimary: coal,
        surface: panel,
        onSurface: cream,
        secondary: green,
        error: Color(0xFFFFB4AB),
      ),
      dividerColor: line,
      textTheme: ThemeData.dark().textTheme.apply(
        bodyColor: cream,
        displayColor: cream,
        fontFamily: "EmberSans",
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: wine,
          foregroundColor: cream,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: cream,
          side: const BorderSide(color: line),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: coal,
        contentPadding: const EdgeInsets.all(17),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: line),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: cream,
        contentTextStyle: TextStyle(color: coal),
      ),
    ),
    home: Home(store: store, initialPage: initialPage),
  );
}

class Home extends StatefulWidget {
  const Home({super.key, required this.store, this.initialPage = 0});
  final LedgerStore store;
  final int initialPage;
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with WidgetsBindingObserver {
  int page = 0;
  bool showPaidReminders = false;
  String selectedCurrency = 'IRT';
  String accountCurrency(String id) =>
      s.accounts.where((a) => a.id == id).firstOrNull?.currency ?? 'IRT';
  Iterable<Account> get currencyAccounts =>
      s.accounts.where((a) => a.currency == selectedCurrency);
  bool get canTransfer => currencies.keys.any(
    (code) => s.accounts.where((a) => a.currency == code).length >= 2,
  );
  String displayMoney(int value) => currencyMoney(value, selectedCurrency);
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  String query = '', filter = 'All', accountFilter = 'All';
  bool recoveryDialogOpened = false;
  LedgerStore get s => widget.store;
  List<Entry> get monthly =>
      s.entries
          .where(
            (e) =>
                e.date.year == month.year &&
                e.date.month == month.month &&
                accountCurrency(e.accountId) == selectedCurrency,
          )
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
  List<Entry> get filtered => monthly
      .where(
        (e) =>
            (filter == 'All' || e.type == filter.toLowerCase()) &&
            (accountFilter == 'All' ||
                e.accountId == accountFilter ||
                e.destinationId == accountFilter) &&
            ('${e.title} ${e.category} ${accountName(e.accountId)}'
                .toLowerCase()
                .contains(query.toLowerCase())),
      )
      .toList();
  String accountName(String id) =>
      s.accounts.where((a) => a.id == id).firstOrNull?.name ?? 'Account';
  @override
  void initState() {
    super.initState();
    page = widget.initialPage;
    WidgetsBinding.instance.addObserver(this);
    s.addListener(changed);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (s.needsPasswordReset) recoveryForm();
    });
  }

  void changed() {
    if (mounted) {
      setState(() {});
      if (s.needsPasswordReset && !recoveryDialogOpened) recoveryForm();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) s.reload();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    s.removeListener(changed);
    super.dispose();
  }

  void message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            if (wide) sidebar(),
            Expanded(
              child: Column(
                children: [
                  topbar(wide),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        wide ? 40 : 20,
                        28,
                        wide ? 40 : 20,
                        32,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1250),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!s.connected) demoNotice(),
                              if (s.syncError != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 18),
                                  child: Wrap(
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        s.syncError!,
                                        style: const TextStyle(color: rose),
                                      ),
                                      TextButton(
                                        onPressed: s.reload,
                                        child: const Text('Retry'),
                                      ),
                                    ],
                                  ),
                                ),
                              heading(wide),
                              const SizedBox(height: 16),
                              DropdownButton<String>(
                                value: selectedCurrency,
                                items: currencies.entries
                                    .map(
                                      (c) => DropdownMenuItem(
                                        value: c.key,
                                        child: Text(c.value),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) => setState(() {
                                  selectedCurrency = value!;
                                  accountFilter = 'All';
                                }),
                              ),
                              const SizedBox(height: 28),
                              if (page == 0)
                                overview()
                              else if (page == 1)
                                transactions()
                              else if (page == 2)
                                accountsPage()
                              else if (page == 3)
                                insights()
                              else if (page == 5)
                                PlanView(
                                  store: s,
                                  currency: selectedCurrency,
                                  bills: remindersPage(),
                                  addBill: () => reminderForm(),
                                  editBill: (bill) => reminderForm(bill),
                                  openEntry: entryDetail,
                                )
                              else
                                settings(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              backgroundColor: panel,
              indicatorColor: wine.withValues(alpha: .4),
              selectedIndex: page,
              onDestinationSelected: (i) => setState(() => page = i),
              labelBehavior:
                  NavigationDestinationLabelBehavior.onlyShowSelected,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.space_dashboard_outlined),
                  label: 'Overview',
                ),
                NavigationDestination(
                  icon: Icon(Icons.swap_vert),
                  label: 'Activity',
                ),
                NavigationDestination(
                  icon: Icon(Icons.account_balance_wallet_outlined),
                  label: 'Accounts',
                ),
                NavigationDestination(
                  icon: Icon(Icons.donut_large),
                  label: 'Insights',
                ),
                NavigationDestination(
                  icon: Icon(Icons.tune),
                  label: 'Settings',
                ),
                NavigationDestination(
                  icon: Icon(Icons.event_note_outlined),
                  label: 'Plan',
                ),
              ],
            ),
    );
  }

  Widget brand() => Row(
    children: [
      Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: wine,
          borderRadius: BorderRadius.circular(11),
        ),
        child: const Icon(
          Icons.local_fire_department_outlined,
          color: cream,
          size: 25,
        ),
      ),
      const SizedBox(width: 11),
      const Text(
        'ember',
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          letterSpacing: -1.2,
        ),
      ),
    ],
  );
  Widget sidebar() => Container(
    width: 222,
    decoration: const BoxDecoration(
      border: Border(right: BorderSide(color: line)),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 32),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        brand(),
        const SizedBox(height: 52),
        label('YOUR WORKSPACE'),
        const SizedBox(height: 18),
        ...List.generate(6, (i) {
          final names = [
            'Overview',
            'Transactions',
            'Accounts',
            'Insights',
            'Settings',
            'Plan',
          ];
          final icons = [
            Icons.space_dashboard_outlined,
            Icons.swap_vert,
            Icons.account_balance_wallet_outlined,
            Icons.donut_large,
            Icons.tune,
            Icons.event_note_outlined,
          ];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: page == i
                  ? wine.withValues(alpha: .22)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(11),
              child: InkWell(
                borderRadius: BorderRadius.circular(11),
                onTap: () => setState(() => page = i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 15,
                  ),
                  child: Row(
                    children: [
                      Icon(icons[i], size: 21, color: page == i ? rose : muted),
                      const SizedBox(width: 12),
                      Text(
                        names[i],
                        style: TextStyle(
                          color: page == i ? cream : muted,
                          fontWeight: page == i
                              ? FontWeight.w600
                              : FontWeight.w400,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
        const Spacer(),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: line),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.spa_outlined, color: rose, size: 22),
              SizedBox(height: 12),
              Text(
                'A little clarity,\nevery day.',
                style: TextStyle(fontSize: 17, height: 1.5),
              ),
              SizedBox(height: 8),
              Text(
                'Your money. Your pace.',
                style: TextStyle(color: muted, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'PERSONAL FINANCE',
          style: TextStyle(fontSize: 10, letterSpacing: 2, color: muted),
        ),
      ],
    ),
  );
  Widget topbar(bool wide) => Container(
    height: 76,
    padding: EdgeInsets.symmetric(horizontal: wide ? 40 : 20),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: line)),
    ),
    child: Row(
      children: [
        if (!wide)
          brand()
        else
          const Text(
            'Personal workspace',
            style: TextStyle(color: muted, fontSize: 14),
          ),
        const Spacer(),
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: s.connected ? (s.syncError == null ? green : rose) : muted,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          s.connected
              ? (s.syncing
                    ? 'Syncing…'
                    : s.syncError == null
                    ? 'Connected'
                    : 'Sync paused')
              : 'Demo mode',
          style: const TextStyle(fontSize: 12, color: muted),
        ),
        const SizedBox(width: 18),
        CircleAvatar(
          radius: 17,
          backgroundColor: const Color(0xFF383034),
          child: Text(
            s.email.isEmpty ? 'E' : s.email[0].toUpperCase(),
            style: const TextStyle(color: rose, fontSize: 13),
          ),
        ),
      ],
    ),
  );
  Widget demoNotice() => Padding(
    padding: const EdgeInsets.only(bottom: 26),
    child: Container(
      padding: const EdgeInsets.fromLTRB(15, 8, 8, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2429),
        border: Border.all(color: wine.withValues(alpha: .35)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome_outlined, color: rose, size: 17),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'A little preview. These are sample records.',
              style: TextStyle(color: rose, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: () => setState(() => page = 4),
            child: const Text('Set up sync', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    ),
  );
  Widget heading(bool wide) {
    final names = [
      'Your money, at a glance.',
      'Every little detail.',
      'A place for every balance.',
      'Know where it goes.',
      'Make it yours.',
      'A little ahead of time.',
    ];
    final sub = [
      'A clear view of what comes in and what goes out.',
      'Your daily income, expenses, and transfers.',
      'Bank, savings, or the cash in your pocket.',
      'Small details. A clearer picture.',
      'Your preferences and private workspace.',
      'Your payday, upcoming bills, and room to spend.',
    ];
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          names[page],
          style: TextStyle(
            fontSize: wide ? 32 : 27,
            fontWeight: FontWeight.w500,
            letterSpacing: -1.1,
          ),
        ),
        const SizedBox(height: 9),
        Text(
          sub[page],
          style: const TextStyle(color: muted, fontSize: 14, height: 1.5),
        ),
      ],
    );
    final action = page == 4 || page == 5
        ? null
        : FilledButton.icon(
            onPressed: () => page == 5
                ? reminderForm()
                : page == 2
                ? accountForm()
                : entryForm(),
            icon: const Icon(Icons.add, size: 18),
            label: Text(
              page == 5
                  ? 'Add bill'
                  : page == 2
                  ? 'Add account'
                  : 'Add transaction',
            ),
          );
    return wide
        ? Row(
            children: [
              Expanded(child: title),
              if (action != null) action,
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              title,
              if (action != null) ...[const SizedBox(height: 20), action],
            ],
          );
  }

  Widget label(String t) => Text(
    t,
    style: const TextStyle(
      fontSize: 10,
      letterSpacing: 1.6,
      color: muted,
      fontWeight: FontWeight.w600,
    ),
  );
  Widget card(Widget child, {Color? color, EdgeInsets? padding}) => Container(
    width: double.infinity,
    padding: padding ?? const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: color ?? panel,
      border: Border.all(color: line),
      borderRadius: BorderRadius.circular(18),
    ),
    child: child,
  );
  Widget moneyText(
    int value, {
    double size = 28,
    Color color = cream,
    String? currency,
  }) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: Alignment.centerLeft,
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: currencyMoney(value, currency ?? selectedCurrency),
            style: TextStyle(
              fontSize: size,
              fontWeight: FontWeight.w500,
              letterSpacing: -.6,
            ),
          ),
          TextSpan(
            text: '  ${currencyLabel(currency ?? selectedCurrency)}',
            style: TextStyle(
              fontSize: size > 30 ? 14 : 12,
              color: color.withValues(alpha: .65),
            ),
          ),
        ],
      ),
      style: TextStyle(color: color),
    ),
  );
  Widget responsiveRow(List<Widget> children, {double breakpoint = 700}) =>
      LayoutBuilder(
        builder: (context, c) => c.maxWidth < breakpoint
            ? Column(
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    children[i],
                    if (i < children.length - 1) const SizedBox(height: 16),
                  ],
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    Expanded(child: children[i]),
                    if (i < children.length - 1) const SizedBox(width: 18),
                  ],
                ],
              ),
      );
  Widget monthPicker() => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        tooltip: 'Previous month',
        onPressed: () =>
            setState(() => month = DateTime(month.year, month.month - 1)),
        icon: const Icon(Icons.chevron_left, size: 20),
      ),
      Text(
        DateFormat('MMMM yyyy').format(month),
        style: const TextStyle(fontSize: 14),
      ),
      IconButton(
        tooltip: 'Next month',
        onPressed: () =>
            setState(() => month = DateTime(month.year, month.month + 1)),
        icon: const Icon(Icons.chevron_right, size: 20),
      ),
    ],
  );
  Widget summaryRow(List<Widget> children) => LayoutBuilder(
    builder: (context, c) {
      if (c.maxWidth >= 700) return responsiveRow(children);
      return Column(
        children: [
          children[0],
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: children[1]),
              const SizedBox(width: 12),
              Expanded(child: children[2]),
            ],
          ),
        ],
      );
    },
  );
  Widget overview() {
    final income = totalOf(monthly, 'income'),
        expense = totalOf(monthly, 'expense');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        summaryRow([
          card(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Total balance',
                      style: TextStyle(color: Color(0xFFE4C5CE), fontSize: 14),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.account_balance_wallet_outlined,
                      color: Color(0xFFE4C5CE),
                      size: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 25),
                moneyText(
                  currencyAccounts.fold(0, (v, a) => v + balance(a, s.entries)),
                  size: 36,
                ),
                const SizedBox(height: 20),
                Text(
                  'Across ${currencyAccounts.length} ${currencyLabel(selectedCurrency)} accounts · all time',
                  style: const TextStyle(
                    color: Color(0xFFE4C5CE),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            color: const Color(0xFF733047),
          ),
          statCard('Income', income, Icons.south_west, green),
          statCard('Expenses', expense, Icons.north_east, rose),
        ]),
        const SizedBox(height: 20),
        ForecastSummary(
          store: s,
          currency: selectedCurrency,
          onOpen: () => setState(() => page = 5),
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            const Expanded(
              child: Text(
                'This month',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              ),
            ),
            monthPicker(),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, c) {
            final left = cashFlow();
            final right = spending();
            return c.maxWidth > 850
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: left),
                      const SizedBox(width: 20),
                      Expanded(flex: 2, child: right),
                    ],
                  )
                : Column(children: [left, const SizedBox(height: 18), right]);
          },
        ),
        const SizedBox(height: 30),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Your accounts',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              ),
            ),
            TextButton(
              onPressed: () => setState(() => page = 2),
              child: const Text('Manage accounts →'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        s.accounts.isEmpty
            ? empty(
                'Start with an account',
                'Add your bank or cash account to begin.',
                action: accountForm,
                button: 'Add account',
              )
            : responsiveRow(s.accounts.take(3).map(accountTile).toList()),
        const SizedBox(height: 30),
        card(
          Column(
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Recent transactions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => page = 1),
                    child: const Text('View all →'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (monthly.isEmpty)
                empty(
                  'A fresh page',
                  'Your transactions for this month will appear here.',
                )
              else
                ...monthly.take(5).map(entryTile),
            ],
          ),
        ),
      ],
    );
  }

  Widget statCard(String title, int value, IconData icon, Color color) => card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title, style: const TextStyle(color: muted, fontSize: 14)),
            const Spacer(),
            Icon(icon, color: color, size: 20),
          ],
        ),
        const SizedBox(height: 22),
        moneyText(value, size: 32),
        const SizedBox(height: 20),
        Text(
          DateFormat('MMMM yyyy').format(month),
          style: const TextStyle(color: muted, fontSize: 12),
        ),
      ],
    ),
    padding: const EdgeInsets.all(18),
  );
  Widget cashFlow() => card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Cash flow',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
              ),
            ),
            dotLegend('In', green),
            const SizedBox(width: 14),
            dotLegend('Out', rose),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text(
              'Net this month  ',
              style: TextStyle(color: muted, fontSize: 12),
            ),
            Text(
              '${displayMoney(totalOf(monthly, 'income') - totalOf(monthly, 'expense'))} ${currencyLabel(selectedCurrency)}',
              style: const TextStyle(fontSize: 13, color: green),
            ),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: Semantics(
            label:
                'Daily cash flow. Income ${displayMoney(totalOf(monthly, 'income'))} ${currencyLabel(selectedCurrency)}. Expenses ${displayMoney(totalOf(monthly, 'expense'))} ${currencyLabel(selectedCurrency)}.',
            hint: 'Move over a bar or tap a day to see its transactions.',
            child: FlowChart(
              entries: monthly,
              month: month,
              currency: selectedCurrency,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('01', style: TextStyle(fontSize: 11, color: muted)),
            Text('08', style: TextStyle(fontSize: 11, color: muted)),
            Text('15', style: TextStyle(fontSize: 11, color: muted)),
            Text('22', style: TextStyle(fontSize: 11, color: muted)),
            Text(
              '${DateTime(month.year, month.month + 1, 0).day}',
              style: const TextStyle(fontSize: 11, color: muted),
            ),
          ],
        ),
      ],
    ),
  );
  Widget dotLegend(String name, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(name, style: const TextStyle(fontSize: 12, color: muted)),
    ],
  );
  List<MapEntry<String, int>> get breakdown {
    final amounts = <String, int>{};
    for (final e in monthly.where((e) => e.type == 'expense')) {
      amounts[e.category] = (amounts[e.category] ?? 0) + e.amount;
    }
    return amounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  }

  Widget spending() {
    final b = breakdown, total = totalOf(monthly, 'expense');
    return card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Spending breakdown',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 25),
          if (b.isEmpty)
            const SizedBox(
              height: 210,
              child: Center(
                child: Text(
                  'No spending this month.',
                  style: TextStyle(color: muted),
                ),
              ),
            )
          else
            ...b
                .take(4)
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Text(
                              item.key,
                              style: const TextStyle(fontSize: 13),
                            ),
                            const Spacer(),
                            Text(
                              '${(item.value / total * 100).round()}%',
                              style: const TextStyle(
                                color: muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 9),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: LinearProgressIndicator(
                            value: item.value / total,
                            minHeight: 5,
                            backgroundColor: line,
                            color: [
                              rose,
                              wine,
                              const Color(0xFFAEA2A8),
                              const Color(0xFF70636B),
                            ][b.indexOf(item) % 4],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          if (b.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${b.length} categories · ${displayMoney(total)} ${currencyLabel(selectedCurrency)}',
                style: const TextStyle(color: muted, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  IconData accountIcon(String kind) => kind == 'Cash'
      ? Icons.payments_outlined
      : kind == 'Savings'
      ? Icons.savings_outlined
      : kind == 'Bank'
      ? Icons.account_balance_outlined
      : Icons.wallet_outlined;
  Widget accountTile(Account a) => card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(accountIcon(a.kind), color: rose, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                a.name,
                style: const TextStyle(fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (page == 2)
              PopupMenuButton<String>(
                tooltip: 'Account options',
                onSelected: (_) => deleteAccount(a),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete empty account'),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 22),
        moneyText(balance(a, s.entries), size: 25, currency: a.currency),
        const SizedBox(height: 12),
        Text(a.kind, style: const TextStyle(fontSize: 12, color: muted)),
      ],
    ),
  );
  IconData categoryIcon(String c) => switch (c) {
    'Food & drink' => Icons.local_cafe_outlined,
    'Groceries' => Icons.shopping_basket_outlined,
    'Transport' => Icons.directions_car_outlined,
    'Home' => Icons.home_outlined,
    'Shopping' => Icons.shopping_bag_outlined,
    'Health' => Icons.favorite_border,
    'Bills' => Icons.receipt_long_outlined,
    'Salary' => Icons.work_outline,
    'Freelance' => Icons.laptop_mac,
    'Transfer' => Icons.swap_horiz,
    'Leisure' => Icons.weekend_outlined,
    _ => Icons.category_outlined,
  };
  Widget entryTile(Entry e) {
    final incoming = e.type == 'income', transfer = e.type == 'transfer';
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => entryDetail(e),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 2),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: incoming
                    ? green.withValues(alpha: .10)
                    : const Color(0xFF30262C),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                categoryIcon(e.category),
                color: incoming ? green : rose,
                size: 19,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${e.category} · ${accountName(e.accountId)}',
                    style: const TextStyle(color: muted, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${transfer
                      ? '↔ '
                      : incoming
                      ? '+'
                      : '−'}${currencyMoney(e.amount, accountCurrency(e.accountId))}',
                  style: TextStyle(
                    color: incoming ? green : cream,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${DateFormat('MMM d').format(e.date)} · ${currencyLabel(accountCurrency(e.accountId))}',
                  style: const TextStyle(color: muted, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget empty(
    String title,
    String text, {
    VoidCallback? action,
    String button = 'Add transaction',
  }) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 12),
    child: Column(
      children: [
        const Icon(Icons.receipt_long_outlined, color: muted, size: 30),
        const SizedBox(height: 16),
        Text(title, style: const TextStyle(fontSize: 17)),
        const SizedBox(height: 8),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: muted, fontSize: 14),
        ),
        if (action != null) ...[
          const SizedBox(height: 18),
          OutlinedButton(onPressed: action, child: Text(button)),
        ],
      ],
    ),
  );
  Widget transactions() => Column(
    children: [
      Align(alignment: Alignment.centerRight, child: monthPicker()),
      const SizedBox(height: 12),
      TextField(
        decoration: const InputDecoration(
          hintText: 'Search transactions…',
          prefixIcon: Icon(Icons.search, size: 21),
        ),
        onChanged: (v) => setState(() => query = v),
      ),
      const SizedBox(height: 18),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ...['All', 'Expense', 'Income', 'Transfer'].map(
            (v) => ChoiceChip(
              label: Text(v),
              selected: filter == v,
              onSelected: (_) => setState(() => filter = v),
              selectedColor: wine.withValues(alpha: .5),
            ),
          ),
          DropdownButton<String>(
            value: s.accounts.any((a) => a.id == accountFilter)
                ? accountFilter
                : 'All',
            underline: const SizedBox(),
            items: [
              const DropdownMenuItem(value: 'All', child: Text('All accounts')),
              ...s.accounts.map(
                (a) => DropdownMenuItem(
                  value: a.id,
                  child: Text('${a.name} · ${currencyLabel(a.currency)}'),
                ),
              ),
            ],
            onChanged: (v) => setState(() => accountFilter = v!),
          ),
        ],
      ),
      const SizedBox(height: 20),
      card(
        Column(
          children: [
            Row(
              children: [
                Text(
                  '${filtered.length} transactions',
                  style: const TextStyle(color: muted, fontSize: 13),
                ),
                const Spacer(),
                Text(
                  selectedCurrency,
                  style: const TextStyle(
                    color: muted,
                    fontSize: 10,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (filtered.isEmpty)
              empty(
                'Nothing here yet',
                'Try another month or add a transaction.',
                action: entryForm,
              )
            else
              ...filtered.map(entryTile),
          ],
        ),
      ),
    ],
  );
  Widget accountsPage() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'TOTAL BALANCE',
        style: const TextStyle(color: muted, fontSize: 11, letterSpacing: 1.6),
      ),
      const SizedBox(height: 12),
      moneyText(
        currencyAccounts.fold(0, (v, a) => v + balance(a, s.entries)),
        size: 42,
      ),
      const SizedBox(height: 30),
      if (s.accounts.isEmpty)
        empty(
          'Your first account',
          'Start with a bank account or cash.',
          action: accountForm,
          button: 'Add account',
        )
      else
        LayoutBuilder(
          builder: (context, c) => Wrap(
            spacing: 18,
            runSpacing: 18,
            children: s.accounts
                .map(
                  (a) => SizedBox(
                    width: c.maxWidth < 650
                        ? c.maxWidth
                        : (c.maxWidth - 18) / 2,
                    child: accountTile(a),
                  ),
                )
                .toList(),
          ),
        ),
      const SizedBox(height: 24),
      OutlinedButton.icon(
        onPressed: canTransfer
            ? () => entryForm(initialType: 'transfer')
            : null,
        icon: const Icon(Icons.swap_horiz, size: 18),
        label: const Text('Transfer between accounts'),
      ),
    ],
  );
  Widget insights() => Column(
    children: [
      Align(alignment: Alignment.centerRight, child: monthPicker()),
      const SizedBox(height: 16),
      responsiveRow([cashFlow(), spending()]),
      const SizedBox(height: 20),
      card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('By category', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 18),
            if (breakdown.isEmpty)
              empty(
                'A clean slate',
                'Add an expense to see your spending patterns.',
              )
            else
              ...breakdown.map(
                (b) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Icon(categoryIcon(b.key), size: 20, color: rose),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          b.key,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      Text(
                        '${displayMoney(b.value)} ${currencyLabel(selectedCurrency)}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    ],
  );
  Widget settings() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your preferences', style: TextStyle(fontSize: 19)),
            const SizedBox(height: 24),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.payments_outlined, color: rose),
              title: Text('Account currencies'),
              subtitle: Text(
                'Toman, USD, EUR and GBP. Totals stay separate by currency.',
                style: TextStyle(color: muted, fontSize: 13),
              ),
            ),
            const Divider(color: line),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.calendar_today_outlined, color: rose),
              title: Text('Monthly overview'),
              subtitle: Text(
                'Calendar months use the Gregorian calendar.',
                style: TextStyle(color: muted, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.cloud_outlined, color: rose),
                const SizedBox(width: 12),
                const Text('Private sync', style: TextStyle(fontSize: 19)),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              s.connected
                  ? 'Signed in as ${s.email}'
                  : 'Keep your MacBook and iPhone in step.',
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 10),
            Text(
              s.connected
                  ? 'Changes sync automatically while the app is open. An internet connection is needed to save.'
                  : 'Connect your Supabase project, then sign in on both devices. Demo records stay separate from your real accounts.',
              style: const TextStyle(color: muted, fontSize: 14, height: 1.7),
            ),
            const SizedBox(height: 22),
            if (s.connected)
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  OutlinedButton.icon(
                    onPressed: s.syncing ? null : s.reload,
                    icon: const Icon(Icons.sync, size: 18),
                    label: const Text('Sync now'),
                  ),
                  TextButton(
                    onPressed: () async {
                      await s.signOut();
                      if (mounted) {
                        message('Signed out. You are viewing sample records.');
                      }
                    },
                    child: const Text('Sign out'),
                  ),
                ],
              )
            else
              FilledButton.icon(
                onPressed: connectForm,
                icon: const Icon(Icons.lock_outline, size: 18),
                label: const Text('Connect your workspace'),
              ),
            if (s.lastSync != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  'Last synced ${DateFormat('HH:mm:ss').format(s.lastSync!)}',
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          'Ember 1.0 · Made for everyday clarity.',
          style: TextStyle(color: muted, fontSize: 12),
        ),
      ),
    ],
  );
  Future<void> entryDetail(Entry e) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(e.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            moneyText(
              e.amount,
              size: 32,
              currency: accountCurrency(e.accountId),
            ),
            const SizedBox(height: 20),
            Text(
              '${e.category} · ${DateFormat.yMMMd().format(e.date)}',
              style: const TextStyle(color: muted),
            ),
            const SizedBox(height: 12),
            Text(
              '${accountName(e.accountId)}${e.destinationId == null ? '' : ' → ${accountName(e.destinationId!)}'}',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await confirm(
                'Delete this transaction?',
                'The account balance will be recalculated.',
              );
              if (ok) {
                try {
                  await s.removeEntry(e.id);
                  if (mounted) message('Transaction deleted.');
                } catch (err) {
                  if (mounted) message(cleanError(err));
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: rose)),
          ),
        ],
      ),
    );
  }

  Future<bool> confirm(String title, String body) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      ) ??
      false;
  Future<void> deleteAccount(Account a) async {
    if (!await confirm(
      'Delete ${a.name}?',
      'Only accounts without transactions can be deleted.',
    )) {
      return;
    }
    try {
      await s.removeAccount(a.id);
    } catch (e) {
      if (mounted) message(cleanError(e));
    }
  }

  Future<void> accountForm() async {
    final draftId = s.newId;
    final name = TextEditingController(),
        opening = TextEditingController(text: '0');
    String kind = 'Bank', currency = selectedCurrency;
    await formDialog(
      'Add an account',
      'Give every part of your money a home.',
      (set) => [
        TextField(
          controller: name,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Account name',
            hintText: 'e.g. Everyday bank',
          ),
        ),
        const SizedBox(height: 18),
        DropdownButtonFormField<String>(
          initialValue: kind,
          decoration: const InputDecoration(labelText: 'Account type'),
          items: [
            'Bank',
            'Cash',
            'Savings',
            'Other',
          ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
          onChanged: (v) => set(() => kind = v!),
        ),
        const SizedBox(height: 18),
        DropdownButtonFormField<String>(
          initialValue: currency,
          decoration: const InputDecoration(labelText: 'Currency'),
          items: currencies.entries
              .map((c) => DropdownMenuItem(value: c.key, child: Text(c.value)))
              .toList(),
          onChanged: (value) => set(() => currency = value!),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: opening,
          inputFormatters: [
            TomanAmountFormatter(() => currency, allowNegative: true),
          ],
          keyboardType: const TextInputType.numberWithOptions(
            signed: true,
            decimal: true,
          ),
          decoration: InputDecoration(
            labelText: 'Opening balance (${currencyLabel(currency)})',
            helperText: 'Your balance before you start tracking.',
          ),
        ),
      ],
      () async {
        final amount = parseCurrencyAmount(opening.text, currency);
        if (name.text.trim().isEmpty || name.text.trim().length > 60) {
          throw Exception('Enter an account name of 1–60 characters.');
        }
        if (amount == null) {
          throw Exception(
            'Enter a valid amount; foreign currencies allow two decimal places.',
          );
        }
        await s.addAccount(
          Account(
            id: draftId,
            name: name.text.trim(),
            kind: kind,
            opening: amount,
            currency: currency,
          ),
        );
        if (mounted) setState(() => selectedCurrency = currency);
      },
      'Create account',
    );
    // Controllers are retained through the dialog exit animation.
  }

  Future<void> entryForm({String initialType = 'expense'}) async {
    final draftId = s.newId;
    if (s.accounts.isEmpty) {
      await accountForm();
      return;
    }
    String type = initialType,
        account = (currencyAccounts.firstOrNull ?? s.accounts.first).id,
        category = categories.first;
    Iterable<Account> compatibleDestinations() => s.accounts.where(
      (a) => a.id != account && a.currency == accountCurrency(account),
    );
    String destination = compatibleDestinations().firstOrNull?.id ?? account;
    void chooseCompatibleDestination() {
      if (!compatibleDestinations().any((a) => a.id == destination)) {
        destination = compatibleDestinations().firstOrNull?.id ?? account;
      }
    }

    final title = TextEditingController(), amount = TextEditingController();
    DateTime date = DateTime.now();
    await formDialog(
      'Add a transaction',
      'A small habit. A clearer picture.',
      (set) => [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'expense', label: Text('Expense')),
            ButtonSegment(value: 'income', label: Text('Income')),
            ButtonSegment(value: 'transfer', label: Text('Transfer')),
          ],
          selected: {type},
          onSelectionChanged: (v) => set(() {
            type = v.first;
            category = type == 'income'
                ? incomeCategories.first
                : categories.first;
            chooseCompatibleDestination();
          }),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: amount,
          inputFormatters: [
            TomanAmountFormatter(() => accountCurrency(account)),
          ],
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(fontSize: 26),
          decoration: InputDecoration(
            labelText: 'Amount',
            suffixText: currencyLabel(accountCurrency(account)),
            hintText: '0',
          ),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: title,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: type == 'transfer'
                ? 'Note (optional)'
                : 'What was it for?',
            hintText: type == 'transfer'
                ? 'e.g. Cash withdrawal'
                : 'e.g. Morning coffee',
          ),
        ),
        const SizedBox(height: 18),
        DropdownButtonFormField<String>(
          initialValue: account,
          decoration: InputDecoration(
            labelText: type == 'transfer' ? 'From account' : 'Account',
          ),
          items: s.accounts
              .map(
                (a) => DropdownMenuItem(
                  value: a.id,
                  child: Text('${a.name} · ${currencyLabel(a.currency)}'),
                ),
              )
              .toList(),
          onChanged: (v) => set(() {
            account = v!;
            chooseCompatibleDestination();
          }),
        ),
        const SizedBox(height: 18),
        if (type == 'transfer' && compatibleDestinations().isNotEmpty)
          DropdownButtonFormField<String>(
            initialValue:
                compatibleDestinations().any((a) => a.id == destination)
                ? destination
                : null,
            decoration: const InputDecoration(
              labelText: 'To account',
              helperText: 'Choose an account with the same currency.',
            ),
            items: compatibleDestinations()
                .map(
                  (a) => DropdownMenuItem(
                    value: a.id,
                    child: Text('${a.name} · ${currencyLabel(a.currency)}'),
                  ),
                )
                .toList(),
            onChanged: (v) => set(() => destination = v!),
          )
        else if (type == 'transfer')
          Text(
            'Add another ${currencyLabel(accountCurrency(account))} account to make a transfer.',
            style: const TextStyle(color: muted, height: 1.5),
          )
        else
          DropdownButtonFormField<String>(
            key: ValueKey(type),
            initialValue: category,
            decoration: const InputDecoration(labelText: 'Category'),
            items: (type == 'income' ? incomeCategories : categories)
                .map(
                  (c) => DropdownMenuItem(
                    value: c,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IgnoreBaseline(
                          child: Icon(categoryIcon(c), size: 20, color: rose),
                        ),
                        const SizedBox(width: 12),
                        Text(c),
                      ],
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) => set(() => category = v!),
          ),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: date,
              firstDate: DateTime(2000),
              lastDate: DateTime.now(),
            );
            if (picked != null) set(() => date = picked);
          },
          icon: const Icon(Icons.calendar_today_outlined, size: 17),
          label: Text(DateFormat.yMMMMd().format(date)),
        ),
      ],
      () async {
        final value = parseCurrencyAmount(
          amount.text,
          accountCurrency(account),
        );
        if (value == null || value <= 0) {
          throw Exception(
            'Enter a positive amount in the account currency (up to two decimal places for USD, EUR or GBP).',
          );
        }
        if (type != 'transfer' && title.text.trim().isEmpty) {
          throw Exception('Add a short description.');
        }
        if (title.text.trim().length > 120) {
          throw Exception('Keep the description under 120 characters.');
        }
        await s.addEntry(
          Entry(
            id: draftId,
            title: title.text.trim().isEmpty
                ? 'Account transfer'
                : title.text.trim(),
            type: type,
            category: type == 'transfer' ? 'Transfer' : category,
            accountId: account,
            destinationId: type == 'transfer' ? destination : null,
            amount: value,
            date: date,
          ),
        );
        if (mounted) {
          setState(() => selectedCurrency = accountCurrency(account));
        }
      },
      'Save transaction',
    );
  }

  Widget remindersPage() {
    final items =
        s.reminders
            .where(
              (r) =>
                  accountCurrency(r.accountId) == selectedCurrency &&
                  r.paid == showPaidReminders,
            )
            .toList()
          ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final overdue = items
        .where((r) => !r.paid && r.daysUntil(DateTime.now()) < 0)
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!s.remindersAvailable && s.connected)
          const Padding(
            padding: EdgeInsets.only(bottom: 20),
            child: Text(
              'Your workspace needs the reminders update before cloud reminders can be saved.',
              style: TextStyle(color: rose),
            ),
          ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            ChoiceChip(
              label: const Text('Upcoming'),
              selected: !showPaidReminders,
              onSelected: (_) => setState(() => showPaidReminders = false),
            ),
            ChoiceChip(
              label: const Text('Paid'),
              selected: showPaidReminders,
              onSelected: (_) => setState(() => showPaidReminders = true),
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (!showPaidReminders)
          Text(
            overdue > 0
                ? '$overdue overdue · ${items.length} pending'
                : '${items.length} upcoming reminders',
            style: const TextStyle(color: muted, fontSize: 16),
          ),
        const SizedBox(height: 16),
        if (items.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: panel,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.event_available_outlined,
                  size: 34,
                  color: rose,
                ),
                const SizedBox(height: 16),
                Text(
                  showPaidReminders
                      ? 'Paid bills will appear here.'
                      : 'Nothing coming up yet.',
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(height: 8),
                Text(
                  showPaidReminders
                      ? 'Your recorded expenses stay in Activity.'
                      : 'Add a loan installment, rent, or another future expense.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: muted, fontSize: 14),
                ),
              ],
            ),
          ),
        ...items.map((r) {
          final days = r.daysUntil(DateTime.now());
          final status = r.paid
              ? 'Paid ${DateFormat.yMMMd().format(r.paidDate!)}'
              : days < 0
              ? '${-days} ${days == -1 ? 'day' : 'days'} overdue'
              : days == 0
              ? 'Due today'
              : days == 1
              ? 'Due tomorrow'
              : 'Due in $days days';
          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: panel,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: !r.paid && days < 0 ? rose.withValues(alpha: .5) : line,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      r.paid
                          ? Icons.check_circle_outline
                          : Icons.event_note_outlined,
                      color: r.paid ? green : rose,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${r.category} · ${accountName(r.accountId)}',
                            style: const TextStyle(color: muted, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Reminder options',
                      onSelected: (action) async {
                        if (action == 'calendar') {
                          await calendarForm(r);
                          return;
                        }
                        if (action == 'edit') {
                          await reminderForm(r);
                          return;
                        }
                        if (action == 'postpone') {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now().add(
                              const Duration(days: 1),
                            ),
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2100),
                          );
                          if (date != null) {
                            try {
                              await s.saveReminder(
                                ExpenseReminder.fromJson({
                                  ...r.toJson(),
                                  'due_date': date.toIso8601String(),
                                }),
                              );
                            } catch (e) {
                              if (mounted) message(cleanError(e));
                            }
                          }
                          return;
                        }
                        if (await confirm(
                          'Delete reminder?',
                          r.paid
                              ? 'The recorded expense will stay in your transactions.'
                              : 'This removes the reminder without recording an expense.',
                        )) {
                          try {
                            await s.removeReminder(r.id);
                          } catch (e) {
                            if (mounted) message(cleanError(e));
                          }
                        }
                      },
                      itemBuilder: (_) => [
                        if (!r.paid)
                          const PopupMenuItem(
                            value: 'calendar',
                            child: Text('Add to calendar'),
                          ),
                        if (!r.paid)
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('Edit'),
                          ),
                        if (!r.paid)
                          const PopupMenuItem(
                            value: 'postpone',
                            child: Text('Postpone'),
                          ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete reminder'),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Text(
                  '${currencyMoney(r.amount, accountCurrency(r.accountId))} ${currencyLabel(accountCurrency(r.accountId))}',
                  style: const TextStyle(fontSize: 25),
                ),
                const SizedBox(height: 10),
                Text(
                  status,
                  style: TextStyle(
                    color: r.paid
                        ? green
                        : days <= 0
                        ? rose
                        : cream,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Due ${DateFormat.yMMMMd().format(r.dueDate)}',
                  style: const TextStyle(color: muted, fontSize: 14),
                ),
                if (r.note.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      r.note,
                      style: const TextStyle(color: muted, fontSize: 14),
                    ),
                  ),
                if (!r.paid)
                  Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        FilledButton.icon(
                          onPressed: s.busy || s.syncing
                              ? null
                              : () => payReminderForm(r),
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('Mark as paid'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => calendarForm(r),
                          icon: const Icon(
                            Icons.event_available_outlined,
                            size: 18,
                          ),
                          label: const Text('Add to calendar'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Future<void> calendarForm(ExpenseReminder reminder) async {
    var alert = 2;
    final account = s.accounts
        .where((a) => a.id == reminder.accountId)
        .firstOrNull;
    if (account == null) {
      message('This reminder’s account is unavailable. Sync and try again.');
      return;
    }
    await formDialog(
      'Add to calendar',
      '${reminder.title} · ${DateFormat.yMMMd().format(reminder.dueDate)}',
      (set) => [
        const Text(
          'The event is set for 9:00 AM in your calendar’s timezone.',
          style: TextStyle(fontSize: 16, height: 1.5),
        ),
        const SizedBox(height: 20),
        DropdownButtonFormField<int>(
          initialValue: alert,
          decoration: const InputDecoration(labelText: 'Requested alert'),
          items: const [
            DropdownMenuItem(
              value: 0,
              child: Text('On the due date at 9:00 AM'),
            ),
            DropdownMenuItem(value: 1, child: Text('1 day before')),
            DropdownMenuItem(value: 2, child: Text('2 days before')),
            DropdownMenuItem(value: 7, child: Text('1 week before')),
            DropdownMenuItem(value: -1, child: Text('No alert')),
          ],
          isExpanded: true,
          onChanged: (value) => set(() => alert = value!),
        ),
        const SizedBox(height: 20),
        const Text(
          'Open the downloaded .ics file in your calendar and confirm the event. In Google Calendar, import it from Settings → Import & export on a computer.',
          style: TextStyle(fontSize: 14, color: muted, height: 1.5),
        ),
        const SizedBox(height: 12),
        const Text(
          'Check the alert after importing: calendar apps may apply their own settings. Changes and payments in Ember won’t update this copy. Repeated imports may create duplicates.',
          style: TextStyle(fontSize: 14, color: muted, height: 1.5),
        ),
        if (!calendarDownloadSupported) ...[
          const SizedBox(height: 12),
          const Text(
            'Open Ember in your browser to download the calendar file.',
            style: TextStyle(color: rose),
          ),
        ],
      ],
      () async {
        if (!calendarDownloadSupported) {
          throw Exception('Calendar export is available in Ember’s web app.');
        }
        final current = s.reminders
            .where((r) => r.id == reminder.id)
            .firstOrNull;
        if (current == null || current.paid) {
          throw Exception(
            'This reminder was paid or removed. Close this window and sync.',
          );
        }
        final currentAccount = s.accounts.firstWhere(
          (a) => a.id == current.accountId,
        );
        downloadCalendarFile(
          reminderCalendarFile(
            current,
            currentAccount,
            alertDays: alert < 0 ? null : alert,
          ),
        );
        if (mounted) {
          message(
            'Calendar file prepared. Open it in your calendar to finish adding the event.',
          );
        }
      },
      'Download calendar file',
    );
  }

  Future<void> reminderForm([ExpenseReminder? reminder]) async {
    if (s.accounts.isEmpty) {
      message('Add an account before creating a reminder.');
      return;
    }
    final id = reminder?.id ?? s.newId;
    var account =
        reminder?.accountId ??
        currencyAccounts.firstOrNull?.id ??
        s.accounts.first.id;
    var category = reminder?.category ?? 'Bills';
    var date = reminder?.dueDate ?? DateTime.now().add(const Duration(days: 1));
    final title = TextEditingController(text: reminder?.title ?? '');
    final amount = TextEditingController(
      text: reminder == null
          ? ''
          : currencyMoney(reminder.amount, accountCurrency(account)),
    );
    final note = TextEditingController(text: reminder?.note ?? '');
    await formDialog(
      reminder == null ? 'New expense reminder' : 'Edit reminder',
      'Keep the due date handy. Your balance changes only when you record payment.',
      (set) => [
        TextField(
          controller: title,
          maxLength: 120,
          decoration: const InputDecoration(
            labelText: 'Expense name',
            hintText: 'Loan payment',
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: account,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Pay from'),
          items: s.accounts
              .map(
                (a) => DropdownMenuItem(
                  value: a.id,
                  child: Text('${a.name} · ${a.currency}'),
                ),
              )
              .toList(),
          onChanged: (value) => set(() {
            account = value!;
          }),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: amount,
          inputFormatters: [
            TomanAmountFormatter(() => accountCurrency(account)),
          ],
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Amount (${currencyLabel(accountCurrency(account))})',
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: category,
          decoration: const InputDecoration(labelText: 'Category'),
          items: categories
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: (value) => set(() => category = value!),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: date,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (picked != null) set(() => date = picked);
          },
          icon: const Icon(Icons.calendar_today_outlined),
          label: Text('Due ${DateFormat.yMMMd().format(date)}'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: note,
          maxLength: 1000,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Note (optional)'),
        ),
      ],
      () async {
        final value = parseCurrencyAmount(
          amount.text,
          accountCurrency(account),
        );
        if (value == null || value <= 0) {
          throw Exception(
            'Enter a positive amount in the selected account currency.',
          );
        }
        await s.saveReminder(
          ExpenseReminder(
            id: id,
            title: title.text.trim(),
            category: category,
            accountId: account,
            amount: value,
            dueDate: date,
            note: note.text.trim(),
          ),
        );
        if (mounted) {
          setState(() {
            selectedCurrency = accountCurrency(account);
            showPaidReminders = false;
          });
        }
      },
      'Save reminder',
    );
  }

  Future<void> payReminderForm(ExpenseReminder r) async {
    var date = DateTime.now();
    await formDialog(
      'Record payment',
      '${r.title} · ${currencyMoney(r.amount, accountCurrency(r.accountId))} ${currencyLabel(accountCurrency(r.accountId))}\nThis records an expense from ${accountName(r.accountId)}. It does not send money.',
      (set) => [
        OutlinedButton.icon(
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: date,
              firstDate: DateTime(2000),
              lastDate: DateTime.now(),
            );
            if (picked != null) set(() => date = picked);
          },
          icon: const Icon(Icons.calendar_today_outlined),
          label: Text('Paid ${DateFormat.yMMMd().format(date)}'),
        ),
      ],
      () => s.payReminder(r.id, date),
      'Record expense & mark paid',
    );
  }

  Future<void> connectForm() async {
    final url = TextEditingController(text: s.url),
        key = TextEditingController(text: s.key),
        email = TextEditingController(),
        password = TextEditingController();
    await formDialog(
      'Your private workspace',
      'Use the same sign-in on your MacBook and iPhone.',
      (set) => [
        const Text(
          'First, run supabase/schema.sql and create your user in Supabase Authentication. Full steps are in SETUP.md.',
          style: TextStyle(color: muted, height: 1.6, fontSize: 14),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: url,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: 'Supabase project URL',
            hintText: 'https://your-project.supabase.co',
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: key,
          decoration: const InputDecoration(
            labelText: 'Publishable key',
            helperText: 'Public/anon key only. Never a secret key.',
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: const InputDecoration(labelText: 'Email'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: password,
          obscureText: true,
          autofillHints: const [AutofillHints.password],
          decoration: const InputDecoration(labelText: 'Password'),
        ),
      ],
      () async {
        if (email.text.trim().isEmpty || password.text.isEmpty) {
          throw Exception('Enter your email and password.');
        }
        await s.configure(url.text, key.text);
        await s.signIn(email.text, password.text);
      },
      'Connect & sign in',
    );
  }

  Future<void> recoveryForm() async {
    if (recoveryDialogOpened || !mounted) return;
    recoveryDialogOpened = true;
    final password = TextEditingController();
    final confirm = TextEditingController();
    await formDialog(
      'Choose a new password',
      'This recovery link is verified. Set a password with at least 8 characters to finish signing in.',
      (set) => [
        TextField(
          controller: password,
          obscureText: true,
          autofocus: true,
          autofillHints: const [AutofillHints.newPassword],
          decoration: const InputDecoration(labelText: 'New password'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: confirm,
          obscureText: true,
          autofillHints: const [AutofillHints.newPassword],
          decoration: const InputDecoration(labelText: 'Confirm new password'),
        ),
      ],
      () async {
        if (password.text != confirm.text) {
          throw Exception('The passwords do not match.');
        }
        await s.updatePassword(password.text);
      },
      'Save password',
      canClose: false,
    );
    password.dispose();
    confirm.dispose();
    recoveryDialogOpened = false;
  }

  String cleanError(Object e) => e.toString().replaceFirst('Exception: ', '');
  Future<void> formDialog(
    String title,
    String subtitle,
    List<Widget> Function(StateSetter) fields,
    Future<void> Function() save,
    String button, {
    bool canClose = true,
  }) async {
    bool saving = false;
    String? error;
    await showDialog<void>(
      context: context,
      barrierDismissible: canClose,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => PopScope(
          canPop: canClose && !saving,
          child: Dialog(
            insetPadding: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 490),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(26),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 24,
                              letterSpacing: -.5,
                            ),
                          ),
                        ),
                        if (canClose)
                          IconButton(
                            tooltip: 'Close',
                            onPressed: saving ? null : () => Navigator.pop(ctx),
                            icon: const Icon(Icons.close, size: 20),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: muted,
                        fontSize: 14,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ...fields(set),
                    if (error != null) ...[
                      const SizedBox(height: 18),
                      Text(
                        error!,
                        style: const TextStyle(color: rose, fontSize: 14),
                      ),
                    ],
                    const SizedBox(height: 26),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: saving
                            ? null
                            : () async {
                                set(() {
                                  saving = true;
                                  error = null;
                                });
                                try {
                                  await save();
                                  if (ctx.mounted) Navigator.pop(ctx);
                                } catch (e) {
                                  if (ctx.mounted) {
                                    set(() {
                                      saving = false;
                                      error = cleanError(e);
                                    });
                                  }
                                }
                              },
                        child: saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(button),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FlowSelection {
  const _FlowSelection(this.day, this.isIncome);
  final int day;
  final bool isIncome;
}

class FlowChart extends StatefulWidget {
  const FlowChart({
    super.key,
    required this.entries,
    required this.month,
    required this.currency,
  });

  final List<Entry> entries;
  final DateTime month;
  final String currency;

  @override
  State<FlowChart> createState() => _FlowChartState();
}

class _FlowChartState extends State<FlowChart> {
  _FlowSelection? selection;

  _FlowSelection? _selectionAt(Offset point, Size size, {bool touch = false}) {
    final days = DateTime(widget.month.year, widget.month.month + 1, 0).day;
    final day = (point.dx / (size.width / days)).floor() + 1;
    if (day < 1 || day > days) return null;
    final dayEntries = widget.entries.where((entry) => entry.date.day == day);
    final income = dayEntries
        .where((entry) => entry.type == 'income')
        .fold<int>(0, (sum, entry) => sum + entry.amount);
    final expense = dayEntries
        .where((entry) => entry.type == 'expense')
        .fold<int>(0, (sum, entry) => sum + entry.amount);
    if (income == 0 && expense == 0) return null;

    if (touch) {
      if (income == 0) return _FlowSelection(day, false);
      if (expense == 0) return _FlowSelection(day, true);
      final slot = size.width / days;
      final incomeCenter = (day - 1) * slot + slot * .26;
      final expenseCenter = (day - 1) * slot + slot * .64;
      return _FlowSelection(
        day,
        (point.dx - incomeCenter).abs() <= (point.dx - expenseCenter).abs(),
      );
    }

    final dailyIncome = <int, int>{};
    final dailyExpenses = <int, int>{};
    for (final entry in widget.entries) {
      if (entry.type == 'income') {
        dailyIncome[entry.date.day] =
            (dailyIncome[entry.date.day] ?? 0) + entry.amount;
      } else if (entry.type == 'expense') {
        dailyExpenses[entry.date.day] =
            (dailyExpenses[entry.date.day] ?? 0) + entry.amount;
      }
    }
    final maxValue = math.max(
      1,
      List.generate(
        days,
        (index) => math.max(
          dailyIncome[index + 1] ?? 0,
          dailyExpenses[index + 1] ?? 0,
        ),
      ).fold<int>(0, math.max),
    );
    final slot = size.width / days;
    final chartHeight = size.height - 14;
    final barWidth = slot * .32;
    final candidates = [
      if (income > 0)
        (value: income, isIncome: true, left: (day - 1) * slot + slot * .1),
      if (expense > 0)
        (value: expense, isIncome: false, left: (day - 1) * slot + slot * .48),
    ];
    for (final bar in candidates) {
      final height = bar.value / maxValue * chartHeight;
      final top = size.height - height;
      if (point.dx >= bar.left &&
          point.dx <= bar.left + barWidth &&
          point.dy >= top &&
          point.dy <= size.height) {
        return _FlowSelection(day, bar.isIncome);
      }
    }
    return null;
  }

  void _updateSelection(_FlowSelection? next) {
    if (selection?.day == next?.day && selection?.isIncome == next?.isIncome) {
      return;
    }
    setState(() => selection = next);
  }

  @override
  Widget build(BuildContext context) {
    final current = selection;
    final selectedEntries = current == null
        ? <Entry>[]
        : widget.entries
              .where(
                (entry) =>
                    entry.date.day == current.day &&
                    entry.type == (current.isIncome ? 'income' : 'expense'),
              )
              .toList();
    final total = selectedEntries.fold<int>(
      0,
      (sum, entry) => sum + entry.amount,
    );
    final selectedDate = current == null
        ? null
        : DateTime(widget.month.year, widget.month.month, current.day);

    return LayoutBuilder(
      builder: (context, constraints) {
        const chartHeight = 170.0;
        final size = Size(constraints.maxWidth, chartHeight);
        void hover(PointerEvent event) =>
            _updateSelection(_selectionAt(event.localPosition, size));
        void tap(TapDownDetails event) => _updateSelection(
          _selectionAt(event.localPosition, size, touch: true),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: chartHeight,
              width: constraints.maxWidth,
              child: MouseRegion(
                onHover: hover,
                onExit: (_) => _updateSelection(null),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: tap,
                  child: CustomPaint(
                    painter: FlowPainter(
                      widget.entries,
                      widget.month,
                      selectedDay: current?.day,
                      selectedIsIncome: current?.isIncome,
                    ),
                    size: Size.infinite,
                  ),
                ),
              ),
            ),
            if (current != null && selectedDate != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: panel,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${current.isIncome ? 'Income' : 'Expense'} · ${DateFormat.yMMMd().format(selectedDate)}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${currencyMoney(total, widget.currency)} ${currencyLabel(widget.currency)}',
                      style: TextStyle(
                        fontSize: 18,
                        color: current.isIncome ? green : rose,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final entry in selectedEntries)
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                entry.title,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            Text(
                              '${currencyMoney(entry.amount, widget.currency)} ${currencyLabel(widget.currency)}',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class FlowPainter extends CustomPainter {
  FlowPainter(
    this.entries,
    this.month, {
    this.selectedDay,
    this.selectedIsIncome,
  });
  final List<Entry> entries;
  final DateTime month;
  final int? selectedDay;
  final bool? selectedIsIncome;
  @override
  void paint(Canvas canvas, Size size) {
    final days = DateTime(month.year, month.month + 1, 0).day;
    final ins = List.filled(days, 0), outs = List.filled(days, 0);
    for (final e in entries) {
      if (e.type == 'income') ins[e.date.day - 1] += e.amount;
      if (e.type == 'expense') outs[e.date.day - 1] += e.amount;
    }
    final maxValue = math.max(1, [...ins, ...outs].reduce(math.max));
    for (var i = 0; i < 4; i++) {
      final y = i * (size.height - 8) / 3;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        Paint()
          ..color = line
          ..strokeWidth = 1,
      );
    }
    final slot = size.width / days;
    for (var i = 0; i < days; i++) {
      for (var j = 0; j < 2; j++) {
        final amount = j == 0 ? ins[i] : outs[i];
        if (amount == 0) continue;
        final h = amount / maxValue * (size.height - 14);
        final rect = Rect.fromLTWH(
          i * slot + j * slot * .38 + slot * .1,
          size.height - h,
          slot * .32,
          h,
        );
        final rounded = RRect.fromRectAndRadius(rect, const Radius.circular(3));
        canvas.drawRRect(
          rounded,
          Paint()
            ..color = (j == 0 ? green : rose).withValues(
              alpha: j == 0 ? 0.9 : 0.8,
            ),
        );
        if (selectedDay == i + 1 && selectedIsIncome == (j == 0)) {
          canvas.drawRRect(
            rounded,
            Paint()
              ..color = cream
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant FlowPainter oldDelegate) => true;
}
