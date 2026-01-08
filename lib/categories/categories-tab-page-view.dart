import 'package:flutter/material.dart';
import 'package:piggybank/helpers/records-utility-functions.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/services/database/database-interface.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/i18n.dart';

import 'categories-grid.dart';

enum SortOption { original, lastUsed, mostUsed, alphabetical }

class CategoryTabPageView extends StatefulWidget {
  final bool? goToEditMovementPage;
  CategoryTabPageView({this.goToEditMovementPage, Key? key}) : super(key: key);

  @override
  CategoryTabPageViewState createState() => CategoryTabPageViewState();
}

class CategoryTabPageViewState extends State<CategoryTabPageView> {
  List<Category?>? _categories;
  CategoryType? categoryType;
  SortOption _selectedSortOption = SortOption.original;
  SortOption _storedDefaultOption = SortOption.original;
  bool _isDefaultOrder = false;
  DatabaseInterface database = ServiceConfig.database;

  @override
  void initState() {
    super.initState();
    _fetchCategories().then((_) {
      _initializeSortPreference();
    });
  }

  Future<void> _fetchCategories() async {
    List<Category?> categories = await database.getAllCategories();
    categories = categories.where((element) => !element!.isArchived).toList();
    categories.sort((a, b) => a!.sortOrder!.compareTo(b!.sortOrder!));
    setState(() {
      _categories = categories;
    });
  }

  // Load the user's preferred sorting order from shared preferences
  Future<void> _initializeSortPreference() async {
    _selectedSortOption = SortOption.original;
    String key = 'defaultCategorySortOption';
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
          ?.setInt('defaultCategorySortOption', _selectedSortOption.index);
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
                            value: _isDefaultOrder ||
                                _selectedSortOption == _storedDefaultOption,
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
    await _initializeSortPreference();
    await _fetchCategories();
  }

  Future<void> onCategoriesReorder(List<Category?> reorderedCategories) async {
    if (reorderedCategories.isEmpty) {
      return;
    }

    var categoryType = reorderedCategories.first!.categoryType;
    var originalOrder = _categories!
        .where((element) => element!.categoryType == categoryType)
        .toList();

    // Check if the order of the elements in `_categories` matches `reorderedCategories`
    bool hasChanged = false;
    for (int i = 0; i < reorderedCategories.length; i++) {
      if (originalOrder[i]?.name != reorderedCategories[i]?.name) {
        hasChanged = true;
        break;
      }
    }

    // If order has changed, update the database
    if (hasChanged) {
      await database.resetCategoryOrderIndexes(
          reorderedCategories.whereType<Category>().toList());
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Select the category'.i18n),
          actions: [
            IconButton(
              icon: Icon(Icons.sort),
              onPressed: _showSortOptions,
            ),
          ],
          bottom: TabBar(
            tabs: [
              Semantics(
                identifier: 'expenses-tab',
                child: Tab(text: "Expenses".i18n.toUpperCase()),
              ),
              Semantics(
                identifier: 'income-tab',
                child: Tab(
                  text: "Income".i18n.toUpperCase(),
                ),
              )
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _categories != null
                ? CategoriesGrid(
                    _categories!
                        .where((element) =>
                            element!.categoryType == CategoryType.expense)
                        .toList(),
                    goToEditMovementPage: widget.goToEditMovementPage,
                    enableManualSorting:
                        _selectedSortOption == SortOption.original,
                    onChangeOrder: onCategoriesReorder)
                : Container(),
            _categories != null
                ? CategoriesGrid(
                    _categories!
                        .where((element) =>
                            element!.categoryType == CategoryType.income)
                        .toList(),
                    goToEditMovementPage: widget.goToEditMovementPage,
                    enableManualSorting:
                        _selectedSortOption == SortOption.original,
                    onChangeOrder: onCategoriesReorder)
                : Container(),
          ],
        ),
      ),
    );
  }
}
