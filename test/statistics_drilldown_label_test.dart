import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/statistics/statistics-models.dart';
import 'package:piggybank/statistics/statistics-utils.dart';
import 'package:timezone/data/latest_all.dart' as tz;

void main() {
  setUpAll(() {
    tz.initializeTimeZones();
    ServiceConfig.localTimezone = "Europe/Vienna";
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('Statistics aggregation tests', () {
    test('aggregateRecordsByDateAndTag aggregates by YEAR correctly', () {
      final cat = Category('Food', categoryType: CategoryType.expense);
      final records = <Record?>[
        Record(10, 'r1', cat, DateTime(2024, 1, 15), tags: {'test'}),
        Record(20, 'r2', cat, DateTime(2024, 6, 20), tags: {'test'}),
        Record(30, 'r3', cat, DateTime(2025, 3, 10), tags: {'test'}),
      ];

      final aggregated = aggregateRecordsByDateAndTag(
          records, AggregationMethod.YEAR, 'test');

      // Should have 2 year buckets: 2024 and 2025
      expect(aggregated.length, 2);

      // First bucket (2024) should aggregate 2 records
      expect(aggregated[0]!.aggregatedValues, 2);
      expect(aggregated[0]!.value, 30); // 10 + 20

      // Second bucket (2025) should have 1 record
      expect(aggregated[1]!.aggregatedValues, 1);
      expect(aggregated[1]!.value, 30);
    });

    test('aggregateRecordsByDateAndCategory aggregates by YEAR correctly', () {
      final cat = Category('Food', categoryType: CategoryType.expense);
      final records = <Record?>[
        Record(15, 'r1', cat, DateTime(2024, 2, 10)),
        Record(25, 'r2', cat, DateTime(2024, 8, 15)),
        Record(35, 'r3', cat, DateTime(2025, 5, 20)),
      ];

      final aggregated =
          aggregateRecordsByDateAndCategory(records, AggregationMethod.YEAR);

      // Should have 2 year buckets: 2024 and 2025
      expect(aggregated.length, 2);

      // First bucket (2024) should aggregate 2 records
      expect(aggregated[0]!.aggregatedValues, 2);
      expect(aggregated[0]!.value, 40); // 15 + 25

      // Second bucket (2025) should have 1 record
      expect(aggregated[1]!.aggregatedValues, 1);
      expect(aggregated[1]!.value, 35);
    });

    test('aggregateRecordsByDateAndTag aggregates by MONTH correctly', () {
      final cat = Category('Food', categoryType: CategoryType.expense);
      final records = <Record?>[
        Record(10, 'r1', cat, DateTime(2024, 3, 5), tags: {'test'}),
        Record(20, 'r2', cat, DateTime(2024, 3, 15), tags: {'test'}),
        Record(30, 'r3', cat, DateTime(2024, 4, 10), tags: {'test'}),
      ];

      final aggregated = aggregateRecordsByDateAndTag(
          records, AggregationMethod.MONTH, 'test');

      // Should have 2 month buckets: March and April
      expect(aggregated.length, 2);
      expect(aggregated[0]!.aggregatedValues, 2); // March has 2 records
      expect(aggregated[1]!.aggregatedValues, 1); // April has 1 record
    });
  });
}

