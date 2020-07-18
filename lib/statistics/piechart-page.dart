import 'package:flutter/material.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/record.dart';
import 'package:charts_flutter/flutter.dart' as charts;

class PieChartPage extends StatefulWidget {

  /// The category page that you can select from the bottom navigation bar.
  /// It contains two tab, showing the categories for expenses and categories
  /// for incomes. It has a single Floating Button that, dependending from which
  /// tab you clicked, it open the EditCategory page passing the selected Category type.

  bool goToEditMovementPage;
  List<Record> records;
  DateTime from;
  DateTime to;
  PieChartPage(this.from, this.to, this.records);


  @override
  PieChartPageState createState() => PieChartPageState();
}

/// Sample linear data type.
class LinearRecord {
  final String category;
  final double value;

  LinearRecord(this.category, this.value);
}

class PieChartPageState extends State<PieChartPage> {

  /// Create series list with one series
  List<charts.Series<LinearRecord, String>> _prepareData(List<Record> records) {
    Map<String, double> aggregatedCategoriesValuesTemporaryMap = new Map();
    double totalSum = 0;
    for (var record in records) {
      totalSum += record.value.abs();
      aggregatedCategoriesValuesTemporaryMap.update(
          record.category.name, (value) => value + record.value.abs(),
          ifAbsent: () => record.value.abs());
    }
    var aggregatedCategoriesAndValues = aggregatedCategoriesValuesTemporaryMap
        .entries.toList();
    aggregatedCategoriesAndValues.sort((a, b) => a.value.compareTo(b.value));

    var limit = aggregatedCategoriesAndValues.length > categoryCount
        ? categoryCount
        : aggregatedCategoriesAndValues.length;
    var topCategoriesAndValue = aggregatedCategoriesAndValues.sublist(0, limit);

    List<LinearRecord> data = [];
    for (var categoryAndValue in topCategoriesAndValue) {
      var percentage = (100 * categoryAndValue.value) / totalSum;
      var lr = LinearRecord(categoryAndValue.key, percentage);
      data.add(lr);
    }

    return [
      new charts.Series<LinearRecord, String>(
        id: 'Expenses',
        colorFn: (LinearRecord sales, i) =>
          palette[i].shadeDefault,
        domainFn: (LinearRecord records, _) => records.category,
        measureFn: (LinearRecord records, _) => records.value,
        labelAccessorFn: (LinearRecord row, _) => row.category,
        data: data,
      )
    ];
  }

  List<charts.Series> seriesList;
  bool animate = true;
  static final palette = charts.MaterialPalette.getOrderedPalettes(categoryCount);
  static final categoryCount = 5;

  @override
  void initState() {
    super.initState();
    palette.shuffle();
    seriesList = _prepareData(widget.records);
  }

  Widget _buildCardPieChart() {
    return Container(
        padding: EdgeInsets.all(10),
        height: 200,
        child: new Card(
            child: new Container(
              padding: EdgeInsets.all(10),
              child: new charts.PieChart(
                  seriesList,
                  animate: animate,

                  // Add the legend behavior to the chart to turn on legends.
                  // This example shows how to optionally show measure and provide a custom
                  // formatter.
                  defaultRenderer: new charts.ArcRendererConfig(arcWidth: 70, arcRendererDecorators: [
                    new charts.ArcLabelDecorator(
                        labelPosition: charts.ArcLabelPosition.outside)
                  ]),
                  behaviors: [
                    new charts.DatumLegend(
                      outsideJustification: charts.OutsideJustification.middleDrawArea,
                      // Positions for "start" and "end" will be left and right respectively
                      // for widgets with a build context that has directionality ltr.
                      // For rtl, "start" and "end" will be right and left respectively.
                      // Since this example has directionality of ltr, the legend is
                      // positioned on the right side of the chart.
                      position: charts.BehaviorPosition.end,
                      // By default, if the position of the chart is on the left or right of
                      // the chart, [horizontalFirst] is set to false. This means that the
                      // legend entries will grow as new rows first instead of a new column.
                      horizontalFirst: false,
                      // This defines the padding around each legend entry.
                      cellPadding: new EdgeInsets.only(right: 4.0, bottom: 4.0),
                      // Set [showMeasures] to true to display measures in series legend.
                      showMeasures: true,
                      // Configure the measure value to be shown by default in the legend.
                      legendDefaultMeasure: charts.LegendDefaultMeasure.firstValue,
                      // Optionally provide a measure formatter to format the measure value.
                      // If none is specified the value is formatted as a decimal.
                      measureFormatter: (num value) {
                        return value == null ? '-' : '${value.toStringAsFixed(2)}%';
                      },
                    ),
                  ],
                )              
            )
        )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
        type: MaterialType.transparency,
        child: new Align(
            alignment: Alignment.topCenter,
            child: _buildCardPieChart()
        )
    );
  }
}