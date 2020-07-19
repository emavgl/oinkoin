import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
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

class CategoryTabPageEditState extends State<CategoryTabPageEdit> {

  int indexTab;
  List<Category> _categories;
  CategoryType categoryType;

  DatabaseInterface database = ServiceConfig.database;

  @override
  void initState() {
    super.initState();
    indexTab = 0;
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

  OpenContainer floatingButtonOpenContainer() {
    ContainerTransitionType _transitionType = ContainerTransitionType.fade;
    const double _fabDimension = 56.0;
    return OpenContainer(
      transitionType: _transitionType,
      openBuilder: (BuildContext context, VoidCallback _) {
        return EditCategoryPage(categoryType: CategoryType.values[indexTab]);
      },
      closedElevation: 6.0,
      closedShape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(
          Radius.circular(_fabDimension / 2),
        ),
      ),
      closedColor: Theme.of(context).colorScheme.secondary,
      closedBuilder: (BuildContext context, VoidCallback openContainer){
        return SizedBox(
          height: _fabDimension,
          width: _fabDimension,
          child: Center(
            child: Icon(
              Icons.add,
              color: Theme.of(context).colorScheme.onSecondary,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          bottom: TabBar(
            onTap: (index) async {
              setState(() {
                indexTab = index;
              });
            },
            tabs: [
              Tab(text: "Expenses".i18n,),
              Tab(text: "Income".i18n,),
            ],
          ),
          title: Text('Categories'.i18n),
        ),
        body: TabBarView(
          children: [
            _categories != null ? CategoriesList(_categories.where((element) => element.categoryType == CategoryType.expense).toList(), callback: refreshCategories) : Container(),
            _categories != null ? CategoriesList(_categories.where((element) => element.categoryType == CategoryType.income).toList(), callback: refreshCategories) : Container(),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: ()  async {
            var categoryType = indexTab == 0 ? CategoryType.expense : CategoryType.income;
            print("CategoryType: " + categoryType.toString());
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => EditCategoryPage(categoryType: categoryType)),
            );
            await refreshCategories();
          },
          tooltip: 'Increment Counter',
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

}
