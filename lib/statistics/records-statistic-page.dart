import 'package:flutter/material.dart';
import 'package:piggybank/helpers/datetime-utility-functions.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/statistics/statistics-models.dart';
import 'package:piggybank/i18n.dart';
import 'category-summary-card.dart';

class RecordsStatisticPage extends StatelessWidget {

  /// CategoryStatisticPage shows statistics of records belonging to
  /// the same category.

  List<Record?> records;
  String? categoryName;
  AggregationMethod aggregationMethod;
  DateTime? from;
  DateTime? to;

  RecordsStatisticPage(this.from, this.to, this.records, this.aggregationMethod) {
    categoryName = this.records[0]!.category!.name;
  }

  Widget _buildNoRecordPage() {
    return new Column(
      children: <Widget>[
        Image.asset(
          'assets/images/no_entry_3.png', width: 200,
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
          CategorySummaryCard(records, aggregationMethod),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isSameDay = getDateStr(from) == getDateStr(to);
    return Scaffold(
        appBar: AppBar(
          title: new Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Flexible(
                child: Text(
                  categoryName!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                child: isSameDay ? Text(getDateStr(from)) : Text(getDateRangeStr(from!, to!)),
                margin: EdgeInsets.only(left: 10),
              )
            ],
          ),
        ),
        body: new Align(
            alignment: Alignment.topCenter,
            child: records.length > 0 ? _buildStatisticPage() : _buildNoRecordPage()
        )
    );
  }

}
