import 'package:piggybank/models/record.dart';
import 'package:piggybank/statistics/statistics-models.dart';
import 'package:piggybank/statistics/statistics-utils.dart';

/// Utility class for calculating statistics from records.
///
/// Provides methods for calculating average and median values
/// based on aggregation periods (day, week, month, year).
class StatisticsCalculator {
  StatisticsCalculator._(); // Private constructor to prevent instantiation

  /// Calculates the average value from records grouped by aggregation period.
  ///
  /// For example, with monthly aggregation, calculates the average of monthly totals.
  ///
  /// Parameters:
  /// - [records]: List of records to calculate from
  /// - [aggregationMethod]: The aggregation method (DAY, WEEK, MONTH, YEAR)
  /// - [from]: Start date of the range
  /// - [to]: End date of the range
  /// - [isBalance]: If true, preserves sign (income positive, expense negative).
  ///                If false, uses absolute values.
  static double calculateAverage(
    List<Record?> records,
    AggregationMethod? aggregationMethod,
    DateTime? from,
    DateTime? to, {
    bool isBalance = false,
  }) {
    final values = _getPeriodValues(
      records,
      aggregationMethod,
      from,
      to,
      isBalance: isBalance,
    );

    if (values.isEmpty) return 0.0;

    final sum = values.fold<double>(0.0, (acc, v) => acc + v);
    return sum / values.length;
  }

  /// Calculates the median value from records grouped by aggregation period.
  ///
  /// For example, with monthly aggregation, calculates the median of monthly totals.
  ///
  /// Parameters:
  /// - [records]: List of records to calculate from
  /// - [aggregationMethod]: The aggregation method (DAY, WEEK, MONTH, YEAR)
  /// - [from]: Start date of the range
  /// - [to]: End date of the range
  /// - [isBalance]: If true, preserves sign (income positive, expense negative).
  ///                If false, uses absolute values.
  static double calculateMedian(
    List<Record?> records,
    AggregationMethod? aggregationMethod,
    DateTime? from,
    DateTime? to, {
    bool isBalance = false,
  }) {
    final values = _getPeriodValues(
      records,
      aggregationMethod,
      from,
      to,
      isBalance: isBalance,
    );

    if (values.isEmpty) return 0.0;

    values.sort();
    final middle = values.length ~/ 2;

    if (values.length % 2 == 0) {
      return (values[middle - 1] + values[middle]) / 2;
    } else {
      return values[middle];
    }
  }

  /// Groups records by aggregation period and sums values for each period.
  ///
  /// Returns a list of period totals. Empty periods are included with value 0.
  static List<double> _getPeriodValues(
    List<Record?> records,
    AggregationMethod? aggregationMethod,
    DateTime? from,
    DateTime? to, {
    required bool isBalance,
  }) {
    // Group records by aggregation period and sum values
    // Use string keys (YYYY-MM-DD) to avoid timezone issues with DateTime objects
    final Map<String, double> periodSums = {};

    String dateKey(DateTime dt) =>
        '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

    for (var record in records) {
      if (record == null) continue;

      final period = truncateDateTime(record.dateTime, aggregationMethod);
      final key = dateKey(period);
      double value = record.value!;

      if (!isBalance) {
        // For non-balance mode, use absolute value
        value = value.abs();
      }

      periodSums[key] = (periodSums[key] ?? 0.0) + value;
    }

    // Include empty periods (0 value) for complete range
    if (aggregationMethod != null && from != null && to != null) {
      final numPeriods = computeNumberOfIntervals(from, to, aggregationMethod);
      var current = from;

      for (var i = 0; i < numPeriods; i++) {
        final period = truncateDateTime(current, aggregationMethod);
        final key = dateKey(period);
        if (!periodSums.containsKey(key)) {
          periodSums[key] = 0.0;
        }
        current =
            getEndOfInterval(current, aggregationMethod).add(Duration(days: 1));
      }
    }

    return periodSums.values.toList();
  }
}
