import 'dart:math';
import 'package:community_charts_flutter/community_charts_flutter.dart' as charts;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:piggybank/i18n.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/statistics/statistics-models.dart';
import 'package:piggybank/statistics/statistics-utils.dart';

import '../helpers/datetime-utility-functions.dart';
import '../helpers/records-utility-functions.dart';

class BalanceBarChartCard extends StatefulWidget {
  final List<Record?> records;
  final AggregationMethod? aggregationMethod;
  final DateTime? from, to;

  BalanceBarChartCard(this.from, this.to, this.records, this.aggregationMethod);

  @override
  _BalanceBarChartCardState createState() => _BalanceBarChartCardState();
}

class _BalanceBarChartCardState extends State<BalanceBarChartCard> {
  late List<charts.Series<DateTimeSeriesRecord, DateTime>> seriesList;
  late List<charts.TickSpec<num>> ticksListY;
  late List<charts.TickSpec<DateTime>> ticksListX;
  late String chartScope;
  double? average;
  String? _selectedDate;
  double? _selectedBalance;
  late double _totalBalance;
  int? _selectedIndex;
  late bool _hasNegativeValues;

  @override
  void initState() {
    super.initState();
    _initializeChartData();
  }

  void _initializeChartData() {
    DateTime start, end;
    DateFormat dateFormat;

    if (widget.aggregationMethod == AggregationMethod.MONTH) {
      dateFormat = DateFormat("MM");
      start = DateTime(widget.from!.year);
      end = DateTime(widget.to!.year + 1);
      chartScope = DateFormat("yyyy").format(start);
    } else if (widget.aggregationMethod == AggregationMethod.YEAR) {
      dateFormat = DateFormat("yyyy");
      start = DateTime(widget.from!.year);
      end = DateTime(widget.to!.year + 1);
      chartScope = DateFormat("yyyy").format(start) +
          " - " +
          DateFormat("yyyy").format(DateTime(widget.to!.year));
    } else {
      dateFormat = DateFormat("dd");
      start = DateTime(widget.from!.year, widget.from!.month);
      end = DateTime(widget.from!.year, widget.from!.month + 1);
      chartScope = DateFormat("yyyy/MM").format(start);
    }

    var balanceRecords = _createBalanceRecords(widget.records, start, end, dateFormat);
    ticksListY = _createYTicks(balanceRecords);
    ticksListX = _createXTicks(start, end);
    seriesList = _createTimeSeries(balanceRecords);

    double sumValues = balanceRecords.fold(0.0, (sum, record) => sum + record.value);
    average = balanceRecords.isNotEmpty ? sumValues / balanceRecords.length : 0;
    _totalBalance = sumValues;

    // Check if there are any negative values
    _hasNegativeValues = balanceRecords.any((record) => record.value < 0);
  }

  List<DateTimeSeriesRecord> _createBalanceRecords(
      List<Record?> records, DateTime start, DateTime end, DateFormat formatter) {
    Map<DateTime?, DateTimeSeriesRecord> aggregatedByDate = {};

    for (var record in records) {
      DateTime? dateTime = truncateDateTime(record!.dateTime, widget.aggregationMethod);
      double value = record.category!.categoryType == CategoryType.income
          ? record.value!.abs()
          : -record.value!.abs();

      aggregatedByDate.update(
          dateTime,
          (tsr) => DateTimeSeriesRecord(dateTime, tsr.value + value),
          ifAbsent: () => DateTimeSeriesRecord(dateTime, value));
    }

    // Fill missing dates with zero balance
    DateTime current = start;
    while (current.isBefore(end)) {
      DateTime truncated = truncateDateTime(current, widget.aggregationMethod);
      aggregatedByDate.putIfAbsent(truncated, () => DateTimeSeriesRecord(truncated, 0));

      if (widget.aggregationMethod == AggregationMethod.DAY) {
        current = current.add(Duration(days: 1));
      } else if (widget.aggregationMethod == AggregationMethod.MONTH) {
        current = DateTime(current.year, current.month + 1);
      } else if (widget.aggregationMethod == AggregationMethod.YEAR) {
        current = DateTime(current.year + 1);
      }
    }

    List<DateTimeSeriesRecord> data = aggregatedByDate.values.toList();
    data.sort((a, b) => a.time!.compareTo(b.time!));
    return data;
  }

  List<charts.Series<DateTimeSeriesRecord, DateTime>> _createTimeSeries(
      List<DateTimeSeriesRecord> balanceRecords) {
    return [
      charts.Series<DateTimeSeriesRecord, DateTime>(
        id: 'Balance',
        colorFn: (DateTimeSeriesRecord record, int? index) {
          // If nothing is selected, all bars are normal color
          if (_selectedIndex == null) {
            return charts.MaterialPalette.blue.shadeDefault;
          }
          // If this bar is selected, use normal color, otherwise use lighter blue
          if (index == _selectedIndex) {
            return charts.MaterialPalette.blue.shadeDefault;
          } else {
            return charts.MaterialPalette.blue.shadeDefault.lighter.lighter;
          }
        },
        domainFn: (DateTimeSeriesRecord record, _) => record.time!,
        measureFn: (DateTimeSeriesRecord record, _) => record.value,
        data: balanceRecords,
      )
    ];
  }

