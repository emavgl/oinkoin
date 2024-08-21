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


  });
}
