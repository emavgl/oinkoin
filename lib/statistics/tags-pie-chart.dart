import 'package:flutter/material.dart';
import 'package:piggybank/models/record.dart';
import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;
import 'package:piggybank/i18n.dart';

import '../services/service-config.dart';
import '../settings/constants/preferences-keys.dart';
import '../settings/preferences-utils.dart';

class LinearTagRecord {
  final String? tag;
  final double value;

  LinearTagRecord(this.tag, this.value);
}

class TagsPieChart extends StatefulWidget {
  final List<Record?> records;
  final Function(double?, String?, List<String>?)? onSelectionChanged;
  final String? selectedTag;

  TagsPieChart(this.records, {this.onSelectionChanged, this.selectedTag});

  @override
  _TagsPieChartState createState() => _TagsPieChartState();
}

class _TagsPieChartState extends State<TagsPieChart> {
  late List<LinearTagRecord> _preparedData;
  late List<charts.Color> _preparedColors;
  late List<charts.Series<LinearTagRecord, String>> seriesList;
  late List<charts.Color> colorPalette;
  late List<LinearTagRecord> linearRecords;
  String? _selectedTag;

  bool _animate = true;
  final Color otherTagColor = Colors.blueGrey;
  late int tagCount;
  late List<charts.Color> defaultColorsPalette;

  @override
  void initState() {
    super.initState();
    _selectedTag = widget.selectedTag;
    _initializeData();
  }

  @override
  void didUpdateWidget(TagsPieChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.records != oldWidget.records) {
      _animate = true;
      _initializeData();
    } else if (widget.selectedTag != oldWidget.selectedTag) {
      _animate = false;
      _selectedTag = widget.selectedTag;
      _updateSeriesList();
    }
  }

  void _initializeData() {
    tagCount = PreferencesUtils.getOrDefault<int>(
        ServiceConfig.sharedPreferences!,
        PreferencesKeys.statisticsPieChartNumberOfCategoriesToDisplay)!;
    defaultColorsPalette = charts.MaterialPalette.getOrderedPalettes(tagCount)
        .map((palette) => palette.shadeDefault).toList();
    defaultColorsPalette.add(charts.ColorUtil.fromDartColor(otherTagColor));

    TagChartData chartData = _prepareData(widget.records);
    _preparedData = chartData.data;
    _preparedColors = chartData.colors;
    _updateSeriesList();
  }

  void _updateSeriesList() {
    seriesList = [
      charts.Series<LinearTagRecord, String>(
        id: 'Tags'.i18n,
        colorFn: (LinearTagRecord datum, i) {
          final color = _preparedColors[i!];
          if (_selectedTag == null || _selectedTag == datum.tag) {
            return color;
          }
          return color.lighter.lighter;
        },
        domainFn: (LinearTagRecord recordsUnderTag, _) => recordsUnderTag.tag!,
        measureFn: (LinearTagRecord recordsUnderTag, _) => recordsUnderTag.value,
        data: _preparedData,
      ),
    ];
    colorPalette = _preparedColors;
    linearRecords = _preparedData;
  }

  TagChartData _prepareData(List<Record?> records) {
    Map<String, double> aggregatedTagsValuesTemporaryMap = {};
    double totalSum = 0;

    for (var record in records) {
      if (record != null) {
        for (var tag in record.tags) {
          totalSum += record.value!.abs();
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

    var limit = aggregatedTagsAndValues.length > tagCount + 1
        ? tagCount
        : aggregatedTagsAndValues.length;

    var topTagsAndValue = aggregatedTagsAndValues.sublist(0, limit);

    List<LinearTagRecord> data = [];
    List<charts.Color> colorsToUse = [];

    for (int i = 0; i < topTagsAndValue.length; i++) {
      var tagAndValue = topTagsAndValue[i];
      var percentage = (100 * tagAndValue.value) / totalSum;
      var lr = LinearTagRecord(tagAndValue.key, percentage);
      data.add(lr);
      colorsToUse.add(defaultColorsPalette[i]);
    }

    if (limit < aggregatedTagsAndValues.length) {
      var remainingTagsAndValue = aggregatedTagsAndValues.sublist(limit);
      var sumOfRemainingTags = remainingTagsAndValue.fold(
        0.0,
        (dynamic value, element) => value + element.value,
      );
      var remainingTagKey = "Others".i18n;
      var percentage = (100 * sumOfRemainingTags) / totalSum;
      var lr = LinearTagRecord(remainingTagKey, percentage);
      data.add(lr);
      colorsToUse.add(charts.ColorUtil.fromDartColor(otherTagColor));
    }

    return TagChartData(data, colorsToUse);
  }

  void _selectTag(String? tagName) {
    setState(() {
      _animate = false;
      if (_selectedTag == tagName) {
        _selectedTag = null;
        if (widget.onSelectionChanged != null)
          widget.onSelectionChanged!(null, null, null);
      } else {
        _selectedTag = tagName;
        if (widget.onSelectionChanged != null) {
          double tagSum = 0;
          for (var r in widget.records) {
            if (r == null) continue;
            if (tagName == "Others".i18n) {
              // Add value for each tag that is NOT a top tag
              int otherTagsInRecord = r.tags.where((t) => !_isTopTag(t)).length;
              tagSum += r.value!.abs() * otherTagsInRecord;
            } else if (r.tags.contains(tagName)) {
              tagSum += r.value!.abs();
            }
          }

          final List<String> topTagNames = linearRecords
              .where((lr) => lr.tag != "Others".i18n)
              .map((lr) => lr.tag!)
              .toList();

          widget.onSelectionChanged!(tagSum, tagName, topTagNames);
        }
      }
      _updateSeriesList();
    });
  }

  void _onSelectionChanged(charts.SelectionModel model) {
    if (!model.hasDatumSelection) {
      _selectTag(null);
    } else {
      final selectedDatum = model.selectedDatum.first;
      final data = selectedDatum.datum as LinearTagRecord;
      _selectTag(data.tag);
    }
  }

  bool _isTopTag(String name) {
    return linearRecords.any((lr) => lr.tag == name && lr.tag != "Others".i18n);
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
    return ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: linearRecords.length,
        padding: const EdgeInsets.all(6.0),
        itemBuilder: (context, i) {
          var linearRecord = linearRecords[i];
          var recordColor = colorPalette[i];
          bool isSelected = _selectedTag == linearRecord.tag;

          return InkWell(
            onTap: () => _selectTag(linearRecord.tag),
            borderRadius: BorderRadius.circular(4),
            child: Container(
                margin: EdgeInsets.fromLTRB(0, 0, 8, 8),
                padding: EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.grey.withAlpha(40)
                      : Colors.transparent,
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
                                height: 10,
                                width: 20,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color.fromARGB(
                                      recordColor.a,
                                      recordColor.r,
                                      recordColor.g,
                                      recordColor.b),
                                ),
                              ),
                              SizedBox(width: 4),
                              Flexible(
                                child: Text(linearRecord.tag!,
                                    style: TextStyle(
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              )
                            ],
                          )),
                    ),
                    Text(linearRecord.value.toStringAsFixed(2) + " %",
                        style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        )),
                  ],
                )),
          );
        });
  }

  Widget _buildCard(BuildContext context) {
    double baseHeight = 200;
    double extraHeightPerItem =
        linearRecords.length > 5 ? (linearRecords.length - 5) * 28.0 : 0;
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

class TagChartData {
  final List<LinearTagRecord> data;
  final List<charts.Color> colors;

  TagChartData(this.data, this.colors);
}
