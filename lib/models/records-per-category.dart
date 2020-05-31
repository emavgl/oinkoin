
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/record.dart';


class RecordsPerCategory {

  List<Record> records;
  Category _category;

  Category get category => _category;

  RecordsPerCategory(this._category, {this.records}) {
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

  static RecordsPerCategory fromMap(Map<String, dynamic> map)
  {
    return RecordsPerCategory(
      map['category'],
      records: map['movements']);
  }
}