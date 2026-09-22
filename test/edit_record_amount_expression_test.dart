import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n_extension/i18n_extension.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/records/edit-record-page.dart';
import 'package:piggybank/services/profile-service.dart';
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

Finder _fieldByIdentifier(String identifier) => find.byWidgetPredicate(
    (w) => w is Semantics && w.properties.identifier == identifier);

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
    SharedPreferences.setMockInitialValues({
      // Use the plain text-field keyboard mode so the amount can be typed with
      // tester.enterText without dealing with the in-app keyboard overlay.
      'amountInputKeyboardType': 0,
    });
    ServiceConfig.sharedPreferences = await SharedPreferences.getInstance();
    ServiceConfig.currencyLocale = const Locale('en', 'US');
    ServiceConfig.currencyNumberFormat = null;
    ServiceConfig.currencyNumberFormatWithoutGrouping = null;
    ServiceConfig.isPremium = true;
    await TestDatabaseHelper.setupTestDatabase();
    await ProfileService.instance.initialize();
  });

  tearDown(() {
    ServiceConfig.isPremium = false;
  });

  Future<void> pumpEditRecordPage(WidgetTester tester,
      {Record? passedRecord}) async {
    await tester.pumpWidget(_buildTestApp(
      EditRecordPage(passedCategory: _testCategory, passedRecord: passedRecord),
    ));
    await tester.pumpAndSettle();
  }

  Finder amountField() => find.descendant(
      of: _fieldByIdentifier('amount-field'),
      matching: find.byType(TextFormField));

  // Runs real async work (the sqflite_common_ffi calls triggered by saving)
  // while still pumping frames, since widget tests otherwise use a fake clock.
  Future<void> settleWithRealAsync(WidgetTester tester,
      {int rounds = 40}) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  Future<void> tapSave(WidgetTester tester) async {
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();
    await settleWithRealAsync(tester);
  }

  Future<List<Record?>> allRecords(WidgetTester tester) async {
    late List<Record?> records;
    await tester.runAsync(() async {
      records = await ServiceConfig.database.getAllRecords();
    });
    return records;
  }

  // Flush the amount listener's 2s debounce so no Timer is left pending.
  Future<void> flushTimers(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 3));
    await settleWithRealAsync(tester);
  }

  group('Saving an amount expression', () {
    testWidgets(
        'saving immediately evaluates the expression before persisting',
        (WidgetTester tester) async {
      await tester.runAsync(
          () => ServiceConfig.database.addCategory(_testCategory));

      await pumpEditRecordPage(tester);

      await tester.enterText(amountField(), '10.05+1234');
      await tester.pump();

      // Save right away, before the debounced evaluator has time to run.
      await tapSave(tester);

      final records = await allRecords(tester);
      expect(records.length, 1);
      expect(records.single!.value, closeTo(-1244.05, 0.0001),
          reason: 'the expression must be resolved before it is saved');

      await flushTimers(tester);
    });

    testWidgets(
        'editing a record and saving an appended expression persists the result',
        (WidgetTester tester) async {
      await tester.runAsync(() async {
        final db = ServiceConfig.database;
        await db.addCategory(_testCategory);
        await db.addRecord(
          Record(-10.05, 'Groceries', _testCategory, DateTime.utc(2023, 1, 1)),
        );
      });

      final stored = (await allRecords(tester)).single!;
      await pumpEditRecordPage(tester, passedRecord: stored);

      // The field is pre-filled with the existing amount; append an expression.
      await tester.enterText(amountField(), '10.05+1234');
      await tester.pump();
      await tapSave(tester);

      final records = await allRecords(tester);
      expect(records.length, 1);
      expect(records.single!.value, closeTo(-1244.05, 0.0001),
          reason: 'the appended expression must be resolved before saving');

      await flushTimers(tester);
    });

    testWidgets('a plain amount without an expression is saved unchanged',
        (WidgetTester tester) async {
      await tester.runAsync(
          () => ServiceConfig.database.addCategory(_testCategory));

      await pumpEditRecordPage(tester);

      await tester.enterText(amountField(), '42.5');
      await tester.pump();
      await tapSave(tester);

      final records = await allRecords(tester);
      expect(records.length, 1);
      expect(records.single!.value, closeTo(-42.5, 0.0001));

      await flushTimers(tester);
    });
  });
}
