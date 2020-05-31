import 'package:piggybank/models/record.dart';

class RecordsPerDay {

  /// Object containing a list of records (movements).
  /// Used for grouping together movements with the same day.
  /// Contains also utility getters to retrieve easily the amount of expenses,
  /// income and balance.

  List<Record> records;
  DateTime dateTime;

  RecordsPerDay(this.dateTime, {this.records}) {
    if (this.records == null) {
      this.records = List();
    }
  }

  double get expenses {
    double total = 0;
    for (var movement in this.records) {
      if (movement.value < 0)
        total += movement.value;
    }
    return total;
  }

  double get income {
    double total = 0;
    for (var movement in this.records) {
      if (movement.value > 0)
        total += movement.value;
    }
    return total;
  }

  double get balance {
    double total = 0;
    for (var movement in this.records) {
      total += movement.value;
    }
    return total;
  }

  void addMovement(Record movement) {
    records.add(movement);
  }

}