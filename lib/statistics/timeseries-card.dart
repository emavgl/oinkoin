import 'package:charts_common/common.dart' as common;
import 'package:charts_flutter/flutter.dart';
import 'package:flutter/material.dart' as fmaterial;
import 'package:piggybank/models/record.dart';
import './i18n/statistics-page.i18n.dart';
import 'package:charts_flutter/src/text_style.dart' as style;
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:charts_flutter/src/text_element.dart' as ChartText;
import 'package:charts_flutter/src/text_style.dart' as ChartStyle;
import 'dart:math';

import 'package:flutter/material.dart';

class TimeSeriesRecord {
  final DateTime time;
  final double dailyValue;

  TimeSeriesRecord(this.time, this.dailyValue);
}

class CustomCircleSymbolRenderer extends CircleSymbolRenderer {
  @override
  void paint(ChartCanvas canvas, Rectangle<num> bounds,
      {List<int> dashPattern,
        Color fillColor,
        FillPatternType fillPattern,
        Color strokeColor,
        double strokeWidthPx}) {
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
        ChartText.TextElement(TimeSeriesCard.pointerValue, style: textStyle),
        (bounds.left).round(),
        (bounds.top - 28).round()
    );
  }
}

class TimeSeriesCard extends StatelessWidget {

  static String pointerValue;
  final List<Record> records;
  List<charts.Series> seriesList;
  List<TickSpec<num>> ticksList;

  TimeSeriesCard(this.records) {
    seriesList = _prepareData(records);
    ticksList = _createTicksList(records);
  }

  List<charts.Series<TimeSeriesRecord, DateTime>> _prepareData(List<Record> records) {
    List<TimeSeriesRecord> data = [];

    records.sort((a, b) => a.dateTime.compareTo(b.dateTime)); // sort descending

    for (var record in records) {
      TimeSeriesRecord timeSerieRecord = new TimeSeriesRecord(record.dateTime, record.value.abs());
      data.add(timeSerieRecord);
    }

    return [
      new charts.Series<TimeSeriesRecord, DateTime>(
        id: 'DailyRecords',
        colorFn: (_, __) => charts.MaterialPalette.blue.shadeDefault,
        domainFn: (TimeSeriesRecord entries, _) => entries.time,
        measureFn: (TimeSeriesRecord entries, _) => entries.dailyValue,
        data: data,
      )
    ];
  }

  bool animate = true;
  static final categoryCount = 5;
  static final palette = charts.MaterialPalette.getOrderedPalettes(categoryCount);

  Widget _buildLineChart() {
    return new Container(
        padding: EdgeInsets.fromLTRB(5, 0, 5, 5),
        child: new charts.TimeSeriesChart(
          seriesList,
          animate: animate,
          dateTimeFactory: const charts.LocalDateTimeFactory(),
          defaultRenderer: new charts.LineRendererConfig(includePoints: true),
          behaviors: [
            charts.LinePointHighlighter(
                symbolRenderer: CustomCircleSymbolRenderer()
            )
          ],
          selectionModels: [
            SelectionModelConfig(
                changedListener: (SelectionModel model) {
                  if (model.hasDatumSelection) {
                    pointerValue = model.selectedSeries[0]
                        .measureFn(model.selectedDatum[0].index)
                        .toString();
                  }
                }
            )
          ],
          domainAxis: new charts.DateTimeAxisSpec(
            tickProviderSpec: charts.DayTickProviderSpec(increments: [(records.length / 3).round() + 1]),
            tickFormatterSpec: new charts.AutoDateTimeTickFormatterSpec(
                day: new charts.TimeFormatterSpec(
                    format: 'd', transitionFormat: 'MM/dd')),
            showAxisLine: false,
          ),
          primaryMeasureAxis: new charts.NumericAxisSpec(
            tickProviderSpec: new charts.StaticNumericTickProviderSpec(
              ticksList
          )),
        )
    );
  }

  Widget _buildCard() {
    return Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
        height: 250,
        child: new Card(
            elevation: 2,
            child: Column(
              children: <Widget>[
                Container(
                    padding: const EdgeInsets.fromLTRB(10, 8, 8, 0),
                    child: Align(
                      alignment: fmaterial.Alignment.centerLeft,
                      child: Text(
                        "Trend in the selected period".i18n,
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

  _createTicksList(List<Record> records) {
    double maxRecord = records.map((e) => e.value.abs()).reduce(max);
    var ticksNumber = [charts.TickSpec<num>(0), charts.TickSpec<num>(50)];
    int maxTick = 50;
    while (maxTick <= maxRecord) {
      maxTick = maxTick * 2;
      ticksNumber.add(charts.TickSpec<num>(maxTick));
    }
    return ticksNumber;
  }
}