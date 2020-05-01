
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:piggybank/components/days-summary-box-card.dart';
import 'package:piggybank/helpers/movements-generator.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/movements-per-day.dart';
import 'package:piggybank/models/movement.dart';
import 'package:piggybank/screens/edit-category-page.dart';
import 'package:piggybank/services/movements-in-memory-database.dart';
import '../i18n/categories-page.i18n.dart';

import '../components/movements-group-card.dart';

class CategoriesPage extends StatefulWidget {
  @override
  CategoriesPageState createState() => CategoriesPageState();
}

class CategoriesPageState extends State<CategoriesPage> {

  List<Category> _categories = new List();

  @override
  void initState() {
    super.initState();
    _categories = MovementsInMemoryDatabase.categories;
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
          return _buildCategory(i, _categories[i]);
        });
  }

  Widget _buildCategory(int index, Category category) {
    return
      InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => EditCategoryPage(passedCategory: category)),
          );
          _categories = MovementsInMemoryDatabase.categories;
        },
        child: ListTile(
            leading: Container(
                width: 40,
                height: 40,
                child: Icon(category.icon, size: 20, color: Colors.white,),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: category.color,
                )
            ),
            title: Text(category.name, style: _biggerFont)
        )
      );
  }

  showAlertDialog(BuildContext context) {
    // set up the button
    Widget okButton = FlatButton(
      child: Text("OK"),
      onPressed: () => Navigator.of(context).pop() // dismiss dialog,
    );

    // set up the AlertDialog
    AlertDialog alert = AlertDialog(
      title: Text("My title"),
      content: Text("This is my message."),
      actions: [
        okButton,
      ],
    );

    // show the dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return alert;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Categories'),
        actions: <Widget>[      // Add 3 lines from here...
          IconButton(icon: Icon(Icons.list), onPressed: (){},),
        ],
      ),
      body: _buildCategories(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => EditCategoryPage()),
          ).then((value) {
            setState(() {
              _categories = MovementsInMemoryDatabase.categories;
            });
          });
        },
        tooltip: 'Increment Counter',
        child: const Icon(Icons.add),
      ),
    );
  }
}