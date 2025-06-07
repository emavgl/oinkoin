import 'package:piggybank/models/record.dart';
import 'package:piggybank/models/recurrent-period.dart';
import 'package:piggybank/models/recurrent-record-pattern.dart';
import 'package:piggybank/services/service-config.dart';

import 'database/database-interface.dart';

class RecurrentRecordService {
  DatabaseInterface database = ServiceConfig.database;

  // Helper methods, use these resistant to DayLight saving
  DateTime dateAddDays(DateTime origin, int daysToAdd) {
    var temp = DateTime.utc(origin.year, origin.month, origin.day)
        .add(new Duration(days: daysToAdd));
    return DateTime(temp.year, temp.month, temp.day); // Use current timezone
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
    final List<Record> newRecurrentRecords = [];

    // Trim to local midnight
    DateTime _atMidnight(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

    final startDateTrimmed = _atMidnight(recordPattern.dateTime!);
    DateTime lastUpdateTrimmed = recordPattern.lastUpdate != null
        ? _atMidnight(recordPattern.lastUpdate!)
        : startDateTrimmed;

    if (recordPattern.lastUpdate == null) {
      newRecurrentRecords.add(
        Record.fromRecurrencePattern(recordPattern, startDateTrimmed),
      );
    }

    if (difference(endDate, lastUpdateTrimmed).isNegative) {
      return [];
    }

    void addRecordsByDayInterval(int intervalDays) {
      final totalDays = difference(endDate, lastUpdateTrimmed).inDays;
      final count = (totalDays / intervalDays).floor();
      for (int i = 1; i <= count; i++) {
        final nextDate = dateAddDays(lastUpdateTrimmed, i * intervalDays);
        newRecurrentRecords.add(
          Record.fromRecurrencePattern(recordPattern, nextDate),
        );
      }
    }

    void addRecordsByMonthInterval(int monthStep) {
      int counter = monthStep;
      while (true) {
        final nextDate = DateTime(
          lastUpdateTrimmed.year,
          lastUpdateTrimmed.month + counter,
          lastUpdateTrimmed.day,
        );
        if (!nextDate.isBefore(endDate)) break;
        newRecurrentRecords.add(
          Record.fromRecurrencePattern(recordPattern, nextDate),
        );
        counter += monthStep;
      }
    }

    switch (recordPattern.recurrentPeriod) {
      case RecurrentPeriod.EveryDay:
        addRecordsByDayInterval(1);
        break;
      case RecurrentPeriod.EveryWeek:
        addRecordsByDayInterval(7);
        break;
      case RecurrentPeriod.EveryTwoWeeks:
        addRecordsByDayInterval(14);
        break;
      case RecurrentPeriod.EveryMonth:
        addRecordsByMonthInterval(1);
        break;
      case RecurrentPeriod.EveryThreeMonths:
        addRecordsByMonthInterval(3);
        break;
      case RecurrentPeriod.EveryFourMonths:
        addRecordsByMonthInterval(4);
        break;
      case RecurrentPeriod.EveryYear:
        addRecordsByMonthInterval(12);
        break;
      default:
        break;
    }

    return newRecurrentRecords;
  }


  Future<void> updateRecurrentRecords() async {
    List<RecurrentRecordPattern> patterns =
    await database.getRecurrentRecordPatterns();

    for (var pattern in patterns) {
      // Now, adjusted to the local of the pattern origin
      final int offsetMinutes = pattern.timezoneOffset ?? 0;
      final DateTime currentUtc = DateTime.now().toUtc();
      final DateTime currentLocal = currentUtc.add(Duration(minutes: offsetMinutes));

      var records = generateRecurrentRecordsFromDateTime(pattern, currentLocal);

      if (records.isNotEmpty) {
        for (var record in records) {
          await database.addRecord(record);
        }
        pattern.lastUpdate = records.last.dateTime;
        await database.updateRecordPatternById(pattern.id, pattern);
      }
    }
  }

}
