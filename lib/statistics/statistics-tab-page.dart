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

  @override
  Widget build(BuildContext context) {
    return new Align(
        alignment: Alignment.topCenter,
        child: new Column(
          children: <Widget>[
            PieChartCard(widget.records),
            CategorySummaryCard(widget.records)
          ],
        )
    );
  }

}