  void _onSelectionChanged(charts.SelectionModel model) {
    setState(() {
      // Reset selection if no datum is selected or clicked outside bars
      if (!model.hasDatumSelection) {
        _selectedDate = null;
        _selectedBalance = null;
        _selectedIndex = null;
      } else {
        final selectedDatum = model.selectedDatum.first;
        final data = selectedDatum.datum as DateTimeSeriesRecord;

        // Reset selection if balance is 0 (no data)
        if (data.value == 0) {
          _selectedDate = null;
          _selectedBalance = null;
          _selectedIndex = null;
        } else {
          _selectedDate = getDateStr(data.time, aggregationMethod: widget.aggregationMethod);
          _selectedBalance = data.value;
          _selectedIndex = selectedDatum.index;
        }
      }

      // Rebuild series with updated colors
      var balanceRecords = seriesList[0].data;
      seriesList = _createTimeSeries(balanceRecords);
    });
  }

  Widget _buildSelectionRow() {
    double displayBalance = _selectedBalance ?? _totalBalance;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Balance".i18n + ": " + getCurrencyValueString(displayBalance),
            style: TextStyle(fontSize: 13),
          ),
          if (_selectedDate != null)
            Text(
              _selectedDate!,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
        ],
      ),
    );
  }

  Widget _buildLineChart(BuildContext context) {
    var isDarkMode = Theme.of(context).brightness == Brightness.dark;
    charts.Color labelAxesColor = isDarkMode ? charts.Color.white : charts.Color.black;
    charts.Color gridLineColor = charts.MaterialPalette.gray.shade400;

    // Build behaviors list conditionally
    List<charts.ChartBehavior<DateTime>> behaviors = [];

    // Add zero line if there are negative values
    if (_hasNegativeValues) {
      behaviors.add(charts.RangeAnnotation<DateTime>([
        charts.LineAnnotationSegment(
          0,
          charts.RangeAnnotationAxisType.measure,
          color: labelAxesColor,
          strokeWidthPx: 2,
        ),
      ], layoutPaintOrder: 100));
    }

    return Container(
        padding: EdgeInsets.fromLTRB(5, 0, 5, 5),
        child: charts.TimeSeriesChart(
          seriesList,
          animate: true,
          defaultRenderer: charts.BarRendererConfig<DateTime>(),
          behaviors: behaviors,
          selectionModels: [
            charts.SelectionModelConfig(
              type: charts.SelectionModelType.info,
              changedListener: _onSelectionChanged,
            )
          ],
          domainAxis: charts.DateTimeAxisSpec(
              tickProviderSpec:
                  charts.StaticDateTimeTickProviderSpec(ticksListX),
              renderSpec: charts.SmallTickRendererSpec(
                  labelStyle: charts.TextStyleSpec(
                      fontSize: 14, color: labelAxesColor),
                  lineStyle: charts.LineStyleSpec(color: labelAxesColor))),
          primaryMeasureAxis: charts.NumericAxisSpec(
              renderSpec: charts.GridlineRendererSpec(
                  labelStyle: charts.TextStyleSpec(
                      fontSize: 14, color: labelAxesColor),
                  lineStyle: charts.LineStyleSpec(
                      color: gridLineColor,
                      thickness: 1)),
              tickProviderSpec:
                  charts.StaticNumericTickProviderSpec(ticksListY)),
        ));
  }

  Widget _buildCard(BuildContext context) {
    return Container(
        height: 320,
        margin: EdgeInsets.only(top: 10, bottom: 10),
        child: Column(
          children: <Widget>[
            Container(
                padding: const EdgeInsets.fromLTRB(10, 8, 8, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Balance Trend in".i18n + " " + chartScope,
                    style: TextStyle(fontSize: 14),
                  ),
                )),
            _buildSelectionRow(),
            Divider(),
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

  List<charts.TickSpec<DateTime>> _createXTicks(DateTime start, DateTime end) {
      List<charts.TickSpec<DateTime>> ticks = [];
      DateTime current = start;
      while (current.isBefore(end)) {
        ticks.add(charts.TickSpec(current));
        if (widget.aggregationMethod == AggregationMethod.DAY) {
            current = current.add(Duration(days: 3));
        } else if (widget.aggregationMethod == AggregationMethod.MONTH) {
            current = DateTime(current.year, current.month + 1);
        } else if (widget.aggregationMethod == AggregationMethod.YEAR) {
            current = DateTime(current.year + 1);
        }
      }
      return ticks;
  }

  List<charts.TickSpec<num>> _createYTicks(List<DateTimeSeriesRecord> records) {
    if (records.isEmpty) {
      return [charts.TickSpec<num>(0)];
    }

    double minValue = records.map((e) => e.value).reduce(min);
    double maxValue = records.map((e) => e.value).reduce(max);

    // Ensure we include zero
    minValue = min(minValue, 0);
    maxValue = max(maxValue, 0);

    int maxNumberOfTicks = 5;
    var range = maxValue - minValue;
    var interval = max(10, (range / (maxNumberOfTicks * 10)).round() * 10);

    List<charts.TickSpec<num>> ticksNumber = [];
    double start = (minValue / interval).floor() * interval.toDouble();
    for (double i = start; i <= maxValue + interval; i = i + interval.toDouble()) {
      ticksNumber.add(charts.TickSpec<num>(i.toInt()));
    }
    return ticksNumber;
  }

}
