import 'dart:math';

import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;
import 'package:community_charts_flutter/community_charts_flutter.dart';
import 'package:community_charts_flutter/src/text_element.dart' as ChartText;
import 'package:community_charts_flutter/src/text_style.dart' as style;
import 'package:flutter/material.dart' as fmaterial;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:piggybank/i18n.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/statistics/statistics-models.dart';
import 'package:piggybank/statistics/statistics-utils.dart';

class CustomCircleSymbolRenderer extends CircleSymbolRenderer {
  Color textColor = Color.black;
  Color backgroundColor = Color.white;

  CustomCircleSymbolRenderer(bool isDarkMode) {
    textColor = isDarkMode ? Color.white : Color.black;
    backgroundColor = isDarkMode ? Color.black : Color.white;
  }

  @override
  void paint(ChartCanvas canvas, Rectangle<num> bounds,
      {List<int>? dashPattern,
      Color? fillColor,
      FillPatternType? fillPattern,
      Color? strokeColor,
      double? strokeWidthPx}) {
    super.paint(canvas, bounds,
        dashPattern: dashPattern,
        fillColor: fillColor,
        strokeColor: strokeColor,
        strokeWidthPx: strokeWidthPx);

    var textStyle = style.TextStyle();
    textStyle.color = this.textColor;
    textStyle.fontSize = 15;
    canvas.drawText(
        ChartText.TextElement(BarChartCard.pointerValue, style: textStyle),
        (bounds.left - 40).round(),
        (bounds.top - 30).round());
  }
}

class BarChartCard extends StatelessWidget {
  static late String pointerValue;
  final List<Record?> records;
  final AggregationMethod? aggregationMethod;
  final DateTime? from, to;
  late List<DateTimeSeriesRecord> aggregatedRecords;
  late List<charts.Series<StringSeriesRecord, String>> seriesList;
  late List<TickSpec<num>> ticksListY;
  late List<TickSpec<String>> ticksListX;
  AxisSpec? domainAxis;
  late String chartScope;
  double? average;

  BarChartCard(this.from, this.to, this.records, this.aggregationMethod) {
    this.aggregatedRecords = aggregateRecordsByDate(records, aggregationMethod);

    // Initialise variables given the aggregation Method
    DateTime start, end;
    DateFormat dateFormat;
    if (this.aggregationMethod == AggregationMethod.MONTH) {
      dateFormat = DateFormat("MM");
      start = DateTime(from!.year);
      end = DateTime(to!.year + 1);
      chartScope = DateFormat("yyyy").format(start);
    } else if (this.aggregationMethod == AggregationMethod.YEAR) {
      dateFormat = DateFormat("yyyy");
      start = DateTime(from!.year);
      end = DateTime(to!.year + 1);
      chartScope = DateFormat("yyyy").format(start) +
          " - " +
          DateFormat("yyyy").format(DateTime(to!.year));
    } else {
      dateFormat = DateFormat("dd");
      start = DateTime(records[0]!.dateTime!.year, records[0]!.dateTime!.month);
      end =
          DateTime(records[0]!.dateTime!.year, records[0]!.dateTime!.month + 1);
      chartScope = DateFormat("yyyy/MM").format(start);
    }

    ticksListY = _createYTicks(this.aggregatedRecords);
    ticksListX = _createXTicks(start, end, dateFormat);
    seriesList = _createStringSeries(records, start, end, dateFormat);

    double sumValues = (this
        .aggregatedRecords
        .fold(0, (dynamic acc, e) => acc + e.value)).abs();
    average = sumValues / aggregatedRecords.length;
  }

