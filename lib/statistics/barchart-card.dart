import 'package:flutter/material.dart';
import 'package:piggybank/models/record.dart';
import 'package:charts_flutter/flutter.dart' as charts;

class TimeSeriesRecord {
  final DateTime time;
  final double dailyValue;

  TimeSeriesRecord(this.time, this.dailyValue);
}

class BarChartCard extends StatelessWidget {
  final List<Record> records;
  List<charts.Series> seriesList;

  BarChartCard(this.records) {
    seriesList = _prepareData(records);
  }

  List<charts.Series<TimeSeriesRecord, DateTime>> _prepareData(
      List<Record> records) {


    List<TimeSeriesRecord> data = [];
    for (var record in records) {
      TimeSeriesRecord timeSerieRecord =
          new TimeSeriesRecord(record.dateTime, record.value.abs());
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
  static final palette =
      charts.MaterialPalette.getOrderedPalettes(categoryCount);

  Widget _buildPieChart() {
    return new Container(
        child: new charts.TimeSeriesChart(
            seriesList,
            animate: animate,
            // Set the default renderer to a bar renderer.
            // This can also be one of the custom renderers of the time series chart.
            defaultRenderer: new charts.BarRendererConfig<DateTime>(),
            // It is recommended that default interactions be turned off if using bar
            // renderer, because the line point highlighter is the default for time
            // series chart.
            defaultInteractions: false,
            // If default interactions were removed, optionally add select nearest
            // and the domain highlighter that are typical for bar charts.
            behaviors: [new charts.SelectNearest(), new charts.DomainHighlighter()],
            domainAxis: new charts.DateTimeAxisSpec(
              tickProviderSpec: charts.DayTickProviderSpec(increments: [(records.length / 3).round() + 1]),
              tickFormatterSpec: new charts.AutoDateTimeTickFormatterSpec(
                  day: new charts.TimeFormatterSpec(
                      format: 'd', transitionFormat: 'MM/dd')),
              showAxisLine: false,
              renderSpec: charts.SmallTickRendererSpec(labelRotation: 60)
            ),
    ));
  }

  Widget _buildCard() {
    return Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
        height: 200,
        child: new Card(elevation: 2, child: _buildPieChart()));
  }

  @override
  Widget build(BuildContext context) {
    return _buildCard();
  }
}
