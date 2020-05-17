import 'dart:ui';

import 'package:piggybank/models/movement.dart';

class MovementsPerDay {

  /// Object containing a list of movements.
  /// Used for grouping together movements with the same day.
  /// Contains also utility getters to retrieve easily the amount of expenses, income and balance.

  List<Movement> movements;
  DateTime dateTime;

  MovementsPerDay(this.dateTime, {this.movements}) {
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

}