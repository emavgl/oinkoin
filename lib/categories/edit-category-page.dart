
import 'package:flutter/material.dart';
import 'package:piggybank/helpers/alert-dialog-builder.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/services/database/database-interface.dart';
import 'package:piggybank/services/service-config.dart';
import '../style.dart';
import './i18n/edit-category-page.i18n.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class EditCategoryPage extends StatefulWidget {

  /// EditCategoryPage is a page containing forms for the editing of a Category object.
  /// EditCategoryPage can take the category object to edit as a constructor parameters
  /// or can create a new Category otherwise.
  
  Category passedCategory;
  CategoryType categoryType;

  EditCategoryPage({Key key, this.passedCategory, this.categoryType}) : super(key: key);

  @override
  EditCategoryPageState createState() => EditCategoryPageState(passedCategory, categoryType);
}

class EditCategoryPageState extends State<EditCategoryPage> {

  Category passedCategory;
  Category category;
  CategoryType categoryType;

  EditCategoryPageState(this.passedCategory, this.categoryType);


  int chosenColorIndex; // Index of the Category.color list for showing the selected color in the list
  int chosenIconIndex; // Index of the Category.icons list for showing the selected color in the list

  DatabaseInterface database = ServiceConfig.database;

  final _formKey = GlobalKey<FormState>();

  Category initCategory(){
    Category category = new Category(null);
    if (this.passedCategory == null) {
      category.color = Category.colors[0];
      category.icon = Category.icons[0];
      category.iconCodePoint = category.icon.codePoint;
      category.categoryType = categoryType;
    } else {
      category.icon = passedCategory.icon;
      category.name = passedCategory.name;
      category.color = passedCategory.color;
      category.categoryType = passedCategory.categoryType;
    }
    return category;
  }

  @override
  void initState() {
    super.initState();
    category = initCategory();
    chosenIconIndex = Category.icons.indexOf(category.icon);
    chosenColorIndex = Category.colors.indexOf(category.color);
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
                    category.icon = Category.icons[index];
                    category.iconCodePoint = category.icon.codePoint;
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
                            category.color = Category.colors[index];
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
              color: category.color, // button color
              child: InkWell(
                splashColor: category.color, // inkwell color
                child: SizedBox(width: 70, height: 70,
                    child: Icon(category.icon, color: Colors.white, size: 30,),
                ),
                onTap: () {},
              )
          )
      )
    );
  }

  Widget _getTextField() {
    return Expanded(
        child: Form(
          key: _formKey,
          child: Container(
            margin: EdgeInsets.all(10),
            child: TextFormField(
                onChanged: (text) {
                  setState(() {
                    category.name = text;
                  });
                },
                validator: (value) {
                  if (value.isEmpty) {
                    return "Please enter the category name".i18n;
                  }
                  return null;
                },
                initialValue: category.name,
                style: TextStyle(
                    fontSize: 22.0,
                    color: Colors.black
                ),
                decoration: InputDecoration(
                    hintText: "Category name".i18n,
                    border: OutlineInputBorder(),
                    errorStyle: TextStyle(
                      fontSize: 16.0,
                    ),
                )),
      ),
        ));
  }

  Widget _getAppBar() {
    return AppBar(
        title: Text("Edit category".i18n),
        actions: <Widget>[
          Visibility(
            visible: widget.passedCategory != null,
            child: IconButton(
              icon: const Icon(Icons.delete),
              tooltip: "Delete".i18n, onPressed: () async {
                // Prompt confirmation
                AlertDialogBuilder deleteDialog = AlertDialogBuilder("Do you really want to delete the category?".i18n)
                      .addSubtitle("Deleting the category you will remove all the associated records".i18n)
                      .addTrueButtonName("Yes".i18n)
                      .addFalseButtonName("No".i18n);

                var continueDelete = await showDialog(context: context, builder: (BuildContext context) {
                  return deleteDialog.build(context);
                });

                if (continueDelete) {
                  database.deleteCategory(widget.passedCategory.name, widget.passedCategory.categoryType);
                  Navigator.pop(context);
                }
            },
          )
        ),
          IconButton(
              icon: const Icon(Icons.save),
              tooltip: "Save".i18n, onPressed: () async {
                if (_formKey.currentState.validate()) {
                  var existingCategory = await database.getCategory(category.name, category.categoryType);
                  if (existingCategory == null) {
                    await database.addCategory(category);
                  } else {
                    await database.updateCategory(category);
                  }
                  Navigator.pop(context);
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
                _getPageSeparatorLabel("Color".i18n),
                _createColorsList(),
                _getPageSeparatorLabel("Icons".i18n),
                _getIconsGrid()
              ],
            ),
          ),
        ),
      ],
    ));
  }
}