import 'package:piggybank/helpers/datetime-utility-functions.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/models/recurrent-period.dart';
import 'package:piggybank/models/recurrent-record-pattern.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:timezone/timezone.dart' as tz; // Import the timezone package

import 'database/database-interface.dart';
import 'logger.dart';

class RecurrentRecordService {
  static final _logger = Logger.withClass(RecurrentRecordService);

  DatabaseInterface database = ServiceConfig.database;

  List<Record> generateRecurrentRecordsFromDateTime(
      RecurrentRecordPattern recordPattern, DateTime utcEndDate) {
    try {
      _logger.debug(
          'Generating recurrent records for pattern: ${recordPattern.title}');
      final List<Record> newRecurrentRecords = [];

    // 1. Get the TZLocation for the pattern's original timezone
    final tz.Location patternLocation =
        getLocation(recordPattern.timeZoneName!);

    // 2. Convert the start and end dates to TZDateTime objects
    final tz.TZDateTime startDate =
        tz.TZDateTime.from(recordPattern.utcDateTime, patternLocation);

    // Use the pattern's end date if it exists and is before the requested end date
    DateTime effectiveEndDate = utcEndDate;
    if (recordPattern.utcEndDate != null && recordPattern.utcEndDate!.isBefore(utcEndDate)) {
      effectiveEndDate = recordPattern.utcEndDate!;
      _logger.debug('Using pattern end date: ${effectiveEndDate}');
    }

    final tz.TZDateTime endDateTz =
        tz.TZDateTime.from(effectiveEndDate, patternLocation);

    // 3. Determine the last update date in the pattern's timezone
    tz.TZDateTime? lastUpdateTz = recordPattern.utcLastUpdate != null
        ? tz.TZDateTime.from(recordPattern.utcLastUpdate!, patternLocation)
        : null;

    if (lastUpdateTz == null) {
      // If there's no last update, add the initial record.
      final newRecord = Record(
        recordPattern.value,
        recordPattern.title,
        recordPattern.category,
        startDate.toUtc(),
        timeZoneName: patternLocation.name,
        description: recordPattern.description,
        recurrencePatternId: recordPattern.id,
        tags: recordPattern.tags,
      );
      newRecurrentRecords.add(newRecord);
      lastUpdateTz = startDate;
    }

      if (endDateTz.isBefore(lastUpdateTz)) {
        return [];
      }

      // Helper function to add records with a given interval
      void addRecordsByPeriod(int periodValue, {bool isMonth = false}) {
        tz.TZDateTime currentDate = lastUpdateTz!;

        // Store the original day, hour, minute, and second from the pattern's start date.
        // This is crucial for maintaining consistency across DST changes and month-end rollovers.
        final int originalStartDay = recordPattern.localDateTime.day;
        final int originalHour = recordPattern.localDateTime.hour;
        final int originalMinute = recordPattern.localDateTime.minute;
        final int originalSecond = recordPattern.localDateTime.second;

        // Now, calculate and add the subsequent records.
        while (true) {
          tz.TZDateTime nextDate;

          // Calculate the next date.
          if (isMonth) {
            // Get the target year and month after adding the period value.
            int targetYear = currentDate.year;
            int targetMonth = currentDate.month + periodValue;

            if (targetMonth > 12) {
              targetYear += (targetMonth - 1) ~/ 12;
              targetMonth = (targetMonth - 1) % 12 + 1;
            }

            // Create a candidate date using the original start day.
            tz.TZDateTime candidateDate = tz.TZDateTime(
              currentDate.location,
              targetYear,
              targetMonth,
              originalStartDay,
              originalHour,
              originalMinute,
              originalSecond,
            );

            // Explicitly check for a month rollover. If the original day was invalid
            // (e.g., day 30 in February), the new date will be in the next month.
            if (candidateDate.month != targetMonth) {
              // If a rollover occurred, set the date to the last day of the target month.
              nextDate = tz.TZDateTime(
                currentDate.location,
                targetYear,
                targetMonth + 1,
                0,
                originalHour,
                originalMinute,
                originalSecond,
              );
            } else {
              // Otherwise, the candidate date is correct.
              nextDate = candidateDate;
            }
          } else {
            // Logic for non-monthly recurrence, manually incrementing the calendar day
            // to avoid time drift issues caused by Daylight Saving Time (DST) changes.
            nextDate = tz.TZDateTime(
              currentDate.location,
              currentDate.year,
              currentDate.month,
              currentDate.day + periodValue,
              originalHour,
              originalMinute,
              originalSecond,
            );
          }

          // Check if the newly calculated date is within the bounds.
          if (nextDate.isBefore(endDateTz) ||
              nextDate.isAtSameMomentAs(endDateTz)) {
            final newRecord = Record(
              recordPattern.value,
              recordPattern.title,
              recordPattern.category,
              nextDate.toUtc(),
              timeZoneName: patternLocation.name,
              description: recordPattern.description,
              recurrencePatternId: recordPattern.id,
              tags: recordPattern.tags,
            );
            newRecurrentRecords.add(newRecord);
            currentDate = nextDate;
          } else {
            // We've gone past the end date, so stop.
            break;
          }
        }
      }

      switch (recordPattern.recurrentPeriod) {
        case RecurrentPeriod.EveryDay:
          addRecordsByPeriod(1);
          break;
        case RecurrentPeriod.EveryWeek:
          addRecordsByPeriod(7);
          break;
        case RecurrentPeriod.EveryTwoWeeks:
          addRecordsByPeriod(14);
          break;
        case RecurrentPeriod.EveryFourWeeks:
          addRecordsByPeriod(28);
          break;
        case RecurrentPeriod.EveryMonth:
          addRecordsByPeriod(1, isMonth: true);
          break;
        case RecurrentPeriod.EveryThreeMonths:
          addRecordsByPeriod(3, isMonth: true);
          break;
        case RecurrentPeriod.EveryFourMonths:
          addRecordsByPeriod(4, isMonth: true);
          break;
        case RecurrentPeriod.EveryYear:
          addRecordsByPeriod(12, isMonth: true);
          break;
        default:
          break;
      }

      _logger.info(
          'Generated ${newRecurrentRecords.length} recurrent records for: ${recordPattern.title}');
      return newRecurrentRecords;
    } catch (e, st) {
      _logger.handle(e, st,
          'Failed to generate recurrent records for: ${recordPattern.title}');
      rethrow;
    }
  }

