import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
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

  @override
  void initState() {
    super.initState();
    titleBarStr = activeCategoryTitle;
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
        floatingActionButton: SpeedDial(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          spacing: 20,
          childrenButtonSize: const Size(65, 65),
          animatedIcon: AnimatedIcons.menu_close,
          childPadding: EdgeInsets.fromLTRB(8, 8, 8, 8),
          children: [
            SpeedDialChild(
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                child: Icon(FontAwesomeIcons.moneyBillWave),
                label: "Add a new 'Expense' category".i18n,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => EditCategoryPage(
                            categoryType: CategoryType.expense)),
                  );
                  await refreshCategoriesAndHighlightsTab(0);
                }),
            SpeedDialChild(
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                child: Icon(FontAwesomeIcons.handHoldingDollar),
                label: "Add a new 'Income' category".i18n,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => EditCategoryPage(
                            categoryType: CategoryType.income)),
                  );
                  await refreshCategoriesAndHighlightsTab(1);
                }),
          ],
        ),
      ),
    );
  }
}
