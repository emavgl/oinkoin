import 'dart:math';

import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/statistics/statistics-models.dart';
import 'package:piggybank/statistics/statistics-utils.dart';

import '../i18n.dart';
import '../models/category-type.dart';

class BarChartCard extends StatefulWidget {
  final List<Record?> records;
  final AggregationMethod? aggregationMethod;
  final DateTime? from, to;
  final Function(double?, DateTime?)? onSelectionChanged;
  final DateTime? selectedDate;

  BarChartCard(this.from, this.to, this.records, this.aggregationMethod,
      {this.onSelectionChanged, this.selectedDate});

  @override
  _BarChartCardState createState() => _BarChartCardState();
}

class _BarChartCardState extends State<BarChartCard> {
  late List<DateTimeSeriesRecord> aggregatedRecords;
  late List<charts.Series<StringSeriesRecord, String>> seriesList;
  late List<charts.TickSpec<num>> ticksListY;
  late List<charts.TickSpec<String>> ticksListX;
  late String chartScope;
  double? average;
  int? _selectedIndex;
  late List<StringSeriesRecord> _chartData;

  bool _animate = true;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void didUpdateWidget(BarChartCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.records != oldWidget.records ||
        widget.aggregationMethod != oldWidget.aggregationMethod ||
        widget.from != oldWidget.from ||
        widget.to != oldWidget.to) {
      _animate = true;
      _initializeData();
    }

