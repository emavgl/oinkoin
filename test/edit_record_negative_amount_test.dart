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

final _expenseCategory = Category(
  'Groceries',
  color: Colors.green,
  categoryType: CategoryType.expense,
);

final _incomeCategory = Category(
  'Salary',
  color: Colors.blue,
  categoryType: CategoryType.income,
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

  // Helper: flush pending timers created by the page's text listener (2s)
  // and any DB async callbacks (10s) after each widget test.
  Future<void> flushTimers(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 11));
  }

  group('edit-record-page negative amount handling', () {
    testWidgets('shows the signed value when editing an expense record',
        (WidgetTester tester) async {
      final utcDateTime = DateTime.utc(2024, 3, 10, 13, 30, 0);
      final record = Record(
        -50.0,
        'Groceries run',
        _expenseCategory,
        utcDateTime,
        timeZoneName: 'Europe/Vienna',
      );

      await tester.pumpWidget(_buildTestApp(
        EditRecordPage(passedRecord: record),
      ));
      await tester.pumpAndSettle();

      expect(find.text('-50'), findsOneWidget);

      await flushTimers(tester);
    });

    testWidgets(
        'shows a positive value as entered for a refund in an expense '
        'category', (WidgetTester tester) async {
      final utcDateTime = DateTime.utc(2024, 3, 10, 13, 30, 0);
      final record = Record(
        10.0, // a refund: positive value in an expense category
        'Refund',
        _expenseCategory,
        utcDateTime,
        timeZoneName: 'Europe/Vienna',
      );

      await tester.pumpWidget(_buildTestApp(
        EditRecordPage(passedRecord: record),
      ));
      await tester.pumpAndSettle();

      expect(find.text('10'), findsOneWidget);

      await flushTimers(tester);
    });

    testWidgets(
        'shows the signed value when editing an income record with a '
        'payback', (WidgetTester tester) async {
      final utcDateTime = DateTime.utc(2024, 3, 10, 13, 30, 0);
      final record = Record(
        -100.0, // a payback: negative value in an income category
        'Employer correction',
        _incomeCategory,
        utcDateTime,
        timeZoneName: 'Europe/Vienna',
      );

      await tester.pumpWidget(_buildTestApp(
        EditRecordPage(passedRecord: record),
      ));
      await tester.pumpAndSettle();

      expect(find.text('-100'), findsOneWidget);

      await flushTimers(tester);
    });
  });
}
