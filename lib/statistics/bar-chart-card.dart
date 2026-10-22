import 'dart:math';

import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;
import 'package:flutter/material.dart';
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
  final Map<int, String?> walletCurrencyMap;

  BarChartCard(this.from, this.to, this.records, this.aggregationMethod,
      {this.onSelectionChanged,
      this.selectedDate,
      this.walletCurrencyMap = const {}});

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
    // Use shared ChartDateRangeConfig for consistent date range handling
    final config = ChartDateRangeConfig.create(
      widget.aggregationMethod!,
      widget.from,
      widget.to,
    );

    // Restrict to records that fall within the (possibly clamped, e.g. for
    // YEAR aggregation over a very wide range) chart window, so the average
    // line, Y-axis scale, and bars all agree with what the x-axis ticks show.
    final visibleRecords = widget.records
        .where((r) =>
            r != null &&
            !r.dateTime.isBefore(config.start) &&
            !r.dateTime.isAfter(config.end))
        .toList();

    this.aggregatedRecords = aggregateRecordsByDate(visibleRecords,
        widget.aggregationMethod,
        walletCurrencyMap: widget.walletCurrencyMap);

    chartScope = config.scopeLabel;
    ticksListY = _createYTicks(this.aggregatedRecords);

    // Use shared ChartTickGenerator for consistent tick generation
    final tickLabels = ChartTickGenerator.generateTicks(config);
    ticksListX =
        tickLabels.map((label) => charts.TickSpec<String>(label)).toList();

    _chartData = _prepareData(visibleRecords, config);
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

  List<StringSeriesRecord> _prepareData(
      List<Record?> records, ChartDateRangeConfig config) {
    List<DateTimeSeriesRecord> dateTimeSeriesRecords = aggregateRecordsByDate(
        records, widget.aggregationMethod,
        walletCurrencyMap: widget.walletCurrencyMap);
    Map<DateTime?, StringSeriesRecord> aggregatedByDay = new Map();
    for (var d in dateTimeSeriesRecords) {
      DateTime truncated = truncateDateTime(d.time!, widget.aggregationMethod);
      StringSeriesRecord record =
          StringSeriesRecord(truncated, d.value, config.formatter);
      // Use the shared config keys so bars and axis ticks always match.
      record.key = config.getKey(truncated);
      aggregatedByDay.putIfAbsent(truncated, () => record);
    }

    // Add a zero-value placeholder for every period in the range, including
    // trailing periods with no records, so the chart keeps a slot for them.
    DateTime currentStart = config.start;
    while (!currentStart.isAfter(config.end)) {
      DateTime truncated =
          truncateDateTime(currentStart, widget.aggregationMethod);
      if (!aggregatedByDay.containsKey(truncated)) {
        StringSeriesRecord record =
            StringSeriesRecord(currentStart, 0, config.formatter);
        record.key = config.getKey(truncated);
        aggregatedByDay[truncated] = record;
      }
      currentStart = config.advance(currentStart);
    }

    List<StringSeriesRecord> data = aggregatedByDay.values.toList();
    data.sort((a, b) => a.timestamp!.compareTo(b.timestamp!));

    return data;
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
