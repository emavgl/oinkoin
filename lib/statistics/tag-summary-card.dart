import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:piggybank/helpers/datetime-utility-functions.dart';
import 'package:piggybank/i18n.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/records/edit-record-page.dart';
import 'package:piggybank/statistics/records-statistic-page.dart';
import 'package:piggybank/statistics/statistics-models.dart';
import 'package:piggybank/statistics/statistics-utils.dart';

import '../components/category_icon_circle.dart';
import '../helpers/records-utility-functions.dart';
import 'detailed-statistics-page.dart';

class TagSummaryCard extends StatelessWidget {
  final List<Record?> records;
  String? tag;
  AggregationMethod? aggregationMethod;
  late List<Record?> aggregatedRecords;

  late double totalTagValue;
  late double maxValue;
  final _biggerFont = const TextStyle(fontSize: 16.0);
  final _dateFont = const TextStyle(fontSize: 12.0);

  TagSummaryCard(this.records, this.aggregationMethod) {
    // Get the first tag from the first record that has tags
    tag = records.firstWhere((r) => r != null && r.tags.isNotEmpty)?.tags.first;

    // Filter records to only include those with this tag
    var tagRecords = records
        .where((record) => record != null && record.tags.contains(tag))
        .toList();

    // Use the same aggregation method as CategorySummaryCard
    aggregatedRecords =
        aggregateRecordsByDateAndTag(tagRecords, aggregationMethod, tag!);
    aggregatedRecords
        .sort((a, b) => a!.value!.compareTo(b!.value!)); // sort desc

    totalTagValue = aggregatedRecords.fold(
        0, (previousValue, element) => previousValue + element!.value!.abs());
    maxValue = tagRecords.map((e) => e!.value!.abs()).reduce(max);
    tagRecords.sort((a, b) => a!.value!.compareTo(b!.value!));
  }

