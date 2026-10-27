import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:piggybank/budgets/budgets-page.dart';
import 'package:piggybank/models/budget.dart';
import 'package:piggybank/services/profile-service.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timezone/data/latest_all.dart' as tz;

import 'helpers/test_database.dart';

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
      // Use the plain text-field keyboard mode so the expression can be typed
      // with tester.enterText without dealing with the in-app keyboard.
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

  // sqflite work runs off the fake clock, so pump across real-async gaps
  // until the page has finished loading.
  Future<void> settle(WidgetTester tester, {int rounds = 40}) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  Future<void> pumpBudgetForm(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: CreateBudgetPage()));
    await settle(tester);
  }

  Future<void> saveBudget(
    WidgetTester tester, {
    required String expression,
  }) async {
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.first, 'Budget');
    await tester.enterText(fields.last, expression);
    await tester.pump();

    // Save immediately, before the debounced expression resolver fires.
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await settle(tester);
  }

  Future<List<Budget>> allBudgets(WidgetTester tester) async {
    late List<Budget> budgets;
    await tester.runAsync(() async {
      budgets = await ServiceConfig.database.getBudgets();
    });
    return budgets;
  }

  group('Math expressions in the target amount field', () {
    const cases = {
      '1000+125': 1125.0,
      '1000-125': 875.0,
      '1000*125': 125000.0,
      '1000/125': 8.0,
    };

    for (final entry in cases.entries) {
      testWidgets('${entry.key} is saved as ${entry.value}',
          (WidgetTester tester) async {
        await pumpBudgetForm(tester);

        await saveBudget(tester, expression: entry.key);

        final budgets = await allBudgets(tester);
        expect(budgets.length, 1);
        expect(
          budgets.single.targetAmount,
          closeTo(entry.value, 0.0001),
          reason: 'the expression must be evaluated, not concatenated',
        );
      });
    }
  });
}
