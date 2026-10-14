import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ember/main.dart';
import 'package:ember/store.dart';
import 'package:ember/preferences.dart';
import 'package:ember/transaction_export.dart';
import 'package:ember/transaction_export_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      'EmberSans',
    )..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'))).load();
  });
  for (final width in [320.0, 390.0, 1440.0]) {
    for (final light in [false, true]) {
      testWidgets('Export controls and download fit $width light=$light', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({});
        final store = LedgerStore(await SharedPreferences.getInstance())
          ..loadDemo();
        String? filename, mime;
        Uint8List? contents;
        await tester.pumpWidget(
          MaterialApp(
            theme: EmberPalette(light).theme,
            home: Scaffold(
              body: TransactionExportView(
                snapshot: ExportSnapshot(
                  accounts: store.accounts,
                  entries: store.entries,
                  now: DateTime.now(),
                ),
                calendar: AppCalendar.gregorian,
                download: (bytes, type, name) async {
                  contents = bytes;
                  mime = type;
                  filename = name;
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('9 transactions'), findsOneWidget);
        await tester.ensureVisible(find.text('Download CSV'));
        await tester.tap(find.text('Download CSV'));
        await tester.pumpAndSettle();
        expect(filename, endsWith('.csv'));
        expect(mime, startsWith('text/csv'));
        expect(contents, isNotEmpty);
        await tester.ensureVisible(find.text('PDF'));
        await tester.tap(find.text('PDF'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Download PDF'));
        await tester.tap(find.text('Download PDF'));
        await tester.pumpAndSettle();
        expect(filename, endsWith('.pdf'));
        expect(contents!.take(4), [37, 80, 68, 70]);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        store.dispose();
      });
    }
  }
  testWidgets('Settings exposes export and empty results disable download', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = LedgerStore(await SharedPreferences.getInstance())
      ..loadDemo();
    await tester.pumpWidget(EmberApp(store: store, initialPage: 4));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Export transactions'));
    await tester.tap(find.text('Export transactions'));
    await tester.pumpAndSettle();
    expect(find.text('9 transactions'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('export-currency')));
    await tester.tap(find.byKey(const ValueKey('export-currency')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Euro (€)').last);
    await tester.pumpAndSettle();
    expect(find.text('No transactions match these filters.'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.ancestor(
              of: find.text('Download CSV'),
              matching: find.byWidgetPredicate((w) => w is FilledButton),
            ),
          )
          .onPressed,
      isNull,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    store.dispose();
  });
}
