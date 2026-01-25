import 'package:flutter/material.dart';
import 'package:piggybank/i18n.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/statistics/savings-rate-card.dart';
import 'package:piggybank/statistics/statistics-models.dart';

import 'balance-barchart-card.dart';
import 'balance-comparison-barchart.dart';
import 'balance-overview-card.dart';

class BalanceTabPage extends StatefulWidget {
  List<Record?> records;
  DateTime? from;
  DateTime? to;

  BalanceTabPage(this.from, this.to, this.records) : super();

  @override
  BalanceTabPageState createState() => BalanceTabPageState();
}

class BalanceTabPageState extends State<BalanceTabPage> {
  AggregationMethod? aggregationMethod;

  AggregationMethod getAggregationMethodGivenTheTimeRange(
      DateTime from, DateTime to) {
    if (from.year != to.year) {
      return AggregationMethod.YEAR;
    } else if (from.month == to.month) {
      return AggregationMethod.DAY;
    } else {
      return AggregationMethod.MONTH;
    }
  }

  @override
  void initState() {
    super.initState();
    this.aggregationMethod =
        getAggregationMethodGivenTheTimeRange(widget.from!, widget.to!);
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

  Widget _buildBalancePage() {
    return new SingleChildScrollView(
      child: new Column(
        children: <Widget>[
          SavingsRateCard(
              widget.from, widget.to, widget.records, aggregationMethod),
          SizedBox(height: 10),
          BalanceComparisonBarChart(
              widget.from, widget.to, widget.records, aggregationMethod),
          SizedBox(height: 10),
          BalanceBarChartCard(
              widget.from, widget.to, widget.records, aggregationMethod)
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return new Align(
        alignment: Alignment.topCenter,
        child: widget.records.length > 0
            ? _buildBalancePage()
            : _buildNoRecordPage());
  }
}
