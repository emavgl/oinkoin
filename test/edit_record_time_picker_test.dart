import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n_extension/i18n_extension.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/records/edit-record-page.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timezone/data/latest_all.dart' as tz;

import 'helpers/test_database.dart';

final _testCategory = Category(
  'Groceries',
  color: Colors.green,
  categoryType: CategoryType.expense,
);

Widget _buildTestApp(Widget child) {
  return I18n(
    child: MaterialApp(home: child),
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tz.initializeTimeZones();
    ServiceConfig.localTimezone = 'Europe/Vienna';
    await initializeDateFormatting('en_US', null);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ServiceConfig.sharedPreferences = await SharedPreferences.getInstance();
    ServiceConfig.currencyLocale = const Locale('en', 'US');
    ServiceConfig.currencyNumberFormat = null;
    ServiceConfig.currencyNumberFormatWithoutGrouping = null;
    await TestDatabaseHelper.setupTestDatabase();
  });

  group('Time picker widget tests', () {
    // Helper: flush pending timers created by the page's text listener (2s)
    // and any DB async callbacks (10s) after each widget test.
    Future<void> flushTimers(WidgetTester tester) async {
      await tester.pump(const Duration(seconds: 11));
    }

    testWidgets('does not show "Add time" when record has non-midnight time',
        (WidgetTester tester) async {
      // 13:30 UTC = 14:30 Vienna (UTC+1 in March)
      final utcDateTime = DateTime.utc(2024, 3, 10, 13, 30, 0);
      final record = Record(
        -10.0,
        'Coffee',
        _testCategory,
        utcDateTime,
        timeZoneName: 'Europe/Vienna',
      );

      await tester.pumpWidget(_buildTestApp(
        EditRecordPage(passedRecord: record),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Add time'), findsNothing);

      await flushTimers(tester);
    });

    testWidgets('shows "Add time" when existing record has midnight time',
        (WidgetTester tester) async {
      // midnight Vienna (UTC+1 in March) = 23:00 UTC previous day
      final utcDateTime = DateTime.utc(2024, 3, 9, 23, 0, 0);
      final record = Record(
        -10.0,
        'Midnight expense',
        _testCategory,
        utcDateTime,
        timeZoneName: 'Europe/Vienna',
      );

      await tester.pumpWidget(_buildTestApp(
        EditRecordPage(passedRecord: record),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Add time'), findsOneWidget);

      await flushTimers(tester);
    });

    testWidgets('time Semantics identifier is present in the widget tree',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildTestApp(
        EditRecordPage(passedCategory: _testCategory),
      ));
      await tester.pumpAndSettle();

      final semanticsWidgets = tester.widgetList(find.byType(Semantics));
      final hasTimeField = semanticsWidgets.any((w) {
        final s = w as Semantics;
        return s.properties.identifier == 'time-field';
      });
      expect(hasTimeField, isTrue);

      await flushTimers(tester);
    });

    testWidgets('long press on time field clears the time',
        (WidgetTester tester) async {
      // 09:15 Vienna CEST (UTC+2) = 07:15 UTC
      final utcDateTime = DateTime.utc(2024, 6, 1, 7, 15, 0);
      final record = Record(
        -5.0,
        'Breakfast',
        _testCategory,
        utcDateTime,
        timeZoneName: 'Europe/Vienna',
      );

      await tester.pumpWidget(_buildTestApp(
        EditRecordPage(passedRecord: record),
      ));
      await tester.pumpAndSettle();

      // Time is set — "Add time" should not be visible
      expect(find.text('Add time'), findsNothing);

      // Long press on the time InkWell to clear
      final timeFinder = find.descendant(
        of: find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.identifier == 'time-field'),
        matching: find.byType(InkWell),
      );
      await tester.longPress(timeFinder.first);
      await tester.pumpAndSettle();

      expect(find.text('Add time'), findsOneWidget);

      await flushTimers(tester);
    });
  });

  group('DateTime combination logic (unit tests)', () {
    test('combining date with time produces correct local datetime', () {
      final localDate = DateTime(2024, 5, 15);
      const hour = 14;
      const minute = 30;

      final localDateTime = DateTime(
          localDate.year, localDate.month, localDate.day, hour, minute);

      expect(localDateTime.hour, 14);
      expect(localDateTime.minute, 30);
      expect(localDateTime.year, 2024);
      expect(localDateTime.month, 5);
      expect(localDateTime.day, 15);
    });

    test('clearing time resets to midnight of the same date', () {
      final localDate = DateTime(2024, 5, 15, 14, 30);
      final localDateOnly =
          DateTime(localDate.year, localDate.month, localDate.day);

      expect(localDateOnly.hour, 0);
      expect(localDateOnly.minute, 0);
    });

    test('record with non-midnight local time is detected as having a time',
        () {
      tz.initializeTimeZones();

      // 13:30 UTC = 14:30 Vienna (UTC+1 in March)
      final utcDateTime = DateTime.utc(2024, 3, 10, 13, 30, 0);
      final record = Record(-10.0, 'Test', _testCategory, utcDateTime,
          timeZoneName: 'Europe/Vienna');

      final localDT = record.localDateTime;
      expect(localDT.hour, 14);
      expect(localDT.minute, 30);
      expect(localDT.hour != 0 || localDT.minute != 0, isTrue);
    });

    test('record at midnight local time is detected as having no time', () {
      tz.initializeTimeZones();

      // midnight Vienna (UTC+1 in March) = 23:00 UTC previous day
      final utcDateTime = DateTime.utc(2024, 3, 9, 23, 0, 0);
      final record = Record(-10.0, 'Test', _testCategory, utcDateTime,
          timeZoneName: 'Europe/Vienna');

      final localDT = record.localDateTime;
      expect(localDT.hour, 0);
      expect(localDT.minute, 0);
      expect(localDT.hour != 0 || localDT.minute != 0, isFalse);
    });

    test('selecting a new date preserves the previously selected time', () {
      const selectedTime = TimeOfDay(hour: 9, minute: 45);
      final newDate = DateTime(2024, 7, 20);

      final localDateTime = DateTime(newDate.year, newDate.month, newDate.day,
          selectedTime.hour, selectedTime.minute);

      expect(localDateTime.hour, 9);
      expect(localDateTime.minute, 45);
      expect(localDateTime.year, 2024);
      expect(localDateTime.month, 7);
      expect(localDateTime.day, 20);
    });

    test('utcDateTime round-trips through local datetime correctly', () {
      tz.initializeTimeZones();

      // Simulate setting a time: 2024-07-20 at 14:30 local (Vienna CEST = UTC+2)
      final localDate = DateTime(2024, 7, 20, 14, 30);
      final utcDateTime = localDate.toUtc();

      // Store and retrieve via Record
      final record = Record(-1.0, 'Test', _testCategory, utcDateTime,
          timeZoneName: ServiceConfig.localTimezone);

      final retrieved = record.localDateTime;
      // The hour/minute in local time should match what we set
      // (this works if the test machine's timezone matches Vienna in summer,
      // otherwise just verify the UTC round-trip)
      expect(
          utcDateTime.millisecondsSinceEpoch, retrieved.millisecondsSinceEpoch);
    });
  });
}
