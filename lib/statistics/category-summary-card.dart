import 'dart:math';

import 'package:flutter/material.dart';
import 'package:piggybank/helpers/datetime-utility-functions.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/record.dart';
import './i18n/statistics-page.i18n.dart';

class CategorySumTuple {
  final Category category;
  double value;
  CategorySumTuple(this.category, this.value);
}

class CategorySummaryCard extends StatelessWidget {

  final List<Record> records;
  String categoryName;

  double totalCategoryValue;
  double maxValue;
  final _biggerFont = const TextStyle(fontSize: 16.0);
  final _dateFont = const TextStyle(fontSize: 12.0);

  CategorySummaryCard(this.records) {
    categoryName = this.records[0].category.name;
    totalCategoryValue = records.fold(
        0, (previousValue, element) => previousValue + element.value.abs());
    maxValue = records.map((e) => e.value.abs()).reduce(max);
    records.sort((a, b) => a.value.compareTo(b.value));
  }

  Widget _buildRecordsStatList() {
    /// Returns a ListView with all the movements contained in the MovementPerDay object
    return ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: records.length,
        separatorBuilder: (context, index) {
          return Divider();
        },
        padding: const EdgeInsets.all(6.0),
        itemBuilder: /*1*/ (context, i) {
          return _buildRow(context, records[i]);
        });
  }

  Widget _buildRow(BuildContext context, Record record) {
    double percentage = (100 * record.value.abs()) / totalCategoryValue;
    double percentageBar = (record.value.abs()) / maxValue;
    String percentageStrRepr = percentage.toStringAsFixed(2);
    String value = record.value.toStringAsFixed(2);
    /// Returns a ListTile rendering the single movement row
    return Column(
      children: <Widget>[
        ListTile(
            title: Container(
              child: Column(
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        record.title != null ? record.title : categoryName,
                        style: _biggerFont,
                      ),
                      Text(
                        "$value ($percentageStrRepr%)",
                        style: _biggerFont,
                      ),
                    ],
                  ),
                  Align(
                      alignment: Alignment.bottomLeft,
                      child: Text(getDateStr(record.dateTime), style: _dateFont,)
                  ),
                  Container(
                    padding: EdgeInsets.fromLTRB(0, 8, 0, 0),
                    child:
                    SizedBox(
                      height: 2,
                      child: LinearProgressIndicator(value: percentageBar, backgroundColor: Colors.transparent,),
                    )
                  )
                ],
              ),
            ),
            leading: Container(
                width: 40,
                height: 40,
                child: Icon(record.category.icon, size: 20, color: Colors.white,),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: record.category.color,
                )
            )
        ),

      ],
    );
  }


  Widget _buildCategoryStatsCard() {
    return Container(
        margin: const EdgeInsets.fromLTRB(10, 5, 10, 0),
        child: new Card(
          elevation: 2,
          child: Column(
            children: <Widget>[
              Container(
                  padding: const EdgeInsets.fromLTRB(10, 8, 8, 0),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Entries for category: ".i18n + categoryName,
                          style: TextStyle(fontSize: 14),
                        ),
                        Text(
                          totalCategoryValue.toStringAsFixed(2),
                          style: TextStyle(fontSize: 14),
                        ),
                      ]
                  )
              ),
              new Divider(),
              _buildRecordsStatList()
            ],
          )
        )
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildCategoryStatsCard();
  }
}