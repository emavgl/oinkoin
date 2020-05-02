import 'dart:math';
import 'package:piggybank/models/category.dart';

class CategoriesGenerator {
  static Random random = new Random();
  static var categoryName = ["Car", "Burritos", "Book", "Groceries", "Coffee", "Dinner"];

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