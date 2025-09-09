import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/models/recurrent-period.dart';
import 'package:piggybank/models/recurrent-record-pattern.dart';
import 'package:timezone/data/latest_all.dart'
    as tz; // Required for timezone tests
import 'package:timezone/timezone.dart' as tz;

// A helper category for use in tests
final testCategory = Category(
  'Groceries',
  color: Colors.green,
  categoryType: CategoryType.expense,
);

void main() {
  // Initialize timezones once for all tests in this file
  tz.initializeTimeZones();

  group('RecurrentRecordPattern', () {
    test('main constructor should correctly initialize all properties', () {
      // Use a fixed UTC time and a specific timezone name for predictable tests.
      const timeZoneName = 'America/New_York';
      final nowUtc = DateTime.utc(2025, 8, 2, 12, 0, 0);
      final lastUpdateUtc = DateTime.utc(2025, 7, 26, 15, 30, 0);

      final pattern = RecurrentRecordPattern(
        150.0,
        'Monthly Rent',
        testCategory,
        nowUtc,
        timeZoneName: timeZoneName,
        RecurrentPeriod.EveryMonth,
        id: 'pattern-1',
        description: 'Rent for the apartment',
        utcLastUpdate: lastUpdateUtc,
        tags: ['housing', 'monthly'].toSet(),
      );

      expect(pattern.id, 'pattern-1');
      expect(pattern.value, 150.0);
      expect(pattern.title, 'Monthly Rent');
      expect(pattern.category, testCategory);
      // The stored datetime should be the UTC datetime
      expect(pattern.utcDateTime, nowUtc);
      // The stored timezone should be the provided name
      expect(pattern.timeZoneName, timeZoneName);
      expect(pattern.recurrentPeriod, RecurrentPeriod.EveryMonth);
      expect(pattern.description, 'Rent for the apartment');
      // The stored last update should be the UTC datetime
      expect(pattern.utcLastUpdate, lastUpdateUtc);
      expect(pattern.tags, ['housing', 'monthly']);

      // We can also test the localDateTime getter
      final expectedLocal =
          tz.TZDateTime.from(nowUtc, tz.getLocation(timeZoneName));
      expect(pattern.localDateTime, expectedLocal);
    });

    test('fromRecord constructor should create a pattern from a record', () {
      // Create a record with a UTC time and a timezone name
      const timeZoneName = 'Europe/Berlin';
      final recordUtcDate = DateTime.utc(2025, 1, 15, 8, 30, 0);

      final record = Record(
        1200.0,
        'Rent',
        testCategory,
        recordUtcDate,
        timeZoneName: timeZoneName,
        id: 1,
        description: 'Monthly rent payment',
        tags: ['housing', 'rent'].toSet(),
      );

      final pattern = RecurrentRecordPattern.fromRecord(
        record,
        RecurrentPeriod.EveryMonth,
        id: 'pattern-1',
      );

      expect(pattern.id, 'pattern-1');
      expect(pattern.value, 1200.0);
      expect(pattern.title, 'Rent');
      expect(pattern.category, testCategory);
      // The pattern should have the same UTC datetime and timezone name as the record
      expect(pattern.utcDateTime, recordUtcDate);
      expect(pattern.timeZoneName, timeZoneName);
      expect(pattern.description, 'Monthly rent payment');
      expect(pattern.recurrentPeriod, RecurrentPeriod.EveryMonth);
      expect(pattern.tags, ['housing', 'rent']);
    });

    group('Serialization/Deserialization (toMap/fromMap)', () {
      test(
          'should correctly serialize and deserialize a fully populated pattern',
          () {
        const timeZoneName = 'Asia/Tokyo';
        final fixedUtcTime =
            DateTime.utc(2023, 10, 26, 3, 0, 0); // 12:00 PM JST
        final lastUpdateUtcTime =
            DateTime.utc(2023, 10, 19, 1, 30, 45); // 10:30 AM JST

        final pattern = RecurrentRecordPattern(
          150.0,
          'Coffee subscription',
          testCategory,
          fixedUtcTime,
          timeZoneName: timeZoneName,
          RecurrentPeriod.EveryWeek,
          id: 'subscription-1',
          description: 'Weekly coffee club',
          utcLastUpdate: lastUpdateUtcTime,
          tags: ['coffee', 'subscription'].toSet(),
        );

        final map = pattern.toMap();
        final decodedPattern = RecurrentRecordPattern.fromMap(map);

        expect(decodedPattern.id, 'subscription-1');
        expect(decodedPattern.value, 150.0);
        expect(decodedPattern.title, 'Coffee subscription');
        expect(map['category_name'], testCategory.name);
        expect(map['category_type'], testCategory.categoryType?.index);
        expect(decodedPattern.description, 'Weekly coffee club');
        expect(decodedPattern.recurrentPeriod, RecurrentPeriod.EveryWeek);

        // Crucial test for UTC datetime and timezone name
        expect(decodedPattern.utcDateTime, fixedUtcTime);
        expect(decodedPattern.timeZoneName, timeZoneName);
        expect(decodedPattern.tags, ['coffee', 'subscription']);

        // Test lastUpdateUtc
        expect(decodedPattern.utcLastUpdate, lastUpdateUtcTime);
      });
    });
  });
}
