import 'package:flutter/material.dart';
import 'package:piggybank/helpers/records-utility-functions.dart';
import 'package:piggybank/i18n.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/statistics/statistics-models.dart';

import 'aggregated-list-view.dart';
import 'summary-models.dart';
import 'tags-piechart.dart';

class TagSummaryCard extends StatefulWidget {
  final List<Record?> records;
  final AggregationMethod aggregationMethod;

  TagSummaryCard(this.records, this.aggregationMethod);

  @override
  _TagSummaryCardState createState() => _TagSummaryCardState();
}

class _TagSummaryCardState extends State<TagSummaryCard> {
  late List<TagSumTuple> tagsAndSums;
  double? totalExpensesSum;
  double? maxExpensesSum;
  final _biggerFont = const TextStyle(fontSize: 16.0);

  @override
  void initState() {
    super.initState();
    if (widget.records.isNotEmpty) {
      tagsAndSums = _aggregateRecordByTag(widget.records);
      totalExpensesSum = tagsAndSums.fold(
          0, ((previousValue, element) => previousValue! + element.value));
      maxExpensesSum = tagsAndSums.isNotEmpty ? tagsAndSums[0].value : 0;
    }
  }

  List<TagSumTuple> _aggregateRecordByTag(List<Record?> records) {
    Map<String, double> aggregatedTagsValuesTemporaryMap = {};
    for (var record in records) {
      if (record != null) {
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
    aggregatedTagsAndValues
        .sort((a, b) => b.value.abs().compareTo(a.value.abs()));
    return aggregatedTagsAndValues
        .map((e) => TagSumTuple(e.key, e.value))
        .toList();
  }

  Widget _buildTagsList() {
    if (widget.records.isEmpty) return Container();
    return AggregatedListView<TagSumTuple>(
      items: tagsAndSums,
      itemBuilder: (context, tagAndSum, i) {
        return _buildTagStatsRow(context, tagAndSum);
      },
    );
  }

  Widget _buildTagStatsRow(BuildContext context, TagSumTuple tagAndSum) {
    double percentage = (100 * tagAndSum.value) / totalExpensesSum!;
    double percentageBar = tagAndSum.value / maxExpensesSum!;
    String percentageStrRepr = percentage.toStringAsFixed(2);
    String tagSumStr = getCurrencyValueString(tagAndSum.value.abs());
    String tag = tagAndSum.key;

    return Column(
      children: <Widget>[
        ListTile(
          title: Container(
            child: Column(
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        tag,
                        style: _biggerFont,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      margin: EdgeInsets.only(left: 5),
                      child: Text(
                        "$tagSumStr ($percentageStrRepr%)",
                        style: _biggerFont,
                      ),
                    )
                  ],
                ),
                Container(
                  padding: EdgeInsets.fromLTRB(0, 8, 0, 0),
                  child: SizedBox(
                    height: 2,
                    child: LinearProgressIndicator(
                      value: percentageBar,
                      backgroundColor: Colors.transparent,
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Padding(
        padding: const EdgeInsets.all(0.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
                padding: const EdgeInsets.fromLTRB(10, 8, 8, 0),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Entries grouped by tags".i18n,
                        style: TextStyle(fontSize: 14),
                      )
                    ])),
            new Divider(),
            TagsPieChart(widget.records),
            SizedBox(height: 6),
            if (widget.records.isNotEmpty)
              _buildTagsList()
            else
              Container(
                alignment: Alignment.center,
                padding: EdgeInsets.all(20),
                child: Text("No tag data available for this period.".i18n),
              ),
          ],
        ),
      ),
    );
  }
}
