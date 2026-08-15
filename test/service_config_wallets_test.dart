import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/models/budget-type.dart';
import 'package:piggybank/models/budget.dart';
import 'package:piggybank/services/database/database-interface.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'helpers/test_database.dart';

import 'package:piggybank/settings/constants/preferences-keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ServiceConfig.sharedPreferences = await SharedPreferences.getInstance();
    // Reset the notifier to its cold-start default so each test simulates a
    // fresh app launch.
    ServiceConfig.walletsEnabledNotifier.value = true;
  });

  test('initWalletsEnabled syncs the notifier to false when the persisted '
      'preference is false', () async {
    await ServiceConfig.sharedPreferences!.setBool(
      PreferencesKeys.walletsEnabled,
      false,
    );

    ServiceConfig.initWalletsEnabled();

    expect(ServiceConfig.walletsEnabledNotifier.value, isFalse);
  });

  test('initWalletsEnabled keeps the notifier enabled when the persisted '
      'preference is true', () async {
    await ServiceConfig.sharedPreferences!.setBool(
      PreferencesKeys.walletsEnabled,
      true,
    );

    ServiceConfig.initWalletsEnabled();

    expect(ServiceConfig.walletsEnabledNotifier.value, isTrue);
  });

  test(
    'initWalletsEnabled defaults to enabled when no preference is stored',
    () async {
      ServiceConfig.initWalletsEnabled();

      expect(ServiceConfig.walletsEnabledNotifier.value, isTrue);
    },
  );

  test('disabling wallets clears budget wallet filters', () async {
    await TestDatabaseHelper.setupTestDatabase();
    final DatabaseInterface database = ServiceConfig.database;
    final budget = Budget(
      name: 'Wallet-specific budget',
      targetAmount: 100,
      budgetType: BudgetType.expense,
      startDate: DateTime(2026, 1, 1),
      walletIds: [1, 2],
    );
    await database.addBudget(budget);

    await ServiceConfig.setWalletsEnabled(false);

    final restored = (await database.getBudgets()).single;
    expect(restored.walletIds, isEmpty);
    expect(ServiceConfig.walletsEnabled, isFalse);

    await ServiceConfig.setWalletsEnabled(true);
    expect((await database.getBudgets()).single.walletIds, isEmpty);
  });
}
