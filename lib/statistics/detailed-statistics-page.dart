import 'package:flutter/material.dart';
import 'package:piggybank/helpers/datetime-utility-functions.dart';
import 'package:piggybank/i18n.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/statistics/overview-card.dart';
import 'package:piggybank/statistics/statistics-models.dart';

import 'barchart-card.dart';

class DetailedStatisticPage extends StatefulWidget {
  final List<Record?> records;
  final AggregationMethod? aggregationMethod;
  final DateTime? from;
  final DateTime? to;
  final String detailedKey;
  final Widget summaryCard;

  DetailedStatisticPage(
    this.from,
    this.to,
    this.records,
    this.aggregationMethod, {
    required this.detailedKey,
    required this.summaryCard,
  }) : super();

  @override
  DetailedStatisticPageState createState() => DetailedStatisticPageState();
}

class DetailedStatisticPageState extends State<DetailedStatisticPage> {
  @override
  void initState() {
    super.initState();
  }

  Widget _buildNoRecordPage() {
    return new Column(
      children: <Widget>[
        Image.asset(
          'assets/images/no_entry_3.png',
          width: 200,
        ),
        Text(
          "No entries to show.".i18n,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22.0,
          ),
        )
      ],
    );
  }

  Widget _buildStatisticPage() {
    return new SingleChildScrollView(
      child: new Column(
        children: <Widget>[
          OverviewCard(
              widget.from, widget.to, widget.records, widget.aggregationMethod),
          BarChartCard(
              widget.from, widget.to, widget.records, widget.aggregationMethod),
          widget.summaryCard,
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
              Flexible(
                child: Text(
                  widget.detailedKey,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                child: Text(getDateRangeStr(widget.from!, widget.to!)),
                margin: EdgeInsets.only(left: 10),
              )
            ],
          ),
        ),
        body: new Align(
            alignment: Alignment.topCenter,
            child: widget.records.length > 0
                ? _buildStatisticPage()
                : _buildNoRecordPage()));
  }
}
