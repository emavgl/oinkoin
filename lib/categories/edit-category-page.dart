import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:piggybank/helpers/alert-dialog-builder.dart';
import 'package:piggybank/models/category-icons.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/premium/splash-screen.dart';
import 'package:piggybank/premium/util-widgets.dart';
import 'package:piggybank/services/database/database-interface.dart';
import 'package:piggybank/services/service-config.dart';
import '../style.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:piggybank/i18n.dart';

class EditCategoryPage extends StatefulWidget {
  /// EditCategoryPage is a page containing forms for the editing of a Category object.
  /// EditCategoryPage can take the category object to edit as a constructor parameters
  /// or can create a new Category otherwise.

  final Category? passedCategory;
  final CategoryType? categoryType;

  EditCategoryPage({Key? key, this.passedCategory, this.categoryType})
      : super(key: key);

  @override
  EditCategoryPageState createState() =>
      EditCategoryPageState(passedCategory, categoryType);
}

class EditCategoryPageState extends State<EditCategoryPage> {
  Category? passedCategory;
  Category? category;
  CategoryType? categoryType;
  late List<IconData?> icons;

  EditCategoryPageState(this.passedCategory, this.categoryType);

  int?
      chosenColorIndex; // Index of the Category.color list for showing the selected color in the list
  int?
      chosenIconIndex; // Index of the Category.icons list for showing the selected color in the list
  Color? pickedColor;
  String? categoryName;

  DatabaseInterface database = ServiceConfig.database;

  final _formKey = GlobalKey<FormState>();

  Category initCategory() {
    Category category = new Category(null);
    if (this.passedCategory == null) {
      category.color = Category.colors[0];
      category.icon = FontAwesomeIcons.question;
      category.iconCodePoint = category.icon!.codePoint;
      category.categoryType = categoryType;
    } else {
      category.icon = passedCategory!.icon;
      category.name = passedCategory!.name;
      categoryName = passedCategory!.name;
      category.color = passedCategory!.color;
      category.categoryType = passedCategory!.categoryType;
    }
    return category;
  }

  @override
  void initState() {
    super.initState();
    category = initCategory();
    icons = ServiceConfig.isPremium
        ? CategoryIcons.pro_category_icons
        : CategoryIcons.free_category_icons;
    chosenIconIndex = icons.indexOf(category!.icon);
    chosenColorIndex = Category.colors.indexOf(category!.color);
    if (chosenColorIndex == -1) {
      pickedColor = category!.color;
    }
  }

