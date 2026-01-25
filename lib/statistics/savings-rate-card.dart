import 'package:flutter/material.dart';
import 'package:piggybank/i18n.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/statistics/statistics-models.dart';
import '../helpers/records-utility-functions.dart';
import 'balance-overview-card.dart';

class SavingsRateCard extends StatelessWidget {
  final List<Record?> records;
  final AggregationMethod? aggregationMethod;
  final DateTime? from;
  final DateTime? to;

  late double totalIncome;
  late double totalExpenses;
  late double savingsRate;
  late String rating;
  late String economicContext;
  late Color ratingColor;

  final headerStyle = const TextStyle(fontSize: 15.0, fontWeight: FontWeight.bold);
  final valueStyle = const TextStyle(fontSize: 32.0, fontWeight: FontWeight.bold);
  final labelStyle = const TextStyle(fontSize: 14.0);
  final descriptionStyle = const TextStyle(fontSize: 13.0);

  SavingsRateCard(this.from, this.to, this.records, this.aggregationMethod) {
    _calculateSavingsRate();
    _determineRating();
  }

  void _calculateSavingsRate() {
    totalIncome = 0;
    totalExpenses = 0;

    for (var record in records) {
      if (record != null) {
        if (record.category!.categoryType == CategoryType.income) {
          totalIncome += record.value!.abs();
        } else {
          totalExpenses += record.value!.abs();
        }
      }
    }

    if (totalIncome > 0) {
      double savings = totalIncome - totalExpenses;
      savingsRate = (savings / totalIncome) * 100;
    } else {
      savingsRate = 0;
    }
  }

  void _determineRating() {
    if (savingsRate < 0) {
      rating = "Debt".i18n;
      economicContext = "Spending more than earning".i18n;
      ratingColor = Colors.red.shade700;
    } else if (savingsRate >= 0 && savingsRate <= 5) {
      rating = "Vulnerable".i18n;
      economicContext = "Living paycheck to paycheck".i18n;
      ratingColor = Colors.orange.shade700;
    } else if (savingsRate > 5 && savingsRate < 10) {
      rating = "At Risk".i18n;
      economicContext = "Little room for error".i18n;
      ratingColor = Colors.orange.shade600;
    } else if (savingsRate >= 10 && savingsRate < 15) {
      rating = "Fair".i18n;
      economicContext = "The traditional minimum recommendation".i18n;
      ratingColor = Colors.yellow.shade700;
    } else if (savingsRate >= 15 && savingsRate < 20) {
      rating = "Good".i18n;
      economicContext = "On track for a standard retirement".i18n;
      ratingColor = Colors.lightGreen.shade700;
    } else if (savingsRate >= 20) {
      rating = "Very Good".i18n;
      economicContext = "Building wealth consistently".i18n;
      ratingColor = Colors.green.shade700;
    }
  }

  Widget _buildSavingsRateDisplay() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Savings Rate".i18n,
          style: headerStyle,
        ),
        SizedBox(height: 10),
        Text(
          "${savingsRate.toStringAsFixed(1)}%",
          style: valueStyle.copyWith(color: ratingColor),
        ),
        SizedBox(height: 5),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: ratingColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            rating,
            style: labelStyle.copyWith(
              color: ratingColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(height: 10),
        Text(
          economicContext,
          style: descriptionStyle,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildCard() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: <Widget>[
          Container(
            padding: EdgeInsets.all(5),
            child: _buildSavingsRateDisplay(),
          ),
          Container(
            padding: EdgeInsets.all(5),
            child: BalanceOverviewCard(from, to, records, aggregationMethod),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: _buildCard(),
    );
  }
}
