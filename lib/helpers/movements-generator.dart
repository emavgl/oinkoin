import 'dart:math';
import 'package:piggybank/models/movement.dart';
import 'package:piggybank/models/tag.dart';

class MovementsGenerator {

  static Random random = new Random();
  static var descriptions = ["Car", "Burritos", "Book", "Groceries", "Coffee", "Dinner"];
  static var tags = [Tag("Shopping"), Tag("Food"), Tag("Gift"), Tag("Fun"), Tag("Rent")];
  static var currentDate = DateTime.now();

  static Movement getRandomMovement(movementDate) {
    // Create new double value, rounded to 2 digit precision
    var mockValue = - (random.nextDouble() * 100);
    mockValue = double.parse(mockValue.toStringAsPrecision(2));

    var mockDescription = _getRandomElement(descriptions);
    List<Tag> mockTags = _getRandomSubset(tags, minimum: 1).whereType<Tag>().toList();
    
    return new Movement(mockValue, mockDescription, mockTags, movementDate);
  }

  static List<Movement> getRandomMovements(movementDate, {quantity = 100}) {
    List<Movement> randomMovements = new List();
    for (var i = 0; i < quantity; i++) {
      Movement randomMovement = getRandomMovement(movementDate);
      randomMovements.add(randomMovement);
    }
    return randomMovements;
  }

 /*
  Get a random subset of elements from the list
  Elements in the list can't repeat
 */
  static List<Object> _getRandomSubset(List<Object> choices, {minimum = 0}) {
    var newList = new List();
    var randomQuantity = random.nextInt(choices.length) + minimum;
    while (newList.length < randomQuantity) {
      var newElement = _getRandomElement(choices);
      if (!newList.contains(newElement))
        newList.add(_getRandomElement(choices));
    }
    return newList;
  }

  /*
    Get random element from list
  */
  static Object _getRandomElement(List<Object> choices) {
    var randomQuantity = random.nextInt(choices.length);
    return choices[randomQuantity];
  }
}