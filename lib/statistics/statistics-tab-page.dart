import 'package:flutter/material.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/statistics/overview-card.dart';
import 'package:piggybank/statistics/statistics-models.dart';
import 'package:piggybank/statistics/statistics-utils.dart';

import 'barchart-card.dart';
import 'categories-summary-card.dart';
import './i18n/statistics-page.i18n.dart';


class StatisticsTabPage extends StatefulWidget {

  /// The category page that you can select from the bottom navigation bar.
  /// It contains two tab, showing the categories for expenses and categories
  /// for incomes. It has a single Floating Button that, dependending from which
  /// tab you clicked, it open the EditCategory page passing the selected Category type.

  List<Record?> records;
  DateTime? from;
  DateTime? to;

  StatisticsTabPage(this.from, this.to, this.records): super();

  @override
  StatisticsTabPageState createState() => StatisticsTabPageState();
}

class StatisticsTabPageState extends State<StatisticsTabPage> {

  int? indexTab;
  List<Record?>? aggregatedRecords;
  AggregationMethod? aggregationMethod;

  @override
  void initState() {
    super.initState();
    indexTab = 0; // index identifying the tab
    this.aggregationMethod = widget.from!.month == widget.to!.month ? AggregationMethod.DAY : AggregationMethod.MONTH;
    this.aggregatedRecords = aggregateRecordsByDateAndCategory(widget.records, aggregationMethod);
  }

  Widget _buildNoRecordPage() {
    return new Column(
      children: <Widget>[
        Image.asset(
          'assets/no_entry_3.png', width: 200,
        ),
        Text("No entries to show.".i18n,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22.0,) ,)
      ],
    );
  }

  Widget _buildStatisticPage() {
    return new SingleChildScrollView(
      child: new Column(
        children: <Widget>[
          OverviewCard(widget.from, widget.to, widget.records, aggregationMethod),
          BarChartCard(widget.from, widget.to, widget.records, aggregationMethod),
          CategoriesSummaryCard(widget.from, widget.to, widget.records, aggregatedRecords, aggregationMethod),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return new Align(
        alignment: Alignment.topCenter,
        child: widget.records.length > 0 ? _buildStatisticPage() : _buildNoRecordPage()
    );
  }

}
