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
    ServiceConfig.isPremium = false;
  });

  tearDown(() {
    ServiceConfig.isPremium = true;
  });

  testWidgets('free users are sent to the Pro page when adding a budget', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: BudgetsPage()));
    await tester.pump();

    await tester.tap(find.text('PRO'));
    await tester.pumpAndSettle();

    expect(find.text('Upgrade to Pro'), findsOneWidget);
  });
}
