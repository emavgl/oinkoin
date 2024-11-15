import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:piggybank/models/category-icons.dart';
import 'package:piggybank/models/model.dart';
import 'category-type.dart';

class Category extends Model {
  /// Object representing a Category.
  /// A category has a name, type, icon, and color.
  /// The category type is used to discriminate between categories for expenses,
  /// and categories for incomes.

  static final List<Color?> colors = [
    Colors.green[300],
    Colors.red[300],
    Colors.blue[300],
    Colors.orange[300],
    Colors.yellow[600],
    Colors.purple[200],
    Colors.grey[400],
    Colors.black,
    Colors.white,
  ];

  String? name;
  Color? color;
  int? iconCodePoint;
  IconData? icon;
  String? iconEmoji;
  DateTime? lastUsed;
  int? recordCount;
  CategoryType? categoryType;
  bool isArchived;
  int? sortOrder; // New field to track the order of categories

  // Updated constructor to include the sortOrder field
  Category(String? name,
      {this.color,
      this.iconCodePoint,
      this.categoryType,
      this.lastUsed,
      this.recordCount,
      this.iconEmoji,
      this.isArchived = false,
      this.sortOrder = 0}) {
    // Initialize sortOrder in constructor
    this.name = name;
    var categoryIcons = CategoryIcons.pro_category_icons;

    if (iconEmoji == null) {
      if (this.iconCodePoint == null ||
          categoryIcons
              .where((i) => i.codePoint == this.iconCodePoint)
              .isEmpty) {
        this.icon = FontAwesomeIcons.question;
        this.iconCodePoint = this.icon!.codePoint;
      } else {
        this.icon =
            categoryIcons.where((i) => i.codePoint == this.iconCodePoint).first;
      }
    }

    if (this.categoryType == null) {
      categoryType = CategoryType.expense;
    }
  }

  /// Converts the Category object to a Map
  Map<String, dynamic> toMap() {
    Map<String, dynamic> map = {
      'name': name,
      'category_type': categoryType!.index,
      'last_used': lastUsed?.millisecondsSinceEpoch,
      'record_count': recordCount,
      'color': null,
      'is_archived': isArchived ? 1 : 0,
      'icon_emoji': iconEmoji,
      'sort_order': sortOrder, // Add sortOrder to the map
    };
    if (color != null) {
      map['color'] = color!.alpha.toString() +
          ":" +
          color!.red.toString() +
          ":" +
          color!.green.toString() +
          ":" +
          color!.blue.toString();
    }
    if (this.icon != null) {
      map['icon'] = this.icon!.codePoint;
    }
    return map;
  }

  /// Creates a Category object from a Map
  static Category fromMap(Map<String, dynamic> map) {
    // Deserialize color
    String? serializedColor = map["color"] as String?;
    Color? color;
    if (serializedColor != null) {
      List<int> colorComponents =
          serializedColor.split(":").map(int.parse).toList();
      color = Color.fromARGB(colorComponents[0], colorComponents[1],
          colorComponents[2], colorComponents[3]);
    }

    // Deserialize last_used
    int? lastUsed = map["last_used"] as int?;
    DateTime? lastUsedFromMap;
    if (lastUsed != null) {
      lastUsedFromMap = DateTime.fromMillisecondsSinceEpoch(lastUsed);
    }

    // Deserialize other fields
    bool isArchivedFromMap =
        (map['is_archived'] != null) ? (map['is_archived'] as int) == 1 : false;
    int recordCountFromMap =
        (map['record_count'] != null) ? map['record_count'] as int : 0;
    String? iconEmojiFromMap = map['icon_emoji'] as String?;
    int? icon = map['icon'] as int?;
    int sortOrder = (map['sort_order'] != null) ? map['sort_order'] as int : 0;

    // Return the Category object
    return Category(
      map["name"],
      color: color,
      iconCodePoint: icon,
      categoryType: CategoryType.values[map['category_type']],
      lastUsed: lastUsedFromMap,
      recordCount: recordCountFromMap,
      iconEmoji: iconEmojiFromMap,
      isArchived: isArchivedFromMap,
      sortOrder: sortOrder, // Initialize sortOrder
    );
  }
}
