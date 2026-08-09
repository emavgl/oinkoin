import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/models/records-per-day.dart';
import 'package:piggybank/statistics/balance-chart-models.dart';
import 'package:piggybank/statistics/statistics-calculator.dart';
import 'package:piggybank/statistics/statistics-models.dart';
import 'package:piggybank/statistics/statistics-utils.dart';
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

Record makeRecord(double value, Category category, DateTime utcDateTime) {
  return Record(
    value,
    'Test',
    category,
    utcDateTime,
    timeZoneName: 'UTC',
  );
}

void main() {
  setUpAll(() {
    tz.initializeTimeZones();
  });

  group('aggregateRecordsByDate', () {
    test('sums raw values so a refund reduces the period net', () {
      final records = [
        makeRecord(-50, expenseCategory, DateTime.utc(2026, 1, 1, 10)),
        makeRecord(10, expenseCategory, DateTime.utc(2026, 1, 1, 14)), // refund
        makeRecord(-30, expenseCategory, DateTime.utc(2026, 1, 2, 10)),
      ];

      final aggregated = aggregateRecordsByDate(records, AggregationMethod.DAY);

      expect(aggregated.length, 2);
      final day1 = aggregated.firstWhere((r) => r.time!.day == 1);
      final day2 = aggregated.firstWhere((r) => r.time!.day == 2);
      expect(day1.value, -40);
      expect(day2.value, -30);
    });
  });

  group('StatisticsCalculator with refunds', () {
    test('average uses the magnitude of the raw sum', () {
      final records = [
        makeRecord(-100, expenseCategory, DateTime.utc(2026, 1, 1)),
        makeRecord(-50, expenseCategory, DateTime.utc(2026, 1, 2)),
        makeRecord(20, expenseCategory, DateTime.utc(2026, 1, 3)), // refund
      ];

      final average = StatisticsCalculator.calculateAverage(
        records,
        AggregationMethod.DAY,
        DateTime(2026, 1, 1),
        DateTime(2026, 1, 3),
      );

      // Periods: -100, -50, +20 -> raw sum -130 -> magnitude 130 / 3
      expect(average, closeTo(130.0 / 3, 1e-9));
    });

    test('balance-mode average keeps the signed net', () {
      final records = [
        makeRecord(-100, expenseCategory, DateTime.utc(2026, 1, 1)),
        makeRecord(20, expenseCategory, DateTime.utc(2026, 1, 2)), // refund
      ];

      final average = StatisticsCalculator.calculateAverage(
        records,
        AggregationMethod.DAY,
        DateTime(2026, 1, 1),
        DateTime(2026, 1, 2),
        isBalance: true,
      );

      expect(average, closeTo(-80.0 / 2, 1e-9));
    });

    test('median uses magnitudes of the period totals', () {
      final records = [
        makeRecord(-100, expenseCategory, DateTime.utc(2026, 1, 1)),
        makeRecord(-50, expenseCategory, DateTime.utc(2026, 1, 2)),
        makeRecord(20, expenseCategory, DateTime.utc(2026, 1, 3)), // refund
      ];

      final median = StatisticsCalculator.calculateMedian(
        records,
        AggregationMethod.DAY,
        DateTime(2026, 1, 1),
        DateTime(2026, 1, 3),
      );

      // | -100 |, | -50 |, | 20 | -> [100, 50, 20] -> sorted [20, 50, 100]
      expect(median, 50);
    });
  });

  group('ComparisonDataAggregator (balance chart) with refunds', () {
    test('expenses magnitude is the abs of the net raw sum', () {
      final records = [
        makeRecord(-50, expenseCategory, DateTime.utc(2026, 1, 1, 10)),
        makeRecord(10, expenseCategory, DateTime.utc(2026, 1, 1, 14)), // refund
        makeRecord(100, incomeCategory, DateTime.utc(2026, 1, 1, 16)),
      ];

      final config = ChartDateRangeConfig.create(
        AggregationMethod.DAY,
        DateTime(2026, 1, 1),
        DateTime(2026, 1, 2),
      );
      final data = ComparisonDataAggregator(AggregationMethod.DAY)
          .aggregate(records, config);

      final point = data.values.single;
      expect(point.expenses, 40); // | -50 + 10 |
      expect(point.income, 100);
      expect(point.netSavings, 60);
    });

    test('income payback reduces the income magnitude', () {
      final records = [
        makeRecord(1000, incomeCategory, DateTime.utc(2026, 1, 1, 10)),
        makeRecord(
            -100, incomeCategory, DateTime.utc(2026, 1, 1, 14)), // payback
      ];

      final config = ChartDateRangeConfig.create(
        AggregationMethod.DAY,
        DateTime(2026, 1, 1),
        DateTime(2026, 1, 2),
      );
      final data = ComparisonDataAggregator(AggregationMethod.DAY)
          .aggregate(records, config);

      final point = data.values.single;
      expect(point.expenses, 0);
      expect(point.income, 900);
      expect(point.netSavings, 900);
    });
  });

  group('RecordsPerDay with refunds/paybacks', () {
    test('expenses, income and balance reflect net amounts', () {
      final day = RecordsPerDay(DateTime(2026, 1, 1), records: [
        makeRecord(-50, expenseCategory, DateTime.utc(2026, 1, 1)),
        makeRecord(10, expenseCategory, DateTime.utc(2026, 1, 1)), // refund
        makeRecord(200, incomeCategory, DateTime.utc(2026, 1, 1)),
        makeRecord(-100, incomeCategory, DateTime.utc(2026, 1, 1)), // payback
      ]);

      expect(day.expenses, -40);
      expect(day.income, 100);
      expect(day.balance, 60);
    });
  });
}
