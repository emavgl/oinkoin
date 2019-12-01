import 'package:piggybank/helpers/movements-generator.dart';
import 'package:piggybank/models/movement.dart';

class MovementsInMemoryDatabase {
    
    static List<Movement> _movements = MovementsGenerator.getRandomMovements(quantity: 20);
    static List<Movement> get movements => _movements;

}