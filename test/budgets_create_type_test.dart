import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/budgets/budgets-page.dart';
import 'package:piggybank/services/profile-service.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'helpers/test_database.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ServiceConfig.sharedPreferences = await SharedPreferences.getInstance();
    await TestDatabaseHelper.setupTestDatabase();
    await ProfileService.instance.initialize();
    ServiceConfig.isPremium = true;
  });

  tearDown(() {
    ServiceConfig.isPremium = true;
  });

  int openedFormIndex(WidgetTester tester) {
    final tabBarView = tester.widget<TabBarView>(
      find.descendant(
        of: find.byType(CreateBudgetPage),
        matching: find.byType(TabBarView),
      ),
    );
    return tabBarView.controller!.index;
  }

  // sqflite work runs off the fake clock, so pump across real-async gaps
  // until the page and the pushed form have finished loading.
  Future<void> settle(WidgetTester tester, {int rounds = 40}) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  Future<void> pumpBudgetsPage(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: BudgetsPage()));
    await settle(tester);
  }

  testWidgets('adding a budget from the Expense tab opens the expense form', (
    tester,
  ) async {
    await pumpBudgetsPage(tester);

    await tester.tap(find.byTooltip('Add a new budget'));
    await settle(tester);

    expect(openedFormIndex(tester), 0);
  });

  testWidgets('adding a budget from the Saving tab opens the saving form', (
    tester,
  ) async {
    await pumpBudgetsPage(tester);

    await tester.tap(find.text('SAVING'));
    await settle(tester);

    await tester.tap(find.byTooltip('Add a new budget'));
    await settle(tester);

    expect(openedFormIndex(tester), 1);
  });

  testWidgets('swiping to the Saving tab opens the saving form', (
    tester,
  ) async {
    await pumpBudgetsPage(tester);

    await tester.fling(
      find.byType(TabBarView).first,
      const Offset(-700, 0),
      2000,
    );
    await settle(tester);

    await tester.tap(find.byTooltip('Add a new budget'));
    await settle(tester);

    expect(openedFormIndex(tester), 1);
  });
}
