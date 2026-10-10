import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shamsi_date/shamsi_date.dart';

enum AppCalendar { gregorian, shamsi }

class AppPreferences extends ChangeNotifier {
  AppPreferences(this.prefs)
    : light = prefs.getString('appearance') == 'light',
      calendar = prefs.getString('calendar') == 'shamsi'
          ? AppCalendar.shamsi
          : AppCalendar.gregorian;
  final SharedPreferences prefs;
  bool light;
  AppCalendar calendar;
  Future<void> setLight(bool value) async {
    await prefs.setString('appearance', value ? 'light' : 'dark');
    light = value;
    notifyListeners();
  }

  Future<void> setCalendar(AppCalendar value) async {
    await prefs.setString('calendar', value.name);
    calendar = value;
    notifyListeners();
  }
}

class PreferencesScope extends InheritedNotifier<AppPreferences> {
  const PreferencesScope({
    super.key,
    required AppPreferences preferences,
    required super.child,
  }) : super(notifier: preferences);
  static AppPreferences? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PreferencesScope>()?.notifier;
}

class EmberPalette {
  const EmberPalette(this.light);
  final bool light;
  static EmberPalette of(BuildContext context) =>
      EmberPalette(Theme.of(context).brightness == Brightness.light);
  Color get coal => light ? const Color(0xFFFFFAEE) : const Color(0xFF171719);
  Color get panel => light ? const Color(0xFFFFFDF6) : const Color(0xFF202022);
  Color get line => light ? const Color(0xFFDADFCC) : const Color(0xFF343234);
  Color get wine => light ? const Color(0xFFB7CF97) : const Color(0xFF8E3D56);
  Color get rose => light ? const Color(0xFF55713C) : const Color(0xFFDAA5B5);
  Color get cream => light ? const Color(0xFF283124) : const Color(0xFFF4EFEA);
  Color get muted => light ? const Color(0xFF616B58) : const Color(0xFFA9A5A5);
  Color get green => light ? const Color(0xFF38675A) : const Color(0xFFACC7B5);
  Color get accentSurface =>
      light ? const Color(0xFFE5EED6) : const Color(0xFF2C2429);
  Color get accentStrong =>
      light ? const Color(0xFFD8E8C5) : const Color(0xFF733047);
  Color get onAccent =>
      light ? const Color(0xFF334526) : const Color(0xFFE4C5CE);
  ThemeData get theme => ThemeData(
    useMaterial3: true,
    brightness: light ? Brightness.light : Brightness.dark,
    scaffoldBackgroundColor: coal,
    fontFamily: 'EmberSans',
    colorScheme:
        ColorScheme.fromSeed(
          seedColor: wine,
          brightness: light ? Brightness.light : Brightness.dark,
        ).copyWith(
          primary: rose,
          onPrimary: light ? Colors.white : coal,
          surface: panel,
          onSurface: cream,
          secondary: green,
          outline: line,
        ),
    dividerColor: line,
    textTheme: (light ? ThemeData.light() : ThemeData.dark()).textTheme.apply(
      bodyColor: cream,
      displayColor: cream,
      fontFamily: 'EmberSans',
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: wine,
        foregroundColor: light ? cream : const Color(0xFFFFFAEE),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: cream,
        side: BorderSide(color: line),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: coal,
      contentPadding: const EdgeInsets.all(17),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: line),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: cream,
      contentTextStyle: TextStyle(color: coal),
    ),
  );
}

mixin PaletteState<T extends StatefulWidget> on State<T> {
  EmberPalette get palette => EmberPalette.of(context);
  Color get coal => palette.coal;
  Color get panel => palette.panel;
  Color get line => palette.line;
  Color get wine => palette.wine;
  Color get rose => palette.rose;
  Color get cream => palette.cream;
  Color get muted => palette.muted;
  Color get green => palette.green;
}

AppCalendar calendarOf(BuildContext context) =>
    PreferencesScope.maybeOf(context)?.calendar ?? AppCalendar.gregorian;
const shamsiMonths = [
  'Farvardin',
  'Ordibehesht',
  'Khordad',
  'Tir',
  'Mordad',
  'Shahrivar',
  'Mehr',
  'Aban',
  'Azar',
  'Dey',
  'Bahman',
  'Esfand',
];

DateTime calendarMonthStart(DateTime date, AppCalendar calendar) {
  if (calendar == AppCalendar.gregorian) return DateTime(date.year, date.month);
  final j = Jalali.fromDateTime(date);
  return Jalali(j.year, j.month).toDateTime();
}

DateTime shiftCalendarMonth(DateTime date, int delta, AppCalendar calendar) {
  if (calendar == AppCalendar.gregorian) {
    return DateTime(date.year, date.month + delta);
  }
  final j = Jalali.fromDateTime(date);
  return Jalali(j.year, j.month).addMonths(delta).toDateTime();
}

