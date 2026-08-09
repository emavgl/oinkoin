import 'package:piggybank/models/record.dart';
import 'package:piggybank/statistics/statistics-models.dart';
import 'package:piggybank/statistics/statistics-utils.dart';

/// Utility class for calculating statistics from records.
///
/// Provides methods for calculating average and median values
/// based on aggregation periods (day, week, month, year).
class StatisticsCalculator {
  StatisticsCalculator._(); // Private constructor to prevent instantiation

  /// Calculates daily average: total spending / number of days in range.
  ///
  /// This is used for WEEK aggregation to show a more intuitive "per day" average
  /// instead of the artificial week-bin average.
  ///
  /// Parameters:
  /// - [records]: List of records to calculate from
  /// - [from]: Start date of the range
  /// - [to]: End date of the range
  /// - [isBalance]: If true, preserves sign (income positive, expense negative).
  ///                If false, the magnitude of the raw sum is used
  ///                (`abs(sum(raw values))`), so refunds net out correctly.
  static double calculateDailyAverage(
    List<Record?> records,
    DateTime? from,
    DateTime? to, {
    bool isBalance = false,
  }) {
    if (records.isEmpty || from == null || to == null) return 0.0;

    // Sum all record values
    double total = 0.0;
    for (var record in records) {
      if (record == null) continue;
      total += record.value!;
    }
    if (!isBalance) {
      total = total.abs();
    }

    // Divide by number of days
    int days = computeNumberOfDays(from, to);
    return days > 0 ? total / days : 0.0;
  }

  /// Calculates daily median: median of daily spending values (excluding zeros).
  ///
  /// This is used for WEEK aggregation to show a "per day" median that excludes
  /// days with no spending, giving a more useful metric than including all zeros.
  ///
  /// Parameters:
  /// - [records]: List of records to calculate from
  /// - [from]: Start date of the range
  /// - [to]: End date of the range
  /// - [isBalance]: If true, preserves sign (income positive, expense negative).
  ///                If false, the magnitude of each day's raw sum is used.
  static double calculateDailyMedian(
    List<Record?> records,
    DateTime? from,
    DateTime? to, {
    bool isBalance = false,
  }) {
    if (records.isEmpty || from == null || to == null) return 0.0;

    // Get daily values
    final dailyValues = _getPeriodValues(
      records,
      AggregationMethod.DAY,
      from,
      to,
      isBalance: isBalance,
    );

    // Filter out zero values
    final nonZeroValues = dailyValues
        .where((v) => v != 0.0)
        .map((v) => isBalance ? v : v.abs())
        .toList();

    if (nonZeroValues.isEmpty) return 0.0;

    // Calculate median of non-zero values
    nonZeroValues.sort();
    final middle = nonZeroValues.length ~/ 2;

    if (nonZeroValues.length % 2 == 0) {
      return (nonZeroValues[middle - 1] + nonZeroValues[middle]) / 2;
    } else {
      return nonZeroValues[middle];
    }
  }

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
  ///                If false, the magnitude of the raw sum is used.
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
    if (!isBalance) return sum.abs() / values.length;
    return sum / values.length;
  }

  /// Calculates the median value from records grouped by aggregation period.
  ///
  /// For example, with monthly aggregation, calculates the median of monthly totals.
  /// Zero values are excluded by default to provide a more meaningful metric that
  /// represents typical spending periods rather than all periods.
  ///
  /// Parameters:
  /// - [records]: List of records to calculate from
  /// - [aggregationMethod]: The aggregation method (DAY, WEEK, MONTH, YEAR)
  /// - [from]: Start date of the range
  /// - [to]: End date of the range
  /// - [isBalance]: If true, preserves sign (income positive, expense negative).
  ///                If false, the magnitude of each period's raw sum is used.
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

    // Filter out zero values for more meaningful median
    final nonZeroValues = values
        .where((v) => v != 0.0)
        .map((v) => isBalance ? v : v.abs())
        .toList();

    if (nonZeroValues.isEmpty) return 0.0;

    // Calculate median of non-zero values
    nonZeroValues.sort();
    final middle = nonZeroValues.length ~/ 2;

    if (nonZeroValues.length % 2 == 0) {
      return (nonZeroValues[middle - 1] + nonZeroValues[middle]) / 2;
    } else {
      return nonZeroValues[middle];
    }
  }

  /// Groups records by aggregation period and sums their raw (signed) values
  /// for each period.
  ///
  /// Returns a list of period totals. Empty periods are included with value 0.
  /// The [isBalance] flag is passed through for the median helpers to decide
  /// whether to preserve signs (balance) or take magnitudes of each period
  /// total.
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
      periodSums[key] = (periodSums[key] ?? 0.0) + record.value!;
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
