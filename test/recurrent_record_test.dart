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

  });
}
