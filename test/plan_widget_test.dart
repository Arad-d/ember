import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ember/main.dart';
import 'package:ember/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = FontLoader('EmberSans')
      ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  for (final width in [320.0, 390.0, 1440.0]) {
    testWidgets('Plan income, buffer, and timeline fit $width', (tester) async {
      tester.view.physicalSize = Size(width, 960);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final s = LedgerStore(await SharedPreferences.getInstance())..loadDemo();
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: EmberApp(store: s, initialPage: 5),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Add income'));
      await tester.tap(find.text('Add income'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'Freelance payment');
      await tester.enterText(find.byType(TextField).at(1), '250000');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(
        s.expectedIncome.any(
          (i) => i.title == 'Freelance payment' && i.amount == 250000,
        ),
        true,
      );
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Forecast settings'));
      await tester.tap(find.text('Forecast settings'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '100000');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(s.planSettings['IRT']!.reserve, 100000);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('View forecast'));
      await tester.tap(find.text('View forecast'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      s.dispose();
    });
  }
}
