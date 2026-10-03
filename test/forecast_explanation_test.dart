import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ember/forecast.dart';
import 'package:ember/main.dart';
import 'package:ember/models.dart';
import 'package:ember/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      'EmberSans',
    )..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  final now = DateTime(2026, 9, 28);
  ExpenseReminder item(String id, int amount, DateTime date) => ExpenseReminder(
    id: id,
    title: id,
    category: 'Bills',
    accountId: 'a',
    amount: amount,
    dueDate: date,
  );
  CashForecast forecast() => CashForecast(
    accounts: const [
      Account(
        id: 'a',
        name: 'Bank',
        kind: 'Bank',
        opening: 140000,
        currency: 'USD',
      ),
      Account(
        id: 'b',
        name: 'Cash',
        kind: 'Cash',
        opening: 10000,
        currency: 'USD',
      ),
    ],
    entries: [],
    bills: [
      item('overdue', 10000, DateTime(2026, 9, 27)),
      item('Rent', 90000, DateTime(2026, 9, 30)),
    ],
    income: [item('Salary', 200000, DateTime(2026, 9, 30))],
    currency: 'USD',
    settings: const PlanSettings(reserve: 90000),
    now: now,
  );
  test(
    'Breakdown carries prior days and explains intraday dip before income',
    () {
      final f = forecast();
      final d = ForecastDayBreakdown(f, DateTime(2026, 9, 30));
      expect(d.opening, 140000);
      expect(d.lowest, 50000);
      expect(d.closing, 250000);
      expect(d.lowestEvent!.title, 'Rent');
      expect(d.events.map((e) => e.title), ['Rent', 'Salary']);
      expect(d.nextIncome!.title, 'Salary');
      expect(d.lowest, f.lowest);
      expect(d.date, f.lowestDate);
    },
  );
  test('Overdue bills apply today; quiet days retain the balance', () {
    final f = forecast();
    final today = ForecastDayBreakdown(f, now);
    expect(today.opening, 150000);
    expect(today.closing, 140000);
    expect(today.events.single.title, 'overdue');
    final quiet = ForecastDayBreakdown(f, DateTime(2026, 9, 29));
    expect(quiet.opening, 140000);
    expect(quiet.lowest, 140000);
    expect(quiet.lowestEvent, isNull);
    expect(quiet.events, isEmpty);
    expect(
      () => ForecastDayBreakdown(f, DateTime(2026, 10, 1)),
      throwsArgumentError,
    );
  });
  for (final width in [320.0, 390.0, 1440.0]) {
    testWidgets('Explanation and bill edit work at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 960);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final store = LedgerStore(await SharedPreferences.getInstance())
        ..loadDemo();
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: EmberApp(store: store, initialPage: 5),
        ),
      );
      await tester.pumpAndSettle();
      final trigger = find.textContaining('Tap to see why');
      await tester.ensureVisible(trigger);
      await tester.tap(trigger);
      await tester.pumpAndSettle();
      expect(find.textContaining('Why this balance?'), findsOneWidget);
      expect(find.text('Projected end of day'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('See the calculation'));
      await tester.tap(find.text('See the calculation'));
      await tester.pumpAndSettle();
      final dir = Platform.environment['EMBER_SCREENSHOT_DIR'];
      if (dir != null && width == 390) {
        await tester.runAsync(() async {
          final image =
              await (key.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '$dir/ember-explanation-phone.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
        });
      }
      final sheet = find.byType(BottomSheet);
      final bill = find.descendant(
        of: sheet,
        matching: find.text('Next month’s rent'),
      );
      await tester.ensureVisible(bill);
      await tester.tap(bill);
      await tester.pumpAndSettle();
      expect(find.text('Edit reminder'), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(1), '7000000');
      await tester.ensureVisible(find.text('Save reminder'));
      await tester.tap(find.text('Save reminder'));
      await tester.pumpAndSettle();
      expect(
        store.reminders
            .firstWhere((r) => r.title == 'Next month’s rent')
            .amount,
        7000000,
      );
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(trigger);
      await tester.tap(trigger);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('What’s included?'));
      await tester.tap(find.text('What’s included?'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Excluded accounts: Savings'), findsOneWidget);
      await tester.ensureVisible(find.text('Edit forecast settings'));
      await tester.tap(find.text('Edit forecast settings'));
      await tester.pumpAndSettle();
      expect(find.byType(CheckboxListTile), findsWidgets);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    });
  }
  testWidgets(
    'Late income links to its editor and timeline opens the chosen day',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final store = LedgerStore(await SharedPreferences.getInstance())
        ..loadDemo();
      final today = DateTime.now();
      store.expectedIncome.add(
        ExpenseReminder(
          id: 'late',
          title: 'Late freelance payment',
          category: 'Freelance',
          accountId: 'bank',
          amount: 10000,
          dueDate: DateTime(today.year, today.month, today.day - 1),
        ),
      );
      await tester.pumpWidget(EmberApp(store: store, initialPage: 5));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Internet bill').first);
      await tester.tap(find.text('Internet bill').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('Why this balance?'), findsOneWidget);
      await tester.ensureVisible(find.text('What’s included?'));
      await tester.tap(find.text('What’s included?'));
      await tester.pumpAndSettle();
      final late = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('Late freelance payment'),
      );
      await tester.ensureVisible(late);
      await tester.tap(late);
      await tester.pumpAndSettle();
      expect(find.text('Edit expected income'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );
}
