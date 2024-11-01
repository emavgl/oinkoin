import 'package:emoji_picker_flutter/emoji_picker_flutter.dart' as emojipicker;
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
  String currentEmoji = '😎'; // Default emoji

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
      category = Category.fromMap(passedCategory!.toMap());
      categoryName = passedCategory!.name;
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

    // Icon
    if (category!.icon == null && category!.iconEmoji != null) {
      chosenIconIndex = -1;
      currentEmoji = category!.iconEmoji!;
    } else {
      chosenIconIndex = icons.indexOf(category!.icon);
    }

    chosenColorIndex = Category.colors.indexOf(category!.color);
    if (chosenColorIndex == -1) {
      pickedColor = category!.color;
    }
    if (chosenColorIndex == -2) {
      pickedColor = null;
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

  bool _emojiShowing = false;
  TextEditingController _controller = TextEditingController();

  Widget _getIconsGrid() {
    var surfaceContainer = Theme.of(context).colorScheme.surfaceContainer;
    var bottonActionColor = Theme.of(context).colorScheme.surfaceContainerLow;
    var buttonColors = Theme.of(context).colorScheme.onSurface.withOpacity(0.6);
    return Column(
      children: [
        Offstage(
          offstage: !_emojiShowing,
          child: emojipicker.EmojiPicker(
            textEditingController: _controller,
            config: emojipicker.Config(
              height: 256,
              checkPlatformCompatibility: true,
              emojiViewConfig: emojipicker.EmojiViewConfig(
                emojiSizeMax: 28,
                backgroundColor: surfaceContainer
              ),
              categoryViewConfig: emojipicker.CategoryViewConfig(
                backgroundColor: bottonActionColor,
                iconColorSelected: buttonColors,
              ),
              bottomActionBarConfig: emojipicker.BottomActionBarConfig(
                backgroundColor: bottonActionColor,
                buttonColor: buttonColors,
                showBackspaceButton: false,
              ),
              searchViewConfig: emojipicker.SearchViewConfig(
                backgroundColor: Colors.white,
              ),
            ),
            onEmojiSelected: (c, emoji) {
              setState(() {
                _emojiShowing = false; // Hide the emoji picker after selection
                _controller.text = emoji.emoji; // Display the emoji
                chosenIconIndex = -1; // Use -1 to indicate an emoji was chosen
                currentEmoji = emoji.emoji; // Update the current emoji
                category!.iconCodePoint = null;
                category!.icon = null;
                category!.iconEmoji = currentEmoji;
              });
            },
          ),
        ),
        GridView.count(
          padding: EdgeInsets.all(0),
          crossAxisCount: 5,
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          children: [
            // First IconButton with emoji
            Container(
              alignment: Alignment.center,
              child: IconButton(
                icon: ServiceConfig.isPremium ? Text(
                  currentEmoji, // Display an emoji as text
                  style: TextStyle(
                    fontSize: 24, // Set the emoji size
                  ),
                )
                : Stack(
                  children: [
                    Text(
                      currentEmoji, // Display an emoji as text
                      style: TextStyle(
                        fontSize: 24, // Set the emoji size
                      ),
                    ),
                    !ServiceConfig.isPremium
                        ? Container(
                      margin: EdgeInsets.fromLTRB(20, 20, 0, 0),
                      child: getProLabel(labelFontSize: 10.0),
                    )
                        : Container()
                  ],
                ), onPressed: ServiceConfig.isPremium
                    ? () {
                      setState(() {
                        _emojiShowing = !_emojiShowing; // Toggle the emoji picker
                      });
                    }
                    : () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => PremiumSplashScreen()),
                  );
                },
              ),
            ),
            // Other icons
            ...List.generate(icons.length, (index) {
              return Container(
                child: IconButton(
                  icon: FaIcon(icons[index]),
                  color: (chosenIconIndex == index)
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  onPressed: () {
                    setState(() {
                      _emojiShowing = false; // Hide emoji picker if open
                      category!.icon = icons[index];
                      category!.iconCodePoint = category!.icon!.codePoint;
                      category!.iconEmoji = null;
                      chosenIconIndex = index;
                    });
                  },
                ),
              );
            }),
          ],
        ),
      ],
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
                _createNoColorCircle(),
                _createColorPickerCircle(),
                _buildColorList(),
              ],
            )));
  }

  Widget _createNoColorCircle() {
    return Container(
      margin: EdgeInsets.all(10),
      child: Stack(
        children: [
          ClipOval(
            child: Material(
              color: Colors
                  .transparent, // Ensure no background color for the Material
              child: InkWell(
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle, // Ensure the shape is a circle
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.8), // Light grey border
                      width: 2.0, // Border width
                    ),
                  ),
                  child: Icon(
                    Icons.not_interested,
                    color: Theme.of(context).colorScheme.onSurface,
                    size: 30,
                  ),
                ),
                onTap: () async {
                  setState(() {
                    pickedColor = null;
                    category!.color = null;
                    chosenColorIndex = -2;
                  });
                },
              ),
            ),
          ),
          ServiceConfig.isPremium ? Container() : getProLabel(),
        ],
      ),
    );
  }

  Widget _createCategoryCirclePreview() {
    return Container(
      margin: EdgeInsets.all(10),
      child: ClipOval(
        child: Material(
          color: category!.color, // Button color
          child: InkWell(
            splashColor: category!.color, // InkWell color
            child: SizedBox(
              width: 70,
              height: 70,
              child: Center( // Center the content
                child: category!.iconEmoji != null // Check for iconEmoji
                    ? Text(
                  category!.iconEmoji!, // Display the emoji
                  style: TextStyle(
                    fontSize: 30, // Adjust the font size for the emoji
                  ),
                )
                    : Icon(
                  category!.icon, // Fallback to the icon
                  color: category!.color != null
                      ? Colors.white
                      : Theme.of(context).colorScheme.onSurface,
                  size: 30,
                ),
              ),
            ),
            onTap: () {},
          ),
        ),
      ),
    );
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
              pickerColor: Category.colors[0]!,
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
            icon: widget.passedCategory == null
                ? const Icon(Icons.archive)
                : !(widget.passedCategory!.isArchived)
                    ? const Icon(Icons.archive)
                    : const Icon(Icons.unarchive),
            tooltip: widget.passedCategory == null
                ? ""
                : !(widget.passedCategory!.isArchived)
                    ? "Archive".i18n
                    : "Unarchive".i18n,
            onPressed: () async {
              bool isCurrentlyArchived = widget.passedCategory!.isArchived;

              String dialogMessage = !isCurrentlyArchived
                  ? "Do you really want to archive the category?".i18n
                  : "Do you really want to unarchive the category?".i18n;

              // Prompt confirmation
              AlertDialogBuilder archiveDialog =
                  AlertDialogBuilder(dialogMessage)
                      .addTrueButtonName("Yes".i18n)
                      .addFalseButtonName("No".i18n);

              if (!isCurrentlyArchived) {
                archiveDialog.addSubtitle(
                    "Archiving the category you will NOT remove the associated records"
                        .i18n);
              }

              var continueArchivingAction = await showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return archiveDialog.build(context);
                  });

              if (continueArchivingAction) {
                await database.setIsArchived(widget.passedCategory!.name!,
                    widget.passedCategory!.categoryType!, !isCurrentlyArchived);
                Navigator.pop(context);
              }
            },
          )),
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
                      "Deleting the category you will remove all the associated records"
                          .i18n)
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
          )),
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
