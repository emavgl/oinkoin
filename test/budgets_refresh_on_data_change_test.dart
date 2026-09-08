import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:piggybank/budgets/budgets-page.dart';
import 'package:piggybank/helpers/records-utility-functions.dart';
import 'package:piggybank/models/budget-type.dart';
import 'package:piggybank/models/budget.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/services/database/database-interface.dart';
import 'package:piggybank/services/profile-service.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timezone/data/latest_all.dart' as tz;

import 'helpers/test_database.dart';

void main() {
  final groceries = Category('Groceries', categoryType: CategoryType.expense);

  late DatabaseInterface database;
  late Budget budget;

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
    setNumberFormatCache();
    ServiceConfig.isPremium = true;

    await TestDatabaseHelper.setupTestDatabase();
    database = ServiceConfig.database;
    await ProfileService.instance.initialize();

    budget = Budget(
      name: 'Food budget',
      targetAmount: 200,
      budgetType: BudgetType.expense,
      startDate: DateTime.now().subtract(const Duration(days: 10)),
      endDate: DateTime.now().add(const Duration(days: 20)),
      categoryNames: ['Groceries'],
    );
    await database.addCategory(groceries);
    await database.addBudget(budget);
  });

  tearDown(() {
    ServiceConfig.isPremium = false;
  });

  Future<void> addTwoMatchingExpenses() async {
    for (var i = 0; i < 2; i++) {
      await database.addRecord(
        Record(-50.0, 'weekly shop', groceries, DateTime.now()),
      );
    }
  }

  Future<void> settleWithRealAsync(WidgetTester tester,
      {int rounds = 40}) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  Future<void> pumpAndRender(WidgetTester tester, Widget widget) async {
    await tester.pumpWidget(widget);
    await settleWithRealAsync(tester);
  }

  testWidgets('budgets page reflects expenses added after it was shown',
      (tester) async {
    await pumpAndRender(tester, const MaterialApp(home: BudgetsPage()));

    expect(find.text('0%'), findsOneWidget);

    await tester.runAsync(addTwoMatchingExpenses);
    await settleWithRealAsync(tester);

    expect(find.text('50%'), findsOneWidget);
    expect(find.text('0%'), findsNothing);
  });

  testWidgets('kept-alive budget detail page refreshes when expenses are added',
      (tester) async {
    await pumpAndRender(
      tester,
      MaterialApp(home: BudgetDetailPage(budget: budget)),
    );

    expect(find.text('(0%)'), findsOneWidget);

    await tester.runAsync(addTwoMatchingExpenses);
    await settleWithRealAsync(tester);

    expect(find.text('(50%)'), findsOneWidget);
    expect(find.text('(0%)'), findsNothing);
  });
}
