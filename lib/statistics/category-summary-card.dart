import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:piggybank/helpers/datetime-utility-functions.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/records/edit-record-page.dart';
import 'package:piggybank/statistics/records-statistic-page.dart';
import 'package:piggybank/statistics/statistics-models.dart';
import 'package:piggybank/statistics/statistics-utils.dart';
import '../components/category_icon_circle.dart';
import '../helpers/records-utility-functions.dart';
import 'package:piggybank/i18n.dart';
import 'package:piggybank/statistics/categories-statistics-page.dart';

class CategorySumTuple {
  final Category category;
  double value;
  CategorySumTuple(this.category, this.value);
}

class CategorySummaryCard extends StatelessWidget {
  final List<Record?> records;
  Category? category;
  AggregationMethod? aggregationMethod;
  late List<Record?> aggregatedRecords;

  late double totalCategoryValue;
  late double maxValue;
  final _biggerFont = const TextStyle(fontSize: 16.0);
  final _dateFont = const TextStyle(fontSize: 12.0);

  CategorySummaryCard(this.records, this.aggregationMethod) {
    aggregatedRecords =
        aggregateRecordsByDateAndCategory(records, aggregationMethod);
    aggregatedRecords
        .sort((a, b) => a!.value!.compareTo(b!.value!)); // sort desc
    category = this.records[0]!.category;
    totalCategoryValue = aggregatedRecords.fold(
        0, (previousValue, element) => previousValue + element!.value!.abs());
    maxValue = records.map((e) => e!.value!.abs()).reduce(max);
    records.sort((a, b) => a!.value!.compareTo(b!.value!));
  }

  Widget _buildRecordsStatList() {
    /// Returns a ListView with all the movements contained in the MovementPerDay object
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
    double percentage = (100 * record.value!.abs()) / totalCategoryValue;
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
                (record.title == null ? record.category!.name : record.title)! +
                    " ($value)";
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
            if (aggregationMethod == AggregationMethod.MONTH) {
              var formatter = DateFormat("yy/MM");
              var categoryRecords = records
                  .where((element) =>
                      element!.category!.name == record.category!.name &&
                      formatter.format(element.dateTime!) ==
                          formatter.format(record.dateTime!))
                  .toList();
              DateTime from =
                  DateTime(record.dateTime!.year, record.dateTime!.month);
              DateTime to =
                  DateTime(record.dateTime!.year, record.dateTime!.month + 1)
                      .subtract(Duration(minutes: 1));
              await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => CategoryStatisticPage(
                          from, to, categoryRecords, AggregationMethod.DAY)));
            }
            if (aggregationMethod == AggregationMethod.DAY) {
              // Tapped on a day aggregated record
              // -> show a page of the included records
              var categoryRecords = records
                  .where((element) =>
                      element!.dateTime!.day == record.dateTime!.day)
                  .toList();
              DateTime? from = categoryRecords[0]!.dateTime;
              DateTime? to = from;
              await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => RecordsStatisticPage(from, to,
                          categoryRecords, AggregationMethod.NOT_AGGREGATED)));
            }
            if (aggregationMethod == AggregationMethod.NOT_AGGREGATED) {
              // Tapped on a single-record, show it in edit record page
              // as readonly
              await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => EditRecordPage(
                        passedRecord: record,
                        readOnly: true,
                  )));
            }
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
                            (record.title != null
                                ? record.title!
                                : record.category!.name!),
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
          leading: CategoryIconCircle(
              iconEmoji: category!.iconEmoji,
              iconDataFromDefaultIconSet: category!.icon,
              backgroundColor: category!.color,
              overlayIcon: category!.isArchived ? Icons.archive : null
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryStatsCard() {
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
                      "Entries for category: ".i18n +
                          category!.name! +
                          (aggregationMethod != AggregationMethod.NOT_AGGREGATED
                              ? (" (per " +
                                  (aggregationMethod == AggregationMethod.MONTH
                                      ? "Month".i18n
                                      : "Day".i18n) +
                                  ")")
                              : ""),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                  Container(
                    child: Text(
                      totalCategoryValue.toStringAsFixed(2),
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
    return _buildCategoryStatsCard();
  }
}
