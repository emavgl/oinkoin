import 'package:piggybank/models/record.dart';
import 'package:piggybank/models/recurrent-period.dart';
import 'package:piggybank/models/recurrent-record-pattern.dart';
import 'package:piggybank/services/service-config.dart';

import 'database/database-interface.dart';

class RecurrentRecordService {
  DatabaseInterface database = ServiceConfig.database;

  // Helper methods, use these resistant to DayLight saving
  DateTime dateAddDays(DateTime origin, int daysToAdd) {
    return DateTime.utc(origin.year, origin.month, origin.day)
        .add(new Duration(days: daysToAdd));
  }

  Duration difference(DateTime dateTime1, DateTime dateTime2) {
    DateTime dateTimeUtc1 =
        DateTime.utc(dateTime1.year, dateTime1.month, dateTime1.day);
    DateTime dateTimeUtc2 =
        DateTime.utc(dateTime2.year, dateTime2.month, dateTime2.day);
    return dateTimeUtc1.difference(dateTimeUtc2);
  }

  List<Record> generateRecurrentRecordsFromDateTime(
      RecurrentRecordPattern recordPattern, DateTime endDate) {
    // Generate the records based on the recurrent pattern starting from last_updated date
    // If the last_update field is null, it will start from the original date set in the pattern
    // including it to the list of records to generate.
    List<Record> newRecurrentRecords = [];
    DateTime startDateTrimmed = new DateTime(recordPattern.dateTime!.year,
        recordPattern.dateTime!.month, recordPattern.dateTime!.day);
    DateTime lastUpdateTrimmed = startDateTrimmed;
    if (recordPattern.lastUpdate != null) {
      lastUpdateTrimmed = new DateTime(recordPattern.lastUpdate!.year,
          recordPattern.lastUpdate!.month, recordPattern.lastUpdate!.day);
    } else {
      DateTime recurrentRecordDate = startDateTrimmed;
      Record newRecord =
          Record.fromRecurrencePattern(recordPattern, recurrentRecordDate);
      newRecurrentRecords.add(newRecord);
    }
    RecurrentPeriod? recurrentPeriod = recordPattern.recurrentPeriod;
    // endDate should happen after lastUpdateTrimmed
    // when the pattern is set with a record in the future
    // this is not the case
    if (difference(endDate, lastUpdateTrimmed).isNegative) {
      return [];
    }
    if (recurrentPeriod == RecurrentPeriod.EveryDay) {
      var numberOfRepetition =
          difference(endDate, lastUpdateTrimmed).abs().inDays;
      for (int i = 1; i < numberOfRepetition + 1; i++) {
        DateTime recurrentRecordDate = dateAddDays(lastUpdateTrimmed, i);
        Record newRecord =
            Record.fromRecurrencePattern(recordPattern, recurrentRecordDate);
        newRecurrentRecords.add(newRecord);
      }
    } else if (recurrentPeriod == RecurrentPeriod.EveryWeek) {
      int numberOfWeeks =
          (difference(endDate, lastUpdateTrimmed).abs().inDays / 7).floor();
      for (int i = 1; i < numberOfWeeks + 1; i++) {
        DateTime recurrentRecordDate = dateAddDays(lastUpdateTrimmed, i * 7);
        Record newRecord =
            Record.fromRecurrencePattern(recordPattern, recurrentRecordDate);
        newRecurrentRecords.add(newRecord);
      }
    } else if (recurrentPeriod == RecurrentPeriod.EveryTwoWeeks) {
      int numberOfTwoWeeks =
          (difference(endDate, lastUpdateTrimmed).abs().inDays / 14).floor();
      for (int i = 1; i < numberOfTwoWeeks + 1; i++) {
        DateTime recurrentRecordDate = dateAddDays(lastUpdateTrimmed, i * 14);
        Record newRecord =
            Record.fromRecurrencePattern(recordPattern, recurrentRecordDate);
        newRecurrentRecords.add(newRecord);
      }
    } else {
      int numberOfMonths = 1;
      if (recurrentPeriod == RecurrentPeriod.EveryMonth) {
        numberOfMonths = 1;
      }
      if (recurrentPeriod == RecurrentPeriod.EveryThreeMonths) {
        numberOfMonths = 3;
      }
      if (recurrentPeriod == RecurrentPeriod.EveryFourMonths) {
        numberOfMonths = 4;
      }
      if (recurrentPeriod == RecurrentPeriod.EveryYear) {
        numberOfMonths = 12;
      }
      int counter = numberOfMonths;
      while (true) {
        DateTime tmpDate = new DateTime(lastUpdateTrimmed.year,
            lastUpdateTrimmed.month + counter, lastUpdateTrimmed.day);
        if (!tmpDate.isBefore(endDate)) {
          break;
        }
        Record newRecord = Record.fromRecurrencePattern(recordPattern, tmpDate);
        newRecurrentRecords.add(newRecord);
        counter += numberOfMonths;
      }
    }
    return newRecurrentRecords;
  }

  Future<void> updateRecurrentRecords() async {
    List<RecurrentRecordPattern> patterns =
        await database.getRecurrentRecordPatterns();
    DateTime currentDate = new DateTime.now();
    for (var pattern in patterns) {
      var records = generateRecurrentRecordsFromDateTime(pattern, currentDate);
      if (records.length > 0) {
        for (var record in records) {
          await database.addRecord(record);
        }
        pattern.lastUpdate = records.last.dateTime;
        await database.updateRecordPatternById(pattern.id, pattern);
      }
    }
  }
}
