import 'package:piggybank/models/category.dart';

class RecordsSummaryPerCategory {
  double _amount;
  Category _category;

  double get amount => _amount;
  Category get category => _category;

  RecordsSummaryPerCategory(this._category, this._amount);

  static RecordsSummaryPerCategory fromMap(Map<String, dynamic> map) {
    return RecordsSummaryPerCategory(map['category'], map['amount']);
  }
}
