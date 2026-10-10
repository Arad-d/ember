import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ember/preferences.dart';
import 'package:ember/main.dart';
import 'package:ember/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final loader = FontLoader("EmberSans")
      ..addFont(rootBundle.load("assets/fonts/Roboto-Regular.ttf"));
    await loader.load();
  });
  test('Shamsi month boundaries, Nowruz and leap Esfand', () {
    final start = calendarMonthStart(DateTime(2024, 3, 20), AppCalendar.shamsi);
    expect(start, DateTime(2024, 3, 20));
    expect(calendarDayNumber(start, AppCalendar.shamsi), 1);
    expect(
      shiftCalendarMonth(start, 1, AppCalendar.shamsi),
      DateTime(2024, 4, 20),
    );
    expect(calendarMonthLength(DateTime(2025, 3, 1), AppCalendar.shamsi), 30);
    expect(calendarMonthLength(DateTime(2024, 3, 1), AppCalendar.shamsi), 29);
  });
  test('Preferences persist without changing ledger records', () async {
    SharedPreferences.setMockInitialValues({'demo': 'existing records'});
    final prefs = await SharedPreferences.getInstance();
    final settings = AppPreferences(prefs);
    await settings.setLight(true);
    await settings.setCalendar(AppCalendar.shamsi);
    final restored = AppPreferences(prefs);
    expect(restored.light, isTrue);
    expect(restored.calendar, AppCalendar.shamsi);
    expect(prefs.getString('demo'), 'existing records');
    settings.dispose();
    restored.dispose();
  });
  for (final width in [320.0, 1440.0]) {
    testWidgets('Settings change appearance and calendar at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = LedgerStore(prefs)..loadDemo();
      await tester.pumpWidget(EmberApp(store: store, initialPage: 4));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<bool>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Light · Pistachio & vanilla').last);
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
        Brightness.light,
      );
      await tester.ensureVisible(
        find.byType(DropdownButtonFormField<AppCalendar>),
      );
      await tester.tap(find.byType(DropdownButtonFormField<AppCalendar>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Solar Hijri (Shamsi)').last);
      await tester.pumpAndSettle();
      expect(prefs.getString('calendar'), 'shamsi');
      final surfaces = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .map((d) => d.color);
      expect(surfaces, contains(const EmberPalette(true).panel));
      expect(surfaces, isNot(contains(const EmberPalette(false).panel)));

      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    });
  }
  testWidgets(
    'English Shamsi date picker returns the same Gregorian day and honors limits',
    (tester) async {
      SharedPreferences.setMockInitialValues({'calendar': 'shamsi'});
      final settings = AppPreferences(await SharedPreferences.getInstance());
      DateTime? picked;
      await tester.pumpWidget(
        PreferencesScope(
          preferences: settings,
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    picked = await pickAppDate(
                      context: context,
                      initialDate: DateTime(2024, 3, 20),
                      firstDate: DateTime(2024, 3, 20),
                      lastDate: DateTime(2024, 3, 21),
                    );
                  },
                  child: Text(
                    displayDate(context, DateTime(2024, 3, 20), year: true),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('1 Farvardin 1403'));
      await tester.pumpAndSettle();
      expect(find.text('Farvardin'), findsOneWidget);
      expect(find.text('Sat'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, '3'))
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('2').last);
      await tester.tap(find.text('Choose date'));
      await tester.pumpAndSettle();
      expect(picked, DateTime(2024, 3, 21));
      await tester.pumpWidget(const SizedBox());
      settings.dispose();
    },
  );
}
