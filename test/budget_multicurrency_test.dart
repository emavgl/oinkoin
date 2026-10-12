import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/helpers/records-utility-functions.dart';
import 'package:piggybank/models/budget-type.dart';
import 'package:piggybank/models/budget.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;

void main() {
  final food = Category('Food', categoryType: CategoryType.expense);
  final salary = Category('Salary', categoryType: CategoryType.income);

  // Wallet 1 = EUR (main currency), wallet 2 = USD, wallet 3 = JPY (no rate).
  const walletCurrencyMap = {1: 'EUR', 2: 'USD', 3: 'JPY'};

  Record expense(double value, int walletId) {
    return Record(
      value,
      'r',
      food,
      DateTime.utc(2026, 1, 10),
      walletId: walletId,
      timeZoneName: 'UTC',
    );
  }

  Record income(double value, int walletId) {
    return Record(
      value,
      'r',
      salary,
      DateTime.utc(2026, 1, 10),
      walletId: walletId,
      timeZoneName: 'UTC',
    );
  }

  Budget expenseBudget() => Budget(
        name: 'Food',
        targetAmount: 500,
        budgetType: BudgetType.expense,
        startDate: DateTime(2026, 1, 1),
      );

  Budget savingBudget() => Budget(
        name: 'Savings',
        targetAmount: 1000,
        budgetType: BudgetType.saving,
        startDate: DateTime(2026, 1, 1),
      );

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    tz.initializeTimeZones();
    ServiceConfig.localTimezone = 'Europe/Vienna';
  });

  group('Expense budgets convert to the default currency', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'defaultCurrency': 'EUR',
        'currencyConversionRates': '{"USD_EUR": 0.92}',
      });
      ServiceConfig.sharedPreferences = await SharedPreferences.getInstance();
    });

    test('EUR + USD records are summed converted, not raw', () {
      final records = [
        expense(-100.0, 1), // 100 EUR
        expense(-100.0, 2), // 100 USD -> 92 EUR
      ];

      expect(
        budgetProgressAmount(expenseBudget(), records, walletCurrencyMap),
        closeTo(192.0, 0.001),
      );
    });

    test('single-currency records are unchanged', () {
      final records = [expense(-100.0, 1), expense(-50.0, 1)];

      expect(
        budgetProgressAmount(expenseBudget(), records, walletCurrencyMap),
        closeTo(150.0, 0.001),
      );
    });

    test('without a wallet map keeps the legacy raw sum', () {
      final records = [expense(-100.0, 1), expense(-100.0, 2)];

      expect(budgetProgressAmount(expenseBudget(), records), 200.0);
    });

    test('missing rate falls back to the raw value', () {
      final records = [
        expense(-100.0, 1), // 100 EUR
        expense(-100.0, 3), // 100 JPY, no JPY_EUR rate -> raw 100
      ];

      expect(
        budgetProgressAmount(expenseBudget(), records, walletCurrencyMap),
        closeTo(200.0, 0.001),
      );
    });

    test('record without wallet counts raw', () {
      final noWallet = Record(
        -100.0,
        'r',
        food,
        DateTime.utc(2026, 1, 10),
        timeZoneName: 'UTC',
      );
      final records = [expense(-100.0, 1), noWallet];

      expect(
        budgetProgressAmount(expenseBudget(), records, walletCurrencyMap),
        closeTo(200.0, 0.001),
      );
    });

    test('budgetRecordAmount converts a single foreign record', () {
      expect(
        budgetRecordAmount(expenseBudget(), expense(-100.0, 2), walletCurrencyMap),
        closeTo(92.0, 0.001),
      );
    });
  });

  group('Saving budgets convert net amounts', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'defaultCurrency': 'EUR',
        'currencyConversionRates': '{"USD_EUR": 0.92}',
      });
      ServiceConfig.sharedPreferences = await SharedPreferences.getInstance();
    });

    test('income minus converted expenses', () {
      final records = [
        income(1000.0, 1), // 1000 EUR income
        expense(-100.0, 2), // 100 USD expense -> -92 EUR
      ];

      // 1000 - 92 = 908
      expect(
        budgetProgressAmount(savingBudget(), records, walletCurrencyMap),
        closeTo(908.0, 0.001),
      );
    });

    test('foreign income is converted too', () {
      final records = [
        income(100.0, 2), // 100 USD income -> 92 EUR
        expense(-10.0, 1), // 10 EUR expense
      ];

      expect(
        budgetProgressAmount(savingBudget(), records, walletCurrencyMap),
        closeTo(82.0, 0.001),
      );
    });
  });

  group('Without a default currency', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      ServiceConfig.sharedPreferences = await SharedPreferences.getInstance();
    });

    test('budgets keep the raw sum', () {
      final records = [expense(-100.0, 1), expense(-100.0, 2)];

      expect(
        budgetProgressAmount(expenseBudget(), records, walletCurrencyMap),
        200.0,
      );
    });
  });
}
