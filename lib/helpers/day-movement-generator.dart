import 'dart:math';
import 'package:piggybank/models/movement.dart';
import 'package:piggybank/models/category.dart';
import 'movements-generator.dart';
import 'package:piggybank/models/movements-per-day.dart';
import '../i18n/categories-generator.i18n.dart'; // TODO remove this when categories will be in one page only


class DayMovementGenerator {

  static Random random = new Random();
  static var descriptions = ["Car".i18n, "Burritos".i18n, "Book".i18n, "Groceries".i18n, "Coffee".i18n, "Dinner".i18n];
  static var tags = [Category("Shopping"), Category("Food"), Category("Gift"), Category("Fun"), Category("Rent")];
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