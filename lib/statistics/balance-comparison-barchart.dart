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

class BalanceComparisonBarChart extends StatefulWidget {
  final List<Record?> records;
  final AggregationMethod? aggregationMethod;
  final DateTime? from, to;

  BalanceComparisonBarChart(this.from, this.to, this.records, this.aggregationMethod);

  @override
  _BalanceComparisonBarChartState createState() => _BalanceComparisonBarChartState();
}

class _BalanceComparisonBarChartState extends State<BalanceComparisonBarChart> {
  late List<charts.Series<_ComparisonData, String>> seriesList;
  late List<charts.TickSpec<num>> ticksListY;
  late List<charts.TickSpec<String>> ticksListX;
  late String chartScope;
  late Map<String, _ComparisonData> comparisonDataMap;

  String? _selectedPeriod;
  String? _selectedPeriodKey;
  double? _selectedExpenses;
  double? _selectedIncome;
  late double _totalExpenses;
  late double _totalIncome;

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

    comparisonDataMap = _createComparisonData(widget.records, start, end, dateFormat);
    ticksListY = _createYTicks(comparisonDataMap);
    ticksListX = _createXTicks(start, end, dateFormat);
    seriesList = _createSeries(comparisonDataMap);

    // Calculate totals
    _totalExpenses = 0;
    _totalIncome = 0;
    for (var data in comparisonDataMap.values) {
      _totalExpenses += data.expenses;
      _totalIncome += data.income;
    }
  }

  Map<String, _ComparisonData> _createComparisonData(
      List<Record?> records, DateTime start, DateTime end, DateFormat formatter) {
    Map<String, _ComparisonData> data = {};

    // Initialize all time periods with zero values
    DateTime current = start;
    while (current.isBefore(end)) {
      String key = formatter.format(current);
      data[key] = _ComparisonData(key, current, 0, 0);

      if (widget.aggregationMethod == AggregationMethod.DAY) {
        current = current.add(Duration(days: 1));
      } else if (widget.aggregationMethod == AggregationMethod.MONTH) {
        current = DateTime(current.year, current.month + 1);
      } else if (widget.aggregationMethod == AggregationMethod.YEAR) {
        current = DateTime(current.year + 1);
      }
    }

    // Aggregate records by date
    for (var record in records) {
      DateTime truncated = truncateDateTime(record!.dateTime, widget.aggregationMethod);
      String key = formatter.format(truncated);

      if (data.containsKey(key)) {
        if (record.category!.categoryType == CategoryType.expense) {
          data[key]!.expenses += record.value!.abs();
        } else {
          data[key]!.income += record.value!.abs();
        }
      }
    }

    return data;
  }

  void _onSelectionChanged(charts.SelectionModel model) {
    setState(() {
      // Reset selection if no datum is selected or clicked outside bars
      if (!model.hasDatumSelection) {
        _selectedPeriod = null;
        _selectedPeriodKey = null;
        _selectedExpenses = null;
        _selectedIncome = null;
      } else {
        final selectedDatum = model.selectedDatum.first;
        final data = selectedDatum.datum as _ComparisonData;

        // Reset selection if both expenses and income are 0 (no data)
        if (data.expenses == 0 && data.income == 0) {
          _selectedPeriod = null;
          _selectedPeriodKey = null;
          _selectedExpenses = null;
          _selectedIncome = null;
        } else {
          _selectedPeriod = getDateStr(data.dateTime, aggregationMethod: widget.aggregationMethod);
          _selectedPeriodKey = data.period;
          _selectedExpenses = data.expenses;
          _selectedIncome = data.income;
        }
      }

      // Rebuild series with updated colors
      seriesList = _createSeries(comparisonDataMap);
    });
  }

  Widget _buildSelectionRow() {
    double displayExpenses = _selectedExpenses ?? _totalExpenses;
    double displayIncome = _selectedIncome ?? _totalIncome;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 13,
                    height: 13,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  SizedBox(width: 6),
                  Text(
                    "Expenses".i18n + ": " + getCurrencyValueString(displayExpenses),
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
              SizedBox(height: 2),
              Row(
                children: [
                  Container(
                    width: 13,
                    height: 13,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  SizedBox(width: 6),
                  Text(
                    "Income".i18n + ": " + getCurrencyValueString(displayIncome),
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
          if (_selectedPeriod != null)
            Text(
              _selectedPeriod!,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
        ],
      ),
    );
  }

  List<charts.Series<_ComparisonData, String>> _createSeries(
      Map<String, _ComparisonData> data) {
    var sortedData = data.values.toList();

    return [
      charts.Series<_ComparisonData, String>(
        id: 'Expenses',
        colorFn: (_ComparisonData data, _) {
          if (_selectedPeriodKey == null) {
            return charts.MaterialPalette.red.shadeDefault;
          }
          return data.period == _selectedPeriodKey
              ? charts.MaterialPalette.red.shadeDefault
              : charts.MaterialPalette.red.shadeDefault.lighter.lighter;
        },
        domainFn: (_ComparisonData data, _) => data.period,
        measureFn: (_ComparisonData data, _) => data.expenses,
        data: sortedData,
      ),
      charts.Series<_ComparisonData, String>(
        id: 'Income',
        colorFn: (_ComparisonData data, _) {
          if (_selectedPeriodKey == null) {
            return charts.MaterialPalette.green.shadeDefault;
          }
          return data.period == _selectedPeriodKey
              ? charts.MaterialPalette.green.shadeDefault
              : charts.MaterialPalette.green.shadeDefault.lighter.lighter;
        },
        domainFn: (_ComparisonData data, _) => data.period,
        measureFn: (_ComparisonData data, _) => data.income,
        data: sortedData,
      ),
    ];
  }

  Widget _buildChart(BuildContext context) {
    var isDarkMode = Theme.of(context).brightness == Brightness.dark;
    charts.Color labelAxesColor = isDarkMode ? charts.Color.white : charts.Color.black;
    charts.Color gridLineColor = charts.MaterialPalette.gray.shade400;

    return Container(
        padding: EdgeInsets.fromLTRB(5, 0, 5, 5),
        child: charts.BarChart(
          seriesList,
          animate: true,
          barGroupingType: charts.BarGroupingType.grouped,
          selectionModels: [
            charts.SelectionModelConfig(
              type: charts.SelectionModelType.info,
              changedListener: _onSelectionChanged,
            )
          ],
          domainAxis: charts.OrdinalAxisSpec(
              tickProviderSpec:
                  charts.StaticOrdinalTickProviderSpec(ticksListX),
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
                    "Income vs Expenses in".i18n + " " + chartScope,
                    style: TextStyle(fontSize: 14),
                  ),
                )),
            _buildSelectionRow(),
            Divider(),
            Expanded(
              child: _buildChart(context),
            )
          ],
        ));
  }

  @override
  Widget build(BuildContext context) {
    return _buildCard(context);
  }

  List<charts.TickSpec<num>> _createYTicks(Map<String, _ComparisonData> data) {
    double maxValue = 0;
    for (var entry in data.values) {
      maxValue = max(maxValue, max(entry.expenses, entry.income));
    }

    int maxNumberOfTicks = 4;
    var interval = max(10, (maxValue / (maxNumberOfTicks * 10)).round() * 10);
    List<charts.TickSpec<num>> ticksNumber = [];
    for (double i = 0; i <= maxValue + interval; i = i + interval) {
      ticksNumber.add(charts.TickSpec<num>(i.toInt()));
    }
    return ticksNumber;
  }

  List<charts.TickSpec<String>> _createXTicks(
      DateTime start, DateTime end, DateFormat formatter) {
    List<charts.TickSpec<String>> ticks = [];
    while (start.isBefore(end)) {
      ticks.add(charts.TickSpec(formatter.format(start)));
      if (widget.aggregationMethod == AggregationMethod.DAY) {
        start = start.add(Duration(days: 3)); // Show every 3rd day
      } else if (widget.aggregationMethod == AggregationMethod.MONTH) {
        start = DateTime(start.year, start.month + 1);
      } else if (widget.aggregationMethod == AggregationMethod.YEAR) {
        start = DateTime(start.year + 1);
      }
    }
    return ticks;
  }
}

class _ComparisonData {
  final String period;
  final DateTime dateTime;
  double expenses;
  double income;

  _ComparisonData(this.period, this.dateTime, this.expenses, this.income);
}
