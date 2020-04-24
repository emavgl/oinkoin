
import 'package:flutter/material.dart';
import 'package:piggybank/components/days-summary-box-card.dart';
import 'package:piggybank/helpers/movements-generator.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/movements-per-day.dart';
import 'package:piggybank/models/movement.dart';
import 'package:piggybank/services/movements-in-memory-database.dart';

import '../components/movements-group-card.dart';

class EditCategoryPage extends StatefulWidget {

  @override
  EditCategoryPageState createState() => EditCategoryPageState();
}

class EditCategoryPageState extends State<EditCategoryPage> {

  List<Color> colors = [
    Colors.green[300],
    Colors.red[300],
    Colors.blue[300],
    Colors.orange[300],
    Colors.yellow[600],
    Colors.purple[200],
    Colors.grey,
    Colors.black,
  ];

  Color chosenColor;
  IconData chosenIcon;

  @override
  void initState() {
    super.initState();
    chosenColor = colors[0];
    chosenIcon = Icons.category;
  }

  Widget _createColorsGrid() {
    return GridView.count(
      // Create a grid with 2 columns. If you change the scrollDirection to
      // horizontal, this produces 2 rows.
      crossAxisCount: 4,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: EdgeInsets.all(20),
      // Generate 100 widgets that display their index in the List.
      children: List.generate(colors.length, (index) {
        return Container(
          margin: EdgeInsets.all(15),
          child: ClipOval(
            child: Material(
            color: colors[index], // button color
            child: InkWell(
              splashColor: Colors.white30, // inkwell color
              onTap: () {
                setState(() {
                  chosenColor = colors[index];
                });
              },
            ),
          ))
        );
      }),
    );

  }

  Widget _createCategoryCirclePreview() {
    return Container(
      margin: EdgeInsets.all(10),
      child: ClipOval(
          child: Material(
              color: chosenColor, // button color
              child: InkWell(
                splashColor: chosenColor, // inkwell color
                child: SizedBox(width: 150, height: 150,
                    child: Column(
                      children: <Widget>[
                        Expanded(
                          flex: 10,
                          child: Icon(chosenIcon, color: Colors.white, size: 82,),
                        ),
                        Expanded(
                          flex: 4,
                          child: SizedBox(width: 60, height: 50, child:
                          Text("Change Icon", softWrap: true, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold ), textAlign: TextAlign.center,)
                        ) ,
                        )

                      ],
                )),
                onTap: () {},
              )
          )
      )
    );
  }

  Widget _getTextField() {
    return Container(
        margin: EdgeInsets.all(20),
        child: TextField(
        decoration: InputDecoration(
        border: OutlineInputBorder()
    )));
  }

  Widget _getAppBar() {
    return AppBar(
        title: const Text('AppBar Demo'),
        actions: <Widget>[
        IconButton(
          icon: const Icon(Icons.save),
          tooltip: 'Show Snackbar', onPressed: () {},
        )]
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _getAppBar(),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                Container(child: _createColorsGrid()),
                Container(child: _createCategoryCirclePreview()),
                Container(child: _getTextField()),
              ],
            ),
          ),
        ),
      ],
    );
  }
}