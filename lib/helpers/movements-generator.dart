import 'dart:math';
import 'package:piggybank/models/movement.dart';

class MovementsGenerator {

  static Random random = new Random();
  static var descriptions = ["Car", "Burritos", "Book", "Groceries", "Coffee", "Dinner"];
  static var tags = ["Shopping", "Food", "Gift", "Fun"];

  static Movement getRandomMovement() {
    // Create new double value, rounded to 2 digit precision
    var mockValue = - (random.nextDouble() * 100);
    mockValue = double.parse(mockValue.toStringAsPrecision(2));

    var mockDescription = _getRandomElement(descriptions);
    List<String> mockTags = _getRandomSubset(tags);
    return new Movement(mockValue, mockDescription, mockTags);
  }

  static List<Movement> getRandomMovements({quantity = 100}) {
    List<Movement> randomMovements = new List();
    for (var i = 0; i < quantity; i++) {
      Movement randomMovement = getRandomMovement();
      randomMovements.add(randomMovement);
    }
    return randomMovements;
  }

 /*
  Get a random subset of elements from the list
  Use with care, it shuffle the original list
 */
  static List<String> _getRandomSubset(List<String> choices) {
    var randomQuantity = random.nextInt(choices.length);
    return choices.take(randomQuantity).toList();
  }

  /*
    Get random element from list
  */
  static String _getRandomElement(List<String> choices) {
    var randomQuantity = random.nextInt(choices.length);
    return choices[randomQuantity];
  }
}