import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/record.dart';

class RecordsPerDay {
  /// Object containing a list of records (movements).
  /// Used for grouping together movements with the same day.
  /// Contains also utility getters to retrieve easily the amount of expenses,
  /// income and balance.

  List<Record?>? records;
  DateTime? dateTime;

  RecordsPerDay(this.dateTime, {this.records}) {
    if (this.records == null) {
      this.records = [];
    }
  }

  double get expenses {
    double total = 0;
    List<Record?> incomeRecords = this
        .records!
        .where((e) => e!.category!.categoryType == CategoryType.expense)
        .toList();
    for (var movement in incomeRecords) {
      total += movement!.value!;
    }
    return total;
  }

  double get income {
    double total = 0;
    List<Record?> incomeRecords = this
        .records!
        .where((e) => e!.category!.categoryType == CategoryType.income)
        .toList();
    for (var movement in incomeRecords) {
      total += movement!.value!;
    }
    return total;
  }

  double get balance {
    return income - (expenses * -1);
  }

  void addMovement(Record movement) {
    records!.add(movement);
  }
}
