import 'dart:math';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:piggybank/models/category-icons.dart';
import 'package:piggybank/models/model.dart';
import 'package:piggybank/services/service-config.dart';

import 'category-type.dart';

class Category extends Model {

  /// Object representing a Category.
  /// A category has an name, type, icon and a color.
  /// The category type is used to discriminate between categories for expenses,
  /// and categories for incomes.

  /// List of icons.
  /// These are the only colors that can be used in the Category.
  /// The order matters in the way they are showed in the list.
  static final List<Color> colors = [
    Colors.green[300],
    Colors.red[300],
    Colors.blue[300],
    Colors.orange[300],
    Colors.yellow[600],
    Colors.purple[200],
    Colors.grey,
    Colors.black,
  ];

  static Random _random = new Random();

  String name;
  Color color;
  int iconCodePoint;
  IconData icon;
  CategoryType categoryType; // 0 for expenses, 1 for income
  List<IconData> categoryIcons;

  Category(String name, {this.color, this.iconCodePoint, this.categoryType}) {
    this.name = name;
    this.categoryIcons = CategoryIcons.pro_category_icons;
    if (this.color == null) {
      var randomColorIndex = _random.nextInt(colors.length);
      this.color = colors[randomColorIndex];
    }

    if (this.iconCodePoint == null || this.categoryIcons.where((i) => i.codePoint == this.iconCodePoint).isEmpty) {
      this.icon = FontAwesomeIcons.question;
      this.iconCodePoint = this.icon.codePoint;
    } else {
      this.icon = this.categoryIcons.where((i) => i.codePoint == this.iconCodePoint).first;
    }

    if (this.categoryType == null) {
      categoryType = CategoryType.expense;
    }
  }

  Map<String, dynamic> toMap() {
    Map<String, dynamic> map = {
      'name': name,
      'color': color.alpha.toString() + ":" + color.red.toString() + ":"
          + color.green.toString() + ":" + color.blue.toString(),
      'icon': this.icon.codePoint,
      'category_type': categoryType.index
    };
    return map;
  }

  static Category fromMap(Map<String, dynamic> map) {
    String serializedColor = map["color"] as String;
    List<int> colorComponents = serializedColor.split(":").map(int.parse).toList();
    return Category(
      map["name"],
      color: Color.fromARGB(colorComponents[0], colorComponents[1], colorComponents[2], colorComponents[3]),
      iconCodePoint: map["icon"],
      categoryType: CategoryType.values[map['category_type']]
    );
  }

}