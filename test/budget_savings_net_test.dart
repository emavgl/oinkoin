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
  final salary = Category('Salary', categoryType: CategoryType.income);
  final groceries = Category('Groceries', categoryType: CategoryType.expense);
  final rent = Category('Rent', categoryType: CategoryType.expense);

  final cycle = BudgetCycle(DateTime(2026, 1, 1), DateTime(2026, 1, 31));

  Record record(
    double value,
    Category category,
    DateTime date, {
    Set<String>? tags,
  }) {
    return Record(
      value,
      category.name,
      category,
      date.toUtc(),
      tags: tags,
    );
  }

  List<Record> januaryRecords() => [
        record(1000, salary, DateTime(2026, 1, 10)),
        record(-300, groceries, DateTime(2026, 1, 15)),
        record(-200, rent, DateTime(2026, 1, 16)),
        // Out of the cycle.
        record(500, salary, DateTime(2026, 2, 5)),
      ];

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    tz.initializeTimeZones();
    ServiceConfig.localTimezone = 'Europe/Vienna';
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ServiceConfig.sharedPreferences = await SharedPreferences.getInstance();
  });

  group('Saving budgets are net (income minus expenses)', () {
    test('match both income and expense records in the selected categories',
        () {
      final budget = Budget(
        name: 'Savings',
        targetAmount: 1000,
        budgetType: BudgetType.saving,
        startDate: DateTime(2026, 1, 1),
        categoryNames: ['Salary', 'Groceries'],
      );

      final matching = matchingBudgetRecords(budget, januaryRecords(), cycle);

      expect(
        matching.map((r) => r.value).toList()..sort(),
        [-300.0, 1000.0],
        reason: 'salary and groceries match; rent and out-of-cycle are excluded',
      );

      expect(budgetProgressAmount(budget, matching), 700.0);
    });

    test('with no category filter, subtract all expenses from all income', () {
      final budget = Budget(
        name: 'Net savings',
        targetAmount: 1000,
        budgetType: BudgetType.saving,
        startDate: DateTime(2026, 1, 1),
      );

      final matching = matchingBudgetRecords(budget, januaryRecords(), cycle);

      // 1000 income - 300 groceries - 200 rent = 500
      expect(budgetProgressAmount(budget, matching), 500.0);
    });

    test('net savings can be negative when expenses exceed income', () {
      final budget = Budget(
        name: 'Net savings',
        targetAmount: 1000,
        budgetType: BudgetType.saving,
        startDate: DateTime(2026, 1, 1),
      );

      final records = [
        record(100, salary, DateTime(2026, 1, 10)),
        record(-400, groceries, DateTime(2026, 1, 15)),
      ];

      expect(
        budgetProgressAmount(
          budget,
          matchingBudgetRecords(budget, records, cycle),
        ),
        -300.0,
      );
    });
  });

  group('Expense budgets are unchanged', () {
    test('only match expense records of the selected categories', () {
      final budget = Budget(
        name: 'Food',
        targetAmount: 500,
        budgetType: BudgetType.expense,
        startDate: DateTime(2026, 1, 1),
        categoryNames: ['Groceries'],
      );

      final matching = matchingBudgetRecords(budget, januaryRecords(), cycle);

      expect(matching.length, 1);
      expect(matching.single.value, -300.0);
      expect(budgetProgressAmount(budget, matching), 300.0);
    });
  });

  group('Transfers never count toward budgets', () {
    Record transfer(Category? category) {
      return Record(
        -500,
        category?.name ?? 'Transfer',
        category,
        DateTime(2026, 1, 20).toUtc(),
        walletId: 1,
        transferWalletId: 2,
        transferValue: 500,
      );
    }

    test('a categorized transfer is ignored by both budget types', () {
      final expenseBudget = Budget(
        name: 'Expense',
        targetAmount: 1000,
        budgetType: BudgetType.expense,
        startDate: DateTime(2026, 1, 1),
      );
      final savingBudget = Budget(
        name: 'Saving',
        targetAmount: 1000,
        budgetType: BudgetType.saving,
        startDate: DateTime(2026, 1, 1),
      );
      final records = [transfer(groceries)];

      for (final budget in [expenseBudget, savingBudget]) {
        final matching = matchingBudgetRecords(budget, records, cycle);
        expect(matching, isEmpty);
        expect(budgetProgressAmount(budget, matching), 0);
      }
    });

    test('a transfer is ignored even when its category is selected', () {
      final budget = Budget(
        name: 'Food',
        targetAmount: 500,
        budgetType: BudgetType.expense,
        startDate: DateTime(2026, 1, 1),
        categoryNames: ['Groceries'],
      );

      final matching =
          matchingBudgetRecords(budget, [transfer(groceries)], cycle);

      expect(matching, isEmpty);
    });

    test('an uncategorized transfer is ignored', () {
      final budget = Budget(
        name: 'Net savings',
        targetAmount: 1000,
        budgetType: BudgetType.saving,
        startDate: DateTime(2026, 1, 1),
      );

      final matching = matchingBudgetRecords(budget, [transfer(null)], cycle);

      expect(matching, isEmpty);
    });
  });

  group('A single-wallet budget sees one side of a transfer', () {
    Record transfer() => Record(
      -500,
      'Transfer',
      null,
      DateTime(2026, 1, 20).toUtc(),
      walletId: 1,
      transferWalletId: 2,
      transferValue: 500,
    );

    Budget walletBudget(List<int> walletIds, BudgetType type) => Budget(
      name: 'Wallet budget',
      targetAmount: 1000,
      budgetType: type,
      startDate: DateTime(2026, 1, 1),
      walletIds: walletIds,
    );

    test('source only subtracts the sent amount for both budget types', () {
      for (final type in [BudgetType.expense, BudgetType.saving]) {
        final budget = walletBudget([1], type);
        final matching = matchingBudgetRecords(budget, [transfer()], cycle);

        expect(matching.length, 1);
        expect(budgetProgressAmount(budget, matching), -500.0);
      }
    });

    test('destination only adds the received amount for both budget types', () {
      for (final type in [BudgetType.expense, BudgetType.saving]) {
        final budget = walletBudget([2], type);
        final matching = matchingBudgetRecords(budget, [transfer()], cycle);

        expect(matching.length, 1);
        expect(budgetProgressAmount(budget, matching), 500.0);
      }
    });

    test('both wallets net to zero', () {
      final budget = walletBudget([1, 2], BudgetType.saving);
      final matching = matchingBudgetRecords(budget, [transfer()], cycle);

      expect(matching, isEmpty);
      expect(budgetProgressAmount(budget, matching), 0);
    });

    test('an unrelated wallet does not see the transfer', () {
      final budget = walletBudget([3], BudgetType.expense);

      expect(matchingBudgetRecords(budget, [transfer()], cycle), isEmpty);
    });
  });
}
