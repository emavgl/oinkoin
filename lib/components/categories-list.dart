import 'dart:math';

import 'package:flutter/material.dart';
import 'package:piggybank/components/days-summary-box-card.dart';
import 'package:piggybank/helpers/movements-generator.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/movements-per-day.dart';
import 'package:piggybank/models/movement.dart';
import 'package:piggybank/screens/edit-category-page.dart';
import 'package:piggybank/services/movements-in-memory-database.dart';
import '../i18n/categories-page.i18n.dart';

import 'movements-group-card.dart';

class CategoriesList extends StatefulWidget {

  int categoryType;

  CategoriesList({Key key, this.categoryType}) : super(key: key);

  @override
  CategoriesListState createState() => CategoriesListState(categoryType);
}

class CategoriesListState extends State<CategoriesList> {
  List<Category> _categories = new List();
  int indexTab;
  int categoryType;

  CategoriesListState(this.categoryType);

  fetchCategories() async {
    var categories = await MovementsInMemoryDatabase.getCategoriesByType(categoryType);
    setState(() {
      _categories = categories;
    });
  }

  @override
  void initState() {
    super.initState();
    indexTab = 0;
    fetchCategories();
  }

  final _biggerFont = const TextStyle(fontSize: 18.0);

  Widget _buildCategories() {
    return ListView.separated(
        shrinkWrap: true,
        separatorBuilder: (context, index) => Divider(),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _categories.length,
        padding: const EdgeInsets.all(6.0),
        itemBuilder: /*1*/ (context, i) {
          return _buildCategory(i, _categories[i]);
        });
  }

  Widget _buildCategory(int index, Category category) {
    return InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) =>
                    EditCategoryPage(passedCategory: category)),
          );
          await fetchCategories();
        },
        child: ListTile(
            leading: Container(
                width: 40,
                height: 40,
                child: Icon(
                  category.icon,
                  size: 20,
                  color: Colors.white,
                ),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: category.color,
                )),
            title: Text(category.name, style: _biggerFont)));
  }

  @override
  Widget build(BuildContext context) {
    return _buildCategories();
  }

}
