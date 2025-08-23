import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:timezone/data/latest.dart' as tz; // Required for timezone tests
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

  group('Record', () {
    test('main constructor should correctly initialize all properties', () {
      // Use a fixed UTC time and a specific timezone name for predictable tests.
      const timeZoneName = 'America/New_York';
      final nowUtc = DateTime.utc(2025, 8, 2, 12, 0, 0);

      final record = Record(
        150.0,
        'Lunch',
        testCategory,
        nowUtc,
        timeZoneName: timeZoneName,
        id: 1,
        description: 'Lunch at the cafe',
        recurrencePatternId: 'pattern-1',
        tags: ['food', 'lunch'].toSet(),
      );

      expect(record.id, 1);
      expect(record.value, 150.0);
      expect(record.title, 'Lunch');
      expect(record.category, testCategory);
      // The stored datetime should be the UTC datetime
      expect(record.utcDateTime, nowUtc);
      // The stored timezone should be the provided name
      expect(record.timeZoneName, timeZoneName);
      expect(record.description, 'Lunch at the cafe');
      expect(record.recurrencePatternId, 'pattern-1');
      expect(record.tags, ['food', 'lunch']);

      // We can also test the localDateTime getter
      final expectedLocal =
          tz.TZDateTime.from(nowUtc, tz.getLocation(timeZoneName));
      expect(record.localDateTime, expectedLocal);
      expect(record.dateTime, expectedLocal);
    });

    test(
        'constructor should default timeZoneName to ServiceConfig.localTimezone if null',
        () {
      final nowUtc = DateTime.utc(2025, 8, 2, 12, 0, 0);
      final record = Record(
        50.0,
        'Books',
        testCategory,
        nowUtc,
        id: 2,
        timeZoneName: null, // Explicitly pass null
      );

      // The timeZoneName should be set to the default from ServiceConfig
      expect(record.timeZoneName, ServiceConfig.localTimezone);
    });

    group('Serialization/Deserialization (toMap/fromMap)', () {
      test(
          'should correctly serialize and deserialize a fully populated record',
          () {
        const timeZoneName = 'Asia/Tokyo';
        final fixedUtcTime = DateTime.utc(2023, 10, 26, 3, 0, 0);

        // Mock a category for the test, similar to the real one
        final testCategoryForMap = Category(
          'Rent',
          color: Colors.blue,
          categoryType: CategoryType.expense,
        );

        final record = Record(
          80.50,
          'Internet Bill',
          testCategoryForMap,
          fixedUtcTime,
          timeZoneName: timeZoneName,
          id: 10,
          description: 'Monthly internet provider bill',
          recurrencePatternId: 'internet-pattern-1',
          tags: ['bill', 'home'].toSet(),
        );

        final map = record.toMap();
        // The `fromMap` constructor expects the category object,
        // so we need to pass a mock category that matches the serialized data.
        map['category'] = testCategoryForMap;
        final decodedRecord = Record.fromMap(map);

        expect(decodedRecord.id, 10);
        expect(decodedRecord.value, 80.50);
        expect(decodedRecord.title, 'Internet Bill');
        expect(decodedRecord.category?.name, testCategoryForMap.name);
        expect(decodedRecord.category?.categoryType,
            testCategoryForMap.categoryType);
        expect(decodedRecord.description, 'Monthly internet provider bill');
        expect(decodedRecord.recurrencePatternId, 'internet-pattern-1');
        expect(decodedRecord.tags, ['bill', 'home']);

        // Crucial test for UTC datetime and timezone name
        expect(decodedRecord.utcDateTime, fixedUtcTime);
        expect(decodedRecord.timeZoneName, timeZoneName);
      });
    });

    group('Getters', () {
      test(
          'date getter should return the date in YYYYMMDD format in the local timezone',
          () {
        // Set up a record with a timezone where the date will be different from UTC
        // UTC: 2025-08-02 23:00:00
        // Asia/Tokyo: 2025-08-03 08:00:00 (+9 hours)
        const timeZoneName = 'Asia/Tokyo';
        final utcDateTime = DateTime.utc(2025, 8, 2, 23, 0, 0);

        final record = Record(
          10.0,
          'Coffee',
          testCategory,
          utcDateTime,
          timeZoneName: timeZoneName,
        );

        // Check the local date representation.
        // We expect the local date to be August 3rd, not August 2nd.
        expect(record.localDateTime.year, 2025);
        expect(record.localDateTime.month, 8);
        expect(record.localDateTime.day, 3);

        // Test the formatted 'date' string
        expect(record.date, '20250803');
      });
    });
  });
}
