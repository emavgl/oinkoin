import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/models/budget-type.dart';
import 'package:piggybank/models/budget.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/recurrent-period.dart';

void main() {
  test('serializes and restores budget filters and recurrence', () {
    final budget = Budget(
      id: 4,
      name: 'Monthly food',
      targetAmount: 450,
      budgetType: BudgetType.expense,
      startDate: DateTime(2026, 1, 15),
      recurrentPeriod: RecurrentPeriod.EveryMonth,
      categoryNames: ['Food'],
      tags: ['planned', 'home'],
      walletIds: [2, 5],
      categoryTagOrLogic: false,
      tagOrLogic: true,
      isArchived: true,
      profileId: 2,
    );

    final restored = Budget.fromMap(budget.toMap());

    expect(restored.id, 4);
    expect(restored.name, 'Monthly food');
    expect(restored.targetAmount, 450);
    expect(restored.budgetType, BudgetType.expense);
    expect(restored.startDate, DateTime(2026, 1, 15));
    expect(restored.recurrentPeriod, RecurrentPeriod.EveryMonth);
    expect(restored.categoryNames, ['Food']);
    expect(restored.tags, ['planned', 'home']);
    expect(restored.walletIds, [2, 5]);
    expect(restored.categoryTagOrLogic, isFalse);
    expect(restored.tagOrLogic, isTrue);
    expect(restored.isArchived, isTrue);
    expect(restored.profileId, 2);
  });

  test('recurring monthly cycles preserve the original starting day', () {
    final budget = Budget(
      name: 'Month end',
      targetAmount: 100,
      budgetType: BudgetType.expense,
      startDate: DateTime(2026, 1, 31),
      recurrentPeriod: RecurrentPeriod.EveryMonth,
    );

    final cycle = budget.currentCycle(DateTime(2026, 3, 15));

    expect(cycle.start, DateTime(2026, 2, 28));
    expect(cycle.end, DateTime(2026, 3, 30));
  });

  test('saving budgets match income records', () {
    final budget = Budget(
      name: 'Savings',
      targetAmount: 500,
      budgetType: BudgetType.saving,
      startDate: DateTime(2026, 1, 1),
    );

    expect(budget.recordCategoryType, CategoryType.income);
  });
}
