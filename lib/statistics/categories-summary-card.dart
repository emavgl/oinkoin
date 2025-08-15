import 'package:flutter/material.dart';
import 'package:piggybank/helpers/records-utility-functions.dart';
import 'package:piggybank/i18n.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/statistics/categories-statistics-page.dart';
import 'package:piggybank/statistics/statistics-models.dart';

import '../components/category_icon_circle.dart';
import 'aggregated-list-view.dart';
import 'categories-piechart.dart';
import 'summary-models.dart';

class CategoriesSummaryCard extends StatelessWidget {
  final List<Record?> records;
  final List<Record?>? aggregatedRecords;
  final AggregationMethod? aggregationMethod;

  final DateTime? from;
  final DateTime? to;
  late List<CategorySumTuple> categoriesAndSums;
  double? totalExpensesSum;
  double? maxExpensesSum;
  final _biggerFont = const TextStyle(fontSize: 16.0);

  CategoriesSummaryCard(this.from, this.to, this.records,
      this.aggregatedRecords, this.aggregationMethod) {
    if (records.length > 0) {
      categoriesAndSums = _aggregateRecordByCategory(records);
      totalExpensesSum = categoriesAndSums.fold(
          0, ((previousValue, element) => previousValue! + element.value!));
      maxExpensesSum = categoriesAndSums[0].value;
    }
  }

  List<CategorySumTuple> _aggregateRecordByCategory(List<Record?> records) {
    Map<String?, CategorySumTuple> aggregatedCategoriesValuesTemporaryMap =
        new Map();
    for (var record in records) {
      aggregatedCategoriesValuesTemporaryMap.update(
          record!.category!.name,
          (tuple) =>
              new CategorySumTuple(tuple.key!, tuple.value! + record.value!),
          ifAbsent: () =>
              new CategorySumTuple(record.category!, record.value!));
    }
    var aggregatedCategoriesAndValues =
        aggregatedCategoriesValuesTemporaryMap.values.toList();
    aggregatedCategoriesAndValues
        .sort((a, b) => b.value!.abs().compareTo(a.value!.abs()));
    return aggregatedCategoriesAndValues;
  }

  Widget _buildCategoriesList() {
    /// Returns a ListView with all the movements contained in the MovementPerDay object
    return AggregatedListView<CategorySumTuple>(
      items: categoriesAndSums,
      itemBuilder: (context, categoryAndSum, i) {
        return _buildCategoryStatsRow(context, categoryAndSum);
      },
    );
  }

  Widget _buildCategoryStatsRow(
      BuildContext context, CategorySumTuple categoryAndSum) {
    double percentage = (100 * categoryAndSum.value!) / totalExpensesSum!;
    double percentageBar = categoryAndSum.value! / maxExpensesSum!;
    String percentageStrRepr = percentage.toStringAsFixed(2);
    String categorySumStr = getCurrencyValueString(categoryAndSum.value!.abs());
    Category category = categoryAndSum.key!;

    /// Returns a ListTile rendering the single movement row
    return Column(
      children: <Widget>[
        ListTile(
          onTap: () async {
            var categoryRecords = records
                .where((element) => element!.category!.name == category.name)
                .toList();
            await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => CategoryStatisticPage(
                        from, to, categoryRecords, aggregationMethod)));
          },
          title: Container(
            child: Column(
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        category.name!,
                        style: _biggerFont,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      margin: EdgeInsets.only(left: 5),
                      child: Text(
                        "$categorySumStr ($percentageStrRepr%)",
                        style: _biggerFont,
                      ),
                    )
                  ],
                ),
                Container(
                  padding: EdgeInsets.fromLTRB(0, 8, 0, 0),
                  child: SizedBox(
                    height: 2,
                    child: LinearProgressIndicator(
                      value: percentageBar,
                      backgroundColor: Colors.transparent,
                    ),
                  ),
                )
              ],
            ),
          ),
          leading: CategoryIconCircle(
              iconEmoji: category.iconEmoji,
              iconDataFromDefaultIconSet: category.icon,
              backgroundColor: category.color,
              overlayIcon: category.isArchived ? Icons.archive : null),
        ),
      ],
    );
  }

  Widget _buildCategoryStatsCard() {
    return Container(
        child: Column(
      children: <Widget>[
        Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 8, 0),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Entries grouped by category".i18n,
                    style: TextStyle(fontSize: 14),
                  ),
                  Text(
                    getCurrencyValueString(totalExpensesSum),
                    style: TextStyle(fontSize: 14),
                  ),
                ])),
        new Divider(),
        CategoriesPieChart(records),
        _buildCategoriesList()
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return _buildCategoryStatsCard();
  }
}
