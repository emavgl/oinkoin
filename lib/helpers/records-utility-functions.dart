import 'dart:collection';
import "package:collection/collection.dart";
import 'package:intl/intl.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/models/records-per-day.dart';


List<RecordsPerDay> groupRecordsByDay(List<Record> records) {
  /// Groups the record in days using the object MovementsPerDay.
  /// It returns a list of MovementsPerDay object, containing at least 1 movement.
  var movementsGroups = groupBy(records, (records) => records.date);
  Queue<RecordsPerDay> movementsPerDay = Queue();
  movementsGroups.forEach((k, groupedMovements) {
    if (groupedMovements.isNotEmpty) {
      DateTime groupedDay = groupedMovements[0].dateTime;
      movementsPerDay.addFirst(new RecordsPerDay(groupedDay, records: groupedMovements));
    }
  });
  var movementsDayList = movementsPerDay.toList();
  movementsDayList.sort((b, a) => a.dateTime.compareTo(b.dateTime));
  return movementsDayList;
}

final currencyNumberFormat = new NumberFormat("#######.0#", "en_US");

String getCurrencyValueString(double value) {
  return currencyNumberFormat.format(value);
}