  List<charts.Series<StringSeriesRecord, String>> _createStringSeries(
      List<Record?> records,
      DateTime start,
      DateTime end,
      DateFormat formatter) {
    List<DateTimeSeriesRecord> dateTimeSeriesRecords =
        aggregateRecordsByDate(records, aggregationMethod);
    Map<DateTime?, StringSeriesRecord> aggregatedByDay = new Map();
    for (var d in dateTimeSeriesRecords) {
      aggregatedByDay.putIfAbsent(
          truncateDateTime(d.time!, aggregationMethod),
          () => StringSeriesRecord(truncateDateTime(d.time!, aggregationMethod),
              d.value, formatter));
    }
    while (start.isBefore(end)) {
      aggregatedByDay.putIfAbsent(truncateDateTime(start, aggregationMethod),
          () => StringSeriesRecord(start, 0, formatter));
      // advance start
      if (aggregationMethod == AggregationMethod.DAY) {
        start = start.add(Duration(days: 1));
      } else if (aggregationMethod == AggregationMethod.MONTH) {
        start = DateTime(start.year, start.month + 1);
      } else if (aggregationMethod == AggregationMethod.YEAR) {
        if (start.year == end.year) {
          start = DateTime(start.year + 1, end.month);
        } else {
          start = DateTime(start.year + 1, 12, 31, 23, 59);
        }
      }
    }
    List<StringSeriesRecord> data = aggregatedByDay.values.toList();
    data.sort(
        (a, b) => a.timestamp!.compareTo(b.timestamp!)); // sort descending
    return [
      new charts.Series<StringSeriesRecord, String>(
        id: 'DailyRecords',
        colorFn: (_, __) => charts.MaterialPalette.blue.shadeDefault,
        domainFn: (StringSeriesRecord entries, _) => entries.key!,
        measureFn: (StringSeriesRecord entries, _) => entries.value,
        data: data,
      )
    ];
  }

  bool animate = true;
  static final categoryCount = 5;
  static final palette =
      charts.MaterialPalette.getOrderedPalettes(categoryCount);

  // Draw the graph
  Widget _buildLineChart(BuildContext context) {
    var isDarkMode = Theme.of(context).brightness == Brightness.dark;
    charts.Color labelAxesColor = isDarkMode ? Color.white : Color.black;
    charts.Color gridLineColor = charts.MaterialPalette.gray.shade400;

    return new Container(
        padding: EdgeInsets.fromLTRB(5, 0, 5, 5),
        child: new charts.BarChart(
          seriesList,
          animate: animate,
          behaviors: [
            charts.LinePointHighlighter(
                symbolRenderer: CustomCircleSymbolRenderer(isDarkMode)),
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
            SelectionModelConfig(changedListener: (SelectionModel model) {
              if (model.hasDatumSelection) {
                pointerValue = model.selectedSeries[0]
                        .labelAccessorFn!(model.selectedDatum[0].index) +
                    ": " +
                    model.selectedSeries[0]
                        .measureFn(model.selectedDatum[0].index)!
                        .toStringAsFixed(2);
              }
            })
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
                      color: gridLineColor,
                      thickness: 1)),
              tickProviderSpec:
                  new charts.StaticNumericTickProviderSpec(ticksListY)),
        ));
  }

  Widget _buildCard(BuildContext context) {
    return Container(
        height: 250,
        margin: EdgeInsets.only(top: 10, bottom: 10),
        child: Column(
          children: <Widget>[
            Container(
                padding: const EdgeInsets.fromLTRB(10, 8, 8, 0),
                child: Align(
                  alignment: fmaterial.Alignment.centerLeft,
                  child: Text(
                    "Trend in".i18n + " " + chartScope,
                    style: fmaterial.TextStyle(fontSize: 14),
                  ),
                )),
            new Divider(),
            fmaterial.Expanded(
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
  List<TickSpec<num>> _createYTicks(List<DateTimeSeriesRecord> records) {
    double maxRecord = records.map((e) => e.value.abs()).reduce(max);
    int maxNumberOfTicks = 4;
    var interval = max(10, (maxRecord / (maxNumberOfTicks * 10)).round() * 10);
    List<TickSpec<num>> ticksNumber = [];
    for (double i = 0; i <= maxRecord + interval; i = i + interval) {
      ticksNumber.add(charts.TickSpec<num>(i.toInt()));
    }
    return ticksNumber;
  }

  List<charts.TickSpec<String>> _createXTicks(
      DateTime start, DateTime end, DateFormat formatter) {
    List<charts.TickSpec<String>> ticks = [];
    while (start.isBefore(end)) {
      ticks.add(charts.TickSpec<String>(formatter.format(start)));
      // advance start
      if (aggregationMethod == AggregationMethod.DAY) {
        start = start.add(Duration(days: 3));
      } else if (aggregationMethod == AggregationMethod.MONTH) {
        start = DateTime(start.year, start.month + 1);
      } else if (aggregationMethod == AggregationMethod.YEAR) {
        start = DateTime(start.year + 1, end.month);
      }
    }
    return ticks;
  }
}
