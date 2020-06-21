import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:piggybank/categories/categories-list.dart';
import 'package:piggybank/categories/edit-category-page.dart';
import 'package:piggybank/models/category-type.dart';
import './i18n/categories-tab-page.i18n.dart';

class CategoryTabPageEdit extends StatefulWidget {

  /// The category page that you can select from the bottom navigation bar.
  /// It contains two tab, showing the categories for expenses and categories
  /// for incomes. It has a single Floating Button that, dependending from which
  /// tab you clicked, it open the EditCategory page passing the selected Category type.


  GlobalKey<CategoriesListState> _expensesCategoryKey = GlobalKey();
  GlobalKey<CategoriesListState> _incomingCategoryKey = GlobalKey();

  CategoriesList expenseSubPage;
  CategoriesList incomeSubPage;

  CategoryTabPageEdit({Key key}) : super(key: key) {
    expenseSubPage = CategoriesList(key: _expensesCategoryKey, categoryType: CategoryType.expense);
    incomeSubPage = CategoriesList(key: _incomingCategoryKey, categoryType: CategoryType.income);
  }

  @override
  CategoryTabPageEditState createState() => CategoryTabPageEditState();
}

class CategoryTabPageEditState extends State<CategoryTabPageEdit> {

  int indexTab;


  @override
  void initState() {
    super.initState();
    indexTab = 0;
  }

  void refreshExpenseCategoriesList() async {
    if (widget._expensesCategoryKey.currentState != null) {
      print("refreshExpenseCategoriesList called");
      await widget._expensesCategoryKey.currentState.fetchCategories();
    }
  }

  void refreshIncomeCategoriesList() async {
    if (widget._incomingCategoryKey.currentState != null) {
      print("refreshIncomeCategoriesList called");
      await widget._incomingCategoryKey.currentState.fetchCategories();
    }
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
              if (index == 0)
                await refreshExpenseCategoriesList();
              else
                await refreshIncomeCategoriesList();
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
            widget.expenseSubPage,
            widget.incomeSubPage
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: ()  async {
            if (indexTab == 0) {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => EditCategoryPage(categoryType: CategoryType.expense)),
              );
              await refreshExpenseCategoriesList();
            }
            if (indexTab == 1) {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => EditCategoryPage(categoryType: CategoryType.income)),
              );
              await refreshIncomeCategoriesList();
            }
          },
          tooltip: 'Increment Counter',
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

}