  Widget _buildRecordsStatList() {
    /// Returns a ListView with all the movements contained in the aggregated records
    return ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: aggregatedRecords.length,
        separatorBuilder: (context, index) {
          return Divider();
        },
        padding: const EdgeInsets.all(6.0),
        itemBuilder: /*1*/ (context, i) {
          return _buildRow(context, aggregatedRecords[i]!);
        });
  }

  Widget _buildRow(BuildContext context, Record record) {
    double percentage = (100 * record.value!.abs()) / totalTagValue;
    double percentageBar = (record.value!.abs()) / maxValue;
    String percentageStrRepr = percentage.toStringAsFixed(2);
    String value = getCurrencyValueString(record.value);

    /// Returns a ListTile rendering the single movement row
    return Column(
      children: <Widget>[
        ListTile(
          onLongPress: () async {
            // Record has no aggregated records inside, show info
            String infoMessage =
                (record.title == null ? tag : record.title)! + " ($value)";
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                elevation: 6,
                behavior: SnackBarBehavior.floating,
                content: Text(
                  infoMessage,
                  style: TextStyle(fontSize: 20),
                ),
                action: SnackBarAction(
                  label: 'Dismiss'.i18n,
                  onPressed: () {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  },
                )));
          },
          onTap: () async {
            // Drill-down behavior:
            // YEAR -> MONTH -> DAY -> RECORDS -> RECORD
            // (where possible; otherwise fall back to record list / record view)

            // Single record - go directly to EditRecordPage
            if (record.aggregatedValues <= 1) {
              await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => EditRecordPage(
                            passedRecord: record,
                            readOnly: true,
                          )));
              return;
            }

            // Multiple aggregated records
            List<Record?> tagRecords;

            if (aggregationMethod == AggregationMethod.YEAR) {
              // Clicked a year bucket -> show month aggregation in that year
              tagRecords = records
                  .where((element) =>
                      element != null &&
                      element.tags.contains(tag) &&
                      element.dateTime!.year == record.dateTime!.year)
                  .toList();

              if (tagRecords.isEmpty) return;

              DateTime from = DateTime(record.dateTime!.year, 1, 1);
              DateTime to =
                  DateTime(record.dateTime!.year + 1, 1, 1).subtract(Duration(minutes: 1));

              await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => DetailedStatisticPage(
                            from,
                            to,
                            tagRecords,
                            AggregationMethod.MONTH,
                            detailedKey: tag!,
                            summaryCard: TagSummaryCard(
                                tagRecords, AggregationMethod.MONTH),
                          )));
              return;
            }

            if (aggregationMethod == AggregationMethod.MONTH) {
              // Clicked a month bucket -> show day aggregation in that month
              var formatter = DateFormat("yy/MM");
              tagRecords = records
                  .where((element) =>
                      element != null &&
                      element.tags.contains(tag) &&
                      formatter.format(element.dateTime!) ==
                          formatter.format(record.dateTime!))
                  .toList();

              if (tagRecords.isEmpty) return;

              DateTime from =
                  DateTime(record.dateTime!.year, record.dateTime!.month);
              DateTime to =
                  DateTime(record.dateTime!.year, record.dateTime!.month + 1)
                      .subtract(Duration(minutes: 1));

              await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => DetailedStatisticPage(
                            from,
                            to,
                            tagRecords,
                            AggregationMethod.DAY,
                            detailedKey: tag!,
                            summaryCard:
                                TagSummaryCard(tagRecords, AggregationMethod.DAY),
                          )));
              return;
            }

            if (aggregationMethod == AggregationMethod.DAY) {
              // Clicked a day bucket -> list records of that day
              tagRecords = records
                  .where((element) =>
                      element != null &&
                      element.tags.contains(tag) &&
                      element.dateTime!.day == record.dateTime!.day &&
                      element.dateTime!.month == record.dateTime!.month &&
                      element.dateTime!.year == record.dateTime!.year)
                  .toList();

              if (tagRecords.isEmpty) return;

              DateTime? from = tagRecords.first!.dateTime;
              DateTime? to = tagRecords.last!.dateTime;

              await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => RecordsStatisticPage(
                          from,
                          to,
                          tag!,
                          isEmpty: tagRecords.isEmpty,
                          TagSummaryCard(
                              tagRecords, AggregationMethod.NOT_AGGREGATED))));
              return;
            }

            // NOT_AGGREGATED case (shouldn't happen here with aggregatedValues > 1)
            tagRecords = [record];
          },
          title: Container(
            child: Column(
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        (record.aggregatedValues > 1
                                ? "(${record.aggregatedValues}) "
                                : "") +
                            (record.aggregatedValues > 1
                                ? tag!
                                : (record.title != null
                                    ? record.title!
                                    : record.category!.name!)),
                        style: _biggerFont,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      child: Text(
                        "$value ($percentageStrRepr%)",
                        style: _biggerFont,
                      ),
                      margin: EdgeInsets.only(left: 10),
                    )
                  ],
                ),
                Align(
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    getDateStr(record.dateTime,
                        aggregationMethod: aggregationMethod),
                    style: _dateFont,
                  ),
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
          leading: record.aggregatedValues <= 1 && record.category != null
              ? CategoryIconCircle(
                  iconEmoji: record.category!.iconEmoji,
                  iconDataFromDefaultIconSet: record.category!.icon,
                  backgroundColor: record.category!.color,
                  overlayIcon:
                      record.category!.isArchived ? Icons.archive : null)
              : Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.7),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.label,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildTagStatsCard() {
    String aggregationLabel = "";
    if (aggregationMethod != null &&
        aggregationMethod != AggregationMethod.NOT_AGGREGATED) {
      switch (aggregationMethod!) {
        case AggregationMethod.DAY:
          aggregationLabel = "Day".i18n;
          break;
        case AggregationMethod.MONTH:
          aggregationLabel = "Month".i18n;
          break;
        case AggregationMethod.YEAR:
          aggregationLabel = "Year".i18n;
          break;
        case AggregationMethod.NOT_AGGREGATED:
          break;
      }
    }

    return Container(
        child: Column(
      children: <Widget>[
        Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 8, 0),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      "Entries for tag: ".i18n +
                          tag! +
                          (aggregationLabel.isNotEmpty
                              ? (" (per " + aggregationLabel + ")")
                              : ""),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                  Container(
                    child: Text(
                      totalTagValue.toStringAsFixed(2),
                      style: TextStyle(fontSize: 14),
                    ),
                    margin: EdgeInsets.only(left: 15),
                  )
                ])),
        new Divider(),
        _buildRecordsStatList()
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return _buildTagStatsCard();
  }
}
