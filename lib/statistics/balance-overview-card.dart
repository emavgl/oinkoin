import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/statistics/statistics-models.dart';
import 'package:piggybank/statistics/detailed-statistics-page.dart';
import 'package:piggybank/statistics/overview-card.dart';
import 'package:piggybank/statistics/barchart-card.dart';
import 'package:piggybank/statistics/categories-summary-card.dart';
import 'package:piggybank/statistics/tags-summary-card.dart';
import '../helpers/records-utility-functions.dart';
import 'package:piggybank/i18n.dart';

class BalanceOverviewCard extends StatelessWidget {
  final List<Record?> records;
  final AggregationMethod? aggregationMethod;
  final DateTime? from;
  final DateTime? to;

  late double totalIncome;
  late double totalExpenses;
  late double saved;

  BalanceOverviewCard(this.from, this.to, this.records, this.aggregationMethod) {
    _calculateTotals();
  }

  void _calculateTotals() {
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

    saved = totalIncome - totalExpenses;
  }

  List<Record?> _filterRecordsByType(CategoryType type) {
    return records.where((record) =>
      record != null && record.category!.categoryType == type
    ).toList();
  }

  Widget _buildClickableBox({
    required BuildContext context,
    required String title,
    required double value,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: color.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            padding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FaIcon(
                      icon,
                      size: 16,
                      color: color,
                    ),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  getCurrencyValueString(value),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToDetail(BuildContext context, String title, List<Record?> filteredRecords) {
    // Do nothing at the moment
  }


  Widget _buildCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          _buildClickableBox(
            context: context,
            title: "Income".i18n,
            value: totalIncome,
            icon: FontAwesomeIcons.arrowTrendUp,
            color: Colors.green,
            onTap: () => _navigateToDetail(
              context,
              "Income".i18n,
              _filterRecordsByType(CategoryType.income),
            ),
          ),
          SizedBox(width: 10),
          _buildClickableBox(
            context: context,
            title: "Expenses".i18n,
            value: totalExpenses,
            icon: FontAwesomeIcons.arrowTrendDown,
            color: Colors.red,
            onTap: () => _navigateToDetail(
              context,
              "Expenses".i18n,
              _filterRecordsByType(CategoryType.expense),
            ),
          ),
          SizedBox(width: 10),
          _buildClickableBox(
            context: context,
            title: "Saved".i18n,
            value: saved,
            icon: FontAwesomeIcons.piggyBank,
            color: saved >= 0 ? Colors.blue : Colors.orange,
            onTap: () => _navigateToDetail(
              context,
              "Balance".i18n,
              records,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildCard(context);
  }
}
