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
  final List<LinearRecord> data;
  final List<charts.Color> colors;

  ChartData(this.data, this.colors);
}

class CategoriesPieChart extends StatefulWidget {
  final List<Record?> records;
  final Function(double?, String?, List<String>?)? onSelectionChanged;
  final String? selectedCategory;

  CategoriesPieChart(this.records, {this.onSelectionChanged, this.selectedCategory});

  @override
  _CategoriesPieChartState createState() => _CategoriesPieChartState();
}

class _CategoriesPieChartState extends State<CategoriesPieChart> {
  late List<LinearRecord> _preparedData;
  late List<charts.Color> _preparedColors;
  late List<charts.Series<LinearRecord, String>> seriesList;
  late List<charts.Color> colorPalette;
  late List<LinearRecord> linearRecords;
  String? _selectedCategory;

  bool _animate = true;
  final Color otherCategoryColor = Colors.blueGrey;
  final Color chartColorForCategoryWithoutBackgroundColor = Colors.grey;
  late int categoryCount;
  late List<charts.Color> defaultColorsPalette;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.selectedCategory;
    _initializeData();
  }

  @override
  void didUpdateWidget(CategoriesPieChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.records != oldWidget.records) {
      _animate = true;
      _initializeData();
    } else if (widget.selectedCategory != oldWidget.selectedCategory) {
      _animate = false;
      _selectedCategory = widget.selectedCategory;
      _updateSeriesList();
    }
  }

  void _initializeData() {
    categoryCount = PreferencesUtils.getOrDefault<int>(
        ServiceConfig.sharedPreferences!,
        PreferencesKeys.statisticsPieChartNumberOfCategoriesToDisplay)!;
    defaultColorsPalette = charts.MaterialPalette.getOrderedPalettes(categoryCount)
        .map((palette) => palette.shadeDefault).toList();
    defaultColorsPalette.add(charts.ColorUtil.fromDartColor(otherCategoryColor));

    ChartData chartData = _prepareData(widget.records);
    _preparedData = chartData.data;
    _preparedColors = chartData.colors;
    _updateSeriesList();
  }

  void _updateSeriesList() {
    seriesList = [
      charts.Series<LinearRecord, String>(
        id: 'Expenses'.i18n,
        colorFn: (LinearRecord datum, i) {
          final color = _preparedColors[i!];
          if (_selectedCategory == null || _selectedCategory == datum.category) {
            return color;
          }
          return color.lighter.lighter;
        },
        domainFn: (LinearRecord recordsUnderCategory, _) =>
            recordsUnderCategory.category!,
        measureFn: (LinearRecord recordsUnderCategory, _) =>
            recordsUnderCategory.value,
        data: _preparedData,
      ),
    ];
    colorPalette = _preparedColors;
    linearRecords = _preparedData;
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
    var limit =
    aggregatedCategoriesAndValues.length > categoryCount + 1
        ? categoryCount
        : aggregatedCategoriesAndValues.length;

    var topCategoriesAndValue = aggregatedCategoriesAndValues.sublist(0, limit);

    // Step 3: If color sorting is enabled, sort by color-related rules
    if (useCategoriesColor) {
      Map<int, double> colorSumMap = {};

      // Compute sum per color
      for (var entry in topCategoriesAndValue) {
        int colorKey = getColorSortValue(entry.key.color ?? chartColorForCategoryWithoutBackgroundColor);
        colorSumMap.update(colorKey, (sum) => sum + entry.value, ifAbsent: () => entry.value);
      }

      topCategoriesAndValue.sort((a, b) {
        int colorA = getColorSortValue(a.key.color ?? chartColorForCategoryWithoutBackgroundColor);
        int colorB = getColorSortValue(b.key.color ?? chartColorForCategoryWithoutBackgroundColor);

        // Compare by total sum of the color group (Descending)
        int totalSumComparison = colorSumMap[colorB]!.compareTo(colorSumMap[colorA]!);
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
      linearRecordsColors.add(categoryAndValue.key.color ?? chartColorForCategoryWithoutBackgroundColor);
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
      colorsToUse =
          linearRecordsColors.map((f) => charts.ColorUtil.fromDartColor(f)).toList();
    } else {
      colorsToUse = defaultColorsPalette;
    }

    return ChartData(data, colorsToUse);
  }

  void _selectCategory(String? categoryName) {
    setState(() {
      _animate = false;
      if (_selectedCategory == categoryName) {
        _selectedCategory = null;
        if (widget.onSelectionChanged != null)
          widget.onSelectionChanged!(null, null, null);
      } else {
        _selectedCategory = categoryName;
        if (widget.onSelectionChanged != null) {
          // Find records for this category to calculate sum
          final double categorySum = widget.records
              .where((r) =>
                  r!.category!.name == categoryName ||
                  (categoryName == "Others".i18n &&
                      !_isTopCategory(r.category!.name!)))
              .fold(0.0, (double acc, r) => acc + r!.value!.abs());

          // Get names of top categories (excluding "Others")
          final List<String> topCategoryNames = linearRecords
              .where((lr) => lr.category != "Others".i18n)
              .map((lr) => lr.category!)
              .toList();

          widget.onSelectionChanged!(
              categorySum, categoryName, topCategoryNames);
        }
      }
      _updateSeriesList();
    });
  }

  void _onSelectionChanged(charts.SelectionModel model) {
    if (!model.hasDatumSelection) {
      _selectCategory(null);
    } else {
      final selectedDatum = model.selectedDatum.first;
      final data = selectedDatum.datum as LinearRecord;
      _selectCategory(data.category);
    }
  }

  bool _isTopCategory(String name) {
    // Helper to determine if a category is among the top displayed ones
    // This is needed for the "Others" calculation logic
    return linearRecords.any((lr) => lr.category == name && lr.category != "Others".i18n);
  }

  Widget _buildPieChart(BuildContext context) {
    return charts.PieChart<String>(
      seriesList,
      animate: _animate,
      defaultRenderer: charts.ArcRendererConfig(arcWidth: 35),
      selectionModels: [
        charts.SelectionModelConfig(
          type: charts.SelectionModelType.info,
          changedListener: _onSelectionChanged,
        ),
      ],
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
          bool isSelected = _selectedCategory == linearRecord.category;

          return InkWell(
            onTap: () => _selectCategory(linearRecord.category),
            borderRadius: BorderRadius.circular(4),
            child: Container(
                margin: EdgeInsets.fromLTRB(0, 0, 8, 8),
                padding: EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.grey.withAlpha(40) : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                ),
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
                                    style: TextStyle(
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    ),
                                    maxLines: 1, overflow: TextOverflow.ellipsis),
                              )
                            ],
                          )),
                    ),
                    Text(linearRecord.value.toStringAsFixed(2) + " %",
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        )),
                  ],
                )),
          );
        });
  }

  Widget _buildCard(BuildContext context) {
    // Calculate dynamic height: base 200px + extra height for more than 5 items
    // Each legend item needs roughly 28px (margin + row height)
    double baseHeight = 200;
    double extraHeightPerItem = linearRecords.length > 5 ? (linearRecords.length - 5) * 28.0 : 0;
    double cardHeight = baseHeight + extraHeightPerItem;

    return Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
        height: cardHeight,
        child: new Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              flex: 1,
              child: Container(
                height: 200,
                child: _buildPieChart(context),
              ),
            ),
            Expanded(
              flex: 1,
              child: _buildLegend(),
            )
          ],
        ));
  }

  @override
  Widget build(BuildContext context) {
    return _buildCard(context);
  }
}
