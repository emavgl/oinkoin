import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/helpers/records-utility-functions.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final expenseCategory = Category(
    'Groceries',
    iconCodePoint: 1,
    categoryType: CategoryType.expense,
  );
  final incomeCategory = Category(
    'Salary',
    iconCodePoint: 2,
    categoryType: CategoryType.income,
  );

  Record expense({int? walletId, double value = -20.0}) => Record(
        value,
        'Groceries',
        expenseCategory,
        DateTime(2026, 6, 1).toUtc(),
        walletId: walletId,
      );

  Record income({int? walletId, double value = 1000.0}) => Record(
        value,
        'Salary',
        incomeCategory,
        DateTime(2026, 6, 1).toUtc(),
        walletId: walletId,
      );

  Record transfer({int? walletId, int? transferWalletId, double value = -100.0}) =>
      Record(
        value,
        'Transfer',
        null,
        DateTime(2026, 6, 1).toUtc(),
        walletId: walletId,
        transferWalletId: transferWalletId,
      );

  group('balanceRelevantRecords', () {
    test('excludes transfers', () {
      final records = [
        expense(walletId: 1),
        transfer(walletId: 1, transferWalletId: 2),
      ];
      final result = balanceRelevantRecords(records);
      expect(result, hasLength(1));
      expect(result.first!.isTransfer, isFalse);
    });

    test(
      'a day made up entirely of transfers has nothing balance-relevant '
      '(reported expectation: "just don\'t show nothing in the header")',
      () {
        final records = [transfer(walletId: 1, transferWalletId: 2)];
        expect(balanceRelevantRecords(records), isEmpty);
      },
    );

    test('keeps expenses and income, drops only transfers', () {
      final records = [
        expense(walletId: 1),
        income(walletId: 1),
        transfer(walletId: 1, transferWalletId: 2),
      ];
      final result = balanceRelevantRecords(records);
      expect(result, hasLength(2));
      expect(result.every((r) => !r!.isTransfer), isTrue);
    });

    test('an empty list stays empty', () {
      expect(balanceRelevantRecords([]), isEmpty);
    });

    test('null entries are dropped like non-matching records', () {
      final result = balanceRelevantRecords([null, expense(walletId: 1)]);
      expect(result, hasLength(1));
    });
  });

  group('day balance total excludes transfers (as computed by '
      'RecordsPerDayCard)', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      ServiceConfig.sharedPreferences = await SharedPreferences.getInstance();
    });

    test(
      'a transfer alongside an expense does not inflate/deflate the day total',
      () {
        final records = [
          expense(walletId: 1, value: -30.0),
          transfer(walletId: 1, transferWalletId: 2, value: -100.0),
        ];
        final total = computeConvertedTotal(
          balanceRelevantRecords(records),
          {1: 'EUR', 2: 'EUR'},
        ).total;
        // Only the expense counts; the -100 transfer must not be included.
        expect(total, -30.0);
      },
    );

    test('a day of only a transfer sums to nothing to show', () {
      final records = [transfer(walletId: 1, transferWalletId: 2, value: -100.0)];
      final relevant = balanceRelevantRecords(records);
      expect(relevant, isEmpty,
          reason:
              'RecordsPerDayCard._formatDayBalance returns "" in this case');
    });
  });
}
