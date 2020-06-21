import 'package:flutter/material.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/categories/edit-category-page.dart';
import 'package:piggybank/services/database/database-interface.dart';
import 'package:piggybank/services/service-config.dart';

class CategoriesList extends StatefulWidget {

  /// CategoriesList fetches the categories of a given categoryType (input parameter)
  /// and renders them using a vertical ListView.

  CategoryType categoryType;

  CategoriesList({Key key, this.categoryType}) : super(key: key);

  @override
  CategoriesListState createState() => CategoriesListState(categoryType);
}

class CategoriesListState extends State<CategoriesList> {
  List<Category> _categories = new List();
  int indexTab;
  CategoryType categoryType;

  DatabaseInterface database = ServiceConfig.database;

  CategoriesListState(this.categoryType);

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

  final _biggerFont = const TextStyle(fontSize: 18.0);

  Widget _buildCategories() {
    return ListView.separated(
        shrinkWrap: true,
        separatorBuilder: (context, index) => Divider(),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _categories.length,
        padding: const EdgeInsets.all(6.0),
        itemBuilder: /*1*/ (context, i) {
          return _buildCategory(_categories[i]);
        });
  }


  Widget _buildCategory(Category category) {
    return InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) =>
                    EditCategoryPage(passedCategory: category)),
          );
          await fetchCategories();
        },
        child: ListTile(
            leading: Container(
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
                )),
            title: Text(category.name, style: _biggerFont)));
  }

  @override
  Widget build(BuildContext context) {
    return _categories.length == 0 ? Container(
        margin: EdgeInsets.all(15),
        child: Column(
          children: <Widget>[
            Image.asset(
              'assets/no_entry_2.png', width: 200,
            ),
            Text("No categories yet.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22.0,) ,)
          ],
        )
    ) : _buildCategories();
  }

}
