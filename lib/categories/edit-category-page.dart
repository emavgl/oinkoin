
import 'package:flutter/material.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/services/database-service.dart';
import 'package:piggybank/services/inmemory-database.dart';
import '../style.dart';
import './i18n/edit-category-page.i18n.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class EditCategoryPage extends StatefulWidget {

  Category passedCategory;
  int categoryType;

  EditCategoryPage({Key key, this.passedCategory, this.categoryType}) : super(key: key);

  @override
  EditCategoryPageState createState() => EditCategoryPageState(passedCategory, categoryType);
}

class EditCategoryPageState extends State<EditCategoryPage> {

  Category category;
  int categoryType;

  EditCategoryPageState(this.category, this.categoryType);

  Color chosenColor;
  int chosenColorIndex;

  IconData chosenIcon;
  int chosenIconIndex;
  DatabaseService database = new InMemoryDatabase();


  @override
  void initState() {
    super.initState();
    if (this.category == null) {
      chosenColor = Category.colors[0];
      chosenIcon = FontAwesomeIcons.hamburger;
      chosenIconIndex = 0;
      chosenColorIndex = 0;
      category = new Category(null);
    } else {
      categoryType = category.categoryType;
      chosenIcon = category.icon;
      chosenIconIndex = Category.icons.indexOf(chosenIcon);
      chosenColor = category.color;
      chosenColorIndex = Category.colors.indexOf(chosenColor);
    }
  }

  Widget _getPageSeparatorLabel(String labelText) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.all(15),
        child: Text(labelText, style: Body1Style, textAlign: TextAlign.left),
      ),
    );
  }


  Widget _getIconsGrid() {
    return GridView.count(
      // Create a grid with 2 columns. If you change the scrollDirection to
      // horizontal, this produces 2 rows
      crossAxisCount: 5,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      // Generate 100 widgets that display their index in the List.
      children: List.generate(Category.icons.length, (index) {
        return Container(
            child: IconButton(
              // Use the FaIcon Widget + FontAwesomeIcons class for the IconData
                icon: FaIcon(Category.icons[index]),
                color: ((chosenIconIndex == index) ? Colors.blueAccent : Colors.black45),
                onPressed: () {
                  setState(() {
                    chosenIcon = Category.icons[index];
                    chosenIconIndex = index;
                });
                }
            )
        );
      }),
    );
  }

  Widget _buildColorList() {
      return ListView.builder(
          shrinkWrap: true,
          scrollDirection: Axis.horizontal,
          itemCount: Category.colors.length,
          itemBuilder: /*1*/ (context, index) {
            return Container(
                margin: EdgeInsets.all(10),
                child: Container(width: 70, child:
                ClipOval(
                    child: Material(
                      color: Category.colors[index], // button color
                      child: InkWell(
                        splashColor: Colors.white30, // inkwell color
                        child: (index == chosenColorIndex) ? SizedBox(width: 50, height: 50,
                          child: Icon(Icons.check, color: Colors.white, size: 20,),
                        ) : Container(),
                        onTap: () {
                          setState(() {
                            chosenColor = Category.colors[index];
                            chosenColorIndex = index;
                          });
                        },
                      ),
                    ))
                )
            );
      });
  }

  Widget _createColorsList() {
    return Container(
      height: 90,
      child: _buildColorList(),
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
                child: SizedBox(width: 70, height: 70,
                    child: Icon(chosenIcon, color: Colors.white, size: 30,),
                ),
                onTap: () {},
              )
          )
      )
    );
  }

  Widget _getTextField() {
    return Expanded(
        child: Container(
          margin: EdgeInsets.all(10),
          child: TextFormField(
              onChanged: (text) {
                setState(() {
                  category.name = text;
                });
              },
              initialValue: category.name,
              style: TextStyle(
                  fontSize: 22.0,
                  color: Colors.black
              ),
              decoration: InputDecoration(
                  hintText: "Category name",
                  border: OutlineInputBorder()
              )),
      ));
  }

  showAlertDialog(BuildContext context, yesButtonName, noButtonName, title, subtitle) async {
    // set up the button
    Widget okButton = FlatButton(
        child: Text(yesButtonName),
      onPressed: () => Navigator.of(context, rootNavigator: true).pop(true),
    );

    // set up the button
    Widget cancelButton = FlatButton(
      child: Text(noButtonName),
      onPressed: () => Navigator.of(context, rootNavigator: true).pop(false)
    );

    // set up the AlertDialog
    AlertDialog alert = AlertDialog(
      title: Text(title),
      content: Text(subtitle),
      actions: [
        okButton,
        cancelButton,
      ],
    );

    // show the dialog
    return await showDialog(
      context: context,
      builder: (BuildContext context) {
        return alert;
      },
    );
  }

  Widget _getAppBar() {
    return AppBar(
        title: Text('Edit category'.i18n),
        actions: <Widget>[
          Visibility(
            visible: widget.passedCategory != null,
            child: IconButton(
              icon: const Icon(Icons.delete),
              tooltip: 'Delete', onPressed: () async {
              var continueDelete = await showAlertDialog(context, "Yes", "No", "Do you really want to delete the category?", "Deleting the category you will remove all the associated expenses");
              if (continueDelete) {
                database.deleteCategoryById(widget.passedCategory.id);
                Navigator.pop(context);
              }
            },
          )
        ),
          IconButton(
              icon: const Icon(Icons.save),
              tooltip: 'Save', onPressed: () async {
            if (category.name != null && category.name.isNotEmpty) {
              category.categoryType = categoryType;
              category.color = chosenColor;
              category.icon = chosenIcon;
              category.iconCodePoint = chosenIcon.codePoint;
              database.upsertCategory(category);
              Navigator.pop(context);
            } else {
              await showAlertDialog(context, "OK", "Cancel", "Category name is missing", "You need to specify the category name");
            }
          }
          )]
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
        type: MaterialType.transparency,
        child: Column(
      children: <Widget>[
        _getAppBar(),
          Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(child: _createCategoryCirclePreview()),
                    Container(child: _getTextField()),
                  ],
                ),
                _getPageSeparatorLabel("Color"),
                _createColorsList(),
                _getPageSeparatorLabel("Icons"),
                _getIconsGrid()
              ],
            ),
          ),
        ),
      ],
    ));
  }
}