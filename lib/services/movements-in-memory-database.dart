import 'package:piggybank/helpers/day-movement-generator.dart';
import 'package:piggybank/models/movements-per-day.dart';

class MovementsInMemoryDatabase {
    static List<MovementsPerDay> _movementsDays = DayMovementGenerator.getRandomDayMovements(quantity: 20);
    static List<MovementsPerDay> get movementsDays => _movementsDays;
}