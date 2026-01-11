import 'package:flutter/material.dart';
import 'package:piggybank/models/record.dart';
import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;
import 'package:piggybank/i18n.dart';
import 'package:piggybank/statistics/statistics-utils.dart';

import '../services/service-config.dart';
import '../settings/constants/preferences-keys.dart';
import '../settings/preferences-utils.dart';

class LinearTagRecord {
  final String? tag;
  final double value;

  LinearTagRecord(this.tag, this.value);
}

class TagChartData {
  final List<charts.Series<LinearTagRecord, String>> series;
  final List<charts.Color> colors;

  TagChartData(this.series, this.colors);
}

class TagsPieChart extends StatelessWidget {
  final List<Record?> records;
  late final List<LinearTagRecord> linearRecords;
  late final List<charts.Series<LinearTagRecord, String>> seriesList;

  final bool animate = true;
  final Color otherTagColor = Colors.blueGrey;
  late final tagCount;
  late List<charts.Color> defaultColorsPalette;
  late final colorPalette;

  TagsPieChart(this.records) {
    tagCount = PreferencesUtils.getOrDefault<int>(
        ServiceConfig.sharedPreferences!,
        PreferencesKeys.statisticsPieChartNumberOfCategoriesToDisplay)!;
    defaultColorsPalette = charts.MaterialPalette.getOrderedPalettes(tagCount)
        .map((palette) => palette.shadeDefault).toList();
    defaultColorsPalette.add(charts.ColorUtil.fromDartColor(otherTagColor));
    TagChartData chartData = _prepareData(records);
    seriesList = chartData.series;
    colorPalette = chartData.colors;
  }

  TagChartData _prepareData(List<Record?> records) {
    Map<String, double> aggregatedTagsValuesTemporaryMap = {};
    double totalSum = 0;

    for (var record in records) {
      if (record != null && record.value != null) {
        totalSum += record.value!.abs();
        for (var tag in record.tags) {
          aggregatedTagsValuesTemporaryMap.update(
            tag,
            (value) => value + record.value!.abs(),
            ifAbsent: () => record.value!.abs(),
          );
        }
      }
    }

    var aggregatedTagsAndValues =
        aggregatedTagsValuesTemporaryMap.entries.toList();
    aggregatedTagsAndValues.sort((b, a) => a.value.compareTo(b.value));

    var limit =
        aggregatedTagsAndValues.length > tagCount + 1 ? tagCount : aggregatedTagsAndValues.length;

    var topTagsAndValue = aggregatedTagsAndValues.sublist(0, limit);

    List<LinearTagRecord> data = [];
    List<Color> linearRecordsColors = [];

    for (var tagAndValue in topTagsAndValue) {
      var percentage = (100 * tagAndValue.value) / totalSum;
      var ltr = LinearTagRecord(tagAndValue.key, percentage);
      data.add(ltr);
      linearRecordsColors.add(Colors.primaries[data.length % Colors.primaries.length]); // Assign a color
    }

    if (limit < aggregatedTagsAndValues.length) {
      var remainingTagsAndValue = aggregatedTagsAndValues.sublist(
        limit,
      );
      var sumOfRemainingTags = remainingTagsAndValue.fold(
        0,
        (dynamic value, element) => value + element.value,
      );
      var remainingTagKey = "Others".i18n;
      var percentage = (100 * sumOfRemainingTags) / totalSum;
      var ltr = LinearTagRecord(remainingTagKey, percentage);
      data.add(ltr);
      linearRecordsColors.add(otherTagColor);
    }

    linearRecords = data;

    List<charts.Color> colorsToUse = linearRecordsColors.map((f) => charts.ColorUtil.fromDartColor(f)).toList();

    var seriesList = [
      charts.Series<LinearTagRecord, String>(
        id: 'Tags'.i18n,
        colorFn:
            (LinearTagRecord recordsUnderTag, i) =>
            colorsToUse[i!],
        domainFn:
            (LinearTagRecord recordsUnderTag, _) =>
                recordsUnderTag.tag!,
        measureFn:
            (LinearTagRecord recordsUnderTag, _) => recordsUnderTag.value,
        labelAccessorFn:
            (LinearTagRecord recordsUnderTag, _) =>
                recordsUnderTag.tag!,
        data: data,
      ),
    ];

    return TagChartData(seriesList, colorsToUse);
  }

  Widget _buildPieChart(BuildContext context) { // Pass BuildContext
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
                  LinearTagRecord linearTagRecord = selectedDatum.first.datum; // Get the clicked data
                  var percentageText = linearTagRecord.value.toStringAsFixed(2) + "%";
                  var tagName = linearTagRecord.tag;

                  // Show SnackBar
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      elevation: 6,
                      content: Text("($percentageText) $tagName"),
                      action: SnackBarAction(
                          label: 'Dismiss'.i18n,
                          onPressed: () {
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          },
                        )
                    ),
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
                              child: Text(linearRecord.tag!,
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
    // Calculate dynamic height: base 200px + extra height for more than 5 items
    // Each legend item needs roughly 28px (margin + row height)
    double baseHeight = 200;
    double extraHeightPerItem = linearRecords.length > 5 ? (linearRecords.length - 5) * 28.0 : 0;
    double cardHeight = baseHeight + extraHeightPerItem;

    return Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
        height: cardHeight,
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
