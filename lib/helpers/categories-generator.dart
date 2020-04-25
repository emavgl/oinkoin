import 'dart:math';
import 'package:piggybank/models/movement.dart';
import 'package:piggybank/models/category.dart';
import '../i18n/categories-generator.i18n.dart';

class CategoriesGenerator {
  static Random random = new Random();
  static var categoryName = ["Car".i18n, "Burritos".i18n, "Book".i18n, "Groceries".i18n, "Coffee".i18n, "Dinner".i18n];

  static Category getRandomCategory() {
    var mockCategoryName = _getRandomElement(categoryName);
    return new Category(mockCategoryName);
  }

  static List<Category> getRandomCategories({quantity = 100}) {
    List<Category> randomCategories = new List();
    for (var i = 0; i < quantity; i++) {
      Category category = getRandomCategory();
      randomCategories.add(category);
    }
    return randomCategories;
  }

  /*
    Get random element from list
  */
  static Object _getRandomElement(List<Object> choices) {
    var randomQuantity = random.nextInt(choices.length);
    return choices[randomQuantity];
  }
}