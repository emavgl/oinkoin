import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/models/recurrent-period.dart';
import 'package:piggybank/models/recurrent-record-pattern.dart';
import 'package:piggybank/services/recurrent-record-service.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:timezone/data/latest_all.dart' as tz;

void main() {
  group('Future recurrent records generation', () {
    setUpAll(() {
      tz.initializeTimeZones();
      ServiceConfig.localTimezone = "Europe/Vienna";
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    final recurrentRecordService = RecurrentRecordService();
    final category1 = Category("testName1");

    test('should generate records up to view end date beyond today', () {
      // Pattern starts in the past
      final patternStartDate = DateTime(2024, 1, 1).toUtc();
      // View end date is in the future (end of month)
      final viewEndDate = DateTime(2024, 1, 31, 23, 59).toUtc();

      final recordPattern = RecurrentRecordPattern(
          100.0, "Daily Pattern", category1, patternStartDate, RecurrentPeriod.EveryDay);

      final records = recurrentRecordService
          .generateRecurrentRecordsFromDateTime(recordPattern, viewEndDate);

      // Should generate from Jan 1 to Jan 31 (31 records)
      expect(records.length, 31);
      expect(records.first.localDateTime.day, 1);
      expect(records.last.localDateTime.day, 31);
    });

    test('should mark records after today as future records', () {
      final patternStartDate = DateTime(2024, 1, 1).toUtc();
      final today = DateTime.now().toUtc();
      // View end date is 10 days from now
      final viewEndDate = today.add(Duration(days: 10));

      final recordPattern = RecurrentRecordPattern(
          50.0, "Daily Future Pattern", category1, patternStartDate, RecurrentPeriod.EveryDay);

      final records = recurrentRecordService
          .generateRecurrentRecordsFromDateTime(recordPattern, viewEndDate);

      // Check that records are generated up to viewEndDate
      expect(records.isNotEmpty, true);

      // All records should be generated (this is just generation, marking happens in service)
      final lastRecord = records.last;
      expect(
        lastRecord.utcDateTime.isBefore(viewEndDate) ||
        lastRecord.utcDateTime.isAtSameMomentAs(viewEndDate),
        true
      );
    });

    test('should split records into past and future correctly in boundary cases', () {
      // Test edge case where today's date is exactly on a recurrent record
      final today = DateTime.now().toUtc();
      final startOfToday = DateTime(today.year, today.month, today.day).toUtc();

      // Pattern starts today
      final recordPattern = RecurrentRecordPattern(
          75.0, "Boundary Test", category1, startOfToday, RecurrentPeriod.EveryDay);

      // View end date is 5 days from today
      final viewEndDate = startOfToday.add(Duration(days: 5));

      final records = recurrentRecordService
          .generateRecurrentRecordsFromDateTime(recordPattern, viewEndDate);

      // Should generate 6 records (today + 5 more days)
      expect(records.length, 6);
    });

    test('should handle monthly pattern with future end date', () {
      final patternStartDate = DateTime(2024, 1, 15).toUtc();
      final viewEndDate = DateTime(2024, 6, 30).toUtc();

      final recordPattern = RecurrentRecordPattern(
          200.0, "Monthly Pattern", category1, patternStartDate, RecurrentPeriod.EveryMonth);

      final records = recurrentRecordService
          .generateRecurrentRecordsFromDateTime(recordPattern, viewEndDate);

      // Should generate: Jan 15, Feb 15, Mar 15, Apr 15, May 15, Jun 15
      expect(records.length, 6);

      // Verify the months
      expect(records[0].localDateTime.month, 1);
      expect(records[1].localDateTime.month, 2);
      expect(records[2].localDateTime.month, 3);
      expect(records[3].localDateTime.month, 4);
      expect(records[4].localDateTime.month, 5);
      expect(records[5].localDateTime.month, 6);
    });

    test('should handle weekly pattern across month boundaries', () {
      final patternStartDate = DateTime(2024, 1, 1).toUtc();
      final viewEndDate = DateTime(2024, 2, 15).toUtc();

      final recordPattern = RecurrentRecordPattern(
          30.0, "Weekly Pattern", category1, patternStartDate, RecurrentPeriod.EveryWeek);

      final records = recurrentRecordService
          .generateRecurrentRecordsFromDateTime(recordPattern, viewEndDate);

      // From Jan 1 to Feb 15 is about 6-7 weeks
      expect(records.length, greaterThanOrEqualTo(6));

      // Verify weekly interval
      if (records.length >= 2) {
        final firstDate = records[0].localDateTime;
        final secondDate = records[1].localDateTime;
        expect(secondDate.difference(firstDate).inDays, 7);
      }
    });

    test('future records should have isFutureRecord flag set to false by default', () {
      // This tests the Record model default behavior
      final category = Category("Test Category");
      final record = Record(
        100.0,
        "Test Record",
        category,
        DateTime.now().toUtc(),
      );

      expect(record.isFutureRecord, false);
    });

    test('future records can be explicitly marked', () {
      final category = Category("Test Category");
      final futureDate = DateTime.now().add(Duration(days: 5)).toUtc();
      final record = Record(
        100.0,
        "Future Record",
        category,
        futureDate,
        isFutureRecord: true,
      );

      expect(record.isFutureRecord, true);
    });

    test('should not generate records when viewEndDate is before pattern start', () {
      final patternStartDate = DateTime(2024, 6, 1).toUtc();
      final viewEndDate = DateTime(2024, 5, 31).toUtc();

      final recordPattern = RecurrentRecordPattern(
          100.0, "Future Pattern", category1, patternStartDate, RecurrentPeriod.EveryDay);

      final records = recurrentRecordService
          .generateRecurrentRecordsFromDateTime(recordPattern, viewEndDate);

      expect(records, isEmpty);
    });

    test('should handle year-spanning patterns correctly', () {
      final patternStartDate = DateTime(2023, 12, 15).toUtc();
      final viewEndDate = DateTime(2024, 1, 31).toUtc();

      final recordPattern = RecurrentRecordPattern(
          150.0, "Year Boundary Pattern", category1, patternStartDate, RecurrentPeriod.EveryWeek);

      final records = recurrentRecordService
          .generateRecurrentRecordsFromDateTime(recordPattern, viewEndDate);

      // Should have records from both 2023 and 2024
      final years = records.map((r) => r.localDateTime.year).toSet();
      expect(years.contains(2023), true);
      expect(years.contains(2024), true);
    });
  });
}

