import 'package:flutter/material.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/statistics/overview-card.dart';
import 'package:piggybank/statistics/statistics-models.dart';
import 'package:piggybank/statistics/statistics-utils.dart';

import 'barchart-card.dart';
import 'categories-summary-card.dart';
import 'package:piggybank/i18n.dart';

class StatisticsTabPage extends StatefulWidget {
  /// The category page that you can select from the bottom navigation bar.
  /// It contains two tab, showing the categories for expenses and categories
  /// for incomes. It has a single Floating Button that, dependending from which
  /// tab you clicked, it open the EditCategory page passing the selected Category type.

  List<Record?> records;
  DateTime? from;
  DateTime? to;

  StatisticsTabPage(this.from, this.to, this.records) : super();

  @override
  StatisticsTabPageState createState() => StatisticsTabPageState();
}

class StatisticsTabPageState extends State<StatisticsTabPage> {
  int? indexTab;
  List<Record?>? aggregatedRecords;
  AggregationMethod? aggregationMethod;

  AggregationMethod getAggregationMethodGivenTheTimeRange(
      DateTime from, DateTime to) {
    if (from.year != to.year) {
      return AggregationMethod.YEAR;
    } else if (from.month == to.month) {
      return AggregationMethod.DAY;
    } else {
      return AggregationMethod.MONTH;
    }
  }

  @override
  void initState() {
    super.initState();
    indexTab = 0; // index identifying the tab
    this.aggregationMethod =
        getAggregationMethodGivenTheTimeRange(widget.from!, widget.to!);
    this.aggregatedRecords =
        aggregateRecordsByDateAndCategory(widget.records, aggregationMethod);
  }

  Widget _buildNoRecordPage() {
    return new Column(
      children: <Widget>[
        Image.asset(
          'assets/images/no_entry_3.png',
          width: 200,
        ),
        Text(
          "No entries to show.".i18n,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22.0,
          ),
        )
      ],
    );
  }

  Widget _buildStatisticPage() {
    return new SingleChildScrollView(
      child: new Column(
        children: <Widget>[
          OverviewCard(
              widget.from, widget.to, widget.records, aggregationMethod),
          SizedBox(height: 10),
          BarChartCard(
              widget.from, widget.to, widget.records, aggregationMethod),
          SizedBox(height: 10),
          CategoriesSummaryCard(widget.from, widget.to, widget.records,
              aggregatedRecords, aggregationMethod),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return new Align(
        alignment: Alignment.topCenter,
        child: widget.records.length > 0
            ? _buildStatisticPage()
            : _buildNoRecordPage());
  }
}
