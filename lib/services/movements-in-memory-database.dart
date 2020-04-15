import 'package:piggybank/helpers/categories-generator.dart';
import 'package:piggybank/helpers/day-movement-generator.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/movements-per-day.dart';

class MovementsInMemoryDatabase {
    static List<MovementsPerDay> _movementsDays = DayMovementGenerator.getRandomDayMovements(quantity: 20);
    static List<Category> _categories = CategoriesGenerator.getRandomCategories(quantity: 4);
    static List<MovementsPerDay> get movementsDays => _movementsDays;
    static List<Category> get categories => _categories;
}