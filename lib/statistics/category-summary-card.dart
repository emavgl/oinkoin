import 'package:flutter/material.dart';
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
  List<CategorySumTuple> categoriesAndSums;
  double totalExpensesSum;
  double maxExpensesSum;
  final _biggerFont = const TextStyle(fontSize: 16.0);

  CategorySummaryCard(this.records) {
    if (records.length > 0) {
      categoriesAndSums = _aggregateRecordByCategory(records);
      totalExpensesSum = categoriesAndSums.fold(
          0, (previousValue, element) => previousValue + element.value);
      maxExpensesSum = categoriesAndSums[0].value;
    }
  }

  List<CategorySumTuple> _aggregateRecordByCategory(List<Record> records) {
    Map<String, CategorySumTuple> aggregatedCategoriesValuesTemporaryMap = new Map();
    for (var record in records) {
      aggregatedCategoriesValuesTemporaryMap.update(
          record.category.name, (tuple) => new CategorySumTuple(tuple.category, tuple.value + record.value),
          ifAbsent: () => new CategorySumTuple(record.category, record.value));
    }
    var aggregatedCategoriesAndValues = aggregatedCategoriesValuesTemporaryMap
        .values.toList();
    aggregatedCategoriesAndValues.sort((a, b) => a.value.compareTo(b.value)); // sort ascending
    return aggregatedCategoriesAndValues;
  }

  Widget _buildCategoriesList() {
    /// Returns a ListView with all the movements contained in the MovementPerDay object
    return ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: categoriesAndSums.length,
        separatorBuilder: (context, index) {
          return Divider();
        },
        padding: const EdgeInsets.all(6.0),
        itemBuilder: /*1*/ (context, i) {
          return _buildCategoryStatsRow(categoriesAndSums[i]);
        });
  }

  Widget _buildCategoryStatsRow(CategorySumTuple categoryAndSum) {
    double percentage = (100 * categoryAndSum.value) / totalExpensesSum;
    double percentageBar = (categoryAndSum.value) / maxExpensesSum;
    String percentageStrRepr = percentage.toStringAsFixed(2);
    String categorySumStr = categoryAndSum.value.toString();
    Category category = categoryAndSum.category;
    /// Returns a ListTile rendering the single movement row
    return Column(
      children: <Widget>[
        ListTile(
            onTap: () async {
            },
            title: Container(
              child: Column(
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        category.name,
                        style: _biggerFont,
                      ),
                      Text(
                        "$categorySumStr ($percentageStrRepr%)",
                        style: _biggerFont,
                      ),
                    ],
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
                child: Icon(category.icon, size: 20, color: Colors.white,),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: category.color,
                )
            )
        ),

      ],
    );
  }


  Widget _buildCategoryStatsCard() {
    return Container(
        padding: EdgeInsets.all(10),
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
                          "Values grouped by category".i18n,
                          style: TextStyle(fontSize: 14),
                        ),
                        Text(
                          totalExpensesSum.toString(),
                          style: TextStyle(fontSize: 14),
                        ),
                      ]
                  )
              ),
              new Divider(),
              _buildCategoriesList()
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