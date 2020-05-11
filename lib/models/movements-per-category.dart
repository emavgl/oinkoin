
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/movement.dart';


class MovementsPerCategory {

  List<Movement> movements;
  Category _category;

  Category get category => _category;

  MovementsPerCategory(this._category, {this.movements}) {
    if (this.movements == null) {
      this.movements = List();
    }
  }

  double get expenses {
    double total = 0;
    for (var movement in this.movements) {
      if (movement.value < 0)
        total += movement.value;
    }
    return total;
  }

  double get income {
    double total = 0;
    for (var movement in this.movements) {
      if (movement.value > 0)
        total += movement.value;
    }
    return total;
  }

  double get balance {
    double total = 0;
    for (var movement in this.movements) {
      total += movement.value;
    }
    return total;
  }

  void addMovement(Movement movement) {
    movements.add(movement);
  }

  static MovementsPerCategory fromMap(Map<String, dynamic> map)
  {
    return MovementsPerCategory(
      map['category'],
      movements: map['movements']);
  }
}