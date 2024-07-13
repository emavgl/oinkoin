import 'package:flutter/material.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/categories/edit-category-page.dart';
import 'package:piggybank/i18n.dart';

class CategoriesList extends StatefulWidget {
  /// CategoriesList fetches the categories of a given categoryType (input parameter)
  /// and renders them using a vertical ListView.

  final List<Category?> categories;
  final void Function()? callback;

  CategoriesList(this.categories, {this.callback});

  @override
  CategoriesListState createState() => CategoriesListState();
}

class CategoriesListState extends State<CategoriesList> {
  @override
  void initState() {
    super.initState();
  }

  final _biggerFont = const TextStyle(fontSize: 18.0);

  Widget _buildCategories() {
    return ListView.separated(
        separatorBuilder: (context, index) => Divider(
              thickness: 0.5,
            ),
        itemCount: widget.categories.length,
        padding: const EdgeInsets.all(6.0),
        itemBuilder: /*1*/ (context, i) {
          return _buildCategory(widget.categories[i]!);
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
          if (widget.callback != null) widget.callback!();
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
            title: Text(category.name!, style: _biggerFont)));
  }

  @override
  Widget build(BuildContext context) {
    // ignore: unnecessary_null_comparison
    return widget.categories != null
        ? new Container(
            margin: EdgeInsets.all(15),
            child: widget.categories.length == 0
                ? new Column(
                    children: <Widget>[
                      Image.asset(
                        'assets/images/no_entry_2.png',
                        width: 200,
                      ),
                      Text(
                        "No categories yet.".i18n,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22.0,
                        ),
                      )
                    ],
                  )
                : _buildCategories())
        : new Container();
  }
}
