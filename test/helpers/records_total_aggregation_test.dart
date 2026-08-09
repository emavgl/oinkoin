import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/helpers/records-utility-functions.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/settings/constants/preferences-keys.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ServiceConfig.sharedPreferences = await SharedPreferences.getInstance();
    ServiceConfig.currencyLocale = const Locale('en', 'US');
    ServiceConfig.currencyNumberFormat = null;
    ServiceConfig.currencyNumberFormatWithoutGrouping = null;
  });

  group('tryParseSignedCurrencyString', () {
    test('preserves a leading minus sign', () {
      expect(tryParseSignedCurrencyString('-50'), -50.0);
    });

    test('parses a plain positive value', () {
      expect(tryParseSignedCurrencyString('50'), 50.0);
    });

    test('parses an explicit positive sign', () {
      expect(tryParseSignedCurrencyString('+50'), 50.0);
    });

    test('handles grouping separators', () async {
      await ServiceConfig.sharedPreferences!
          .setString(PreferencesKeys.decimalSeparator, '.');
      await ServiceConfig.sharedPreferences!
          .setString(PreferencesKeys.groupSeparator, ',');
      setNumberFormatCache();

      expect(tryParseSignedCurrencyString('-1,234.56'), -1234.56);
    });

    test('returns null for unparseable input', () {
      expect(tryParseSignedCurrencyString('abc'), isNull);
    });
  });

  group('aggregation with refunds (abs applied to the total)', () {
    final expenseRecords = [
      makeRecord(-50, expenseCategory),
      makeRecord(10, expenseCategory), // refund: reduces the net
    ];

    test('buildCurrencyBreakdown with isAbsValue nets refunds per currency',
        () {
      final breakdown =
          buildCurrencyBreakdown(expenseRecords, const {}, isAbsValue: true);
      // | -50 + 10 | = 40, not 50 + 10 = 60
      expect(breakdown[''], 40);
    });

    test('buildCurrencyBreakdown keeps signed totals by default', () {
      final breakdown =
          buildCurrencyBreakdown(expenseRecords, const {}, isAbsValue: false);
      expect(breakdown[''], -40);
    });

    test('computeConvertedTotal with isAbsValue nets refunds', () {
      final result =
          computeConvertedTotal(expenseRecords, const {}, isAbsValue: true);
      expect(result.total, 40);
    });

    test('computeConvertedTotal keeps the signed net by default', () {
      final result =
          computeConvertedTotal(expenseRecords, const {}, isAbsValue: false);
      expect(result.total, -40);
    });

    test('computeTotalInCurrency nets refunds', () {
      final result = computeTotalInCurrency(expenseRecords, const {}, 'EUR',
          isAbsValue: true);
      expect(result.total, 40);
    });

    test('income paybacks reduce the income total', () {
      final incomeRecords = [
        makeRecord(1000, incomeCategory),
        makeRecord(-100, incomeCategory), // payback
      ];
      final result =
          computeConvertedTotal(incomeRecords, const {}, isAbsValue: true);
      expect(result.total, 900);
    });
  });
}