int calendarMonthLength(DateTime date, AppCalendar calendar) =>
    calendar == AppCalendar.shamsi
    ? Jalali.fromDateTime(date).monthLength
    : DateTime(date.year, date.month + 1, 0).day;
int calendarDayNumber(DateTime date, AppCalendar calendar) =>
    calendar == AppCalendar.shamsi ? Jalali.fromDateTime(date).day : date.day;
String displayDate(
  BuildContext context,
  DateTime date, {
  bool year = false,
  bool monthOnly = false,
}) {
  if (calendarOf(context) == AppCalendar.shamsi) {
    final j = Jalali.fromDateTime(date);
    return '${monthOnly ? '' : '${j.day} '}${shamsiMonths[j.month - 1]}${year || monthOnly ? ' ${j.year}' : ''}';
  }
  return (monthOnly
          ? DateFormat('MMMM yyyy', 'en_US')
          : year
          ? DateFormat.yMMMd('en_US')
          : DateFormat.MMMd('en_US'))
      .format(date);
}

Future<DateTime?> pickAppDate({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  if (calendarOf(context) == AppCalendar.gregorian) {
    return showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      locale: const Locale('en_US'),
    );
  }
  return showDialog<DateTime>(
    context: context,
    builder: (_) => _ShamsiPicker(
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    ),
  );
}

class _ShamsiPicker extends StatefulWidget {
  const _ShamsiPicker({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });
  final DateTime initialDate, firstDate, lastDate;
  @override
  State<_ShamsiPicker> createState() => _ShamsiPickerState();
}

class _ShamsiPickerState extends State<_ShamsiPicker> {
  late Jalali selected = Jalali.fromDateTime(widget.initialDate);
  late Jalali month = Jalali(selected.year, selected.month);
  bool allowed(Jalali date) {
    final value = date.toDateTime();
    final first = DateUtils.dateOnly(widget.firstDate),
        last = DateUtils.dateOnly(widget.lastDate);
    return !value.isBefore(first) && !value.isAfter(last);
  }

  @override
  Widget build(BuildContext context) {
    final first = Jalali.fromDateTime(widget.firstDate),
        last = Jalali.fromDateTime(widget.lastDate);
    final offset = month.weekDay - 1;
    return AlertDialog(
      title: const Text('Choose a Shamsi date'),
      content: SizedBox(
        width: 340,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Previous month',
                    onPressed:
                        month.year == first.year && month.month == first.month
                        ? null
                        : () => setState(() => month = month.addMonths(-1)),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: DropdownButton<int>(
                      isExpanded: true,
                      value: month.year,
                      items: [
                        for (var y = first.year; y <= last.year; y++)
                          DropdownMenuItem(value: y, child: Text('$y')),
                      ],
                      onChanged: (year) {
                        if (year == null) return;
                        setState(() {
                          var m = month.month;
                          if (year == first.year && m < first.month) {
                            m = first.month;
                          }
                          if (year == last.year && m > last.month) {
                            m = last.month;
                          }
                          month = Jalali(year, m);
                        });
                      },
                    ),
                  ),
                  IconButton(
                    tooltip: 'Next month',
                    onPressed:
                        month.year == last.year && month.month == last.month
                        ? null
                        : () => setState(() => month = month.addMonths(1)),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              Text(
                shamsiMonths[month.month - 1],
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  for (final d in [
                    'Sat',
                    'Sun',
                    'Mon',
                    'Tue',
                    'Wed',
                    'Thu',
                    'Fri',
                  ])
                    Expanded(
                      child: Center(
                        child: Text(d, style: const TextStyle(fontSize: 11)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              for (
                var row = 0;
                row < (offset + month.monthLength + 6) ~/ 7;
                row++
              )
                Row(
                  children: [
                    for (var col = 0; col < 7; col++)
                      Expanded(
                        child: Builder(
                          builder: (_) {
                            final day = row * 7 + col - offset + 1;
                            if (day < 1 || day > month.monthLength) {
                              return const SizedBox(height: 42);
                            }
                            final date = Jalali(month.year, month.month, day);
                            final active =
                                selected.year == month.year &&
                                selected.month == month.month &&
                                selected.day == day;
                            return TextButton(
                              style: TextButton.styleFrom(
                                minimumSize: const Size(0, 42),
                                padding: EdgeInsets.zero,
                                backgroundColor: active
                                    ? Theme.of(
                                        context,
                                      ).colorScheme.primaryContainer
                                    : null,
                              ),
                              onPressed: allowed(date)
                                  ? () => setState(() => selected = date)
                                  : null,
                              child: Text('$day'),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              const SizedBox(height: 8),
              Text(
                '${selected.day} ${shamsiMonths[selected.month - 1]} ${selected.year}',
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: allowed(selected)
              ? () => Navigator.pop(context, selected.toDateTime())
              : null,
          child: const Text('Choose date'),
        ),
      ],
    );
  }
}
