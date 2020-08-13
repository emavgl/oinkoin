import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/records/edit-record-page.dart';
import './i18n/categories-grid-list.i18n.dart';


class CategoriesGrid extends StatefulWidget {

  /// CategoriesGrid fetches the categories of a given Category type
  /// and renders them using a GridView. By default, it returns the
  /// selected category. If you pass the parameter goToEditMovementPage=true
  /// when selecting a category, it will go to EditMovementPage.

  /// CategoriesList fetches the categories of a given categoryType (input parameter)
  /// and renders them using a vertical ListView.

  List<Category> categories;

  bool goToEditMovementPage;

  CategoriesGrid(this.categories, {this.goToEditMovementPage});

  @override
  CategoriesGridState createState() => CategoriesGridState();
}

class CategoriesGridState extends State<CategoriesGrid> {
  
  Widget _buildCategories() {
    return GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        children: List.generate(widget.categories.length, (index) {
          return _buildCategory(widget.categories[index]);
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
      child: Container(
        margin: EdgeInsets.all(5),
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
            Flexible(
              child: Container(
                margin: EdgeInsets.fromLTRB(0, 10, 0, 0),
                child:  Text( category.name, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis,),
              ),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.categories != null ? new Container(
        margin: EdgeInsets.all(15),
        child: widget.categories.length == 0 ? new Column(
          children: <Widget>[
            Image.asset(
              'assets/no_entry_2.png', width: 200,
            ),
            Text("No categories yet.".i18n,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22.0,) ,)
          ],
        ) : _buildCategories()
    ) : new Container();
  }
}
