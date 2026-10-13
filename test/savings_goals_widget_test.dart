import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ember/main.dart';
import 'package:ember/store.dart';
import 'package:ember/savings_goal.dart';
import 'package:ember/models.dart';
import 'package:ember/forecast.dart';
import 'package:ember/what_if.dart';
import 'package:ember/savings_goals_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final loader = FontLoader('EmberSans')
      ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
    await loader.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  for (final width in [320.0, 390.0, 1440.0]) {
    for (final light in [false, true]) {
      testWidgets('Goals create and preview at $width light=$light', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({
          'appearance': light ? 'light' : 'dark',
        });
        final s = LedgerStore(await SharedPreferences.getInstance())
          ..loadDemo();
        final screenshotKey = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: screenshotKey,
            child: EmberApp(store: s, initialPage: 5),
          ),
        );
        Future<void> capture(String label) async {
          const screenshotDirectory = String.fromEnvironment(
            'SAVINGS_SCREENSHOT_DIR',
          );
          if (width != 390 || screenshotDirectory.isEmpty) return;
          await tester.runAsync(() async {
            await Directory(screenshotDirectory).create(recursive: true);
            final boundary =
                screenshotKey.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final img = await boundary.toImage();
            final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
            await File(
              '$screenshotDirectory/savings-$label-${light ? 'light' : 'dark'}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            img.dispose();
          });
        }

        await tester.pumpAndSettle();
        expect(find.text('Savings goals'), findsOneWidget);
        await tester.ensureVisible(find.text('Add goal'));
        await tester.tap(find.text('Add goal'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Goal name'),
          'New laptop',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Target amount'),
          '100000000',
        );
        await tester.ensureVisible(find.text('Save goal'));
        await tester.tap(find.text('Save goal'));
        await tester.pumpAndSettle();
        expect(s.savingsGoals.single.name, 'New laptop');
        await tester.ensureVisible(find.text('Try in forecast'));
        if (width == 390) {
          await Scrollable.ensureVisible(
            tester.element(find.text('Savings goals')),
            alignment: .1,
          );
          await tester.pumpAndSettle();
        }
        await capture('goals');
        await tester.ensureVisible(find.text('Try in forecast'));
        await tester.tap(find.text('Try in forecast'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Preview contribution'));
        await tester.tap(find.text('Preview contribution'));
        await tester.pumpAndSettle();
        expect(find.text('After contribution'), findsOneWidget);
        expect(s.entries, hasLength(9));
        await tester.ensureVisible(find.text('Done'));
        await capture('preview');
        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();
        expect(find.text('Savings goals'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        s.dispose();
      });
    }
  }
  testWidgets('No eligible savings account routes to Accounts', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final s = LedgerStore(await SharedPreferences.getInstance());
    s.accounts = [
      const Account(id: 'b', name: 'Bank', kind: 'Bank', opening: 0),
    ];
    await tester.pumpWidget(EmberApp(store: s, initialPage: 5));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Add a savings account'));
    await tester.tap(find.text('Add a savings account'));
    await tester.pumpAndSettle();
    expect(find.text('Add account'), findsWidgets);
    await tester.pumpWidget(const SizedBox.shrink());
    s.dispose();
  });
  testWidgets('Reached and overdue cards stay editable', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final s = LedgerStore(await SharedPreferences.getInstance())..loadDemo();
    s.savingsGoals = [
      SavingsGoal(
        id: 'g',
        name: 'Laptop',
        target: 100000000,
        currency: 'IRT',
        deadline: DateTime.now().subtract(const Duration(days: 2)),
        accountId: 'savings',
      ),
    ];
    await tester.pumpWidget(EmberApp(store: s, initialPage: 5));
    await tester.pumpAndSettle();
    expect(find.text('Deadline passed'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('Goal options'));
    await tester.tap(find.byTooltip('Goal options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit goal'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Goal name'),
      'New name',
    );
    await tester.ensureVisible(find.text('Save goal'));
    await tester.tap(find.text('Save goal'));
    await tester.pumpAndSettle();
    expect(s.savingsGoals.single.name, 'New name');
    await tester.pumpWidget(const SizedBox.shrink());
    s.dispose();
  });
  testWidgets(
    'Excluded savings is not described as included when an earlier low controls available',
    (tester) async {
      final today = DateTime(2026, 10, 13);
      final bank = Account(id: 'b', name: 'Bank', kind: 'Bank', opening: 100);
      final savings = Account(
        id: 's',
        name: 'Savings',
        kind: 'Savings',
        opening: 0,
      );
      final snapshot = WhatIfSnapshot(
        accounts: [bank, savings],
        entries: [],
        bills: [
          ExpenseReminder(
            id: 'bill',
            title: 'Bill',
            category: 'Bills',
            accountId: 'b',
            amount: 50,
            dueDate: DateTime(today.year, today.month, today.day + 1),
          ),
        ],
        income: [
          ExpenseReminder(
            id: 'pay',
            title: 'Pay',
            category: 'Salary',
            accountId: 'b',
            amount: 100,
            dueDate: DateTime(today.year, today.month, today.day + 2),
          ),
        ],
        currency: 'IRT',
        settings: const PlanSettings(),
        now: today,
      );
      final g = SavingsGoal(
        id: 'g',
        name: 'Laptop',
        target: 10,
        currency: 'IRT',
        deadline: DateTime(today.year, today.month + 1),
        accountId: 's',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ContributionPreview(
              snapshot: snapshot,
              goal: g,
              sources: [bank],
              suggestion: 10,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Contribution date'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('16'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Preview contribution'));
      await tester.tap(find.text('Preview contribution'));
      await tester.pumpAndSettle();
      expect(find.text('After contribution'), findsOneWidget);
      expect(
        find.text(
          'Both accounts are included in your forecast. This transfer keeps their combined balance the same.',
        ),
        findsNothing,
      );
    },
  );
  testWidgets(
    'Creation captures currency and stays usable with keyboard open',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      SharedPreferences.setMockInitialValues({});
      final store = LedgerStore(await SharedPreferences.getInstance())
        ..loadDemo();
      final currency = ValueNotifier('IRT');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<String>(
              valueListenable: currency,
              builder: (context, value, _) => SingleChildScrollView(
                child: SavingsGoalsView(
                  store: store,
                  currency: value,
                  openAccounts: () {},
                  openForecastSettings: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add goal'));
      await tester.pumpAndSettle();
      currency.value = 'USD';
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Goal name'),
        'Keyboard goal',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Target amount'),
        '500',
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save goal'));
      await tester.tap(find.text('Save goal'));
      await tester.pumpAndSettle();
      expect(store.savingsGoals.single.currency, 'IRT');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
      currency.dispose();
    },
  );
  testWidgets('No source account routes to forecast settings', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = LedgerStore(await SharedPreferences.getInstance())
      ..loadDemo();
    store.planSettings['IRT'] = const PlanSettings(accountIds: ['savings']);
    store.savingsGoals = [
      SavingsGoal(
        id: 'g',
        name: 'Laptop',
        target: 100000000,
        currency: 'IRT',
        deadline: DateTime.now().add(const Duration(days: 60)),
        accountId: 'savings',
      ),
    ];
    bool settingsOpened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SavingsGoalsView(
              store: store,
              currency: 'IRT',
              openAccounts: () {},
              openForecastSettings: () {
                settingsOpened = true;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Try in forecast'));
    await tester.tap(find.text('Try in forecast'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Forecast settings'));
    await tester.pumpAndSettle();
    expect(settingsOpened, true);
    await tester.pumpWidget(const SizedBox.shrink());
    store.dispose();
  });
}
