import 'package:flutter/material.dart';
import 'package:piggybank/categories/categories-grid.dart';


class CategoryTabPageView extends StatefulWidget {

  /// The category page that you can select from the bottom navigation bar.
  /// It contains two tab, showing the categories for expenses and categories
  /// for incomes. It has a single Floating Button that, dependending from which
  /// tab you clicked, it open the EditCategory page passing the selected Category type.

  bool goToEditMovementPage;
  CategoryTabPageView({Key key, this.goToEditMovementPage=false})
      : super(key: key);

  @override
  CategoryTabPageViewState createState() => CategoryTabPageViewState();
}

class CategoryTabPageViewState extends State<CategoryTabPageView> {

  int indexTab;

  final GlobalKey<CategoriesGridState> _expensesCategoryKey = GlobalKey();
  final GlobalKey<CategoriesGridState> _incomingCategoryKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    indexTab = 0;
  }

  void refreshExpenseCategoriesList() async {
    await _expensesCategoryKey.currentState.fetchCategories();
  }

  void refreshIncomeCategoriesList() async {
    await _incomingCategoryKey.currentState.fetchCategories();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          bottom: TabBar(
            onTap: (index){
              setState(() {
                indexTab = index;
              });
            },
            tabs: [
              Tab(text: "Expenses",),
              Tab(text: "Income",)
            ],
          ),
          title: Text('Select the category'),
        ),
        body: TabBarView(
          children: [
            CategoriesGrid(key: _expensesCategoryKey,categoryType: 0, goToEditMovementPage: widget.goToEditMovementPage,),
            CategoriesGrid(key: _incomingCategoryKey, categoryType: 1, goToEditMovementPage: widget.goToEditMovementPage,),
          ],
        ),
      ),
    );
  }

}
