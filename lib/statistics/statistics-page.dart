import 'package:flutter/material.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/statistics/piechart-card.dart';
import 'package:piggybank/statistics/statistics-tab-page.dart';

class StatisticsPage extends StatefulWidget {

  /// The category page that you can select from the bottom navigation bar.
  /// It contains two tab, showing the categories for expenses and categories
  /// for incomes. It has a single Floating Button that, dependending from which
  /// tab you clicked, it open the EditCategory page passing the selected Category type.

  List<Record> records;
  DateTime from;
  DateTime to;
  StatisticsPage(this.from, this.to, this.records): super();

  @override
  StatisticsPageState createState() => StatisticsPageState();
}

class StatisticsPageState extends State<StatisticsPage> {

  int indexTab;

  @override
  void initState() {
    super.initState();
    indexTab = 0;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          bottom: TabBar(
            onTap: (index){
              setState(() {
                indexTab = index;
              });
            },
            tabs: [
              Tab(text: "Expenses",),
              Tab(text: "Income",)
            ],
          ),
          title: Text('Charts'),
        ),
        body: TabBarView(
          children: [
            StatisticsTabPage(widget.records.where((element) => element.category.categoryType == CategoryType.expense).toList()),
            StatisticsTabPage(widget.records.where((element) => element.category.categoryType == CategoryType.income).toList()),
          ],
        ),
      ),
    );
  }

}
