import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/models/recurrent-period.dart';
import 'package:piggybank/models/recurrent-record-pattern.dart';
import 'package:piggybank/services/recurrent-record-service.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:timezone/data/latest.dart' as tz;

// A helper method to perform the common date assertions.
void _assertRecordsMatchDates(
    List<Record> records, List<DateTime> expectedDates) {
  expect(records.length, expectedDates.length);
  for (int i = 0; i < records.length; i++) {
    expect(records[i].localDateTime.year, expectedDates[i].year,
        reason: 'Record $i year mismatch');
    expect(records[i].localDateTime.month, expectedDates[i].month,
        reason: 'Record $i month mismatch');
    expect(records[i].localDateTime.day, expectedDates[i].day,
        reason: 'Record $i day mismatch');
  }
}

void main() {
  group('recurrent service test', () {
    // Shared setup for all tests in the group.
    setUpAll(() {
      tz.initializeTimeZones();
      ServiceConfig.localTimezone = "Europe/Vienna";
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    final recurrentRecordService = RecurrentRecordService();
    final category1 = Category("testName1");

    test('daily recurrent different months', () {
      final dateTime = DateTime(2020, 2, 20).toUtc();
      final endDate = DateTime(2020, 3, 2).toUtc();
      final recordPattern = RecurrentRecordPattern(
          1, "Daily", category1, dateTime, RecurrentPeriod.EveryDay);

      final records = recurrentRecordService
          .generateRecurrentRecordsFromDateTime(recordPattern, endDate);

      final expectedDates = [
        DateTime(2020, 2, 20),
        DateTime(2020, 2, 21),
        DateTime(2020, 2, 22),
        DateTime(2020, 2, 23),
        DateTime(2020, 2, 24),
        DateTime(2020, 2, 25),
        DateTime(2020, 2, 26),
        DateTime(2020, 2, 27),
        DateTime(2020, 2, 28),
        DateTime(2020, 2, 29),
        DateTime(2020, 3, 1),
        DateTime(2020, 3, 2),
      ];

      _assertRecordsMatchDates(records, expectedDates);
    });

    test('daily recurrent same month', () {
      final dateTime = DateTime(2020, 2, 20).toUtc();
      final endDate = DateTime(2020, 2, 25).toUtc();
      final recordPattern = RecurrentRecordPattern(
          1, "Daily", category1, dateTime, RecurrentPeriod.EveryDay);

      final records = recurrentRecordService
          .generateRecurrentRecordsFromDateTime(recordPattern, endDate);

      final expectedDates = [
        DateTime(2020, 2, 20),
        DateTime(2020, 2, 21),
        DateTime(2020, 2, 22),
        DateTime(2020, 2, 23),
        DateTime(2020, 2, 24),
        DateTime(2020, 2, 25),
      ];

      _assertRecordsMatchDates(records, expectedDates);
    });

    test('monthly recurrent same year', () {
      final dateTime = DateTime(2020, 2, 20).toUtc();
      final endDate = DateTime(2020, 5, 25).toUtc();
      final recordPattern = RecurrentRecordPattern(
          1, "Monthly", category1, dateTime, RecurrentPeriod.EveryMonth);

      final records = recurrentRecordService
          .generateRecurrentRecordsFromDateTime(recordPattern, endDate);

      final expectedDates = [
        DateTime(2020, 2, 20),
        DateTime(2020, 3, 20),
        DateTime(2020, 4, 20),
        DateTime(2020, 5, 20),
      ];

      _assertRecordsMatchDates(records, expectedDates);
    });

    test('monthly recurrent same year strange dates', () {
      final dateTime = DateTime(2020, 1, 30).toUtc();
      final endDate = DateTime(2020, 4, 25).toUtc();
      final recordPattern = RecurrentRecordPattern(
          1, "Monthly", category1, dateTime, RecurrentPeriod.EveryMonth);

      final records = recurrentRecordService
          .generateRecurrentRecordsFromDateTime(recordPattern, endDate);

      final expectedDates = [
        DateTime(2020, 1, 30),
        DateTime(2020, 2, 29),
        DateTime(2020, 3, 30),
      ];

      _assertRecordsMatchDates(records, expectedDates);
    });

    test('monthly recurrent different year', () {
      final dateTime = DateTime(2020, 2, 20).toUtc();
      final endDate = DateTime(2021, 2, 25).toUtc();
      final recordPattern = RecurrentRecordPattern(
          1, "Monthly", category1, dateTime, RecurrentPeriod.EveryMonth);

      final records = recurrentRecordService
          .generateRecurrentRecordsFromDateTime(recordPattern, endDate);

      final expectedDates = [
        DateTime(2020, 2, 20),
        DateTime(2020, 3, 20),
        DateTime(2020, 4, 20),
        DateTime(2020, 5, 20),
        DateTime(2020, 6, 20),
        DateTime(2020, 7, 20),
        DateTime(2020, 8, 20),
        DateTime(2020, 9, 20),
        DateTime(2020, 10, 20),
        DateTime(2020, 11, 20),
        DateTime(2020, 12, 20),
        DateTime(2021, 1, 20),
        DateTime(2021, 2, 20),
      ];

      _assertRecordsMatchDates(records, expectedDates);
    });

    test('weekly recurrent', () {
      final dateTime = DateTime(2020, 10, 1).toUtc();
      final endDate = DateTime(2020, 10, 15).toUtc();
      final recordPattern = RecurrentRecordPattern(
          1, "Weekly", category1, dateTime, RecurrentPeriod.EveryWeek);

      final records = recurrentRecordService
          .generateRecurrentRecordsFromDateTime(recordPattern, endDate);

      final expectedDates = [
        DateTime(2020, 10, 1),
        DateTime(2020, 10, 8),
        DateTime(2020, 10, 15),
      ];

      _assertRecordsMatchDates(records, expectedDates);
    });

    test('bi-weekly recurrent', () {
      final dateTime = DateTime(2020, 10, 1).toUtc();
      final endDate = DateTime(2020, 10, 30).toUtc();
      final recordPattern = RecurrentRecordPattern(
          1, "Bi-Weekly", category1, dateTime, RecurrentPeriod.EveryTwoWeeks);

      final records = recurrentRecordService
          .generateRecurrentRecordsFromDateTime(recordPattern, endDate);

      final expectedDates = [
        DateTime(2020, 10, 1),
        DateTime(2020, 10, 15),
        DateTime(2020, 10, 29),
      ];

      _assertRecordsMatchDates(records, expectedDates);
    });

    test('three-months recurrent', () {
      final dateTime = DateTime(2020, 1, 5).toUtc();
      final endDate = DateTime(2020, 12, 30).toUtc();
      final recordPattern = RecurrentRecordPattern(1, "Three-Months", category1,
          dateTime, RecurrentPeriod.EveryThreeMonths);

      final records = recurrentRecordService
          .generateRecurrentRecordsFromDateTime(recordPattern, endDate);

      final expectedDates = [
        DateTime(2020, 1, 5),
        DateTime(2020, 4, 5),
        DateTime(2020, 7, 5),
        DateTime(2020, 10, 5),
      ];

      _assertRecordsMatchDates(records, expectedDates);
    });

    test('four-months recurrent', () {
      final dateTime = DateTime(2020, 1, 5).toUtc();
      final endDate = DateTime(2020, 12, 30).toUtc();
      final recordPattern = RecurrentRecordPattern(1, "Four-Months", category1,
          dateTime, RecurrentPeriod.EveryFourMonths);

      final records = recurrentRecordService
          .generateRecurrentRecordsFromDateTime(recordPattern, endDate);

      final expectedDates = [
        DateTime(2020, 1, 5),
        DateTime(2020, 5, 5),
        DateTime(2020, 9, 5),
      ];

      _assertRecordsMatchDates(records, expectedDates);
    });

    test('every year recurrent', () {
      final dateTime = DateTime(2020, 1, 5).toUtc();
      final endDate = DateTime(2022, 12, 30).toUtc();
      final recordPattern = RecurrentRecordPattern(
          1, "Every-Year", category1, dateTime, RecurrentPeriod.EveryYear);

      final records = recurrentRecordService
          .generateRecurrentRecordsFromDateTime(recordPattern, endDate);

      final expectedDates = [
        DateTime(2020, 1, 5),
        DateTime(2021, 1, 5),
        DateTime(2022, 1, 5),
      ];

      _assertRecordsMatchDates(records, expectedDates);
    });

    test('recurrent pattern in the future must return no records', () {
      final patternStartDate = DateTime(2020, 10, 1).toUtc();
      final endDate = DateTime(2020, 01, 30).toUtc();
      final recordPattern = RecurrentRecordPattern(
          1, "Future", category1, patternStartDate, RecurrentPeriod.EveryDay);

      final records = recurrentRecordService
          .generateRecurrentRecordsFromDateTime(recordPattern, endDate);

      expect(records, isEmpty);
    });

    test(
        'recurrent pattern in the future should work when executed in a future date',
        () {
      final patternStartDate = DateTime(2020, 10, 1).toUtc();
      final endDate = DateTime(2020, 10, 5).toUtc();
      final recordPattern = RecurrentRecordPattern(
          1, "Future", category1, patternStartDate, RecurrentPeriod.EveryDay);

      final records = recurrentRecordService
          .generateRecurrentRecordsFromDateTime(recordPattern, endDate);

      final expectedDates = [
        DateTime(2020, 10, 1),
        DateTime(2020, 10, 2),
        DateTime(2020, 10, 3),
        DateTime(2020, 10, 4),
        DateTime(2020, 10, 5),
      ];

      _assertRecordsMatchDates(records, expectedDates);
    });

    test(
        'daily recurrent with different timezones should follow pattern timezone for recurrence',
        () {
      // The user's local timezone is set to Europe/Vienna (UTC+1) in setUpAll.
      // We create a pattern with a different timezone: America/New_York (UTC-5).
      // The recurrence logic should step forward one day according to New York time.
      // The generated records' localDateTime should then also be in New York time.

      // We choose a UTC start date that, when converted to New York time, results in a different day.
      // 2023-01-02 00:00 UTC is 2023-01-01 19:00 in America/New_York (UTC-5).
      final patternUtcStartDateTime = DateTime.utc(2023, 1, 2, 0, 0);
      final endDate = DateTime.utc(2023, 1, 4, 0, 0);

      // Create the record pattern with a specific timezone
      final recordPattern = RecurrentRecordPattern(
        10.0,
        "Daily Recurrence",
        category1,
        patternUtcStartDateTime,
        RecurrentPeriod.EveryDay,
        timeZoneName: "America/New_York",
      );

      final records = recurrentRecordService
          .generateRecurrentRecordsFromDateTime(recordPattern, endDate);

      // The expected dates for the generated records should follow the recurrence
      // based on the "America/New_York" timezone.
      // The localDateTime on the records should also reflect this timezone.
      // 1. Pattern start date in NY time: 2023-01-01 19:00. The date is Jan 1.
      // 2. One day later in NY time: 2023-01-02 19:00. The date is Jan 2.
      // 3. One day later in NY time: 2023-01-03 19:00. The date is Jan 3.
      final expectedDatesInNewYorkTime = [
        DateTime(2023, 1, 1),
        DateTime(2023, 1, 2),
        DateTime(2023, 1, 3),
      ];

      _assertRecordsMatchDates(records, expectedDatesInNewYorkTime);
    });

    test('generated records should have tags from the recurrent pattern', () {
      final patternStartDate = DateTime(2023, 1, 1).toUtc();
      final endDate = DateTime(2023, 1, 3).toUtc();
      final tags = ['work', 'travel', 'expenses'];

      final recordPattern = RecurrentRecordPattern(
        50.0,
        "Tagged Recurrent Record",
        category1,
        patternStartDate,
        RecurrentPeriod.EveryDay,
        tags: tags,
      );

      final records = recurrentRecordService
          .generateRecurrentRecordsFromDateTime(recordPattern, endDate);

      expect(records.length, 3); // Expect 3 records for 3 days
      for (var record in records) {
        expect(record.tags, equals(tags));
      }
    });
  });
}
