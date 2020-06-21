import 'package:piggybank/models/record.dart';

import 'category.dart';
import 'model.dart';
import 'dart:convert';

class Backup extends Model {
  List<Record> records;
  List<Category> categories;
  var created_at;

  Backup(this.categories, this.records) {
    created_at = new DateTime.now().millisecondsSinceEpoch;
  }

  Map<String, dynamic> toMap() {
    Map<String, dynamic> map = {
      'records': List.generate(records.length, (index) => records[index].toMap()),
      'categories': List.generate(categories.length, (index) => categories[index].toMap()),
      'created_at': created_at,
    };
    return map;
  }

  static Backup fromMap(Map<String, dynamic> map) {
    var records = List.generate(map["records"].length, (i) {
      Map<String, dynamic> currentRowMap = Map<String, dynamic>.from(map["records"][i]);
      currentRowMap["category"] = Category.fromMap(currentRowMap);
      return Record.fromMap(currentRowMap);
    });
    var categories = List.generate(map["categories"].length, (i) {
      return Category.fromMap(map["categories"][i]);
    });
    return Backup(categories, records);
  }

}