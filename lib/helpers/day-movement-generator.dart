import 'dart:math';
import 'package:piggybank/models/movement.dart';
import 'package:piggybank/models/tag.dart';
import 'movements-generator.dart';
import 'package:piggybank/models/movements-per-day.dart';

class DayMovementGenerator {

  static Random random = new Random();
  static var descriptions = ["Car", "Burritos", "Book", "Groceries", "Coffee", "Dinner"];
  static var tags = [Tag("Shopping"), Tag("Food"), Tag("Gift"), Tag("Fun"), Tag("Rent")];
  static var currentDate = DateTime.now();

  static MovementsPerDay getMockMovementDay() {
    int randomQuantity = random.nextInt(5);
    List<Movement> movements = MovementsGenerator.getRandomMovements(currentDate, quantity: randomQuantity);

    // Get an older date, generation after generation
    currentDate = currentDate.subtract(new Duration(days: random.nextInt(30)));
    
    return new MovementsPerDay(currentDate, movements: movements);
  }

  static List<MovementsPerDay> getRandomDayMovements({quantity = 100}) {
    List<MovementsPerDay> randomMovementDay = new List();
    for (var i = 0; i < quantity; i++) {
      MovementsPerDay randomMovement = getMockMovementDay();
      randomMovementDay.add(randomMovement);
    }
    return randomMovementDay;
  }

}