import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ember/main.dart';
import 'package:ember/models.dart';
import 'package:ember/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final loader = FontLoader('EmberSans')
      ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
    await loader.load();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'Reminder lifecycle persists and payment changes the balance once',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final store = LedgerStore(prefs)..loadDemo();
      final bank = store.accounts.first;
      final original = balance(bank, store.entries);
      final bill = ExpenseReminder(
        id: 'test-bill',
        title: 'Loan',
        category: 'Bills',
        accountId: bank.id,
        amount: 250000,
        dueDate: DateTime.now().add(const Duration(days: 3)),
      );
      await store.saveReminder(bill);
      expect(balance(bank, store.entries), original);
      await store.saveReminder(
        ExpenseReminder.fromJson({...bill.toJson(), 'due_date': '2030-09-18'}),
      );
      final reloaded = LedgerStore(prefs)..loadDemo();
      expect(
        reloaded.reminders.firstWhere((r) => r.id == bill.id).dueDate,
        DateTime(2030, 9, 18),
      );
      await store.payReminder(bill.id, DateTime.now());
      await store.payReminder(bill.id, DateTime.now());
      expect(balance(bank, store.entries), original - bill.amount);
      expect(store.entries.where((e) => e.id == bill.id), hasLength(1));
      await expectLater(store.saveReminder(bill), throwsException);
      await store.removeReminder(bill.id);
      expect(store.entries.where((e) => e.id == bill.id), hasLength(1));
      store.dispose();
      reloaded.dispose();
    },
  );
  test('Due labels use calendar days and survive serialization', () {
    final bill = ExpenseReminder(
      id: 'r',
      title: 'Rent',
      category: 'Home',
      accountId: 'a',
      amount: 1200,
      dueDate: DateTime(2026, 9, 18),
    );
    expect(bill.daysUntil(DateTime(2026, 9, 17, 23, 59)), 1);
    expect(bill.daysUntil(DateTime(2026, 9, 18, 23)), 0);
    expect(bill.daysUntil(DateTime(2026, 9, 19)), -1);
    expect(ExpenseReminder.fromJson(bill.toJson()).amount, 1200);
  });
  test(
    'Cloud payment uses one atomic RPC and failed payment remains pending',
    () async {
      final requests = <http.Request>[];
      final store = LedgerStore(
        await SharedPreferences.getInstance(),
        client: MockClient((request) async {
          requests.add(request);
          return http.Response('{}', 503);
        }),
      )..loadDemo();
      store.userId = 'owner';
      store.url = 'https://example.supabase.co';
      store.key = 'public';
      store.access = 'access';
      store.expires = DateTime.now().add(const Duration(hours: 1));
      final bill = store.reminders.first;
      final before = store.entries.length;
      await expectLater(
        store.payReminder(bill.id, DateTime.now()),
        throwsException,
      );
      expect(store.entries.length, before);
      expect(store.reminders.first.paid, false);
      expect(requests, hasLength(1));
      expect(requests.single.url.path, '/rest/v1/rpc/pay_expense_reminder');
      expect(jsonDecode(requests.single.body)['reminder_id'], bill.id);
      store.dispose();
    },
  );
  for (final width in [1440.0, 390.0, 320.0]) {
    testWidgets('Reminders and create form fit width $width', (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = LedgerStore(await SharedPreferences.getInstance())
        ..loadDemo();
      await tester.pumpWidget(EmberApp(store: store));
      await tester.pumpAndSettle();
      if (width >= 1000) {
        await tester.tap(find.text('Plan'));
      } else {
        await tester.tap(find.byType(NavigationDestination).at(5));
      }
      await tester.pumpAndSettle();
      expect(find.text('Loan payment'), findsWidgets);
      expect(find.text('1 day overdue'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Add to calendar').first);
      await tester.tap(find.text('Add to calendar').first);
      await tester.pumpAndSettle();
      expect(find.text('2 days before'), findsOneWidget);
      expect(find.text('Download calendar file'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Add bill').first);
      await tester.tap(find.text('Add bill').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'Car insurance');
      await tester.enterText(find.byType(TextField).at(1), '400000');
      await tester.ensureVisible(find.text('Save reminder'));
      await tester.tap(find.text('Save reminder'));
      await tester.pumpAndSettle();
      expect(
        store.reminders.any(
          (r) => r.title == 'Car insurance' && r.amount == 400000,
        ),
        true,
      );
      expect(tester.takeException(), isNull);
      store.dispose();
    });
  }
}
