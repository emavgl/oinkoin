import 'package:flutter/material.dart';
import 'package:piggybank/categories/categories-list.dart';
import 'package:piggybank/categories/edit-category-page.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/services/database/database-interface.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/i18n.dart';

class TabCategories extends StatefulWidget {
  /// The category page that you can select from the bottom navigation bar.
  /// It contains two tab, showing the categories for expenses and categories
  /// for incomes. It has a single Floating Button that, dependending from which
  /// tab you clicked, it open the EditCategory page passing the selected Category type.

  TabCategories({Key? key}) : super(key: key);

  @override
  TabCategoriesState createState() => TabCategoriesState();
}

class TabCategoriesState extends State<TabCategories>
    with SingleTickerProviderStateMixin {
  List<Category?>? _categories;
  CategoryType? categoryType;
  TabController? _tabController;
  DatabaseInterface database = ServiceConfig.database;
  bool showArchived = false;
  String activeCategoryTitle = 'Categories'.i18n;
  late String titleBarStr;
  double _fabRotation = 0.0;
  int _previousTabIndex = 0;

  @override
  void initState() {
    super.initState();
    titleBarStr = activeCategoryTitle;
    _tabController = new TabController(length: 2, vsync: this);
    _tabController!.addListener(_handleTabChange);
    database.getAllCategories().then((categories) => {
          setState(() {
            _categories = categories;
          })
        });
  }

  void _handleTabChange() {
    // Check if the tab index has actually changed (works for both clicks and swipes)
    if (_tabController!.index != _previousTabIndex &&
        !_tabController!.indexIsChanging) {
      setState(() {
        _fabRotation += 3.14159; // 180 degrees rotation
        _previousTabIndex = _tabController!.index;
      });
    }
  }

  @override
  void dispose() {
    _tabController?.removeListener(_handleTabChange);
    _tabController?.dispose();
    super.dispose();
  }

  refreshCategories() async {
    var newlyFetchedCategories = await database.getAllCategories();
    setState(() {
      _categories = newlyFetchedCategories;
    });
  }

  refreshCategoriesAndHighlightsTab(int destionationTabIndex) async {
    var newlyFetchedCategories = await database.getAllCategories();
    setState(() {
      _categories = newlyFetchedCategories;
    });
    await Future.delayed(Duration(milliseconds: 50));
    if (_tabController!.index != destionationTabIndex) {
      _tabController!.animateTo(destionationTabIndex);
    }
  }

  onTabChange() async {
    await refreshCategories();
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
                Tab(
                  text: "Expenses".i18n.toUpperCase(),
                ),
                Tab(
                  text: "Income".i18n.toUpperCase(),
                ),
              ],
            ),
            title: Text(titleBarStr),
            actions: [
              PopupMenuButton<int>(
                icon: Icon(Icons.more_vert),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(
                    Radius.circular(10.0),
                  ),
                ),
                onSelected: (index) async {
                  if (index == 1) {
                    setState(() {
                      showArchived = !showArchived;
                      if (showArchived) {
                        titleBarStr = "Archived Categories".i18n;
                      } else {
                        titleBarStr = activeCategoryTitle;
                      }
                    });
                  }
                },
                itemBuilder: (BuildContext context) {
                  var archivedOptionStr = showArchived
                      ? "Show active categories".i18n
                      : "Show archived categories".i18n;
                  return {archivedOptionStr: 1}.entries.map((entry) {
                    return PopupMenuItem<int>(
                      padding: EdgeInsets.all(20),
                      value: entry.value,
                      child: Text(entry.key,
                          style: TextStyle(
                            fontSize: 16,
                          )),
                    );
                  }).toList();
                },
              ),
            ]),
        body: TabBarView(
          controller: _tabController,
          children: [
            _categories != null
                ? CategoriesList(
                    _categories!
                        .where((element) =>
                            element!.categoryType == CategoryType.expense &&
                            element.isArchived == showArchived)
                        .toList(),
                    callback: refreshCategories)
                : Container(),
            _categories != null
                ? CategoriesList(
                    _categories!
                        .where((element) =>
                            element!.categoryType == CategoryType.income &&
                            element.isArchived == showArchived)
                        .toList(),
                    callback: refreshCategories)
                : Container(),
          ],
        ),
        floatingActionButton: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: _fabRotation),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            builder: (context, rotation, child) {
              return Transform.rotate(
                angle: rotation,
                child: FloatingActionButton(
                  backgroundColor: _tabController?.index == 0
                      ? Colors.red[300]
                      : Colors.green[300],
                  onPressed: () async {
                    if (_tabController?.index == 0) {
                      // Expenses tab
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => EditCategoryPage(
                                categoryType: CategoryType.expense)),
                      );
                      await refreshCategoriesAndHighlightsTab(0);
                    } else {
                      // Income tab
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => EditCategoryPage(
                                categoryType: CategoryType.income)),
                      );
                      await refreshCategoriesAndHighlightsTab(1);
                    }
                  },
                  child: const Icon(Icons.add, color: Colors.white),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
