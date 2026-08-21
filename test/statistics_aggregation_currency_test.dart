import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/helpers/records-utility-functions.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/statistics/balance-chart-models.dart';
import 'package:piggybank/statistics/statistics-calculator.dart';
import 'package:piggybank/statistics/statistics-models.dart';
import 'package:piggybank/statistics/statistics-utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;

final expenseCategory = Category(
  'Food',
  color: Colors.red,
  categoryType: CategoryType.expense,
);

List<Record?> _multiCurrencyRecords() => [
      // 100 BRL in wallet 1, 50 USD in wallet 2, same day.
      Record(-100.0, 'r1', expenseCategory, DateTime.utc(2025, 1, 15),
          walletId: 1, timeZoneName: 'UTC'),
      Record(-50.0, 'r2', expenseCategory, DateTime.utc(2025, 1, 15),
          walletId: 2, timeZoneName: 'UTC'),
    ];

const _walletCurrencyMap = {1: 'BRL', 2: 'USD'};

void main() {
  setUpAll(() async {
    tz.initializeTimeZones();
    TestWidgetsFlutterBinding.ensureInitialized();
    ServiceConfig.localTimezone = 'Europe/Vienna';
    // Main currency USD, BRL -> USD rate 0.1931 (100 BRL = 19.31 USD).
    SharedPreferences.setMockInitialValues({
      'defaultCurrency': 'USD',
      'currencyConversionRates': '{"BRL_USD": 0.1931}',
    });
    ServiceConfig.sharedPreferences = await SharedPreferences.getInstance();
    ServiceConfig.currencyLocale = const Locale('en', 'US');
    ServiceConfig.currencyNumberFormat = null;
    ServiceConfig.currencyNumberFormatWithoutGrouping = null;
    setNumberFormatCache();
  });

  group('Multi-currency chart aggregation (issue #411)', () {
    test('aggregateRecordsByDate converts real values to the default currency',
        () {
      final result = aggregateRecordsByDate(
        _multiCurrencyRecords(),
        AggregationMethod.DAY,
        walletCurrencyMap: _walletCurrencyMap,
      );

      // 100 BRL * 0.1931 + 50 USD = 19.31 + 50 = 69.31 USD, not 150.
      // The aggregation preserves the real (signed) value: expenses stay
      // negative. abs() is only applied at the representation boundary.
      expect(result.length, 1);
      expect(result.single.value, closeTo(-69.31, 0.001),
          reason: 'Bar chart must sum values converted to the main currency, '
              'keeping the sign');
    });

    test('ComparisonDataAggregator converts expenses to the default currency',
        () {
      final config = ChartDateRangeConfig.create(
        AggregationMethod.DAY,
        DateTime(2025, 1, 1),
        DateTime(2025, 1, 16),
      );
      final aggregator = ComparisonDataAggregator(AggregationMethod.DAY,
          walletCurrencyMap: _walletCurrencyMap);
      final data = aggregator.aggregate(_multiCurrencyRecords(), config);

      final period = data['15'];
      expect(period, isNotNull);
      expect(period!.expenses, closeTo(69.31, 0.001),
          reason: 'Balance chart must sum expenses converted to the main currency');
    });

    test('StatisticsCalculator average converts values to the default currency',
        () {
      final average = StatisticsCalculator.calculateAverage(
        _multiCurrencyRecords(),
        AggregationMethod.DAY,
        DateTime(2025, 1, 15),
        DateTime(2025, 1, 15),
        walletCurrencyMap: _walletCurrencyMap,
      );

      expect(average, closeTo(69.31, 0.001),
          reason: 'Average must be computed in the main currency');
    });
  });

  group('Without a default currency', () {
    setUp(() async {
      // No main currency configured: conversion is impossible, so aggregations
      // must keep the previous raw-sum behavior.
      SharedPreferences.setMockInitialValues({});
      ServiceConfig.sharedPreferences = await SharedPreferences.getInstance();
    });

    test('aggregateRecordsByDate keeps raw signed sums', () {
      final result = aggregateRecordsByDate(
        _multiCurrencyRecords(),
        AggregationMethod.DAY,
        walletCurrencyMap: _walletCurrencyMap,
      );

      // No main currency to convert to: falls back to the raw signed sum.
      expect(result.single.value, closeTo(-150.0, 0.001));
    });
  });
}
