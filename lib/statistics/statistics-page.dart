import 'package:flutter/material.dart';
import 'package:i18n_extension/i18n_widget.dart';
import 'package:intl/intl.dart';
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

  String getDateRangeStr(DateTime start, DateTime end) {
    /// Returns a string representing the range from :start to :end
    Locale myLocale = I18n.locale;
    DateTime lastDayOfTheMonth = (start.month < 12) ? new DateTime(start.year, start.month + 1, 0) : new DateTime(start.year + 1, 1, 0);
    lastDayOfTheMonth = lastDayOfTheMonth.add(Duration(hours: 23, minutes: 59));
    if (lastDayOfTheMonth.isAtSameMomentAs(end)) {
      // Visualizing an entire month
      String localeRepr = DateFormat.yMMMM(myLocale.languageCode).format(lastDayOfTheMonth);
      return localeRepr[0].toUpperCase() + localeRepr.substring(1); // capitalize
    } else {
      String startLocalRepr = DateFormat.yMMMd(myLocale.languageCode).format(start);
      String endLocalRepr = DateFormat.yMMMd(myLocale.languageCode).format(start);
      return startLocalRepr.split(",")[0] + " - " + endLocalRepr;
    }
  }

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
            StatisticsTabPage(records.where((element) => element.category.categoryType == CategoryType.expense).toList()),
            StatisticsTabPage(records.where((element) => element.category.categoryType == CategoryType.income).toList()),
          ],
        ),
      ),
    );
  }

}
