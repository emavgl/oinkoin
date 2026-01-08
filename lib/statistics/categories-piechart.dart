import 'package:flutter/material.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/record.dart';
import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;
import 'package:piggybank/i18n.dart';
import 'package:piggybank/statistics/statistics-utils.dart';

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
  final Color chartColorForCategoryWithoutBackgroundColor = Colors.grey;
  late final categoryCount;
  late List<charts.Color> defaultColorsPalette;
  late final colorPalette;

  CategoriesPieChart(this.records) {
    categoryCount = PreferencesUtils.getOrDefault<int>(
        ServiceConfig.sharedPreferences!,
        PreferencesKeys.statisticsPieChartNumberOfCategoriesToDisplay)!;
    defaultColorsPalette =
        charts.MaterialPalette.getOrderedPalettes(categoryCount)
            .map((palette) => palette.shadeDefault)
            .toList();
    defaultColorsPalette
        .add(charts.ColorUtil.fromDartColor(otherCategoryColor));
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

    bool useCategoriesColor = PreferencesUtils.getOrDefault<bool>(
        ServiceConfig.sharedPreferences!,
        PreferencesKeys.statisticsPieChartUseCategoryColors)!;

    // Step 1: Sort by value descending (ignoring color)
    var aggregatedCategoriesAndValues =
        aggregatedCategoriesValuesTemporaryMap.entries.toList();
    aggregatedCategoriesAndValues.sort((b, a) => a.value.compareTo(b.value));

    // Step 2: Apply the limit
    var limit = aggregatedCategoriesAndValues.length > categoryCount + 1
        ? categoryCount
        : aggregatedCategoriesAndValues.length;

    var topCategoriesAndValue = aggregatedCategoriesAndValues.sublist(0, limit);

    // Step 3: If color sorting is enabled, sort by color-related rules
    if (useCategoriesColor) {
      Map<int, double> colorSumMap = {};

      // Compute sum per color
      for (var entry in topCategoriesAndValue) {
        int colorKey = getColorSortValue(
            entry.key.color ?? chartColorForCategoryWithoutBackgroundColor);
        colorSumMap.update(colorKey, (sum) => sum + entry.value,
            ifAbsent: () => entry.value);
      }

      topCategoriesAndValue.sort((a, b) {
        int colorA = getColorSortValue(
            a.key.color ?? chartColorForCategoryWithoutBackgroundColor);
        int colorB = getColorSortValue(
            b.key.color ?? chartColorForCategoryWithoutBackgroundColor);

        // Compare by total sum of the color group (Descending)
        int totalSumComparison =
            colorSumMap[colorB]!.compareTo(colorSumMap[colorA]!);
        if (totalSumComparison != 0) {
          return totalSumComparison;
        }

        // If total sum is the same, compare by color value (Ascending)
        int colorComparison = colorA.compareTo(colorB);
        if (colorComparison != 0) {
          return colorComparison;
        }

        // If color is the same, sort by individual value (Descending)
        return b.value.compareTo(a.value);
      });
    }

    // Store data and colors
    List<LinearRecord> data = [];
    List<Color> linearRecordsColors = [];

    for (var categoryAndValue in topCategoriesAndValue) {
      var percentage = (100 * categoryAndValue.value) / totalSum;
      var lr = LinearRecord(categoryAndValue.key.name!, percentage);
      data.add(lr);
      linearRecordsColors.add(categoryAndValue.key.color ??
          chartColorForCategoryWithoutBackgroundColor);
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
    List<charts.Color> colorsToUse = [];
    if (useCategoriesColor) {
      colorsToUse = linearRecordsColors
          .map((f) => charts.ColorUtil.fromDartColor(f))
          .toList();
    } else {
      colorsToUse = defaultColorsPalette;
    }

    var seriesList = [
      charts.Series<LinearRecord, String>(
        id: 'Expenses'.i18n,
        colorFn: (LinearRecord recordsUnderCategory, i) => colorsToUse[i!],
        domainFn: (LinearRecord recordsUnderCategory, _) =>
            recordsUnderCategory.category!,
        measureFn: (LinearRecord recordsUnderCategory, _) =>
            recordsUnderCategory.value,
        labelAccessorFn: (LinearRecord recordsUnderCategory, _) =>
            recordsUnderCategory.category!,
        data: data,
      ),
    ];

    return ChartData(seriesList, colorsToUse);
  }

  Widget _buildPieChart(BuildContext context) {
    // Pass BuildContext
    return Container(
      child: charts.PieChart<String>(
        seriesList,
        animate: animate,
        defaultRenderer: charts.ArcRendererConfig(arcWidth: 35),
        behaviors: [
          charts.SelectNearest(),
        ],
        selectionModels: [
          charts.SelectionModelConfig(
            type: charts.SelectionModelType.info,
            changedListener: (charts.SelectionModel model) {
              if (model.hasDatumSelection) {
                final selectedDatum = model.selectedDatum;
                if (selectedDatum.isNotEmpty) {
                  LinearRecord linearRecord =
                      selectedDatum.first.datum; // Get the clicked data
                  var percentageText =
                      linearRecord.value.toStringAsFixed(2) + "%";
                  var categoryName = linearRecord.category;

                  // Show SnackBar
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        elevation: 6,
                        content: Text("($percentageText) $categoryName"),
                        action: SnackBarAction(
                          label: 'Dismiss'.i18n,
                          onPressed: () {
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          },
                        )),
                  );
                }
              }
            },
          ),
        ],
      ),
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

  Widget _buildCard(BuildContext context) {
    return Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
        height: 200,
        child: new Row(
          children: <Widget>[
            Expanded(child: _buildPieChart(context)),
            Expanded(child: _buildLegend())
          ],
        ));
  }

  @override
  Widget build(BuildContext context) {
    return _buildCard(context);
  }
}
