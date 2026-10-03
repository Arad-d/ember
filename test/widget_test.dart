import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ember/main.dart';
import 'package:ember/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final loader = FontLoader("EmberSans")
      ..addFont(rootBundle.load("assets/fonts/Roboto-Regular.ttf"));
    await loader.load();
  });
  for (final size in [
    const Size(1440, 1000),
    const Size(390, 844),
    const Size(320, 740),
  ]) {
    testWidgets('Overview and forms fit ${size.width}', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final store = LedgerStore(await SharedPreferences.getInstance());
      store.loadDemo();
      await tester.pumpWidget(EmberApp(store: store));
      await tester.pumpAndSettle();
      expect(find.text('Your money, at a glance.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Add transaction'));
      await tester.pumpAndSettle();
      expect(find.text('Save transaction'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.enterText(find.byType(TextField).at(0), '123000');
      await tester.enterText(find.byType(TextField).at(1), 'Test coffee');
      await tester.ensureVisible(find.text('Save transaction'));
      await tester.tap(find.text('Save transaction'));
      await tester.pumpAndSettle();
      expect(
        store.entries.any(
          (e) => e.title == 'Test coffee' && e.amount == 123000,
        ),
        isTrue,
      );
      expect(tester.takeException(), isNull);
      for (final index in [1, 2, 3, 4]) {
        if (size.width >= 1000) {
          await tester.tap(
            find
                .text(
                  [
                    'Overview',
                    'Transactions',
                    'Accounts',
                    'Insights',
                    'Settings',
                  ][index],
                )
                .first,
          );
        } else {
          await tester.tap(find.byType(NavigationDestination).at(index));
        }
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      store.dispose();
    });
  }
}
