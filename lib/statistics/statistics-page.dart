import 'package:flutter/material.dart';
import 'package:piggybank/models/movement.dart';
import 'package:piggybank/services/sqlite-database.dart';
import './i18n/statistics-page.i18n.dart';

import 'statistics-pie-chart.dart';
import 'statistics-line-chart.dart';
import 'statistics-bar-chart.dart';

// This class shows statistics to the user based on the given interval of time.
// If no interval is provided, TODO
// The statistics page has three tabs: expenses, income and balance; the first
// two tabs reports a line and a pie chart related to the expenses and income
// movements, respectively. The third tab reports a bar chart comparing expenses
// and income.
// TODO we could also have a unique tab with a single line chart and a single
// TODO bar chart for both expenses and income, and two pie charts for expenses
// TODO and income (so a total of 4 graphs instead of 5)
class StatisticsPage extends StatefulWidget {
  final DateTime startingDate;
  final DateTime endingDate;

  StatisticsPage({this.startingDate, this.endingDate});

  @override
  StatisticsPageState createState() => StatisticsPageState();
}

class StatisticsPageState extends State<StatisticsPage> {
  int indexTab;
  List<Movement> incomeMovements;
  List<Movement> expensesMovements;

  @override
  void initState() {
    super.initState();
    indexTab = 0;
  }

  // to get movements with the given date interval
  void fetchMovements() async {

    setState(() async {

      // clear the lists, we are going to fetch new data
      incomeMovements.clear();
      expensesMovements.clear();

      List<Movement> movementsForStatistics = await SqliteDatabase.instance
          .getAllMovementsInInterval(widget.startingDate, widget.endingDate);

      movementsForStatistics.forEach((movement) => () {
            if (movement.value > 0)
              incomeMovements.add(movement);
            else if (movement.value < 0)
              expensesMovements.add(movement);
            else {
              // TODO what to do?
            }
          });
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          bottom: TabBar(
            onTap: (index) {
              setState(() {
                indexTab = index;
              });
            },
            tabs: [
              Tab(
                text: "Expenses".i18n,
              ),
              Tab(
                text: "Income".i18n,
              ),
              Tab(
                text: "Balance".i18n,
              ),
            ],
          ),
          title: Text('Statistics'.i18n),
        ),
        body: TabBarView(
          children: [
            StatisticsPieChart(
              movementsForChart: expensesMovements,
            ),
            StatisticsLineChart(
              movementsForChart: incomeMovements,
            ),
            StatisticsBarChart(
              incomeMovementsForChart: incomeMovements,
              expensesMovementsForChart: expensesMovements,
            ),
          ],
        ),
      ),
    );
  }
}
