import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/records/edit-record-page.dart';
import 'package:piggybank/services/database/database-interface.dart';
import 'package:piggybank/services/service-config.dart';


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

  DatabaseInterface database = ServiceConfig.database;

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
                    builder: (context) => EditRecordPage(passedCategory: category)
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
