import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/record.dart';

class RecordsPerCategory {
  List<Record>? records;
  Category? _category;

  Category? get category => _category;

  RecordsPerCategory(this._category, {this.records}) {
    if (this.records == null) {
      this.records = [];
    }
  }

  /// Net total of records whose category type is expense. Records are stored
  /// with their sign, so a refund (+10) in an expense category reduces the net.
  double get expenses {
    double total = 0;
    for (var movement in this.records!) {
      if (movement.category?.categoryType == CategoryType.expense) {
        total += movement.value!;
      }
    }
    return total;
  }

  /// Net total of records whose category type is income. A payback (-100) in
  /// an income category reduces the net.
  double get income {
    double total = 0;
    for (var movement in this.records!) {
      if (movement.category?.categoryType == CategoryType.income) {
        total += movement.value!;
      }
    }
    return total;
  }

  double get balance {
    double total = 0;
    for (var movement in this.records!) {
      total += movement.value!;
    }
    return total;
  }

  void addMovement(Record movement) {
    records!.add(movement);
  }

  static RecordsPerCategory fromMap(Map<String, dynamic> map) {
    return RecordsPerCategory(map['category'], records: map['movements']);
  }
}
