
import 'package:flutter/material.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/record.dart';
import './i18n/days-summary-box-card.dart';

class DaysSummaryBox extends StatefulWidget {
  
  /// DaysSummaryBox is a card that, given a list of records,
  /// shows the total income, total expenses, total balance resulting from
  /// all the movements in input days.

  List<Record?> records;
  DaysSummaryBox(this.records);

  @override
  DaysSummaryBoxState createState() => DaysSummaryBoxState();
}

class DaysSummaryBoxState extends State<DaysSummaryBox> {
  final _biggerFont = const TextStyle(fontSize: 18.0);
  final _subtitleFont = const TextStyle(fontSize: 13.0);

  double totalIncome() {
    return widget.records.where((record) => record!.category!.categoryType == CategoryType.income).fold(0.0, (previousValue, record) => previousValue + record!.value!);
  }

  double totalExpenses() {
    return widget.records.where((record) => record!.category!.categoryType == CategoryType.expense).fold(0.0, (previousValue, record) => previousValue + record!.value!);
  }

  double totalBalance() {
    return totalIncome() + totalExpenses();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
        elevation: 1,
        //color: Colors.white,
        //surfaceTintColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(6.0),
          child: Row(
            children: <Widget>[
              Expanded(
                flex: 1,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      "Income".i18n,
                      style: _subtitleFont,
                    ),
                    SizedBox(height: 5), // spacing
                    Text(
                      totalIncome().toStringAsFixed(1),
                      style: _biggerFont,
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
                      "Expenses".i18n,
                      style: _subtitleFont,
                    ),
                    SizedBox(height: 5), // spacing
                    Text(
                      totalExpenses().toStringAsFixed(1),
                      style: _biggerFont,
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
                      "Balance".i18n,
                      style: _subtitleFont,
                    ),
                    SizedBox(height: 5), // spacing
                    Text(
                      totalBalance().toStringAsFixed(1),
                      style: _biggerFont,
                    ),
                  ],
                ),
              ),
            ],
          ),
        )
    );
  }
}