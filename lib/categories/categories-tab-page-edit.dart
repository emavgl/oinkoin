import 'package:flutter/material.dart';
import 'package:piggybank/categories/categories-list.dart';
import 'package:piggybank/categories/category-sort-option.dart';
import 'package:piggybank/categories/edit-category-page.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/services/database/database-interface.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/settings/constants/preferences-keys.dart';
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

  SortOption _selectedSortOption = SortOption.original;
  SortOption _storedDefaultOption = SortOption.original;
  bool _isDefaultOrder = false;

  @override
  void initState() {
    super.initState();
    titleBarStr = activeCategoryTitle;
    _tabController = new TabController(length: 2, vsync: this);
    _tabController!.addListener(_handleTabChange);
    _fetchCategories().then((_) => _initializeSortPreference());
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

  Future<void> _fetchCategories() async {
    List<Category?> categories = await database.getAllCategories();
    categories.sort((a, b) => a!.sortOrder!.compareTo(b!.sortOrder!));
    setState(() {
      _categories = categories;
    });
  }

  // Load the user's preferred sorting order from shared preferences
  Future<void> _initializeSortPreference() async {
    _selectedSortOption = SortOption.original;
    String key = PreferencesKeys.categoryListSortOption;
    if (ServiceConfig.sharedPreferences!.containsKey(key)) {
      final savedSortIndex = ServiceConfig.sharedPreferences?.getInt(key);
      if (savedSortIndex != null) {
        setState(() {
          _storedDefaultOption = SortOption.values[savedSortIndex];
          _selectedSortOption = SortOption.values[savedSortIndex];
        });
        _applySort(_selectedSortOption);
      }
    }
  }

  // Store the user's selected sort option in shared preferences
  Future<void> storeOnUserPreferences() async {
    if (_isDefaultOrder) {
      await ServiceConfig.sharedPreferences
          ?.setInt(PreferencesKeys.categoryListSortOption, _selectedSortOption.index);
      setState(() {
        _storedDefaultOption = _selectedSortOption;
      });
    }
    _isDefaultOrder = false;
  }

  // Apply the sort based on the selected option
  void _applySort(SortOption sortOption) {
    switch (sortOption) {
      case SortOption.lastUsed:
        _sortByLastUsed();
        break;
      case SortOption.mostUsed:
        _sortByMostUsed();
        break;
      case SortOption.original:
        _fetchCategories();
        break;
      case SortOption.alphabetical:
        _sortAlphabetically();
        break;
    }
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding:
                      const EdgeInsets.only(left: 16.0, top: 16, right: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Order by".i18n,
                        style: TextStyle(
                          fontSize: 22,
                        ),
                      ),
                      Row(
                        children: [
                          Checkbox(
                            value: _isDefaultOrder || _selectedSortOption == _storedDefaultOption,
                            onChanged: (value) {
                              setModalState(() {
                                _isDefaultOrder = value ?? false;
                              });
                              storeOnUserPreferences();
                            },
                          ),
                          Text("Make it default".i18n),
                        ],
                      ),
                    ],
                  ),
                ),
                Divider(),
                ListTile(
                  leading: Icon(Icons.update),
                  title: Text(
                    "Last Used".i18n,
                    style: TextStyle(
                      color: _selectedSortOption == SortOption.lastUsed
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                  ),
                  trailing: _selectedSortOption == SortOption.lastUsed
                      ? Icon(Icons.check,
                          color: Theme.of(context).colorScheme.primary)
                      : null,
                  onTap: () {
                    setModalState(() {
                      _selectedSortOption = SortOption.lastUsed;
                      _applySort(_selectedSortOption);
                      storeOnUserPreferences();
                    });
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.abc),
                  title: Text(
                    "Name (Alphabetically)".i18n,
                    style: TextStyle(
                      color: _selectedSortOption == SortOption.alphabetical
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                  ),
                  trailing: _selectedSortOption == SortOption.alphabetical
                      ? Icon(Icons.check,
                      color: Theme.of(context).colorScheme.primary)
                      : null,
                  onTap: () {
                    setModalState(() {
                      _selectedSortOption = SortOption.alphabetical;
                      _applySort(_selectedSortOption);
                      storeOnUserPreferences();
                    });
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.trending_up),
                  title: Text(
                    "Most Used".i18n,
                    style: TextStyle(
                      color: _selectedSortOption == SortOption.mostUsed
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                  ),
                  trailing: _selectedSortOption == SortOption.mostUsed
                      ? Icon(Icons.check,
                          color: Theme.of(context).colorScheme.primary)
                      : null,
                  onTap: () {
                    setModalState(() {
                      _selectedSortOption = SortOption.mostUsed;
                      _applySort(_selectedSortOption);
                      storeOnUserPreferences();
                    });
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.reorder),
                  title: Text(
                    "Original Order".i18n,
                    style: TextStyle(
                      color: _selectedSortOption == SortOption.original
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                  ),
                  trailing: _selectedSortOption == SortOption.original
                      ? Icon(Icons.check,
                          color: Theme.of(context).colorScheme.primary)
                      : null,
                  onTap: () {
                    setModalState(() {
                      _selectedSortOption = SortOption.original;
                      _applySort(_selectedSortOption);
                      storeOnUserPreferences();
                    });
                    Navigator.pop(context);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _sortByLastUsed() {
    setState(() {
      _selectedSortOption = SortOption.lastUsed;
      _categories?.sort((a, b) {
        final aLastUsed = a?.lastUsed;
        final bLastUsed = b?.lastUsed;

        if (aLastUsed == null && bLastUsed == null)
          return 0; // keep original order
        if (aLastUsed == null) return 1; // 'a' comes after 'b' if 'a' is null
        if (bLastUsed == null) return -1; // 'a' comes before 'b' if 'b' is null

        return bLastUsed
            .compareTo(aLastUsed); // Regular comparison if both are non-null
      });
    });
  }

  void _sortByMostUsed() {
    setState(() {
      _selectedSortOption = SortOption.mostUsed;
      _categories?.sort((a, b) => b!.recordCount!.compareTo(a!.recordCount!));
    });
  }

  void _sortAlphabetically() {
    setState(() {
      _selectedSortOption = SortOption.alphabetical;
      _categories?.sort((a, b) => a!.name!.compareTo(b!.name!));
    });
  }

  refreshCategories() async {
    await _fetchCategories();
    _applySort(_selectedSortOption);
  }

  refreshCategoriesAndHighlightsTab(int destinationTabIndex) async {
    await _fetchCategories();
    _applySort(_selectedSortOption);
    await Future.delayed(Duration(milliseconds: 50));
    if (_tabController!.index != destinationTabIndex) {
      _tabController!.animateTo(destinationTabIndex);
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
              IconButton(
                icon: Icon(Icons.sort),
                onPressed: _showSortOptions,
              ),
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
