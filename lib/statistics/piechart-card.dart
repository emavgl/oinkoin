import 'package:flutter/material.dart';
import 'package:piggybank/models/record.dart';
import 'package:charts_flutter/flutter.dart' as charts;
import './i18n/statistics-page.i18n.dart';

class LinearRecord {
  final String category;
  final double value;

  LinearRecord(this.category, this.value);
}

class PieChartCard extends StatelessWidget {

  final List<Record> records;

  PieChartCard(this.records) {
    seriesList = _prepareData(records);
  }

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
    aggregatedCategoriesAndValues.sort((b, a) => a.value.compareTo(b.value)); // sort descending

    var limit = aggregatedCategoriesAndValues.length > categoryCount
        ? categoryCount
        : aggregatedCategoriesAndValues.length;

    var topCategoriesAndValue = aggregatedCategoriesAndValues.sublist(0, limit);

    // add top categories
    List<LinearRecord> data = [];
    for (var categoryAndValue in topCategoriesAndValue) {
      var percentage = (100 * categoryAndValue.value) / totalSum;
      var lr = LinearRecord(categoryAndValue.key, percentage);
      data.add(lr);
    }

    // if visualized categories are less than the total amount of categories
    // aggregated the reaming category as a mock category name "Other"
    if (limit < aggregatedCategoriesAndValues.length) {
      var remainingCategoriesAndValue = aggregatedCategoriesAndValues.sublist(limit);
      var sumOfRemainingCategories = remainingCategoriesAndValue.fold(0, (value, element) => value + element.value);
      var remainingCategoryKey = "Others".i18n;
      var percentage = (100 * sumOfRemainingCategories) / totalSum;
      var lr = LinearRecord(remainingCategoryKey, percentage);
      data.add(lr);
    }

    return [
      new charts.Series<LinearRecord, String>(
        id: 'Expenses'.i18n,
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
  static final categoryCount = 5;
  static final palette = charts.MaterialPalette.getOrderedPalettes(categoryCount);

  Widget _buildCardPieChart() {
    return Container(
        padding: EdgeInsets.all(10),
        height: 200,
        child: new Card(
            elevation: 2,
            child: new Container(
              padding: EdgeInsets.all(10),
              child: new charts.PieChart(
                  seriesList,
                  animate: animate,

                  // Add the legend behavior to the chart to turn on legends.
                  // This example shows how to optionally show measure and provide a custom
                  // formatter.
                  defaultRenderer: new charts.ArcRendererConfig(arcWidth: 35),
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
                      cellPadding: new EdgeInsets.only(right: 20.0, bottom: 10.0),
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
    return _buildCardPieChart();
  }
}