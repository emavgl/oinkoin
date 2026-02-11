import 'dart:math';
import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/statistics/statistics-models.dart';
import 'package:piggybank/statistics/statistics-utils.dart';

/// Data model for comparison chart entries.
/// Tracks income, expenses, and cumulative savings for a time period.
class ComparisonData {
  final String period;
  final DateTime dateTime;
  double expenses;
  double income;
  double cumulativeSavings = 0;

  ComparisonData(this.period, this.dateTime, this.expenses, this.income);

  /// Returns the net savings (income - expenses) for this period.
  double get netSavings => income - expenses;
}

// ChartDateRangeConfig is now imported from statistics-utils.dart
// and is shared between bar-chart and balance-chart for consistency.

/// Aggregates records by time period for comparison chart display.
class ComparisonDataAggregator {
  final AggregationMethod aggregationMethod;

  ComparisonDataAggregator(this.aggregationMethod);

  /// Aggregates records into comparison data points.
  Map<String, ComparisonData> aggregate(
    List<Record?> records,
    ChartDateRangeConfig config,
  ) {
    final data = <String, ComparisonData>{};

    // Initialize all time periods with zero values
    var current = config.start;
    while (current.isBefore(config.end)) {
      final key = config.getKey(current);
      data[key] = ComparisonData(key, current, 0, 0);
      current = config.advance(current);
    }

    // Aggregate records into periods
    for (var record in records) {
      if (record == null) continue;

      final truncated = truncateDateTime(record.dateTime, aggregationMethod);
      final key = config.getKey(truncated);

      if (data.containsKey(key)) {
        if (record.category?.categoryType == CategoryType.expense) {
          data[key]!.expenses += record.value?.abs() ?? 0;
        } else {
          data[key]!.income += record.value?.abs() ?? 0;
        }
      }
    }

    // Calculate cumulative savings
    _calculateCumulativeSavings(data);

    return data;
  }

  /// Calculates cumulative savings across all periods.
  void _calculateCumulativeSavings(Map<String, ComparisonData> data) {
    final sortedValues = data.values.toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    var runningSum = 0.0;
    for (var item in sortedValues) {
      runningSum += item.netSavings;
      item.cumulativeSavings = runningSum;
    }
  }
}

// ChartTickGenerator for Y-axis is specific to balance chart
// X-axis ticks are generated using the shared ChartTickGenerator from statistics-utils.dart
class BalanceChartTickGenerator {
  final AggregationMethod aggregationMethod;

  BalanceChartTickGenerator(this.aggregationMethod);

  /// Creates Y-axis ticks based on data values.
  List<charts.TickSpec<num>> createYTicks(Map<String, ComparisonData> data) {
    var maxValue = 0.0;
    var minValue = 0.0;

    for (var entry in data.values) {
      final net = entry.netSavings;
      maxValue = max(maxValue,
          max(entry.income, max(entry.expenses, entry.cumulativeSavings)));
      minValue = min(minValue, min(net, entry.cumulativeSavings));
    }

    minValue = min(minValue, 0);
    maxValue = max(maxValue, 0);

    const maxNumberOfTicks = 5;
    final range = maxValue - minValue;
    var interval = max(10, (range / (maxNumberOfTicks * 10)).round() * 10);

    if (interval == 0) interval = 10;

    final ticks = <charts.TickSpec<num>>[];
    final start = (minValue / interval).floor() * interval.toDouble();
    for (var i = start; i <= maxValue + interval; i += interval.toDouble()) {
      ticks.add(charts.TickSpec<num>(i.toInt()));
    }
    return ticks;
  }

  /// Creates X-axis ticks using the shared ChartTickGenerator.
  List<charts.TickSpec<String>> createXTicks(ChartDateRangeConfig config) {
    final labels = ChartTickGenerator.generateTicks(config);
    return labels.map((label) => charts.TickSpec<String>(label)).toList();
  }
}

/// Factory for creating chart series from comparison data.
class BalanceChartSeriesFactory {
  final bool showNetView;
  final String? selectedPeriodKey;

  BalanceChartSeriesFactory({
    required this.showNetView,
    this.selectedPeriodKey,
  });

  /// Creates all series for the balance chart.
  List<charts.Series<ComparisonData, String>> createSeries(
    Map<String, ComparisonData> data,
    bool showCumulativeLine,
  ) {
    final sortedData = data.values.toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    final series = <charts.Series<ComparisonData, String>>[];

    if (showNetView) {
      series.add(_createNetSavingsSeries(sortedData));
    } else {
      series.add(_createExpensesSeries(sortedData));
      series.add(_createIncomeSeries(sortedData));
    }

    if (showCumulativeLine) {
      series.add(_createCumulativeSeries(sortedData));
    }

    return series;
  }

  charts.Series<ComparisonData, String> _createExpensesSeries(
    List<ComparisonData> data,
  ) {
    return charts.Series<ComparisonData, String>(
      id: 'Expenses',
      colorFn: (d, _) => _getSelectedColor(
        d.period == selectedPeriodKey,
        charts.MaterialPalette.red.shadeDefault,
      ),
      domainFn: (d, _) => d.period,
      measureFn: (d, _) => d.expenses,
      data: data,
    );
  }

  charts.Series<ComparisonData, String> _createIncomeSeries(
    List<ComparisonData> data,
  ) {
    return charts.Series<ComparisonData, String>(
      id: 'Income',
      colorFn: (d, _) => _getSelectedColor(
        d.period == selectedPeriodKey,
        charts.MaterialPalette.green.shadeDefault,
      ),
      domainFn: (d, _) => d.period,
      measureFn: (d, _) => d.income,
      data: data,
    );
  }

  charts.Series<ComparisonData, String> _createNetSavingsSeries(
    List<ComparisonData> data,
  ) {
    return charts.Series<ComparisonData, String>(
      id: 'NetSavings',
      colorFn: (d, _) {
        final isPositive = d.netSavings >= 0;
        final baseColor = isPositive
            ? charts.MaterialPalette.green.shadeDefault
            : charts.MaterialPalette.red.shadeDefault;
        return _getSelectedColor(d.period == selectedPeriodKey, baseColor);
      },
      domainFn: (d, _) => d.period,
      measureFn: (d, _) => d.netSavings,
      data: data,
    );
  }

  charts.Series<ComparisonData, String> _createCumulativeSeries(
    List<ComparisonData> data,
  ) {
    return charts.Series<ComparisonData, String>(
      id: 'CumulativeBalance',
      colorFn: (_, __) => charts.MaterialPalette.blue.shadeDefault,
      domainFn: (d, _) => d.period,
      measureFn: (d, _) => d.cumulativeSavings,
      data: data,
    )..setAttribute(charts.rendererIdKey, 'customLine');
  }

  charts.Color _getSelectedColor(bool isSelected, charts.Color baseColor) {
    if (selectedPeriodKey == null || isSelected) {
      return baseColor;
    }
    return baseColor.lighter.lighter;
  }
}
