import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/statistics/statistics-models.dart';
import "package:collection/collection.dart";

DateTime truncateDateTime(DateTime dateTime, AggregationMethod aggregationMethod) {
  DateTime newDateTime;
  switch (aggregationMethod) {
    case AggregationMethod.DAY:
      newDateTime = new DateTime(dateTime.year, dateTime.month, dateTime.day);
      break;
    case AggregationMethod.MONTH:
      newDateTime = new DateTime(dateTime.year, dateTime.month);
      break;
    case AggregationMethod.YEAR:
      newDateTime = new DateTime(dateTime.year);
      break;
    case AggregationMethod.CUSTOM:
      newDateTime = dateTime;
      break;
  }
  return newDateTime;
}

List<DateTimeSeriesRecord> aggregateRecordsByDate(List<Record> records, AggregationMethod aggregationMethod) {
  /// Record Day 1: 100 euro Food, 20 euro Food, 30 euro Transports
  /// Record Day 1: 150 euro,
  /// Available grouping: by day, month, year.
  Map<DateTime, DateTimeSeriesRecord> aggregatedByDay = new Map();
  for (var record in records) {
    DateTime dateTime = truncateDateTime(record.dateTime, aggregationMethod);
    aggregatedByDay.update(
        dateTime,
            (tsr) => new DateTimeSeriesRecord(dateTime, tsr.value + record.value.abs()),
        ifAbsent: () => new DateTimeSeriesRecord(dateTime, record.value.abs()));
  }
  List<DateTimeSeriesRecord> data = aggregatedByDay.values.toList();
  data.sort((a, b) => a.value.compareTo(b.value));
  return data;
}

List<Record> aggregateRecordsByDateAndCategory(List<Record> records, AggregationMethod aggregationMethod) {
  /// Record Day 1: 100 euro Food, 20 euro Food, 30 euro Transports
  /// Record Day 1: 120 euro food, 30 euro transports.
  /// Available grouping: by day, month, year.
  if (aggregationMethod == AggregationMethod.CUSTOM) return records; // don't aggregate
  List<Record> newAggregatedRecords = [];
  Map<DateTime, List<Record>> mapDateTimeRecords = groupBy(
      records, (Record obj) => truncateDateTime(obj.dateTime, aggregationMethod));
  for (var recordsByDatetime in mapDateTimeRecords.entries) {
    Map<String, List<Record>> mapRecordsCategory = groupBy(
        recordsByDatetime.value, (Record obj) => obj.category.name);
    for (var recordsSameDateTimeSameCategory in mapRecordsCategory
        .entries) {
      Record aggregatedRecord;
      if (recordsSameDateTimeSameCategory.value.length > 1) {
        Category category = recordsSameDateTimeSameCategory.value[0].category;
        var value = recordsSameDateTimeSameCategory.value.fold(
            0, (previousValue, element) => previousValue +
            element.value);
        aggregatedRecord = new Record(
            value, category.name, category, truncateDateTime(recordsByDatetime.key, aggregationMethod));
        aggregatedRecord.aggregatedValues = recordsSameDateTimeSameCategory.value.length;
      } else {
        aggregatedRecord = recordsSameDateTimeSameCategory.value[0];
      }
      newAggregatedRecords.add(aggregatedRecord);
    }
  }  return newAggregatedRecords;
}