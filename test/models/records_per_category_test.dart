import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/models/records-per-category.dart';
import 'package:timezone/data/latest_all.dart' as tz;

final expenseCategory = Category(
  'Groceries',
  color: Colors.red,
  categoryType: CategoryType.expense,
);

final incomeCategory = Category(
  'Salary',
  color: Colors.green,
  categoryType: CategoryType.income,
);

Record makeRecord(double value, Category category) {
  return Record(
    value,
    'Test',
    category,
    DateTime.utc(2026, 1, 1),
    timeZoneName: 'UTC',
  );
}

void main() {
  setUpAll(() {
    tz.initializeTimeZones();
  });

  group('RecordsPerCategory with refunds/paybacks', () {
    test('expenses is the net of all expense-type records', () {
      final rpc = RecordsPerCategory(expenseCategory, records: [
        makeRecord(-50, expenseCategory),
        makeRecord(-20, expenseCategory),
        makeRecord(10, expenseCategory), // refund reduces the net
      ]);

      expect(rpc.expenses, -60);
      expect(rpc.income, 0);
      expect(rpc.balance, -60);
    });

    test('income is the net of all income-type records', () {
      final rpc = RecordsPerCategory(incomeCategory, records: [
        makeRecord(1000, incomeCategory),
        makeRecord(-100, incomeCategory), // payback reduces the net
      ]);

      expect(rpc.income, 900);
      expect(rpc.expenses, 0);
      expect(rpc.balance, 900);
    });

    test('expenses and income are split by category type, not by sign', () {
      // A positive refund (+10) in an expense category counts as expense,
      // while a positive income record is not treated as a "refund" of it.
      final rpc = RecordsPerCategory(expenseCategory, records: [
        makeRecord(-50, expenseCategory),
        makeRecord(10, expenseCategory), // refund: positive value, expense type
        makeRecord(200, incomeCategory),
      ]);

      expect(rpc.expenses, -40);
      expect(rpc.income, 200);
      expect(rpc.balance, 160);
    });

    test('balance is the raw sum of every record', () {
      final rpc = RecordsPerCategory(expenseCategory, records: [
        makeRecord(-50, expenseCategory),
        makeRecord(10, expenseCategory),
        makeRecord(-100, incomeCategory),
        makeRecord(300, incomeCategory),
      ]);

      expect(rpc.balance, 160);
    });
  });
}
