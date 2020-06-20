import 'dart:math';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:piggybank/models/model.dart';

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

  /// List of icons.
  /// These are the only icons that can be used in the Category.
  /// Feel free to add more icons. The order matters in the way
  /// they are showed in the grid.
  static final List<IconData> icons = [
    // food
    FontAwesomeIcons.hamburger,
    FontAwesomeIcons.pizzaSlice,
    FontAwesomeIcons.cheese,
    FontAwesomeIcons.appleAlt,
    FontAwesomeIcons.breadSlice,
    FontAwesomeIcons.iceCream,
    FontAwesomeIcons.cocktail,
    FontAwesomeIcons.wineGlass,
    FontAwesomeIcons.birthdayCake,
    FontAwesomeIcons.fish,
    FontAwesomeIcons.coffee,

    // transports
    FontAwesomeIcons.gasPump,
    FontAwesomeIcons.car,
    FontAwesomeIcons.carBattery,
    FontAwesomeIcons.parking,
    FontAwesomeIcons.biking,
    FontAwesomeIcons.motorcycle,
    FontAwesomeIcons.bicycle,
    FontAwesomeIcons.caravan,
    FontAwesomeIcons.taxi,
    FontAwesomeIcons.planeDeparture,
    FontAwesomeIcons.ship,
    FontAwesomeIcons.train,

    // Shopping
    FontAwesomeIcons.shoppingCart,
    FontAwesomeIcons.shoppingBag,
    FontAwesomeIcons.shoppingBasket,
    FontAwesomeIcons.gem,
    FontAwesomeIcons.tag,
    FontAwesomeIcons.gift,
    FontAwesomeIcons.mitten,
    FontAwesomeIcons.socks,
    FontAwesomeIcons.hatCowboy,

    // Entertainment
    FontAwesomeIcons.gamepad,
    FontAwesomeIcons.theaterMasks,
    FontAwesomeIcons.swimmer,
    FontAwesomeIcons.bowlingBall,
    FontAwesomeIcons.golfBall,
    FontAwesomeIcons.baseballBall,
    FontAwesomeIcons.basketballBall,
    FontAwesomeIcons.footballBall,
    FontAwesomeIcons.volleyballBall,
    FontAwesomeIcons.skiing,
    FontAwesomeIcons.tv,
    FontAwesomeIcons.film,

    FontAwesomeIcons.home,
    FontAwesomeIcons.wallet,
    FontAwesomeIcons.question
  ];


  static Random _random = new Random();

  String name;
  Color color;
  int iconCodePoint;
  IconData icon;
  int categoryType; // 0 for expenses, 1 for income

  Category(String name, {this.color, this.iconCodePoint, this.categoryType}) {
    this.name = name;
    if (this.color == null) {
      var randomColorIndex = _random.nextInt(colors.length);
      this.color = colors[randomColorIndex];
    }

    if (this.iconCodePoint == null) {
      var randomIconIndex = _random.nextInt(icons.length);
      this.icon = icons[randomIconIndex];
      this.iconCodePoint = this.icon.codePoint;
    } else {
      this.icon = icons.where((i) => i.codePoint == this.iconCodePoint).first;
    }

    if (this.categoryType == null) {
      categoryType = 0;
    }
  }

  Map<String, dynamic> toMap() {
    Map<String, dynamic> map = {
      'name': name,
      'color': color.alpha.toString() + ":" + color.red.toString() + ":"
          + color.green.toString() + ":" + color.blue.toString(),
      'icon': this.icon.codePoint,
      'category_type': categoryType
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
      categoryType: map["category_type"]
    );
  }

}