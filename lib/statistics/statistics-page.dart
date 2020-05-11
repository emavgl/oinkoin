import 'package:flutter/material.dart';
import 'package:piggybank/categories/categories-list.dart';
import './i18n/statistics-page.i18n.dart';

import 'statistics-pie-chart.dart';
import 'statistics-line-chart.dart';
import 'statistics-bar-chart.dart';

class StatisticsPage extends StatefulWidget {
  @override
  StatisticsPageState createState() => StatisticsPageState();
}

class StatisticsPageState extends State<StatisticsPage> {

  int indexTab;

  final GlobalKey<CategoriesListState> _expensesCategoryKey = GlobalKey();
  final GlobalKey<CategoriesListState> _incomingCategoryKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    indexTab = 0;
  }

  void refreshExpenseCategoriesList() async {
    await _expensesCategoryKey.currentState.fetchCategories();
  }

  void refreshIncomeCategoriesList() async {
    await _incomingCategoryKey.currentState.fetchCategories();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          bottom: TabBar(
            onTap: (index){
              setState(() {
                indexTab = index;
              });
            },
            tabs: [
              Tab(text: "Expenses".i18n,),
              Tab(text: "Income".i18n,),
              Tab(text: "Balance".i18n,),
            ],
          ),
          title: Text('Statistics'.i18n),
        ),
        body: TabBarView(
          children: [
            StatisticsBarChart(),
            StatisticsLineChart(),
            StatisticsPieChart(),
          ],
        ),
      ),
    );
  }
}
