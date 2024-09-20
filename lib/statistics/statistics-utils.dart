import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/statistics/statistics-models.dart';
import "package:collection/collection.dart";

double computeNumberOfMonthsBetweenTwoDates(DateTime from, DateTime to) {
  var apprxSizeOfMonth = 30;
  var numberOfDaysInBetween = from.difference(to).abs().inDays;
  var numberOfMonths = numberOfDaysInBetween / apprxSizeOfMonth;
  return numberOfMonths;
}

double computeNumberOfYearsBetweenTwoDates(DateTime from, DateTime to) {
  var apprxSizeOfYear = 365;
  var numberOfDaysInBetween = from.difference(to).abs().inDays;
  return numberOfDaysInBetween / apprxSizeOfYear;
}

double? computeAverage(DateTime from, DateTime to,
    List<DateTimeSeriesRecord> records, AggregationMethod aggregationMethod) {
  var sumValues = records.fold(0, (dynamic acc, e) => acc + e.value).abs();
  switch (aggregationMethod) {
    case AggregationMethod.DAY:
      return sumValues /
          records
              .length; // divide for each entries (eg. 20), not for each days (30).
    case AggregationMethod.MONTH:
      // Question here is: how much of the month I am covering.
      // If a new month is starting, I don't want the it counts as an entire
      // month when computing the average for each month.
      // For example today is the 2 of March and I have spent nothing yet.
      // And I want to compute the average of expenses per month of 2021.
      // And I don't want that just 2 days of March will have an impact on
      // the average.
      // Idea: instead of dividing the sum per 3 months. I will rather
      // divide the sum per 2 months (January, February) + 2/30 (March).
      // But Am I counting the days with expenses, or all the days.
      // If a count just the days with expenses, how much sense has this ...
      return sumValues / computeNumberOfMonthsBetweenTwoDates(from, to);
    case AggregationMethod.YEAR:
      return sumValues / computeNumberOfYearsBetweenTwoDates(from, to);
    default:
      return sumValues / records.length;
  }
}

DateTime? truncateDateTime(
    DateTime? dateTime, AggregationMethod? aggregationMethod) {
  DateTime? newDateTime;
  switch (aggregationMethod!) {
    case AggregationMethod.DAY:
      newDateTime = new DateTime(dateTime!.year, dateTime.month, dateTime.day);
      break;
    case AggregationMethod.MONTH:
      newDateTime = new DateTime(dateTime!.year, dateTime.month);
      break;
    case AggregationMethod.YEAR:
      newDateTime = new DateTime(dateTime!.year);
      break;
    case AggregationMethod.CUSTOM:
      newDateTime = dateTime;
      break;
  }
  return newDateTime;
}

List<DateTimeSeriesRecord> aggregateRecordsByDate(
    List<Record?> records, AggregationMethod? aggregationMethod) {
  /// Record Day 1: 100 euro Food, 20 euro Food, 30 euro Transport
  /// Record Day 1: 150 euro,
  /// Available grouping: by day, month, year.
  Map<DateTime?, DateTimeSeriesRecord> aggregatedByDay = new Map();
  for (var record in records) {
    DateTime? dateTime = truncateDateTime(record!.dateTime, aggregationMethod);
    aggregatedByDay.update(
        dateTime,
        (tsr) =>
            new DateTimeSeriesRecord(dateTime, tsr.value + record.value!.abs()),
        ifAbsent: () =>
            new DateTimeSeriesRecord(dateTime, record.value!.abs()));
  }
  List<DateTimeSeriesRecord> data = aggregatedByDay.values.toList();
  data.sort((a, b) => a.value.compareTo(b.value));
  return data;
}

List<Record?> aggregateRecordsByDateAndCategory(
    List<Record?> records, AggregationMethod? aggregationMethod) {
  /// Record Day 1: 100 euro Food, 20 euro Food, 30 euro Transport
  /// Record Day 1: 120 euro food, 30 euro transports.
  /// Available grouping: by day, month, year.
  if (aggregationMethod == AggregationMethod.CUSTOM)
    return records; // don't aggregate
  List<Record?> newAggregatedRecords = [];
  Map<DateTime?, List<Record?>> mapDateTimeRecords = groupBy(records,
      (Record? obj) => truncateDateTime(obj!.dateTime, aggregationMethod));
  for (var recordsByDatetime in mapDateTimeRecords.entries) {
    Map<String?, List<Record?>> mapRecordsCategory =
        groupBy(recordsByDatetime.value, (Record? obj) => obj!.category!.name);
    for (var recordsSameDateTimeSameCategory in mapRecordsCategory.entries) {
      Record? aggregatedRecord;
      if (recordsSameDateTimeSameCategory.value.length > 1) {
        Category category = recordsSameDateTimeSameCategory.value[0]!.category!;
        var value = recordsSameDateTimeSameCategory.value.fold(0,
            (dynamic previousValue, element) => previousValue + element!.value);
        aggregatedRecord = new Record(value, category.name, category,
            truncateDateTime(recordsByDatetime.key, aggregationMethod));
        aggregatedRecord.aggregatedValues =
            recordsSameDateTimeSameCategory.value.length;
      } else {
        aggregatedRecord = recordsSameDateTimeSameCategory.value[0];
      }
      newAggregatedRecords.add(aggregatedRecord);
    }
  }
  return newAggregatedRecords;
}
