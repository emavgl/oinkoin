import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:piggybank/helpers/datetime-utility-functions.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/records/records-day-list.dart';
import 'package:piggybank/statistics/overview-card.dart';
import 'package:piggybank/statistics/piechart-card.dart';
import 'package:piggybank/statistics/timeseries-card.dart';

import 'categories-summary-card.dart';
import 'category-summary-card.dart';

class CategoryStatisticPage extends StatefulWidget {

  /// CategoryStatisticPage shows statistics of records belonging to
  /// the same category.

  List<Record> records;
  DateTime from;
  DateTime to;

  CategoryStatisticPage(this.from, this.to, this.records): super();

  @override
  CategoryStatisticPageState createState() => CategoryStatisticPageState();
}

class CategoryStatisticPageState extends State<CategoryStatisticPage> {

  String categoryName;

  @override
  void initState() {
    super.initState();
    categoryName = widget.records[0].category.name;
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
          OverviewCard(widget.records),
          TimeSeriesCard(widget.records),
          CategorySummaryCard(widget.records),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: new Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(categoryName),
              Text(getDateRangeStr(widget.from, widget.to))
            ],
          ),
        ),
        body: new Align(
            alignment: Alignment.topCenter,
            child: widget.records.length > 0 ? _buildStatisticPage() : _buildNoRecordPage()
        )
    );
  }

}
