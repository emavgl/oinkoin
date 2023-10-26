import 'package:piggybank/models/record.dart';
import 'package:piggybank/models/recurrent-period.dart';
import 'package:piggybank/models/recurrent-record-pattern.dart';
import 'package:piggybank/services/service-config.dart';

import 'database/database-interface.dart';

class RecurrentRecordService {

  DatabaseInterface database = ServiceConfig.database;

  List<Record> generateRecurrentRecordsFromDateTime(RecurrentRecordPattern recordPattern, DateTime endDate) {
    // Generate the records based on the recurrent pattern starting from last_updated date
    // If the last_update field is null, it will start from the original date set in the pattern
    // including it to the list of records to generate.
    List<Record> newRecurrentRecords = [];
    DateTime startDateTrimmed = new DateTime(recordPattern.dateTime!.year, recordPattern.dateTime!.month, recordPattern.dateTime!.day);
    DateTime lastUpdateTrimmed = startDateTrimmed;
    if (recordPattern.lastUpdate != null) {
      lastUpdateTrimmed = new DateTime(recordPattern.lastUpdate!.year, recordPattern.lastUpdate!.month, recordPattern.lastUpdate!.day);
    } else {
      DateTime recurrentRecordDate = startDateTrimmed;
      Record newRecord = Record.fromRecurrencePattern(recordPattern, recurrentRecordDate);
      newRecurrentRecords.add(newRecord);
    }
    RecurrentPeriod? recurrentPeriod = recordPattern.recurrentPeriod;
    if (recurrentPeriod == RecurrentPeriod.EveryDay) {
      var numberOfRepetition = endDate.difference(lastUpdateTrimmed).abs().inDays;
      for (int i = 1; i < numberOfRepetition + 1; i++) {
        DateTime recurrentRecordDate = lastUpdateTrimmed.add(new Duration(days: i));
        Record newRecord = Record.fromRecurrencePattern(recordPattern, recurrentRecordDate);
        newRecurrentRecords.add(newRecord);
      }
    }
    else if (recurrentPeriod == RecurrentPeriod.EveryWeek) {
      int numberOfWeeks = (endDate.difference(startDateTrimmed).abs().inDays / 7).floor();
      for (int i = 1; i < numberOfWeeks + 1; i++) {
        DateTime recurrentRecordDate = startDateTrimmed.add(new Duration(days: i*7));
        Record newRecord = Record.fromRecurrencePattern(recordPattern, recurrentRecordDate);
        newRecurrentRecords.add(newRecord);
      }
    }
    else if (recurrentPeriod == RecurrentPeriod.EveryMonth) {
      int counter = 1;
      while (true) {
        DateTime tmpDate = new DateTime(lastUpdateTrimmed.year, lastUpdateTrimmed.month + counter, lastUpdateTrimmed.day);
        if (!tmpDate.isBefore(endDate)) {
          break;
        }
        Record newRecord = Record.fromRecurrencePattern(recordPattern, tmpDate);
        newRecurrentRecords.add(newRecord);
        counter++;
      }
    }
    return newRecurrentRecords;
  }

  Future<void> updateRecurrentRecords() async {
    List<RecurrentRecordPattern> patterns = await database.getRecurrentRecordPatterns();
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