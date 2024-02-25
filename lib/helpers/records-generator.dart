import 'dart:math';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/models/category.dart';

class RecordsGenerator {
  /// Methods for creating random Movements from a set of pre-defined data.
  /// Used in unit-tests.

  static Random random = new Random();
  static var descriptions = [
    "Car",
    "Burritos",
    "Book",
    "Groceries",
    "Coffee",
    "Dinner"
  ];
  static var tags = [
    Category("Shopping"),
    Category("Food"),
    Category("Gift"),
    Category("Fun"),
    Category("Rent")
  ];
  static var currentDate = DateTime.now();

  static Record getRandomRecord(recordDate) {
    // Create new double value, rounded to 2 digit precision
    var mockValue = -(random.nextDouble() * 100);
    mockValue = double.parse(mockValue.toStringAsPrecision(2));

    var mockDescription = _getRandomElement(descriptions);
    List<Category> mockTags =
        _getRandomSubset(tags, minimum: 1).whereType<Category>().toList();

    return new Record(
        mockValue, mockDescription as String?, mockTags[0], recordDate);
  }

  static List<Record> getRandomMovements(movementDate, {quantity = 100}) {
    List<Record> randomMovements = [];
    for (var i = 0; i < quantity; i++) {
      Record randomMovement = getRandomRecord(movementDate);
      randomMovements.add(randomMovement);
    }
    return randomMovements;
  }

  /*
  Get a random subset of elements from the list
  Elements in the list can't repeat
 */
  static List<Object> _getRandomSubset(List<Object> choices, {minimum = 0}) {
    var newList = [];
    var randomQuantity = random.nextInt(choices.length) + minimum;
    while (newList.length < randomQuantity) {
      var newElement = _getRandomElement(choices);
      if (!newList.contains(newElement))
        newList.add(_getRandomElement(choices));
    }
    return newList as List<Object>;
  }

  /*
    Get random element from list
  */
  static Object _getRandomElement(List<Object> choices) {
    var randomQuantity = random.nextInt(choices.length);
    return choices[randomQuantity];
  }
}
