import 'package:flutter/material.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/record.dart';
import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;
import 'package:piggybank/i18n.dart';

import '../services/service-config.dart';
import '../settings/constants/preferences-keys.dart';
import '../settings/preferences-utils.dart';

class LinearRecord {
  final String? category;
  final double value;

  LinearRecord(this.category, this.value);
}

class ChartData {
  final List<charts.Series<LinearRecord, String>> series;
  final List<charts.Color> colors;

  ChartData(this.series, this.colors);
}

class CategoriesPieChart extends StatelessWidget {
  final List<Record?> records;
  late final List<LinearRecord> linearRecords;
  late final List<charts.Series<LinearRecord, String>> seriesList;

  final bool animate = true;
  final Color otherCategoryColor = Colors.blueGrey;
  static final categoryCount = 4;
  static final defaultColorsPalette =
    charts.MaterialPalette.getOrderedPalettes(categoryCount + 1)
        .map((palette) => palette.shadeDefault).toList();
  late final colorPalette;

  CategoriesPieChart(this.records) {
    ChartData chartData = _prepareData(records);
    seriesList = chartData.series;
    colorPalette = chartData.colors;
  }

  ChartData _prepareData(List<Record?> records) {
    Map<Category, double> aggregatedCategoriesValuesTemporaryMap = {};
    double totalSum = 0;

    for (var record in records) {
      totalSum += record!.value!.abs();
      aggregatedCategoriesValuesTemporaryMap.update(
        record.category!,
        (value) => value + record.value!.abs(),
        ifAbsent: () => record.value!.abs(),
      );
    }

    var aggregatedCategoriesAndValues =
        aggregatedCategoriesValuesTemporaryMap.entries.toList();
    aggregatedCategoriesAndValues.sort((b, a) => a.value.compareTo(b.value));

    var limit =
        aggregatedCategoriesAndValues.length > categoryCount + 1
            ? categoryCount
            : aggregatedCategoriesAndValues.length;

    var topCategoriesAndValue = aggregatedCategoriesAndValues.sublist(0, limit);

    // Store data and colors
    List<LinearRecord> data = [];
    List<Color> linearRecordsColors = [];

    for (var categoryAndValue in topCategoriesAndValue) {
      var percentage = (100 * categoryAndValue.value) / totalSum;
      var lr = LinearRecord(categoryAndValue.key.name!, percentage);
      data.add(lr);
      linearRecordsColors.add(categoryAndValue.key.color!);
    }

    // Handle "Others" category
    if (limit < aggregatedCategoriesAndValues.length) {
      var remainingCategoriesAndValue = aggregatedCategoriesAndValues.sublist(
        limit,
      );
      var sumOfRemainingCategories = remainingCategoriesAndValue.fold(
        0,
        (dynamic value, element) => value + element.value,
      );
      var remainingCategoryKey = "Others".i18n;
      var percentage = (100 * sumOfRemainingCategories) / totalSum;
      var lr = LinearRecord(remainingCategoryKey, percentage);
      data.add(lr);
      linearRecordsColors.add(otherCategoryColor);
    }

    linearRecords = data;

    // Color palette to use
    bool useCategoriesColor = PreferencesUtils.getOrDefault<bool>(
        ServiceConfig.sharedPreferences!,
        PreferencesKeys.statisticsUseCategoryColorsOnPieChart)!;
    List<charts.Color> colorsToUse = [];
    if (useCategoriesColor) {
      colorsToUse = linearRecordsColors.map((f) => charts.ColorUtil.fromDartColor(f)).toList();
    } else {
      colorsToUse = defaultColorsPalette;
    }

    var seriesList = [
      charts.Series<LinearRecord, String>(
        id: 'Expenses'.i18n,
        colorFn:
            (LinearRecord recordsUnderCategory, i) =>
            colorsToUse[i!],
        domainFn:
            (LinearRecord recordsUnderCategory, _) =>
                recordsUnderCategory.category!,
        measureFn:
            (LinearRecord recordsUnderCategory, _) => recordsUnderCategory.value,
        labelAccessorFn:
            (LinearRecord recordsUnderCategory, _) =>
                recordsUnderCategory.category!,
        data: data,
      ),
    ];

    return ChartData(seriesList, colorsToUse);
  }

  Widget _buildPieChart() {
    return new Container(
        child: new charts.PieChart<String>(
      seriesList,
      animate: animate,
      defaultRenderer: new charts.ArcRendererConfig(arcWidth: 35),
    ));
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
          var recordColor = colorPalette[i];
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
                                    color: Color.fromARGB(
                                        recordColor.a,
                                        recordColor.r,
                                        recordColor.g,
                                        recordColor.b),
                                  )),
                            ),
                            Flexible(
                              child: Text(linearRecord.category!,
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                            )
                          ],
                        )),
                  ),
                  Text(linearRecord.value.toStringAsFixed(2) + " %"),
                ],
              ));
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
        ));
  }

  @override
  Widget build(BuildContext context) {
    return _buildCard();
  }
}