    if (widget.selectedDate != oldWidget.selectedDate) {
      _animate = false;
      _updateSelectedIndexFromDate();
    }
  }

  void _initializeData() {
    this.aggregatedRecords =
        aggregateRecordsByDate(widget.records, widget.aggregationMethod);

    // Use shared ChartDateRangeConfig for consistent date range handling
    final config = ChartDateRangeConfig.create(
      widget.aggregationMethod!,
      widget.from,
      widget.to,
    );

    chartScope = config.scopeLabel;
    ticksListY = _createYTicks(this.aggregatedRecords);

    // Use shared ChartTickGenerator for consistent tick generation
    final tickLabels = ChartTickGenerator.generateTicks(config);
    ticksListX =
        tickLabels.map((label) => charts.TickSpec<String>(label)).toList();

    _chartData = _prepareData(
        widget.records, config.start, config.end, config.formatter);
    seriesList = _createSeriesList();

    double sumValues = (this
        .aggregatedRecords
        .fold(0.0, (dynamic acc, e) => acc + e.value)).abs();
    average =
        sumValues / (aggregatedRecords.isEmpty ? 1 : aggregatedRecords.length);
    _selectedIndex = null;

    _updateSelectedIndexFromDate();
  }

  void _updateSelectedIndexFromDate() {
    if (widget.selectedDate == null) {
      _selectedIndex = null;
    } else {
      for (int i = 0; i < _chartData.length; i++) {
        if (truncateDateTime(
                _chartData[i].timestamp!, widget.aggregationMethod) ==
            widget.selectedDate) {
          _selectedIndex = i;
          break;
        }
      }
    }
    seriesList = _createSeriesList();
  }

  void _onSelectionChanged(charts.SelectionModel model) {
    setState(() {
      _animate = false;
      if (!model.hasDatumSelection) {
        _selectedIndex = null;
        if (widget.onSelectionChanged != null)
          widget.onSelectionChanged!(null, null);
      } else {
        final selectedDatum = model.selectedDatum.first;
        final data = selectedDatum.datum as StringSeriesRecord;

        if (_selectedIndex == selectedDatum.index) {
          // Toggle off if already selected
          _selectedIndex = null;
          if (widget.onSelectionChanged != null)
            widget.onSelectionChanged!(null, null);
        } else {
          _selectedIndex = selectedDatum.index;
          if (widget.onSelectionChanged != null) {
            widget.onSelectionChanged!(data.value.abs(), data.timestamp);
          }
        }
      }
      seriesList = _createSeriesList();
    });
  }

  List<StringSeriesRecord> _prepareData(List<Record?> records, DateTime start,
      DateTime end, DateFormat formatter) {
    List<DateTimeSeriesRecord> dateTimeSeriesRecords =
        aggregateRecordsByDate(records, widget.aggregationMethod);
    Map<DateTime?, StringSeriesRecord> aggregatedByDay = new Map();
    for (var d in dateTimeSeriesRecords) {
      DateTime truncated = truncateDateTime(d.time!, widget.aggregationMethod);
      StringSeriesRecord record =
          StringSeriesRecord(truncated, d.value, formatter);
      // Ensure the key matches what we use in ticks
      record.key = _generateDataKey(truncated, start, end);
      aggregatedByDay.putIfAbsent(truncated, () => record);
    }

    DateTime currentStart = start;
    while (!currentStart.isAfter(end)) {
      DateTime truncated =
          truncateDateTime(currentStart, widget.aggregationMethod);
      if (!aggregatedByDay.containsKey(truncated)) {
        StringSeriesRecord record =
            StringSeriesRecord(currentStart, 0, formatter);
        record.key = _generateDataKey(truncated, start, end);
        aggregatedByDay[truncated] = record;
      }
      if (widget.aggregationMethod == AggregationMethod.DAY) {
        currentStart = currentStart.add(Duration(days: 1));
      } else if (widget.aggregationMethod == AggregationMethod.WEEK) {
        currentStart = currentStart.add(Duration(days: 7));
      } else if (widget.aggregationMethod == AggregationMethod.MONTH) {
        currentStart = DateTime(currentStart.year, currentStart.month + 1);
      } else if (widget.aggregationMethod == AggregationMethod.YEAR) {
        if (currentStart.year == end.year) {
          currentStart = DateTime(currentStart.year + 1, end.month);
        } else {
          currentStart = DateTime(currentStart.year + 1, 12, 31, 23, 59);
        }
      }
    }

    List<StringSeriesRecord> data = aggregatedByDay.values.toList();
    data.sort((a, b) => a.timestamp!.compareTo(b.timestamp!));

    return data;
  }

  /// Generates a data key that matches the tick labels exactly.
  String _generateDataKey(
      DateTime date, DateTime rangeStart, DateTime rangeEnd) {
    String key;
    if (widget.aggregationMethod == AggregationMethod.WEEK) {
      key = _getWeekLabel(date);
    } else if (widget.aggregationMethod == AggregationMethod.DAY) {
      // For DAY aggregation, match the tick generation logic:
      // Only show month at the start of a month (day 1)
      // Example: 30 March to 3 April -> "30 31 1/4 2 3"
      final bool isMonthStart = date.day == 1;

      key = isMonthStart ? "${date.month}/${date.day}" : "${date.day}";
    } else {
      // For MONTH and YEAR, use the formatter
      key = widget.aggregationMethod == AggregationMethod.MONTH
          ? "${date.month}"
          : "${date.year}";
    }
    return key;
  }

  List<charts.Series<StringSeriesRecord, String>> _createSeriesList() {
    bool allExpenses = widget.records.isNotEmpty &&
        widget.records
            .every((r) => r?.category?.categoryType == CategoryType.expense);
    bool allIncome = widget.records.isNotEmpty &&
        widget.records
            .every((r) => r?.category?.categoryType == CategoryType.income);

    charts.Color baseColor = charts.MaterialPalette.blue.shadeDefault;
    if (allExpenses) baseColor = charts.MaterialPalette.red.shadeDefault;
    if (allIncome) baseColor = charts.MaterialPalette.green.shadeDefault;

    return [
      new charts.Series<StringSeriesRecord, String>(
        id: 'DailyRecords',
        colorFn: (StringSeriesRecord record, int? index) {
          if (_selectedIndex == null || index == _selectedIndex) {
            return baseColor;
          } else {
            return baseColor.lighter.lighter;
          }
        },
        domainFn: (StringSeriesRecord entries, _) => entries.key!,
        measureFn: (StringSeriesRecord entries, _) => entries.value.abs(),
        data: _chartData,
      )
    ];
  }

  String _getWeekLabel(DateTime date) {
    // Get the start of the week and calculate the end day
    int startDay = date.day;
    DateTime weekEnd = date.add(Duration(days: 6));
    // Make sure we don't go beyond the current month
    if (weekEnd.month != date.month) {
      weekEnd = DateTime(date.year, date.month + 1, 0); // Last day of month
    }
    int endDay = weekEnd.day;
    return '$startDay-$endDay';
  }

  bool animate = true;

  // Draw the graph
  Widget _buildLineChart(BuildContext context) {
    var isDarkMode = Theme.of(context).brightness == Brightness.dark;
    charts.Color labelAxesColor =
        isDarkMode ? charts.Color.white : charts.Color.black;
    charts.Color gridLineColor = charts.MaterialPalette.gray.shade400;

    return new Container(
        padding: EdgeInsets.fromLTRB(5, 0, 5, 5),
        child: new charts.BarChart(
          seriesList,
          animate: _animate,
          behaviors: [
            charts.RangeAnnotation([
              new charts.LineAnnotationSegment(
                average!,
                charts.RangeAnnotationAxisType.measure,
                color: labelAxesColor,
                endLabel: 'Average'.i18n,
                labelStyleSpec: new charts.TextStyleSpec(
                    fontSize: 12, // size in Pts.
                    color: labelAxesColor),
              ),
            ], layoutPaintOrder: 100),
          ],
          selectionModels: [
            charts.SelectionModelConfig(
              type: charts.SelectionModelType.info,
              changedListener: _onSelectionChanged,
            )
          ],
          domainAxis: new charts.OrdinalAxisSpec(
              tickProviderSpec:
                  new charts.StaticOrdinalTickProviderSpec(ticksListX),
              renderSpec: new charts.SmallTickRendererSpec(
                  // Tick and Label styling here.
                  labelStyle: new charts.TextStyleSpec(
                      fontSize: 14, // size in Pts.
                      color: labelAxesColor),

                  // Change the line colors to match text color.
                  lineStyle: new charts.LineStyleSpec(color: labelAxesColor))),
          primaryMeasureAxis: new charts.NumericAxisSpec(
              renderSpec: new charts.GridlineRendererSpec(
                  // Tick and Label styling here.
                  labelStyle: new charts.TextStyleSpec(
                      fontSize: 14, // size in Pts.
                      color: labelAxesColor),

                  // Change the line colors to match text color with grid lines
                  lineStyle: new charts.LineStyleSpec(
                      color: gridLineColor, thickness: 1)),
              tickProviderSpec:
                  new charts.StaticNumericTickProviderSpec(ticksListY)),
        ));
  }

  Widget _buildCard(BuildContext context) {
    return Container(
        height: 250,
        child: Column(
          children: <Widget>[
            Expanded(
              child: _buildLineChart(context),
            )
          ],
        ));
  }

  @override
  Widget build(BuildContext context) {
    return _buildCard(context);
  }

  // Ticks creation utils
  List<charts.TickSpec<num>> _createYTicks(List<DateTimeSeriesRecord> records) {
    if (records.isEmpty) {
      return [charts.TickSpec<num>(0)];
    }

    double maxRecord = records.map((e) => e.value.abs()).reduce(max);
    int maxNumberOfTicks = 4;
    var interval = max(10, (maxRecord / (maxNumberOfTicks * 10)).round() * 10);
    List<charts.TickSpec<num>> ticksNumber = [];
    for (double i = 0; i <= maxRecord + interval; i = i + interval) {
      ticksNumber.add(charts.TickSpec<num>(i.toInt()));
    }
    return ticksNumber;
  }
}
