import 'package:piggybank/models/category.dart';

class MovementsSummaryPerCategory {
  double _amount;
  Category _category;

  double get amount => _amount;
  Category get category => _category;

  MovementsSummaryPerCategory(this._category, this._amount);

  static MovementsSummaryPerCategory fromMap(Map<String, dynamic> map) {
    return MovementsSummaryPerCategory(map['category'], map['amount']);
  }
}
