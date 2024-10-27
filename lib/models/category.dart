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

  /// List of icons.
  /// These are the only colors that can be used in the Category.
  /// The order matters in the way they are shown in the list.
  static final List<Color?> colors = [
    Colors.green[300],
    Colors.red[300],
    Colors.blue[300],
    Colors.orange[300],
    Colors.yellow[600],
    Colors.purple[200],
    Colors.grey[400],
    Colors.black,
  ];

  String? name;
  Color? color;
  int? iconCodePoint;
  IconData? icon;
  DateTime? lastUsed;
  int? recordCount;
  CategoryType? categoryType; // 0 for expenses, 1 for income
  bool isArchived;

  // Updated constructor to include the isArchived field
  Category(String? name,
      {this.color,
      this.iconCodePoint,
      this.categoryType,
      this.lastUsed,
      this.recordCount,
      this.isArchived = false}) {
    this.name = name;
    var categoryIcons = CategoryIcons.pro_category_icons;

    // Assign a default icon if none is provided or the provided one is invalid
    if (this.iconCodePoint == null ||
        categoryIcons.where((i) => i.codePoint == this.iconCodePoint).isEmpty) {
      this.icon = FontAwesomeIcons.question;
      this.iconCodePoint = this.icon!.codePoint;
    } else {
      this.icon =
          categoryIcons.where((i) => i.codePoint == this.iconCodePoint).first;
    }

    // Set default category type to expense if not provided
    if (this.categoryType == null) {
      categoryType = CategoryType.expense;
    }
  }

  Map<String, dynamic> toMap() {
    Map<String, dynamic> map = {
      'name': name,
      'icon': this.icon!.codePoint,
      'category_type': categoryType!.index,
      'last_used': lastUsed?.millisecondsSinceEpoch,
      'record_count': recordCount,
      'color': null,
      'is_archived': isArchived ? 1 : 0
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
    return map;
  }

  static Category fromMap(Map<String, dynamic> map) {
    // Handle color deserialization
    // If not provided, null is assigned as a valid color (blank)
    String? serializedColor = map["color"] as String?;
    Color? color;
    if (serializedColor != null) {
      List<int> colorComponents =
          serializedColor.split(":").map(int.parse).toList();
      color = Color.fromARGB(colorComponents[0], colorComponents[1],
          colorComponents[2], colorComponents[3]);
    }

    // Handle last_used with default value of null if missing
    int? lastUsed = map["last_used"] as int?;
    DateTime? lastUsedFromMap;
    if (lastUsed != null) {
      lastUsedFromMap = DateTime.fromMillisecondsSinceEpoch(lastUsed);
    }

    // Handle is_archived with default value of false if missing
    bool isArchivedFromMap =
        (map['is_archived'] != null) ? (map['is_archived'] as int) == 1 : false;

    // Handle record_count with default value of 0 if missing
    int recordCountFromMap =
        (map['record_count'] != null) ? map['record_count'] as int : 0;

    // Return the Category object
    return Category(
      map["name"],
      color: color,
      iconCodePoint: map["icon"],
      categoryType: CategoryType.values[map['category_type']],
      lastUsed: lastUsedFromMap,
      recordCount: recordCountFromMap,
      isArchived: isArchivedFromMap,
    );
  }
}
