import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:piggybank/components/movements-bar-chart.dart';
import 'package:piggybank/components/movements-line-chart.dart';

class StatisticsPage extends StatelessWidget {
  static const double kStatisticsExtent = 75.0;

  @override
  Widget build(BuildContext context) {
    return ListView(
   //   itemExtent: kStatisticsExtent,
      children: <Widget>[MovementsLineChart(), MovementsBarChart()],
    );
  }
}
