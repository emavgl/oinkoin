import 'package:flutter/material.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/records/edit-record-page.dart';
import 'package:piggybank/i18n.dart';
import 'package:reorderable_grid/reorderable_grid.dart';

class CategoriesGrid extends StatefulWidget {
  final List<Category?> categories;
  final bool? goToEditMovementPage;
  final bool enableManualSorting;
  final Function(List<Category?>) onChangeOrder;

  CategoriesGrid(this.categories,
      {this.goToEditMovementPage,
      required this.enableManualSorting,
      required this.onChangeOrder});

  @override
  CategoriesGridState createState() => CategoriesGridState();
}

class CategoriesGridState extends State<CategoriesGrid> {

  List<Category?> orderedCategories = [];
  bool enableManualSorting = false;

  @override
  void initState() {
    super.initState();
    enableManualSorting = widget.enableManualSorting;
    orderedCategories = List.from(
        widget.categories); // Initialize with a copy of the categories list
  }

  @override
  void didUpdateWidget(covariant CategoriesGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Check if the categories list has been updated and update orderedCategories accordingly
    if (oldWidget.categories != widget.categories) {
      setState(() {
        orderedCategories = List.from(widget.categories);
        enableManualSorting = widget.enableManualSorting;
      });
    }
  }

  /// Builds a single category item
  Widget _buildCategory(Category category) {
    return Container(
      child: Center(
        child: InkWell(
          onTap: () async {
            if (widget.goToEditMovementPage != null &&
                widget.goToEditMovementPage!) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      EditRecordPage(passedCategory: category),
                ),
              );
            } else {
              Navigator.pop(context, category);
            }
          },
          child: Container(
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  child: Center(
                    child: category.iconEmoji != null
                        ? Text(
                            category.iconEmoji!,
                            style: TextStyle(fontSize: 20),
                          )
                        : Icon(
                            category.icon,
                            size: 20,
                            color: category.color != null
                                ? Colors.white
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                  ),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: category.color,
                  ),
                ),
                Flexible(
                  child: Container(
                    margin: EdgeInsets.fromLTRB(0, 10, 0, 0),
                    child: Text(
                      category.name!,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the grid of categories with reordering capability
  Widget _buildCategories() {
    var size = MediaQuery.of(context).size;
    final double itemHeight = 250;
    final double itemWidth = size.width / 2;

    final generatedChildren = List.generate(orderedCategories.length, (index) {
      final category = orderedCategories[index];
      return Container(
        key: ValueKey(index.toString()), // Ensure each item has a unique key
        child: _buildCategory(category!),
      );
    });

    return ReorderableGridView.extent(
      onReorder: (int oldIndex, int newIndex) async {
        setState(() {
          final item = orderedCategories.removeAt(oldIndex);
          orderedCategories.insert(newIndex, item);
        });
        await widget.onChangeOrder(orderedCategories);
      },
      itemDragEnable: (index) {
        return enableManualSorting;
      },
      key: GlobalKey(), // Assign a global key to the grid view
      childAspectRatio: (itemWidth / itemHeight),
      padding: EdgeInsets.only(top: 10),
      crossAxisSpacing: 5.0,
      mainAxisSpacing: 5.0,
      maxCrossAxisExtent: size.width / 4,
      children: generatedChildren,
    );
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
