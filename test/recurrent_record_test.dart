import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/recurrent-period.dart';
import 'package:piggybank/models/recurrent-record-pattern.dart';

import 'package:piggybank/services/recurrent-record-service.dart';


main() {
  group('recurrent service test', () {

    test('daily recurrent different months', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      RecurrentRecordService recurrentRecordService = new RecurrentRecordService();
      Category category1 = new Category("testName1");
      DateTime dateTime = new DateTime(2020, 2, 20);
      DateTime endDate = new DateTime(2020, 3, 2);
      RecurrentRecordPattern recordPattern = RecurrentRecordPattern(1, "Daily", category1, dateTime, RecurrentPeriod.EveryDay);
      var records = recurrentRecordService.generateRecurrentRecordsFromDateTime(recordPattern, endDate);
      expect(records.length, 12);
      expect(records[11].dateTime!.month, 3);
      expect(records[11].dateTime!.day, 2);
    });

    test('daily recurrent same month', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      RecurrentRecordService recurrentRecordService = new RecurrentRecordService();
      Category category1 = new Category("testName1");
      DateTime dateTime = new DateTime(2020, 2, 20);
      DateTime endDate = new DateTime(2020, 2, 25);
      RecurrentRecordPattern recordPattern = RecurrentRecordPattern(1, "Daily", category1, dateTime, RecurrentPeriod.EveryDay);
      var records = recurrentRecordService.generateRecurrentRecordsFromDateTime(recordPattern, endDate);
      expect(records.length, 6);
    });

    test('monthly recurrent same year', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      RecurrentRecordService recurrentRecordService = new RecurrentRecordService();
      Category category1 = new Category("testName1");
      DateTime dateTime = new DateTime(2020, 2, 20);
      DateTime endDate = new DateTime(2020, 5, 25);
      RecurrentRecordPattern recordPattern = RecurrentRecordPattern(1, "Monthly", category1, dateTime, RecurrentPeriod.EveryMonth);
      var records = recurrentRecordService.generateRecurrentRecordsFromDateTime(recordPattern, endDate);
      expect(records.length, 4);
      expect(records[3].dateTime!.month, 5);
      expect(records[3].dateTime!.day, 20);
    });

    test('monthly recurrent same year strange dates', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      RecurrentRecordService recurrentRecordService = new RecurrentRecordService();
      Category category1 = new Category("testName1");
      DateTime dateTime = new DateTime(2020, 1, 30);
      DateTime endDate = new DateTime(2020, 4, 25);
      RecurrentRecordPattern recordPattern = RecurrentRecordPattern(1, "Monthly", category1, dateTime, RecurrentPeriod.EveryMonth);
      var records = recurrentRecordService.generateRecurrentRecordsFromDateTime(recordPattern, endDate);
      expect(records.length, 3);
      expect(records[2].dateTime!.month, 3);
      expect(records[2].dateTime!.day, 30);
    });

    test('monthly recurrent different year', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      RecurrentRecordService recurrentRecordService = new RecurrentRecordService();
      Category category1 = new Category("testName1");
      DateTime dateTime = new DateTime(2020, 2, 20);
      DateTime endDate = new DateTime(2021, 2, 25);
      RecurrentRecordPattern recordPattern = RecurrentRecordPattern(1, "Monthly", category1, dateTime, RecurrentPeriod.EveryMonth);
      var records = recurrentRecordService.generateRecurrentRecordsFromDateTime(recordPattern, endDate);
      expect(records.length, 13);
      expect(records[12].dateTime!.month, 2);
      expect(records[12].dateTime!.day, 20);
    });

    test('weekly recurrent', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      RecurrentRecordService recurrentRecordService = new RecurrentRecordService();
      Category category1 = new Category("testName1");
      DateTime dateTime = new DateTime(2020, 10, 1);
      DateTime endDate = new DateTime(2020, 10, 15);
      RecurrentRecordPattern recordPattern = RecurrentRecordPattern(1, "Weekly", category1, dateTime, RecurrentPeriod.EveryWeek);
      var records = recurrentRecordService.generateRecurrentRecordsFromDateTime(recordPattern, endDate);
      expect(records.length, 3);
      expect(records[2].dateTime!.month, 10);
      expect(records[2].dateTime!.day, 15);
    });

    test('bi-weekly recurrent', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      RecurrentRecordService recurrentRecordService = new RecurrentRecordService();
      Category category1 = new Category("testName1");
      DateTime dateTime = new DateTime(2020, 10, 1);
      DateTime endDate = new DateTime(2020, 10, 30);
      RecurrentRecordPattern recordPattern = RecurrentRecordPattern(1, "Bi-Weekly", category1, dateTime, RecurrentPeriod.EveryTwoWeeks);
      var records = recurrentRecordService.generateRecurrentRecordsFromDateTime(recordPattern, endDate);
      expect(records.length, 3);
      expect(records[1].dateTime!.month, 10);
      expect(records[1].dateTime!.day, 15);
      expect(records[2].dateTime!.month, 10);
      expect(records[2].dateTime!.day, 29);
    });

    test('three-months recurrent', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      RecurrentRecordService recurrentRecordService = new RecurrentRecordService();
      Category category1 = new Category("testName1");
      DateTime dateTime = new DateTime(2020, 1, 5);
      DateTime endDate = new DateTime(2020, 12, 30);
      RecurrentRecordPattern recordPattern = RecurrentRecordPattern(1, "Three-Months", category1, dateTime, RecurrentPeriod.EveryThreeMonths);
      var records = recurrentRecordService.generateRecurrentRecordsFromDateTime(recordPattern, endDate);
      expect(records.length, 4);
      expect(records[1].dateTime!.month, 4);
      expect(records[1].dateTime!.day, 5);
      expect(records[2].dateTime!.month, 7);
      expect(records[2].dateTime!.day, 5);
      expect(records[3].dateTime!.month, 10);
      expect(records[3].dateTime!.day, 5);
    });

    test('four-months recurrent', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      RecurrentRecordService recurrentRecordService = new RecurrentRecordService();
      Category category1 = new Category("testName1");
      DateTime dateTime = new DateTime(2020, 1, 5);
      DateTime endDate = new DateTime(2020, 12, 30);
      RecurrentRecordPattern recordPattern = RecurrentRecordPattern(1, "Three-Months", category1, dateTime, RecurrentPeriod.EveryFourMonths);
      var records = recurrentRecordService.generateRecurrentRecordsFromDateTime(recordPattern, endDate);
      expect(records.length, 3);
      expect(records[1].dateTime!.month, 5);
      expect(records[1].dateTime!.day, 5);
      expect(records[2].dateTime!.month, 9);
      expect(records[2].dateTime!.day, 5);
    });

    test('every year recurrent', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      RecurrentRecordService recurrentRecordService = new RecurrentRecordService();
      Category category1 = new Category("testName1");
      DateTime dateTime = new DateTime(2020, 1, 5);
      DateTime endDate = new DateTime(2022, 12, 30);
      RecurrentRecordPattern recordPattern = RecurrentRecordPattern(1, "Every-Year", category1, dateTime, RecurrentPeriod.EveryYear);
      var records = recurrentRecordService.generateRecurrentRecordsFromDateTime(recordPattern, endDate);
      expect(records.length, 3);
      expect(records[1].dateTime!.year, 2021);
      expect(records[1].dateTime!.month, 1);
      expect(records[1].dateTime!.day, 5);
      expect(records[2].dateTime!.year, 2022);
      expect(records[2].dateTime!.month, 1);
      expect(records[2].dateTime!.day, 5);
    });

    test('recurrent pattern in the future must return no records', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      RecurrentRecordService recurrentRecordService = new RecurrentRecordService();
      Category category1 = new Category("testName1");
      DateTime patternStartDate = new DateTime(2020, 10, 1); // date of the start of the pattern
      DateTime endDate = new DateTime(2020, 01, 30); // date of today
      RecurrentRecordPattern recordPattern = RecurrentRecordPattern(1, "Bi-Weekly", category1, patternStartDate, RecurrentPeriod.EveryDay);
      var records = recurrentRecordService.generateRecurrentRecordsFromDateTime(recordPattern, endDate);
      // must happen nothing
      expect(records.length, 0);
    });

    test('recurrent pattern in the future should work when executed in a future date', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      RecurrentRecordService recurrentRecordService = new RecurrentRecordService();
      Category category1 = new Category("testName1");
      DateTime patternStartDate = new DateTime(2020, 10, 1); // date of the start of the pattern
      DateTime endDate = new DateTime(2020, 10, 5); // date of today
      RecurrentRecordPattern recordPattern = RecurrentRecordPattern(1, "Bi-Weekly", category1, patternStartDate, RecurrentPeriod.EveryDay);
      var records = recurrentRecordService.generateRecurrentRecordsFromDateTime(recordPattern, endDate);
      expect(records.length, 5);
    });

    test('generateRecurrentRecordsFromDateTime respects pattern timezone offset (local time)', () {
      // Simulate a pattern created in UTC+3 (offset +180 minutes)
      final patternUtcMillis = DateTime.utc(2025, 6, 1, 12, 0).millisecondsSinceEpoch;
      final timezoneOffsetMinutes = 180; // UTC+3

      // Create pattern's dateTime as local time (UTC + offset)
      final patternDateTime =
      DateTime.fromMillisecondsSinceEpoch(patternUtcMillis, isUtc: true)
          .add(Duration(minutes: timezoneOffsetMinutes));

      final recurrentPattern = RecurrentRecordPattern(
        100.0,
        "Monthly subscription",
        null,
        patternDateTime,
        RecurrentPeriod.EveryMonth,
        id: "pattern1",
      );

      // Device current time is UTC (offset 0) but we simulate endDate as UTC + 0
      final deviceNowUtc = DateTime.utc(2025, 7, 1, 12, 0);

      // Generate records up to deviceNowUtc adjusted to pattern timezone
      // So convert deviceNowUtc to pattern local time:
      final endDateLocal = deviceNowUtc.add(Duration(minutes: timezoneOffsetMinutes));

      // Generate recurrent records using your method
      RecurrentRecordService recurrentRecordService = new RecurrentRecordService();
      var generatedRecords =
      recurrentRecordService.
      generateRecurrentRecordsFromDateTime(recurrentPattern, endDateLocal);

      // Expect at least one record generated on or after patternDateTime (local)
      expect(generatedRecords.isNotEmpty, true);

      // The first generated record should have dateTime on the same year/month/day as patternDateTime,
      // but hour is expected to be 0 (midnight local time)
      final firstGenerated = generatedRecords.first.dateTime;
      final expectedDate = patternDateTime;

      expect(firstGenerated?.year, expectedDate.year);
      expect(firstGenerated?.month, expectedDate.month);
      expect(firstGenerated?.day, expectedDate.day);
      expect(firstGenerated?.hour, 0);        // expect midnight
      expect(firstGenerated?.minute, 0);
      expect(firstGenerated?.second, 0);

      // The next record should be one month after the first (local time, at midnight)
      if (generatedRecords.length > 1) {
        final nextGenerated = generatedRecords[1].dateTime;
        final expectedNextMonth = DateTime(
          expectedDate.year,
          expectedDate.month + 1,
          expectedDate.day,
        );

        expect(nextGenerated?.year, expectedNextMonth.year);
        expect(nextGenerated?.month, expectedNextMonth.month);
        expect(nextGenerated?.day, expectedNextMonth.day);
        expect(nextGenerated?.hour, 0);
        expect(nextGenerated?.minute, 0);
        expect(nextGenerated?.second, 0);
      }
    });

  });
}
