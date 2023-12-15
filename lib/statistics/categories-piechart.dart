import 'package:flutter/material.dart';
import 'package:piggybank/models/record.dart';
import 'package:community_charts_flutter/community_charts_flutter.dart' as charts;
import 'package:piggybank/i18n.dart';

class LinearRecord {
  final String? category;
  final double value;

  LinearRecord(this.category, this.value);
}

class CategoriesPieChart extends StatelessWidget {

  final List<Record?> records;
  late List<LinearRecord> linearRecords;
  late List<charts.Series<LinearRecord, String>> seriesList;

  CategoriesPieChart(this.records) {
    seriesList = _prepareData(records);
  }

  List<charts.Series<LinearRecord, String>> _prepareData(List<Record?> records) {
    Map<String, double> aggregatedCategoriesValuesTemporaryMap = new Map();
    double totalSum = 0;
    for (var record in records) {
      totalSum += record!.value!.abs();
      aggregatedCategoriesValuesTemporaryMap.update(
          record.category!.name!, (value) => value + record.value!.abs(),
          ifAbsent: () => record.value!.abs());
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
      var sumOfRemainingCategories = remainingCategoriesAndValue.fold(0, (dynamic value, element) => value + element.value);
      var remainingCategoryKey = "Others".i18n;
      var percentage = (100 * sumOfRemainingCategories) / totalSum;
      var lr = LinearRecord(remainingCategoryKey, percentage);
      data.add(lr);
    }

    linearRecords = data;

    return [
      new charts.Series<LinearRecord, String>(
        id: 'Expenses'.i18n,
        colorFn: (LinearRecord sales, i) =>
          palette[i!].shadeDefault,
        domainFn: (LinearRecord records, _) => records.category!,
        measureFn: (LinearRecord records, _) => records.value,
        labelAccessorFn: (LinearRecord row, _) => row.category!,
        data: data,
      )
    ];
  }

  bool animate = true;
  static final categoryCount = 4;
  static final palette = charts.MaterialPalette.getOrderedPalettes(categoryCount+1);

  Widget _buildPieChart() {
    return new Container(
        child: new charts.PieChart<String>(
          seriesList,
          animate: animate,
          defaultRenderer: new charts.ArcRendererConfig(arcWidth: 35),
        )
    );
  }

  Widget _buildLegend() {
    /// Returns a ListView with all the movements contained in the MovementPerDay object
    return ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: linearRecords.length,
        padding: const EdgeInsets.all(6.0),
        itemBuilder: /*1*/ (context, i) {
          var linearRecord = linearRecords[i];
          var recordColor = palette[i].shadeDefault;
          return Container(
            margin: EdgeInsets.fromLTRB(0, 0, 8, 8),
            child: new Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Flexible(
                  child: Container(
                      margin: EdgeInsets.fromLTRB(0, 0, 4, 0),
                      child: Row(
                        children: <Widget>[
                          Container(
                            child: Container(
                                height: 10,
                                width: 20,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color.fromARGB(recordColor.a, recordColor.r, recordColor.g, recordColor.b),
                                )
                            ),
                          ),
                          Flexible(
                            child: Text(
                                linearRecord.category!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis
                            ),
                          )
                        ],
                      )
                  ),
                ),
                Text(linearRecord.value.toStringAsFixed(2) + " %"),
              ],
            )
          );
        });
  }

  Widget _buildCard() {
    return Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
        height: 200,
        child: new Row(
          children: <Widget>[
            Expanded(child: _buildPieChart()),
            Expanded(child: _buildLegend())
          ],
        )
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildCard();
  }
}