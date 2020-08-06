import 'package:flutter/material.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/services/database/database-interface.dart';
import 'package:piggybank/services/service-config.dart';

import 'categories-grid.dart';
import './i18n/categories-tab-page.i18n.dart';


class CategoryTabPageView extends StatefulWidget {

  /// The category page that you can select from the bottom navigation bar.
  /// It contains two tab, showing the categories for expenses and categories
  /// for incomes. It has a single Floating Button that, dependending from which
  /// tab you clicked, it open the EditCategory page passing the selected Category type.

  bool goToEditMovementPage;
  CategoryTabPageView({this.goToEditMovementPage});

  @override
  CategoryTabPageViewState createState() => CategoryTabPageViewState();
}

class CategoryTabPageViewState extends State<CategoryTabPageView> {

  List<Category> _categories;
  CategoryType categoryType;

  DatabaseInterface database = ServiceConfig.database;

  @override
  void initState() {
    super.initState();
    database.getAllCategories().then((categories) => {
      setState(() {
        _categories = categories;
      })
    });
  }

  refreshCategories() async {
    var newlyFetchedCategories = await database.getAllCategories();
    setState(() {
      _categories = newlyFetchedCategories;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          bottom: TabBar(
            tabs: [
              Tab(text: "Expenses".i18n,),
              Tab(text: "Income".i18n,)
            ],
          ),
          title: Text('Select the category'.i18n),
        ),
        body: TabBarView(
          children: [
            _categories != null ? CategoriesGrid(_categories.where((element) => element.categoryType == CategoryType.expense).toList(), goToEditMovementPage: widget.goToEditMovementPage) : Container(),
            _categories != null ? CategoriesGrid(_categories.where((element) => element.categoryType == CategoryType.income).toList(), goToEditMovementPage: widget.goToEditMovementPage) : Container(),
          ],
        ),
      ),
    );
  }


}
