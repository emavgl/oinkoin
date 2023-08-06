import 'package:community_charts_common/community_charts_common.dart';
import 'package:community_charts_flutter/community_charts_flutter.dart' as charts;
import 'package:community_charts_flutter/community_charts_flutter.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as fmaterial;
import 'package:intl/intl.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/statistics/statistics-models.dart';
import 'package:piggybank/statistics/statistics-utils.dart';
import './i18n/statistics-page.i18n.dart';
import 'package:community_charts_flutter/src/text_style.dart' as style;
import 'package:community_charts_flutter/src/text_element.dart' as ChartText;
import 'dart:math';

import 'package:flutter/material.dart';


class CustomCircleSymbolRenderer extends CircleSymbolRenderer {
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

    canvas.drawRect(
        Rectangle(bounds.left - 5, bounds.top - 30, bounds.width + 10, bounds.height + 10),
        fill: Color.white
    );
    var textStyle = style.TextStyle();
    textStyle.color = Color.black;
    textStyle.fontSize = 15;
    canvas.drawText(
        ChartText.TextElement(BarChartCard.pointerValue, style: textStyle),
        (bounds.left).round(),
        (bounds.top - 28).round()
    );
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

    // Initialise varibales given the aggregation Method
    DateTime start, end;
    DateFormat dateFormat;
    if (this.aggregationMethod == AggregationMethod.MONTH) {
      dateFormat = DateFormat("MM");
      start = DateTime(records[0]!.dateTime!.year);
      end = DateTime(records[0]!.dateTime!.year + 1);
      chartScope = DateFormat("yyyy").format(start);
    } else {
      dateFormat = DateFormat("dd");
      start = DateTime(records[0]!.dateTime!.year, records[0]!.dateTime!.month);
      end = DateTime(records[0]!.dateTime!.year, records[0]!.dateTime!.month + 1);
      chartScope = DateFormat("yyyy/MM").format(start);
    }

    ticksListY = _createYTicks(this.aggregatedRecords);
    ticksListX = _createXTicks(start, end, dateFormat);
    seriesList = _createStringSeries(records, start, end, dateFormat);

    double sumValues = (this.aggregatedRecords.fold(0, (dynamic acc, e) => acc + e.value)).abs();
    average = sumValues / aggregatedRecords.length;
  }

  List<charts.Series<StringSeriesRecord, String>> _createStringSeries(List<Record?> records, DateTime start, DateTime end, DateFormat formatter) {
    List<DateTimeSeriesRecord> dateTimeSeriesRecords = aggregateRecordsByDate(records, aggregationMethod);
    Map<DateTime?, StringSeriesRecord> aggregatedByDay = new Map();
    for (var d in dateTimeSeriesRecords) {
      aggregatedByDay.putIfAbsent(truncateDateTime(d.time, aggregationMethod), () => StringSeriesRecord(truncateDateTime(d.time, aggregationMethod), d.value, formatter));
    }
    while (start.isBefore(end)) {
      aggregatedByDay.putIfAbsent(truncateDateTime(start, aggregationMethod), () => StringSeriesRecord(start, 0, formatter));
      start = aggregationMethod == AggregationMethod.DAY ? start.add(Duration(days: 1)) : DateTime(start.year, start.month + 1);
    }
    List<StringSeriesRecord> data = aggregatedByDay.values.toList();
    data.sort((a, b) => a.timestamp!.compareTo(b.timestamp!)); // sort descending
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
  static final palette = charts.MaterialPalette.getOrderedPalettes(categoryCount);

  // Draw the graph
  Widget _buildLineChart() {
    return new Container(
        padding: EdgeInsets.fromLTRB(5, 0, 5, 5),
        child: new charts.BarChart(
          seriesList as List<Series<StringSeriesRecord, String>>,
          animate: animate,
          behaviors: [
            charts.LinePointHighlighter(
                symbolRenderer: CustomCircleSymbolRenderer()
            ),
            charts.RangeAnnotation([
              new charts.LineAnnotationSegment(
                  average!, charts.RangeAnnotationAxisType.measure,
                  color: charts.MaterialPalette.gray.shade400,
                  endLabel: 'Average'.i18n) ,
            ]),
          ],
          selectionModels: [
            SelectionModelConfig(
                changedListener: (SelectionModel model) {
                  if (model.hasDatumSelection) {
                    pointerValue = model.selectedSeries[0].labelAccessorFn!(model.selectedDatum[0].index) + ": " + model.selectedSeries[0]
                        .measureFn(model.selectedDatum[0].index)!
                        .toStringAsFixed(2);
                  }
                }
            )
          ],
          domainAxis: new charts.OrdinalAxisSpec(
              tickProviderSpec:
              new charts.StaticOrdinalTickProviderSpec(ticksListX)
          ),
          primaryMeasureAxis: new charts.NumericAxisSpec(
            tickProviderSpec: new charts.StaticNumericTickProviderSpec(
              ticksListY
          )),
        )
    );
  }

  Widget _buildCard() {
    return Container(
        height: 250,
        margin: EdgeInsets.only(top: 10, bottom: 10),
        child: new Card(
            elevation: 0,
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
                    )
                ),
                new Divider(),
                fmaterial.Expanded(child: _buildLineChart(),)
              ],
            )
        )
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildCard();
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

  List<charts.TickSpec<String>> _createXTicks(DateTime start, DateTime end, DateFormat formatter) {
    List<charts.TickSpec<String>> ticks = [];
    while (start.isBefore(end)) {
      ticks.add(charts.TickSpec<String>(formatter.format(start)));
      start = aggregationMethod == AggregationMethod.MONTH ? DateTime(start.year, start.month + 1) : start.add(Duration(days: 3));
    }
    return ticks;
  }
}