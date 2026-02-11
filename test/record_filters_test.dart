import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/statistics/statistics-models.dart';
import 'package:piggybank/statistics/record-filters.dart';
import 'package:piggybank/statistics/statistics-utils.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

// Test categories
final groceriesCategory = Category(
  'Groceries',
  color: Colors.green,
  categoryType: CategoryType.expense,
);

final salaryCategory = Category(
  'Salary',
  color: Colors.blue,
  categoryType: CategoryType.income,
);

final entertainmentCategory = Category(
  'Entertainment',
  color: Colors.purple,
  categoryType: CategoryType.expense,
);

// Helper function to create test records
Record createRecord({
  required double value,
  required Category category,
  required DateTime dateTime,
  Set<String> tags = const {},
}) {
  return Record(
    value,
    'Test',
    category,
    dateTime.toUtc(),
    timeZoneName: 'UTC',
    tags: tags,
  );
}

void main() {
  // Initialize timezone database once for all tests
  setUpAll(() {
    tz.initializeTimeZones();
  });

  group('RecordFilters', () {
    group('byDate', () {
      test('returns all records when date is null', () {
        final records = [
          createRecord(
              value: 10,
              category: groceriesCategory,
              dateTime: DateTime(2026, 2, 1)),
          createRecord(
              value: 20,
              category: groceriesCategory,
              dateTime: DateTime(2026, 2, 2)),
        ];

        final result =
            RecordFilters.byDate(records, null, AggregationMethod.DAY);

        expect(result.length, 2);
      });

      test('returns all records when method is null', () {
        final records = [
          createRecord(
              value: 10,
              category: groceriesCategory,
              dateTime: DateTime(2026, 2, 1)),
          createRecord(
              value: 20,
              category: groceriesCategory,
              dateTime: DateTime(2026, 2, 2)),
        ];

        final result =
            RecordFilters.byDate(records, DateTime(2026, 2, 1), null);

        expect(result.length, 2);
      });

      test('filters by DAY aggregation correctly', () {
        // Use UTC dates directly since that's how records are stored
        final targetDate = DateTime.utc(2026, 2, 1);
        final records = [
          createRecord(
              value: 10, category: groceriesCategory, dateTime: targetDate),
          createRecord(
              value: 20,
              category: groceriesCategory,
              dateTime: DateTime.utc(2026, 2, 2)),
          createRecord(
              value: 30, category: groceriesCategory, dateTime: targetDate),
        ];

        final result =
            RecordFilters.byDate(records, targetDate, AggregationMethod.DAY);

        // Should find records from Feb 1 (records 0 and 2)
        expect(result.length, 2);
      });

      test('filters by MONTH aggregation correctly', () {
        // Use UTC dates directly since that's how records are stored
        final targetDate = DateTime.utc(2026, 2, 1);
        final records = [
          createRecord(
              value: 10,
              category: groceriesCategory,
              dateTime: DateTime.utc(2026, 2, 5)),
          createRecord(
              value: 20,
              category: groceriesCategory,
              dateTime: DateTime.utc(2026, 2, 15)),
          createRecord(
              value: 30,
              category: groceriesCategory,
              dateTime: DateTime.utc(2026, 3, 1)),
        ];

        final result =
            RecordFilters.byDate(records, targetDate, AggregationMethod.MONTH);

        // Should find records from February (records 0 and 1)
        expect(result.length, 2);
      });

      test('returns new list without modifying original', () {
        final records = [
          createRecord(
              value: 10,
              category: groceriesCategory,
              dateTime: DateTime(2026, 2, 1)),
        ];
        final originalLength = records.length;

        RecordFilters.byDate(
            records, DateTime(2026, 2, 2), AggregationMethod.DAY);

        expect(records.length, originalLength);
      });
    });

    group('byCategory', () {
      test('returns all records when category is null', () {
        final records = [
          createRecord(
              value: 10,
              category: groceriesCategory,
              dateTime: DateTime(2026, 2, 1)),
          createRecord(
              value: 20,
              category: salaryCategory,
              dateTime: DateTime(2026, 2, 1)),
        ];

        final result = RecordFilters.byCategory(records, null, null);

        expect(result.length, 2);
      });

      test('filters by category name correctly', () {
        final records = [
          createRecord(
              value: 10,
              category: groceriesCategory,
              dateTime: DateTime(2026, 2, 1)),
          createRecord(
              value: 20,
              category: salaryCategory,
              dateTime: DateTime(2026, 2, 1)),
          createRecord(
              value: 30,
              category: groceriesCategory,
              dateTime: DateTime(2026, 2, 2)),
        ];

        final result = RecordFilters.byCategory(records, 'Groceries', null);

        expect(result.length, 2);
        expect(result.every((r) => r?.category?.name == 'Groceries'), isTrue);
      });

      test('filters "Others" categories correctly', () {
        final topCategories = ['Groceries', 'Salary'];
        final records = [
          createRecord(
              value: 10,
              category: groceriesCategory,
              dateTime: DateTime(2026, 2, 1)),
          createRecord(
              value: 20,
              category: salaryCategory,
              dateTime: DateTime(2026, 2, 1)),
          createRecord(
              value: 30,
              category: entertainmentCategory,
              dateTime: DateTime(2026, 2, 1)),
        ];

        final result =
            RecordFilters.byCategory(records, 'Others', topCategories);

        expect(result.length, 1);
        expect(result.first?.category?.name, 'Entertainment');
      });

      test('returns all records when "Others" without topCategories', () {
        final records = [
          createRecord(
              value: 10,
              category: groceriesCategory,
              dateTime: DateTime(2026, 2, 1)),
        ];

        final result = RecordFilters.byCategory(records, 'Others', null);

        expect(result.length, 1);
      });
    });

    group('byTag', () {
      test('returns all records when tag is null', () {
        final records = [
          createRecord(
              value: 10,
              category: groceriesCategory,
              dateTime: DateTime(2026, 2, 1),
              tags: {'food'}),
          createRecord(
              value: 20,
              category: groceriesCategory,
              dateTime: DateTime(2026, 2, 1),
              tags: {'home'}),
        ];

        final result = RecordFilters.byTag(records, null, null);

        expect(result.length, 2);
      });

      test('filters by tag correctly', () {
        final records = [
          createRecord(
              value: 10,
              category: groceriesCategory,
              dateTime: DateTime(2026, 2, 1),
              tags: {'food'}),
          createRecord(
              value: 20,
              category: groceriesCategory,
              dateTime: DateTime(2026, 2, 1),
              tags: {'home'}),
          createRecord(
              value: 30,
              category: groceriesCategory,
              dateTime: DateTime(2026, 2, 1),
              tags: {'food', 'essential'}),
        ];

        final result = RecordFilters.byTag(records, 'food', null);

        expect(result.length, 2);
        expect(result.every((r) => r?.tags.contains('food') ?? false), isTrue);
      });

      test('filters "Others" tags correctly', () {
        final topCategories = ['food', 'home'];
        final records = [
          createRecord(
              value: 10,
              category: groceriesCategory,
              dateTime: DateTime(2026, 2, 1),
              tags: {'food'}),
          createRecord(
              value: 20,
              category: groceriesCategory,
              dateTime: DateTime(2026, 2, 1),
              tags: {'home'}),
          createRecord(
              value: 30,
              category: groceriesCategory,
              dateTime: DateTime(2026, 2, 1),
              tags: {'misc'}),
          createRecord(
              value: 40,
              category: groceriesCategory,
              dateTime: DateTime(2026, 2, 1),
              tags: {'food', 'misc'}),
        ];

        final result = RecordFilters.byTag(records, 'Others', topCategories);

        expect(result.length, 2);
        expect(result.any((r) => r?.tags.contains('misc') ?? false), isTrue);
      });

      test('excludes records without tags when filtering', () {
        final records = [
          createRecord(
              value: 10,
              category: groceriesCategory,
              dateTime: DateTime(2026, 2, 1),
              tags: {'food'}),
          createRecord(
              value: 20,
              category: groceriesCategory,
              dateTime: DateTime(2026, 2, 1),
              tags: {}),
        ];

        final result = RecordFilters.byTag(records, 'food', null);

        expect(result.length, 1);
      });
    });

    group('withTags', () {
      test('returns only records with tags', () {
        final records = [
          createRecord(
              value: 10,
              category: groceriesCategory,
              dateTime: DateTime(2026, 2, 1),
              tags: {'food'}),
          createRecord(
              value: 20,
              category: groceriesCategory,
              dateTime: DateTime(2026, 2, 1),
              tags: {}),
          createRecord(
              value: 30,
              category: groceriesCategory,
              dateTime: DateTime(2026, 2, 1),
              tags: {'home'}),
        ];

        final result = RecordFilters.withTags(records);

        expect(result.length, 2);
        expect(result.every((r) => r?.tags.isNotEmpty ?? false), isTrue);
      });

      test('returns empty list when no records have tags', () {
        final records = [
          createRecord(
              value: 10,
              category: groceriesCategory,
              dateTime: DateTime(2026, 2, 1),
              tags: {}),
          createRecord(
              value: 20,
              category: groceriesCategory,
              dateTime: DateTime(2026, 2, 1),
              tags: {}),
        ];

        final result = RecordFilters.withTags(records);

        expect(result.isEmpty, isTrue);
      });
    });

    group('byMultipleCriteria', () {
      test('applies category and tag filters (skips date filter in test)', () {
        final records = [
          createRecord(
              value: 10,
              category: groceriesCategory,
              dateTime: DateTime(2026, 2, 1),
              tags: {'food'}),
          createRecord(
              value: 20,
              category: groceriesCategory,
              dateTime: DateTime(2026, 2, 2),
              tags: {'food'}),
          createRecord(
              value: 30,
              category: salaryCategory,
              dateTime: DateTime(2026, 2, 1),
              tags: {'income'}),
          createRecord(
              value: 40,
              category: groceriesCategory,
              dateTime: DateTime(2026, 2, 1),
              tags: {'home'}),
        ];

        final result = RecordFilters.byMultipleCriteria(
          records,
          category: 'Groceries',
        );

        expect(result.length, 3);
        expect(result.every((r) => r?.category?.name == 'Groceries'), isTrue);
      });

      test('applies no filters when no criteria provided', () {
        final records = [
          createRecord(
              value: 10,
              category: groceriesCategory,
              dateTime: DateTime(2026, 2, 1)),
          createRecord(
              value: 20,
              category: salaryCategory,
              dateTime: DateTime(2026, 2, 2)),
        ];

        final result = RecordFilters.byMultipleCriteria(records);

        expect(result.length, 2);
      });
    });

    group('forTagAggregation', () {
      test('filters by selected tag', () {
        final records = [
          createRecord(
              value: 10,
              category: groceriesCategory,
              dateTime: DateTime(2026, 2, 1),
              tags: {'food'}),
          createRecord(
              value: 20,
              category: groceriesCategory,
              dateTime: DateTime(2026, 2, 2),
              tags: {'food'}),
          createRecord(
              value: 30,
              category: groceriesCategory,
              dateTime: DateTime(2026, 2, 1),
              tags: {'home'}),
        ];

        final result = RecordFilters.forTagAggregation(
          records,
          null,
          null,
          'food',
          null,
        );

        expect(result.length, 2);
        expect(result.every((r) => r?.tags.contains('food') ?? false), isTrue);
      });

      test('handles "Others" tag with exclusions', () {
        final topCategories = ['food'];
        final records = [
          createRecord(
              value: 10,
              category: groceriesCategory,
              dateTime: DateTime(2026, 2, 1),
              tags: {'food'}),
          createRecord(
              value: 20,
              category: groceriesCategory,
              dateTime: DateTime(2026, 2, 1),
              tags: {'misc'}),
          createRecord(
              value: 30,
              category: groceriesCategory,
              dateTime: DateTime(2026, 2, 1),
              tags: {'other'}),
        ];

        final result = RecordFilters.forTagAggregation(
          records,
          null,
          null,
          'Others',
          topCategories,
        );

        expect(result.length, 2);
        expect(
            result.every((r) => !(r?.tags.contains('food') ?? false)), isTrue);
      });
    });
  });
}
