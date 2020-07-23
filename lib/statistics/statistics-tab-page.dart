import 'package:flutter/material.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/statistics/piechart-card.dart';

import 'category-summary-card.dart';

class StatisticsTabPage extends StatefulWidget {

  /// The category page that you can select from the bottom navigation bar.
  /// It contains two tab, showing the categories for expenses and categories
  /// for incomes. It has a single Floating Button that, dependending from which
  /// tab you clicked, it open the EditCategory page passing the selected Category type.

  List<Record> records;

  StatisticsTabPage(this.records): super();

  @override
  StatisticsTabPageState createState() => StatisticsTabPageState();
}

class StatisticsTabPageState extends State<StatisticsTabPage> {

  int indexTab;

  @override
  void initState() {
    super.initState();
    indexTab = 0;
  }

  Widget _buildNoRecordPage() {
    return new Column(
      children: <Widget>[
        Image.asset(
          'assets/no_entry_3.png', width: 200,
        ),
        Text("No entries to show.",
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
          PieChartCard(widget.records),
          CategorySummaryCard(widget.records)
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
