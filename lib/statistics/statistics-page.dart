import 'package:flutter/material.dart';
import 'package:piggybank/helpers/datetime-utility-functions.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/statistics/statistics-tab-page.dart';
import './i18n/statistics-page.i18n.dart';

class StatisticsPage extends StatelessWidget {

  /// Statistics Page
  /// It has takes the initial date, ending date and a list of records
  /// and shows widgets representing statistics of the given records

  List<Record> records;
  DateTime from;
  DateTime to;
  StatisticsPage(this.from, this.to, this.records);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          bottom: TabBar(
            tabs: [
              Tab(text: "Expenses".i18n,),
              Tab(text: "Income".i18n,)
            ],
          ),
          title: new Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text('Charts'.i18n),
              Text(getDateRangeStr(from, to))
            ],
          ),
        ),
        body: TabBarView(
          children: [
            StatisticsTabPage(from, to, records.where((element) => element.category.categoryType == CategoryType.expense).toList()),
            StatisticsTabPage(from, to, records.where((element) => element.category.categoryType == CategoryType.income).toList()),
          ],
        ),
      ),
    );
  }

}
