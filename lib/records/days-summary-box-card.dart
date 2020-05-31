
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:piggybank/models/records-per-day.dart';
import './i18n/days-summary-box-card.dart';

class DaysSummaryBox extends StatefulWidget {
  
  /// DaysSummaryBox is a card that, given a list of MovementsPerDay objects,
  /// shows the total income, total expenses, total balance resulting from
  /// all the movements in input days.

  final List<RecordsPerDay> _movementDays;
  const DaysSummaryBox(this._movementDays);

  @override
  DaysSummaryBoxState createState() => DaysSummaryBoxState();
}

class DaysSummaryBoxState extends State<DaysSummaryBox> {
  final _biggerFont = const TextStyle(fontSize: 18.0);
  final _subtitleFont = const TextStyle(fontSize: 13.0);

  double totalIncome() {
    var totalIncome = 0.0;
    for (var value in widget._movementDays) {
      totalIncome += value.income;
    }
    return totalIncome;
  }

  double totalExpenses() {
    var totalExpenses = 0.0;
    for (var value in widget._movementDays) {
      totalExpenses += value.expenses;
    }
    return totalExpenses;
  }

  double totalBalance() {
    var totalBalance = 0.0;
    for (var value in widget._movementDays) {
      totalBalance += value.balance;
    }
    return totalBalance;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
        elevation: 2,
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