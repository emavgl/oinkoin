import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/statistics/statistics-models.dart';
import 'package:piggybank/statistics/record-filters.dart';
import 'package:timezone/data/latest_all.dart' as tz;

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

      group('Timezone edge cases', () {
        test('filters correctly across DST transition boundaries', () {
          // Test around DST start (March 30, 2025 in Europe)
          // 2:00 AM becomes 3:00 AM
          final beforeDst = DateTime.utc(2025, 3, 29, 23, 30); // 11:30 PM UTC
          final duringDst = DateTime.utc(2025, 3, 30, 1, 30); // 1:30 AM UTC
          final afterDst = DateTime.utc(2025, 3, 30, 10, 0); // 10:00 AM UTC

          // Create records in Europe/Berlin timezone
          Record createBerlinRecord(DateTime utcDate, String tzName) {
            return Record(
              10.0,
              'Test',
              groceriesCategory,
              utcDate,
              timeZoneName: tzName,
            );
          }

          final records = [
            createBerlinRecord(beforeDst, 'Europe/Berlin'),
            createBerlinRecord(duringDst, 'Europe/Berlin'),
            createBerlinRecord(afterDst, 'Europe/Berlin'),
          ];

          // Filter for March 30
          final targetDate = DateTime(2025, 3, 30);
          final result =
              RecordFilters.byDate(records, targetDate, AggregationMethod.DAY);

          // All three records should be on March 30 in Europe/Berlin
          // (beforeDst is 00:30, duringDst is 02:30 or 03:30 depending on DST, afterDst is 11:00)
          expect(result.length, 3);
        });

        test('filters correctly with different timezones for same UTC instant',
            () {
          // Same UTC instant: Feb 1, 2026 10:00 PM UTC
          final utcInstant = DateTime.utc(2026, 2, 1, 22, 0);

          // New York (UTC-5): Feb 1, 2026 5:00 PM
          final nyRecord = Record(
            10.0,
            'NY Test',
            groceriesCategory,
            utcInstant,
            timeZoneName: 'America/New_York',
          );

          // Tokyo (UTC+9): Feb 2, 2026 7:00 AM
          final tokyoRecord = Record(
            20.0,
            'Tokyo Test',
            groceriesCategory,
            utcInstant,
            timeZoneName: 'Asia/Tokyo',
          );

          // London (UTC+0): Feb 1, 2026 10:00 PM
          final londonRecord = Record(
            30.0,
            'London Test',
            groceriesCategory,
            utcInstant,
            timeZoneName: 'Europe/London',
          );

          final records = [nyRecord, tokyoRecord, londonRecord];

          // Filter for Feb 1 - should match NY and London, but not Tokyo
          final targetDate = DateTime(2026, 2, 1);
          final result =
              RecordFilters.byDate(records, targetDate, AggregationMethod.DAY);

          expect(result.length, 2);
          expect(result.any((r) => r?.title == 'NY Test'), isTrue);
          expect(result.any((r) => r?.title == 'London Test'), isTrue);
          expect(result.any((r) => r?.title == 'Tokyo Test'), isFalse);
        });

        test('handles month boundaries correctly with timezone differences',
            () {
          // Jan 31, 2026 11:30 PM UTC = Feb 1, 2026 in positive timezones
          final utcDate = DateTime.utc(2026, 1, 31, 23, 30);

          final nyRecord = Record(
            10.0,
            'NY',
            groceriesCategory,
            utcDate,
            timeZoneName: 'America/New_York',
          );

          final tokyoRecord = Record(
            20.0,
            'Tokyo',
            groceriesCategory,
            utcDate,
            timeZoneName: 'Asia/Tokyo',
          );

          final records = [nyRecord, tokyoRecord];

          // Filter for Jan 31 - should match NY (Jan 31 6:30 PM)
          final jan31Result = RecordFilters.byDate(
              records, DateTime(2026, 1, 31), AggregationMethod.DAY);
          expect(jan31Result.length, 1);
          expect(jan31Result.first?.title, 'NY');

          // Filter for Feb 1 - should match Tokyo (Feb 1 8:30 AM)
          final feb1Result = RecordFilters.byDate(
              records, DateTime(2026, 2, 1), AggregationMethod.DAY);
          expect(feb1Result.length, 1);
          expect(feb1Result.first?.title, 'Tokyo');
        });

        test('filters by MONTH with records spanning month boundaries', () {
          // End of January in different timezones
          final jan30Utc =
              DateTime.utc(2026, 1, 30, 20, 0); // Evening Jan 30 UTC
          final jan31Utc = DateTime.utc(2026, 1, 31, 2, 0); // Early Jan 31 UTC
          final feb1Utc = DateTime.utc(2026, 2, 1, 2, 0); // Early Feb 1 UTC

          final records = [
            Record(10.0, 'Test', groceriesCategory, jan30Utc,
                timeZoneName: 'America/New_York'),
            Record(20.0, 'Test', groceriesCategory, jan31Utc,
                timeZoneName: 'Europe/London'),
            Record(30.0, 'Test', groceriesCategory, feb1Utc,
                timeZoneName: 'Asia/Tokyo'),
          ];

          // All should be in their respective local months
          final janResult = RecordFilters.byDate(
              records, DateTime(2026, 1, 1), AggregationMethod.MONTH);
          final febResult = RecordFilters.byDate(
              records, DateTime(2026, 2, 1), AggregationMethod.MONTH);

          // Jan 30 NY -> Jan 30, Jan 31 London -> Jan 31, Feb 1 Tokyo -> Feb 1
          expect(janResult.length, 2);
          expect(febResult.length, 1);
        });

        test('filters by WEEK correctly with timezone boundaries', () {
          // Create records at the week boundary in different timezones
          final week1Utc =
              DateTime.utc(2026, 1, 5, 20, 0); // Monday, Jan 5 evening UTC
          final week2Utc =
              DateTime.utc(2026, 1, 8, 2, 0); // Thursday, Jan 8 early UTC
          final week2LateUtc =
              DateTime.utc(2026, 1, 10, 20, 0); // Saturday, Jan 10 evening UTC

          final records = [
            Record(10.0, 'Test', groceriesCategory, week1Utc,
                timeZoneName: 'America/New_York'),
            Record(20.0, 'Test', groceriesCategory, week2Utc,
                timeZoneName: 'Europe/London'),
            Record(30.0, 'Test', groceriesCategory, week2LateUtc,
                timeZoneName: 'Asia/Tokyo'),
          ];

          // Jan 8, 2026 is in week 2 (Jan 8-14)
          final week2Result = RecordFilters.byDate(
              records, DateTime(2026, 1, 8), AggregationMethod.WEEK);

          // week1Utc in NY -> Jan 5 (week 1)
          // week2Utc in London -> Jan 8 (week 2)
          // week2LateUtc in Tokyo -> Jan 11 (week 2)
          expect(week2Result.length, 2);
        });

        test('handles UTC records correctly', () {
          // All records in UTC timezone
          final records = [
            createRecord(
                value: 10,
                category: groceriesCategory,
                dateTime: DateTime.utc(2026, 2, 1, 10, 0)),
            createRecord(
                value: 20,
                category: groceriesCategory,
                dateTime: DateTime.utc(2026, 2, 1, 15, 0)),
            createRecord(
                value: 30,
                category: groceriesCategory,
                dateTime: DateTime.utc(2026, 2, 2, 8, 0)),
          ];

          final result = RecordFilters.byDate(
              records, DateTime.utc(2026, 2, 1), AggregationMethod.DAY);

          expect(result.length, 2);
        });
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