  Future<List<Record>> updateRecurrentRecords(DateTime endDate) async {
    try {
      _logger.info('Starting recurrent records update...');
      List<RecurrentRecordPattern> patterns =
          await database.getRecurrentRecordPatterns();

      _logger.debug('Processing ${patterns.length} recurrent patterns');

      // Use end of current day (23:59:59.999) in UTC for splitting past/future records
      final DateTime nowUtc = DateTime.now().toUtc();
      final DateTime endOfToday = DateTime.utc(
        nowUtc.year,
        nowUtc.month,
        nowUtc.day,
        23,
        59,
        59,
        999,
      );

      int totalRecordsAdded = 0;
      List<Record> allFutureRecords = [];

      for (var pattern in patterns) {
        // Generate records up to the specified endDate
        var allRecords = generateRecurrentRecordsFromDateTime(pattern, endDate);

        if (allRecords.isNotEmpty) {
          // Split records into past (up to end of today) and future (after end of today)
          final pastRecords = allRecords
              .where((r) =>
                  r.utcDateTime.isBefore(endOfToday) ||
                  r.utcDateTime.isAtSameMomentAs(endOfToday))
              .toList();

          final futureRecords = allRecords
              .where((r) => r.utcDateTime.isAfter(endOfToday))
              .toList();

          // Mark future records
          for (var record in futureRecords) {
            record.isFutureRecord = true;
          }

          // Add only past records to the database
          if (pastRecords.isNotEmpty) {
            await database.addRecordsInBatch(pastRecords);
            totalRecordsAdded += pastRecords.length;

            // Update the last update date of the pattern with the latest UTC time.
            // We use the UTC time from the last generated past record.
            pattern.utcLastUpdate = pastRecords.last.utcDateTime;
            await database.updateRecordPatternById(pattern.id, pattern);
          }

          // Collect future records to return
          allFutureRecords.addAll(futureRecords);
        }
      }

      _logger.info(
          'Recurrent records update completed: ${totalRecordsAdded} records added to database, ${allFutureRecords.length} future records generated from ${patterns.length} patterns');
      return allFutureRecords;
    } catch (e, st) {
      _logger.handle(e, st, 'Failed to update recurrent records');
      rethrow;
    }
  }
}