  Widget _getPageSeparatorLabel(String labelText) {
    TextStyle textStyle = TextStyle(
      fontFamily: FontNameDefault,
      fontWeight: FontWeight.w300,
      fontSize: 26.0,
      color: MaterialThemeInstance.currentTheme?.colorScheme.onSurface,
    );
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.fromLTRB(15, 15, 0, 5),
        child: Text(labelText, style: textStyle, textAlign: TextAlign.left),
      ),
    );
  }

  Widget _getIconsGrid() {
    return GridView.count(
      // Create a grid with 2 columns. If you change the scrollDirection to
      // horizontal, this produces 2 rows
      padding: EdgeInsets.all(0),
      crossAxisCount: 5,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      // Generate 100 widgets that display their index in the List.
      children: List.generate(icons.length, (index) {
        return Container(
            child: IconButton(
                // Use the FaIcon Widget + FontAwesomeIcons class for the IconData
                icon: FaIcon(icons[index]),
                color: ((chosenIconIndex == index)
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                onPressed: () {
                  setState(() {
                    category!.icon = icons[index];
                    category!.iconCodePoint = category!.icon!.codePoint;
                    chosenIconIndex = index;
                  });
                }));
      }),
    );
  }

  Widget _buildColorList() {
    return ListView.builder(
        shrinkWrap: true,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: Category.colors.length,
        itemBuilder: /*1*/ (context, index) {
          return Container(
              margin: EdgeInsets.all(10),
              child: Container(
                  width: 70,
                  child: ClipOval(
                      child: Material(
                    color: Category.colors[index], // button color
                    child: InkWell(
                      splashColor: Colors.white30, // inkwell color
                      child: (index == chosenColorIndex)
                          ? SizedBox(
                              width: 50,
                              height: 50,
                              child: Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 20,
                              ),
                            )
                          : Container(),
                      onTap: () {
                        setState(() {
                          category!.color = Category.colors[index];
                          chosenColorIndex = index;
                        });
                      },
                    ),
                  ))));
        });
  }

  Widget _createColorsList() {
    return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Container(
            height: 90,
            child: Row(
              children: [
                _createColorPickerCircle(),
                _buildColorList(),
              ],
            )));
  }

  Widget _createCategoryCirclePreview() {
    return Container(
        margin: EdgeInsets.all(10),
        child: ClipOval(
            child: Material(
                color: category!.color, // button color
                child: InkWell(
                  splashColor: category!.color, // inkwell color
                  child: SizedBox(
                    width: 70,
                    height: 70,
                    child: Icon(
                      category!.icon,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  onTap: () {},
                ))));
  }

  Widget _createColorPickerCircle() {
    return Container(
        margin: EdgeInsets.all(10),
        child: Stack(
          children: [
            ClipOval(
                child: Material(
              child: Container(
                  decoration: BoxDecoration(
                      gradient: LinearGradient(
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                          colors: pickedColor == null
                              ? [
                                  Colors.yellow,
                                  Colors.red,
                                  Colors.indigo,
                                  Colors.teal
                                ]
                              : [pickedColor!, pickedColor!])),
                  child: InkWell(
                    splashColor: category!.color, // inkwell color
                    child: SizedBox(
                      width: 70,
                      height: 70,
                      child: Icon(
                        Icons.colorize,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    onTap: ServiceConfig.isPremium
                        ? openColorPicker
                        : () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => PremiumSplashScreen()),
                            );
                          },
                  )), // button color
            )),
            ServiceConfig.isPremium ? Container() : getProLabel()
          ],
        ));
  }

  openColorPicker() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Container(
              padding: EdgeInsets.all(15),
              color: Theme.of(context).primaryColor,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Choose a color".i18n,
                    style: TextStyle(color: Colors.white),
                  ),
                  IconButton(
                      icon: const Icon(Icons.close),
                      color: Colors.white,
                      onPressed: () {
                        Navigator.of(context, rootNavigator: true)
                            .pop('dialog');
                      })
                ],
              )),
          titlePadding: const EdgeInsets.all(0.0),
          contentPadding: const EdgeInsets.all(0.0),
          content: SingleChildScrollView(
            child: MaterialPicker(
              pickerColor: category!.color!,
              onColorChanged: (newColor) {
                setState(() {
                  pickedColor = newColor;
                  category!.color = newColor;
                  chosenColorIndex = -1;
                });
              },
              enableLabel: false,
            ),
          ),
        );
      },
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
                categoryName = text;
              });
            },
            validator: (value) {
              if (value!.isEmpty) {
                return "Please enter the category name".i18n;
              }
              return null;
            },
            initialValue: categoryName,
            style: TextStyle(
                fontSize: 22.0, color: Theme.of(context).colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: "Category name".i18n,
              errorStyle: TextStyle(
                fontSize: 16.0,
              ),
            )),
      ),
    ));
  }

  Widget _getAppBar() {
    return AppBar(title: Text("Edit category".i18n), actions: <Widget>[
      Visibility(
          visible: widget.passedCategory != null,
          child: IconButton(
            icon: const Icon(Icons.delete),
            tooltip: "Delete".i18n,
            onPressed: () async {
              // Prompt confirmation
              AlertDialogBuilder deleteDialog = AlertDialogBuilder(
                      "Do you really want to delete the category?".i18n)
                  .addSubtitle(
                      "Deleting the category you will remove all the associated records".i18n)
                  .addTrueButtonName("Yes".i18n)
                  .addFalseButtonName("No".i18n);

              var continueDelete = await showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return deleteDialog.build(context);
                  });

              if (continueDelete) {
                database.deleteCategory(widget.passedCategory!.name,
                    widget.passedCategory!.categoryType);
                Navigator.pop(context);
              }
            },
          ))
    ]);
  }

  Widget _getPickColorCard() {
    return Container(
      child: Container(
        padding: EdgeInsets.only(bottom: 10),
        child: Column(
          children: [
            _getPageSeparatorLabel("Color".i18n),
            Divider(
              thickness: 0.5,
            ),
            _createColorsList(),
          ],
        ),
      ),
    );
  }

  Widget _getIconPickerCard() {
    return Container(
      child: Container(
        child: Column(
          children: [
            _getPageSeparatorLabel("Icon".i18n),
            Divider(
              thickness: 0.5,
            ),
            _getIconsGrid(),
          ],
        ),
      ),
    );
  }

  Widget _getPreviewAndTitleCard() {
    return Container(
        child: Column(
      children: [
        _getPageSeparatorLabel("Name".i18n),
        Divider(
          thickness: 0.5,
        ),
        Container(
          child: Row(
            children: <Widget>[
              Container(child: _createCategoryCirclePreview()),
              Container(child: _getTextField()),
            ],
          ),
        ),
      ],
    ));
  }

  saveCategory() async {
    if (_formKey.currentState!.validate()) {
      if (category!.name == null) {
        // Then it is a newly created category
        // Call the method add category
        category!.name = categoryName;
        await database.addCategory(category);
      } else {
        // If category.name is already set
        // I'm editing an existing category
        // Call the method updateCategory
        String? existingName = category!.name;
        var existingType = category!.categoryType;
        category!.name = categoryName;
        await database.updateCategory(existingName, existingType, category);
      }
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _getAppBar() as PreferredSizeWidget?,
      resizeToAvoidBottomInset: false,
      body: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            _getPreviewAndTitleCard(),
            _getPickColorCard(),
            _getIconPickerCard(),
            SizedBox(height: 75),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: saveCategory,
        tooltip: 'Add a new category'.i18n,
        child: const Icon(Icons.save),
      ),
    );
  }
}
