import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ember/main.dart';
import 'package:ember/models.dart';
import 'package:ember/forecast.dart';
import 'package:ember/store.dart';
import 'package:ember/what_if.dart';
import 'package:ember/what_if_page.dart';

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
  for (final width in [320.0, 390.0, 1440.0]) {
    testWidgets('What if flow fits $width and never changes ledger records', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 960);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = LedgerStore(prefs)..loadDemo();
      final before = jsonEncode({
        'entries': store.entries.map((e) => e.toJson()).toList(),
        'bills': store.reminders.map((r) => r.toJson()).toList(),
        'income': store.expectedIncome.map((i) => i.toJson()).toList(),
      });
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: EmberApp(store: store, initialPage: 5),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('What if?'));
      await tester.tap(find.text('What if?'));
      await tester.pumpAndSettle();
      expect(find.text('Simulation'), findsOneWidget);
      await tester.tap(find.text('Add a purchase'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('scenario-amount')),
        '90000000',
      );
      await tester.enterText(find.byKey(const Key('scenario-title')), 'Laptop');
      await tester.ensureVisible(find.text('See impact'));
      await tester.tap(find.text('See impact'));
      await tester.pumpAndSettle();
      expect(find.text('A shortfall is projected'), findsOneWidget);
      expect(find.text('Current plan'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final screenshotDirectory = Platform.environment['EMBER_SCREENSHOT_DIR'];
      if (screenshotDirectory != null && (width == 390 || width == 1440)) {
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '$screenshotDirectory/ember-whatif-${width.toInt()}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
        });
      }
      if (width < 850) {
        await tester.tap(find.text('Add or edit changes'));
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(find.text('Edit'));
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('scenario-amount')),
        '100000',
      );
      await tester.tap(find.text('See impact'));
      await tester.pumpAndSettle();
      expect(find.text('Stays above your buffer'), findsOneWidget);
      await tester.ensureVisible(find.text('Delay income'));
      await tester.tap(find.text('Delay income'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('7 days later'));
      await tester.tap(find.text('See impact'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Change a bill'));
      await tester.tap(find.text('Change a bill'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('scenario-amount')),
        '750000',
      );
      await tester.tap(find.text('See impact'));
      await tester.pumpAndSettle();
      expect(find.text('Remove'), findsNWidgets(3));
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('60 days'));
      await tester.tap(find.text('60 days'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Chart & daily details'));
      await tester.tap(find.text('Chart & daily details'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Remove').first);
      await tester.tap(find.text('Remove').first);
      await tester.pumpAndSettle();
      expect(find.text('Remove'), findsNWidgets(2));
      await tester.ensureVisible(find.text('Clear all'));
      await tester.tap(find.text('Clear all'));
      await tester.pumpAndSettle();
      expect(find.text('What would you like to try?'), findsOneWidget);
      final after = jsonEncode({
        'entries': store.entries.map((e) => e.toJson()).toList(),
        'bills': store.reminders.map((r) => r.toJson()).toList(),
        'income': store.expectedIncome.map((i) => i.toJson()).toList(),
      });
      expect(after, before);
      expect(prefs.getString('demo'), isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Simulation'), findsNothing);
      await tester.ensureVisible(find.text('What if?'));
      await tester.tap(find.text('What if?'));
      await tester.pumpAndSettle();
      expect(find.text('What would you like to try?'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    });
  }
  testWidgets('Empty account selection explains how to start', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = LedgerStore(await SharedPreferences.getInstance())
      ..loadDemo();
    final snapshot = WhatIfSnapshot(
      accounts: store.accounts,
      entries: [],
      bills: [],
      income: [],
      currency: 'IRT',
      settings: const PlanSettings(accountIds: []),
      now: DateTime.now(),
    );
    await tester.pumpWidget(MaterialApp(home: WhatIfPage(snapshot: snapshot)));
    await tester.pumpAndSettle();
    expect(
      find.text('Choose accounts in Plan → Forecast settings to start.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });
  testWidgets('Large text and decimal currency fit the purchase form', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final snapshot = WhatIfSnapshot(
      accounts: const [
        Account(
          id: 'a',
          name: 'Everyday',
          kind: 'Bank',
          opening: 100000,
          currency: 'USD',
        ),
      ],
      entries: [],
      bills: [],
      income: [],
      currency: 'USD',
      settings: const PlanSettings(),
      now: DateTime.now(),
    );
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: WhatIfPage(snapshot: snapshot),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Add a purchase'));
    await tester.tap(find.text('Add a purchase'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('scenario-amount')), '125.50');
    await tester.ensureVisible(find.text('See impact'));
    await tester.tap(find.text('See impact'));
    await tester.pumpAndSettle();
    expect(find.text('874.50 USD'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
