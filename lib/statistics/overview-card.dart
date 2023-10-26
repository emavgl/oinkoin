import 'package:flutter/material.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/statistics/statistics-models.dart';
import 'package:piggybank/statistics/statistics-utils.dart';
import '../helpers/records-utility-functions.dart';
import './i18n/statistics-page.i18n.dart';

class OverviewCard extends StatelessWidget {

  final List<Record?> records;
  final AggregationMethod? aggregationMethod;
  final DateTime? from;
  final DateTime? to;
  late List<DateTimeSeriesRecord> aggregatedRecords;

  double? maxRecord;
  double? minRecord;
  late double minAggregated;
  late double maxAggregated;
  int? numberOfRecords;
  double? sumValues;
  late double averageValue;
  double? median;

  final headerStyle = const TextStyle(fontSize: 13.0);
  final valueStyle = const TextStyle(fontSize: 18.0);
  final dateStyle = const TextStyle(fontSize: 24.0);

  OverviewCard(this.from, this.to, this.records, this.aggregationMethod) {
    this.records.sort((a, b) => a!.value!.abs().compareTo(b!.value!.abs()));
    aggregatedRecords = aggregateRecordsByDate(this.records, aggregationMethod);
    sumValues = this.records.fold(0, (dynamic acc, e) => acc + e!.value).abs();
    minAggregated = this.aggregatedRecords.first.value.abs();
    maxAggregated = this.aggregatedRecords.last.value.abs();
    averageValue = (sumValues! /  this.aggregatedRecords.length);
  }

  Widget _buildSecondRow () {
    return IntrinsicHeight(
      child: Row(
        children: <Widget>[
          Expanded(
            flex: 1,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  "Max".i18n + " (" + (aggregationMethod == AggregationMethod.MONTH? "Month".i18n : "Day".i18n) + ")",
                  style: headerStyle,
                ),
                SizedBox(height: 5), // spacing
                Text(
                  getCurrencyValueString(maxAggregated.abs()),
                  style: valueStyle,
                ),
              ],
            ),
          ),
          VerticalDivider(endIndent: 10, indent: 10),
          Expanded(
            flex: 1,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  "Min".i18n + " (" + (aggregationMethod == AggregationMethod.MONTH? "Month".i18n : "Day".i18n) + ")",
                  style: headerStyle,
                ),
                SizedBox(height: 5), // spacing
                Text(
                  getCurrencyValueString(minAggregated.abs()),
                  style: valueStyle,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFirstRow () {
    return IntrinsicHeight(
      child: Row(
        children: <Widget>[
          Expanded(
            flex: 1,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  "Sum".i18n,
                  style: headerStyle,
                ),
                SizedBox(height: 5), // spacing
                Text(
                  getCurrencyValueString(sumValues!.abs()),
                  style: valueStyle,
                ),
              ],
            ),
          ),
          VerticalDivider(endIndent: 10, indent: 10),
          Expanded(
            flex: 1,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  "Average".i18n,
                  style: headerStyle,
                ),
                SizedBox(height: 5), // spacing
                Text(
                  getCurrencyValueString(averageValue.abs()),
                  style: valueStyle,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard() {
    return Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(6.0),
          child: Column(
            children: <Widget>[
              Container(
                padding: EdgeInsets.all(10),
                child:  _buildFirstRow(),
              ),
              Divider(endIndent: 10, indent: 10),
              Container(
                padding: EdgeInsets.all(10),
                child:  _buildSecondRow(),
              ),
            ],
          )
        )
    );
  }


  @override
  Widget build(BuildContext context) {
    return Container(
      child: _buildCard(),
    );
  }
}