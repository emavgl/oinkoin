import 'dart:math';

import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/categories/edit-category-page.dart';
import 'package:piggybank/movements/edit-movement-page.dart';
import 'package:piggybank/services/database-service.dart';
import 'package:piggybank/services/inmemory-database.dart';
import './i18n/categories-page.i18n.dart';

import '../movements/movements-group-card.dart';

class CategoriesGrid extends StatefulWidget {

  /// CategoriesGrid fetches the categories of a given Category type
  /// and renders them using a GridView. By default, it returns the
  /// selected category. If you pass the parameter goToEditMovementPage=true
  /// when selecting a category, it will go to EditMovementPage.

  int categoryType;
  bool goToEditMovementPage;

  CategoriesGrid({Key key, this.categoryType, this.goToEditMovementPage=false})
      : super(key: key);

  @override
  CategoriesGridState createState() => CategoriesGridState(categoryType);
}

class CategoriesGridState extends State<CategoriesGrid> {
  List<Category> _categories = new List();
  int indexTab;
  int categoryType;

  DatabaseService database = new InMemoryDatabase();

  CategoriesGridState(this.categoryType);

  fetchCategories() async {
    var categories = await database.getCategoriesByType(categoryType);
    setState(() {
      _categories = categories;
    });
  }

  @override
  void initState() {
    super.initState();
    indexTab = 0;
    fetchCategories();
  }

  Widget _buildCategories() {
    return GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        children: List.generate(_categories.length, (index) {
          return _buildCategory(_categories[index]);
        }),
    );
  }

  Widget _buildCategory(Category category) {
    return InkWell(
        onTap: () async {
          if (widget.goToEditMovementPage != null && widget.goToEditMovementPage) {
            // navigate to EditMovementPage
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => EditMovementPage(passedCategory: category)
                )
            );
          } else {
            // navigate back to the caller, passing the selected Category
            Navigator.pop(context, category);
          }
        },
        child: Padding(
          padding: EdgeInsets.all(15),
          child: Column(
            children: [
              Container(
                  width: 40,
                  height: 40,
                  child: Icon(
                    category.icon,
                    size: 20,
                    color: Colors.white,
                  ),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: category.color,
                  )
              ),
              Container(
                margin: EdgeInsets.fromLTRB(0, 10, 0, 0),
                child:  Text(category.name),
              )
            ],
          ),
        )
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildCategories();
  }

}
