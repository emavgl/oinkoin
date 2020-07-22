import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:piggybank/categories/categories-list.dart';
import 'package:piggybank/categories/edit-category-page.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/services/database/database-interface.dart';
import 'package:piggybank/services/service-config.dart';
import './i18n/categories-tab-page.i18n.dart';

class CategoryTabPageEdit extends StatefulWidget {

  /// The category page that you can select from the bottom navigation bar.
  /// It contains two tab, showing the categories for expenses and categories
  /// for incomes. It has a single Floating Button that, dependending from which
  /// tab you clicked, it open the EditCategory page passing the selected Category type.

  @override
  CategoryTabPageEditState createState() => CategoryTabPageEditState();
}

class CategoryTabPageEditState extends State<CategoryTabPageEdit> with SingleTickerProviderStateMixin {

  List<Category> _categories;
  CategoryType categoryType;
  TabController _tabController;
  DatabaseInterface database = ServiceConfig.database;

  @override
  void initState() {
    super.initState();
    _tabController = new TabController(length: 2, vsync: this);
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
            controller: _tabController,
            tabs: [
              Tab(text: "Expenses".i18n,),
              Tab(text: "Income".i18n,),
            ],
          ),
          title: Text('Categories'.i18n),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _categories != null ? CategoriesList(_categories.where((element) => element.categoryType == CategoryType.expense).toList(), callback: refreshCategories) : Container(),
            _categories != null ? CategoriesList(_categories.where((element) => element.categoryType == CategoryType.income).toList(), callback: refreshCategories) : Container(),
          ],
        ),
        floatingActionButton: SpeedDial(
          animatedIcon: AnimatedIcons.menu_close,
          childBottomMargin: 16,
          marginRight: 14,
          children: [
            SpeedDialChild(
              child: Icon(FontAwesomeIcons.moneyBillWave),
              label: "Add a new 'Expense' category".i18n,
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => EditCategoryPage(categoryType: CategoryType.expense)),
                );
                await refreshCategories();
                if (_tabController.index == 1)
                  _tabController.animateTo(0);
              }
            ),
            SpeedDialChild(
                child: Icon(FontAwesomeIcons.handHoldingUsd),
                label: "Add a new 'Income' category".i18n,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => EditCategoryPage(categoryType: CategoryType.income)),
                  );
                  await refreshCategories();
                  if (_tabController.index == 0)
                    _tabController.animateTo(1);
                }
            ),
          ],
        ),
      ),
    );
  }

}
