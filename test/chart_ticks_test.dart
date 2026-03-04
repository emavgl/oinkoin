import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/statistics/statistics-models.dart';
import 'package:piggybank/statistics/statistics-utils.dart';

void main() {
  group('ChartTickGenerator.generateDayTicks', () {
    test('should generate simple day labels for same month', () {
      // November 15-21 (same month)
      final start = DateTime(2025, 11, 15);
      final end = DateTime(2025, 11, 21);

      final ticks = ChartTickGenerator.generateDayTicks(start, end);

      expect(ticks, equals(['15', '16', '17', '18', '19', '20', '21']));
    });

    test('should show month on day 1 when crossing months', () {
      // March 30 - April 3 (crosses month boundary)
      final start = DateTime(2025, 3, 30);
      final end = DateTime(2025, 4, 3);

      final ticks = ChartTickGenerator.generateDayTicks(start, end);

      expect(ticks, equals(['30', '31', '4/1', '2', '3']));
    });

    test('should show month on day 1 for start of month', () {
      // May 1-7 (starts on day 1)
      final start = DateTime(2025, 5, 1);
      final end = DateTime(2025, 5, 7);

      final ticks = ChartTickGenerator.generateDayTicks(start, end);

      expect(ticks, equals(['5/1', '2', '3', '4', '5', '6', '7']));
    });

    test('should show month on day 1 when crossing year boundary', () {
      // December 29 - January 2 (crosses year boundary)
      final start = DateTime(2025, 12, 29);
      final end = DateTime(2026, 1, 2);

      final ticks = ChartTickGenerator.generateDayTicks(start, end);

      expect(ticks, equals(['29', '30', '31', '1/1', '2']));
    });

    test('should handle longer ranges with jump', () {
      // January 1-31 (full month)
      final start = DateTime(2025, 1, 1);
      final end = DateTime(2025, 1, 31);

      final ticks = ChartTickGenerator.generateDayTicks(start, end);

      // With 31 days, jump should be ceil(31/12) = 3
      // Should show approximately every 3rd day plus start and month boundaries
      expect(ticks.contains('1/1'), isTrue);
      expect(ticks.contains('4'), isTrue);
      expect(ticks.contains('7'), isTrue);
      expect(ticks.contains('10'), isTrue);
      expect(ticks.contains('13'), isTrue);
      expect(ticks.contains('16'), isTrue);
      expect(ticks.contains('19'), isTrue);
      expect(ticks.contains('22'), isTrue);
      expect(ticks.contains('25'), isTrue);
      expect(ticks.contains('28'), isTrue);
      expect(ticks.contains('31'), isTrue);
    });

    test('should show only month boundaries for multi-month range', () {
      // February 28 - March 3 (Feb has 28 days in 2025)
      final start = DateTime(2025, 2, 28);
      final end = DateTime(2025, 3, 3);

      final ticks = ChartTickGenerator.generateDayTicks(start, end);

      expect(ticks, equals(['28', '3/1', '2', '3']));
    });
  });

  group('ChartDateRangeConfig.getKey', () {
    test('should generate simple day keys for same month', () {
      final config = ChartDateRangeConfig.create(
        AggregationMethod.DAY,
        DateTime(2025, 11, 15),
        DateTime(2025, 11, 21),
      );

      expect(config.getKey(DateTime(2025, 11, 15)), equals('15'));
      expect(config.getKey(DateTime(2025, 11, 16)), equals('16'));
      expect(config.getKey(DateTime(2025, 11, 20)), equals('20'));
      expect(config.getKey(DateTime(2025, 11, 21)), equals('21'));
    });

    test('should show month on day 1 when crossing months', () {
      final config = ChartDateRangeConfig.create(
        AggregationMethod.DAY,
        DateTime(2025, 3, 30),
        DateTime(2025, 4, 3),
      );

      expect(config.getKey(DateTime(2025, 3, 30)), equals('30'));
      expect(config.getKey(DateTime(2025, 3, 31)), equals('31'));
      expect(config.getKey(DateTime(2025, 4, 1)), equals('4/1'));
      expect(config.getKey(DateTime(2025, 4, 2)), equals('2'));
      expect(config.getKey(DateTime(2025, 4, 3)), equals('3'));
    });

    test('should show month on day 1 for start of month', () {
      final config = ChartDateRangeConfig.create(
        AggregationMethod.DAY,
        DateTime(2025, 5, 1),
        DateTime(2025, 5, 7),
      );

      expect(config.getKey(DateTime(2025, 5, 1)), equals('5/1'));
      expect(config.getKey(DateTime(2025, 5, 2)), equals('2'));
      expect(config.getKey(DateTime(2025, 5, 7)), equals('7'));
    });

    test('should show month on day 1 when crossing year boundary', () {
      final config = ChartDateRangeConfig.create(
        AggregationMethod.DAY,
        DateTime(2025, 12, 29),
        DateTime(2026, 1, 2),
      );

      expect(config.getKey(DateTime(2025, 12, 29)), equals('29'));
      expect(config.getKey(DateTime(2025, 12, 31)), equals('31'));
      expect(config.getKey(DateTime(2026, 1, 1)), equals('1/1'));
      expect(config.getKey(DateTime(2026, 1, 2)), equals('2'));
    });

    test('should handle leap year February', () {
      final config = ChartDateRangeConfig.create(
        AggregationMethod.DAY,
        DateTime(2024, 2, 28),
        DateTime(2024, 3, 2),
      );

      expect(config.getKey(DateTime(2024, 2, 28)), equals('28'));
      expect(config.getKey(DateTime(2024, 2, 29)), equals('29'));
      expect(config.getKey(DateTime(2024, 3, 1)), equals('3/1'));
      expect(config.getKey(DateTime(2024, 3, 2)), equals('2'));
    });
  });

  group('Tick and Key Consistency', () {
    test('tick labels should match data keys for same month', () {
      final start = DateTime(2025, 11, 15);
      final end = DateTime(2025, 11, 21);

      final config = ChartDateRangeConfig.create(
        AggregationMethod.DAY,
        start,
        end,
      );

      final ticks = ChartTickGenerator.generateDayTicks(start, end);

      // Verify each day in the range has a matching key
      for (int day = 15; day <= 21; day++) {
        final date = DateTime(2025, 11, day);
        final key = config.getKey(date);
        expect(ticks, contains(key), reason: 'Tick for $date should be "$key"');
      }
    });

    test('tick labels should match data keys when crossing months', () {
      final start = DateTime(2025, 3, 30);
      final end = DateTime(2025, 4, 3);

      final config = ChartDateRangeConfig.create(
        AggregationMethod.DAY,
        start,
        end,
      );

      final ticks = ChartTickGenerator.generateDayTicks(start, end);

      // March dates
      expect(ticks, contains(config.getKey(DateTime(2025, 3, 30))));
      expect(ticks, contains(config.getKey(DateTime(2025, 3, 31))));

      // April dates
      expect(ticks, contains(config.getKey(DateTime(2025, 4, 1))));
      expect(ticks, contains(config.getKey(DateTime(2025, 4, 2))));
      expect(ticks, contains(config.getKey(DateTime(2025, 4, 3))));
    });

    test('tick labels should match data keys at month start', () {
      final start = DateTime(2025, 5, 1);
      final end = DateTime(2025, 5, 7);

      final config = ChartDateRangeConfig.create(
        AggregationMethod.DAY,
        start,
        end,
      );

      final ticks = ChartTickGenerator.generateDayTicks(start, end);

      // Day 1 should be '5/1'
      expect(config.getKey(DateTime(2025, 5, 1)), equals('5/1'));
      expect(ticks.first, equals('5/1'));

      // Other days should be just the day number
      expect(config.getKey(DateTime(2025, 5, 2)), equals('2'));
      expect(config.getKey(DateTime(2025, 5, 7)), equals('7'));
    });
  });

  group('Edge Cases', () {
    test('should handle single day range', () {
      final start = DateTime(2025, 6, 15);
      final end = DateTime(2025, 6, 15);

      final ticks = ChartTickGenerator.generateDayTicks(start, end);

      expect(ticks, equals(['15']));
    });

    test('should handle two-day range crossing month', () {
      final start = DateTime(2025, 5, 31);
      final end = DateTime(2025, 6, 1);

      final ticks = ChartTickGenerator.generateDayTicks(start, end);

      expect(ticks, equals(['31', '6/1']));
    });

    test('should handle range starting on day 1', () {
      final start = DateTime(2025, 7, 1);
      final end = DateTime(2025, 7, 5);

      final config = ChartDateRangeConfig.create(
        AggregationMethod.DAY,
        start,
        end,
      );

      final ticks = ChartTickGenerator.generateDayTicks(start, end);

      expect(ticks.first, equals('7/1'));
      expect(config.getKey(DateTime(2025, 7, 1)), equals('7/1'));
    });

    test('should handle range ending on day 1 of next month', () {
      final start = DateTime(2025, 8, 29);
      final end = DateTime(2025, 9, 1);

      final config = ChartDateRangeConfig.create(
        AggregationMethod.DAY,
        start,
        end,
      );

      final ticks = ChartTickGenerator.generateDayTicks(start, end);

      // September 1 should show month
      expect(ticks.last, equals('9/1'));
      expect(config.getKey(DateTime(2025, 9, 1)), equals('9/1'));
    });
  });

  group('Date Range Record Filtering', () {
    // Helper function to test date filtering logic
    // Returns true if the recordDate is within the inclusive range [fromDate, toDate]
    bool isRecordInRange(
        DateTime recordDate, DateTime fromDate, DateTime toDate) {
      return !recordDate.isBefore(fromDate) && !recordDate.isAfter(toDate);
    }

    test('should include records on exact start and end dates', () {
      final fromDate = DateTime(2025, 11, 15);
      final toDate = DateTime(2025, 11, 21, 23, 59, 59);

      // Start date
      expect(isRecordInRange(DateTime(2025, 11, 15, 10, 30), fromDate, toDate),
          isTrue);
      // End date
      expect(isRecordInRange(DateTime(2025, 11, 21, 18, 45), fromDate, toDate),
          isTrue);
      // Middle date
      expect(isRecordInRange(DateTime(2025, 11, 17, 12, 0), fromDate, toDate),
          isTrue);
    });

    test('should exclude records before start date', () {
      final fromDate = DateTime(2025, 11, 15);
      final toDate = DateTime(2025, 11, 21, 23, 59, 59);

      // Just before start (Nov 14 23:59)
      expect(isRecordInRange(DateTime(2025, 11, 14, 23, 59), fromDate, toDate),
          isFalse);
      // Exact start (Nov 15 00:00)
      expect(isRecordInRange(DateTime(2025, 11, 15, 0, 0), fromDate, toDate),
          isTrue);
      // Within range
      expect(isRecordInRange(DateTime(2025, 11, 16, 12, 0), fromDate, toDate),
          isTrue);
    });

    test('should exclude records after end date', () {
      final fromDate = DateTime(2025, 11, 15);
      final toDate = DateTime(2025, 11, 21, 23, 59, 59);

      // Within range
      expect(isRecordInRange(DateTime(2025, 11, 20, 12, 0), fromDate, toDate),
          isTrue);
      // Exact end (Nov 21 23:59:59)
      expect(
          isRecordInRange(DateTime(2025, 11, 21, 23, 59, 59), fromDate, toDate),
          isTrue);
      // Just after end (Nov 22 00:00)
      expect(isRecordInRange(DateTime(2025, 11, 22, 0, 0), fromDate, toDate),
          isFalse);
    });

    test('should handle single day range correctly', () {
      final fromDate = DateTime(2025, 11, 15);
      final toDate = DateTime(2025, 11, 15, 23, 59, 59);

      // Day before at 23:59
      expect(isRecordInRange(DateTime(2025, 11, 14, 23, 59), fromDate, toDate),
          isFalse);
      // Start of day
      expect(isRecordInRange(DateTime(2025, 11, 15, 0, 0), fromDate, toDate),
          isTrue);
      // Mid day
      expect(isRecordInRange(DateTime(2025, 11, 15, 12, 0), fromDate, toDate),
          isTrue);
      // End of day
      expect(
          isRecordInRange(DateTime(2025, 11, 15, 23, 59, 59), fromDate, toDate),
          isTrue);
      // Day after at 00:00
      expect(isRecordInRange(DateTime(2025, 11, 16, 0, 0), fromDate, toDate),
          isFalse);
    });

    test('should handle month boundary correctly', () {
      final fromDate = DateTime(2025, 11, 30);
      final toDate = DateTime(2025, 12, 2, 23, 59, 59);

      // Before range (Nov 29)
      expect(isRecordInRange(DateTime(2025, 11, 29, 10, 0), fromDate, toDate),
          isFalse);
      // Last day of Nov
      expect(isRecordInRange(DateTime(2025, 11, 30, 20, 0), fromDate, toDate),
          isTrue);
      // First day of Dec
      expect(isRecordInRange(DateTime(2025, 12, 1, 8, 0), fromDate, toDate),
          isTrue);
      // Within range (Dec 2)
      expect(isRecordInRange(DateTime(2025, 12, 2, 12, 0), fromDate, toDate),
          isTrue);
      // After range (Dec 3)
      expect(isRecordInRange(DateTime(2025, 12, 3, 0, 0), fromDate, toDate),
          isFalse);
    });

    test('should handle year boundary correctly', () {
      final fromDate = DateTime(2025, 12, 31);
      final toDate = DateTime(2026, 1, 1, 23, 59, 59);

      // Before range (Dec 30)
      expect(isRecordInRange(DateTime(2025, 12, 30, 10, 0), fromDate, toDate),
          isFalse);
      // Last day of 2025
      expect(isRecordInRange(DateTime(2025, 12, 31, 23, 0), fromDate, toDate),
          isTrue);
      // First day of 2026
      expect(isRecordInRange(DateTime(2026, 1, 1, 1, 0), fromDate, toDate),
          isTrue);
      // After range (Jan 2)
      expect(isRecordInRange(DateTime(2026, 1, 2, 15, 0), fromDate, toDate),
          isFalse);
    });

    test('should exclude record at exact midnight of day before', () {
      final fromDate = DateTime(2025, 11, 15);
      final toDate = DateTime(2025, 11, 21, 23, 59, 59);

      // 1 second before midnight of start day
      expect(
          isRecordInRange(DateTime(2025, 11, 14, 23, 59, 59), fromDate, toDate),
          isFalse);
      // Exact midnight of start day
      expect(isRecordInRange(DateTime(2025, 11, 15, 0, 0, 0), fromDate, toDate),
          isTrue);
    });
  });
}
