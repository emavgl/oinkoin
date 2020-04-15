
import 'package:flutter/material.dart';
import 'package:piggybank/components/days-summary-box-card.dart';
import 'package:piggybank/helpers/movements-generator.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/movements-per-day.dart';
import 'package:piggybank/models/movement.dart';
import 'package:piggybank/services/movements-in-memory-database.dart';

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

  Widget slideLeftBackground() {
    return Container(
      color: Colors.red,
      child: Align(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            Icon(
              Icons.delete,
              color: Colors.white,
            ),
            Text(
              " Delete",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.right,
            ),
            SizedBox(
              width: 20,
            ),
          ],
        ),
        alignment: Alignment.centerRight,
      ),
    );
  }


  Widget _buildCategory(int index, Category category) {
    String categoryName = category.name;
    return Dismissible(
      confirmDismiss: (DismissDirection direction) async {
        return await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text("Confirm"),
              content: const Text("Are you sure you wish to delete this item?"),
              actions: <Widget>[
                FlatButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text("CANCEL")
                ),
                FlatButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text("DELETE"),
                ),
              ],
            );
          },
        );
      },
      key: UniqueKey(),
      direction: DismissDirection.endToStart,
      background: slideLeftBackground(),
      onDismissed: (direction) {
        // Remove the item from the data source.
        setState(() {
          _categories.removeAt(index);
        });

        // Then show a snackbar.
        Scaffold.of(context)
            .showSnackBar(
              SnackBar(
                content: Text("Deleted category: " + categoryName),
                action: SnackBarAction(
                    label: "UNDO",
                    onPressed: () => setState(() => _categories.insert(index, category),) // this is what you needed
                ),
              )
        );
      },
      child: ListTile(
          leading: Container(
              width: 40,
              height: 40,
              child: Icon(Icons.attach_money, size: 20, color: Colors.white,),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: category.color,
              )
          ),
          title: Text(category.name, style: _biggerFont)
      ),
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
        onPressed: () => showAlertDialog(context),
        tooltip: 'Increment Counter',
        child: const Icon(Icons.add),
      ),
    );
  }
}