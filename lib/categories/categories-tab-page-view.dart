import 'package:flutter/material.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/services/database/database-interface.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/i18n.dart';

import 'categories-grid.dart';

enum SortOption { original, lastUsed, mostUsed }

class CategoryTabPageView extends StatefulWidget {
  final bool? goToEditMovementPage;
  CategoryTabPageView({this.goToEditMovementPage});

  @override
  CategoryTabPageViewState createState() => CategoryTabPageViewState();
}

class CategoryTabPageViewState extends State<CategoryTabPageView> {
  List<Category?>? _categories;
  CategoryType? categoryType;
  SortOption _selectedSortOption = SortOption.original;
  bool _isDefaultOrder = false;
  DatabaseInterface database = ServiceConfig.database;

  @override
  void initState() {
    super.initState();
    _initializeSortPreference();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    var categories = await database.getAllCategories();
    setState(() {
      _categories = categories;
    });
  }

  // Load the user's preferred sorting order from shared preferences
  Future<void> _initializeSortPreference() async {
    String key = 'defaultCategorySortOption';
    if (ServiceConfig.sharedPreferences!.containsKey(key)) {
      final savedSortIndex = ServiceConfig.sharedPreferences?.getInt(key);
      if (savedSortIndex != null) {
        setState(() {
          _selectedSortOption = SortOption.values[savedSortIndex];
        });
        _applySort(_selectedSortOption);
      }
    }
    _selectedSortOption = SortOption.original;
  }

  // Store the user's selected sort option in shared preferences
  Future<void> storeOnUserPreferences() async {
    if (_isDefaultOrder) {
      await ServiceConfig.sharedPreferences
          ?.setInt('defaultCategorySortOption', _selectedSortOption.index);
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
                            value: _isDefaultOrder,
                            onChanged: (value) {
                              setModalState(() {
                                _isDefaultOrder = value ?? false;
                              });
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
                  title: Text("Last Used".i18n),
                  onTap: () {
                    _sortByLastUsed();
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.trending_up),
                  title: Text("Most Used".i18n),
                  onTap: () {
                    _sortByMostUsed();
                    Navigator.pop(context);
                  },
                ),
                if (_selectedSortOption !=
                    SortOption.original) // Show Original Order conditionally
                  ListTile(
                    leading: Icon(Icons.reorder),
                    title: Text("Original Order".i18n),
                    onTap: () {
                      _selectedSortOption = SortOption.original;
                      _fetchCategories();
                      storeOnUserPreferences();
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
    storeOnUserPreferences();
  }

  void _sortByMostUsed() {
    setState(() {
      _selectedSortOption = SortOption.mostUsed;
      _categories?.sort((a, b) => a!.recordCount!.compareTo(b!.recordCount!));
    });
    storeOnUserPreferences();
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
              Tab(text: "Expenses".i18n.toUpperCase()),
              Tab(text: "Income".i18n.toUpperCase()),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _categories != null
                ? CategoriesGrid(
                    _categories!
                        .where((element) =>
                            element!.categoryType == CategoryType.expense &&
                            !element.isArchived)
                        .toList(),
                    goToEditMovementPage: widget.goToEditMovementPage,
                  )
                : Container(),
            _categories != null
                ? CategoriesGrid(
                    _categories!
                        .where((element) =>
                            element!.categoryType == CategoryType.income &&
                            !element.isArchived)
                        .toList(),
                    goToEditMovementPage: widget.goToEditMovementPage,
                  )
                : Container(),
          ],
        ),
      ),
    );
  }
}
