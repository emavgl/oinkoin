import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/models/recurrent-record-pattern.dart';

import 'category.dart';
import 'model.dart';
class Backup extends Model {
  List<Record?> records;
  List<Category?> categories;
  List<RecurrentRecordPattern> recurrentRecordsPattern;
  var created_at;

  String? packageName;
  String? version;
  String? databaseVersion;

  Backup(this.packageName, this.version, this.databaseVersion,
      this.categories, this.records, this.recurrentRecordsPattern) {
    created_at = new DateTime.now().millisecondsSinceEpoch;
  }

  Map<String, dynamic> toMap() {
    Map<String, dynamic> map = {
      'records': List.generate(records.length, (index) => records[index]!.toMap()),
      'categories': List.generate(categories.length, (index) => categories[index]!.toMap()),
      'recurrent_record_patterns': List.generate(recurrentRecordsPattern.length,
              (index) => recurrentRecordsPattern[index].toMap()),
      'created_at': created_at,
      'package_name': packageName ?? '',
      'version': version ?? '',
      'database_version': databaseVersion ?? '',
    };
    return map;
  }

  static Backup fromMap(Map<String, dynamic> map) {
    // Step 1: load categories
    var categories = List.generate(map["categories"].length, (i) {
      return Category.fromMap(map["categories"][i]);
    });

    // Step 2: load records
    var records = List.generate(map["records"].length, (i) {
      Map<String, dynamic> currentRowMap =
      Map<String, dynamic>.from(map["records"][i]);
      String? categoryName = currentRowMap["category_name"];
      CategoryType categoryType =
      CategoryType.values[currentRowMap["category_type"]];
      Category matchingCategory = categories.firstWhere(
              (element) =>
          element.categoryType == categoryType &&
              element.name == categoryName,
          orElse: null);
      currentRowMap["category"] = matchingCategory;
      return Record.fromMap(currentRowMap);
    });

    // Step 3: load recurrent record patterns
    var recurrentRecordsPattern =
    List.generate(map["recurrent_record_patterns"].length, (i) {
      Map<String, dynamic> currentRowMap =
      Map<String, dynamic>.from(map["recurrent_record_patterns"][i]);
      String? categoryName = currentRowMap["category_name"];
      CategoryType categoryType =
      CategoryType.values[currentRowMap["category_type"]];
      Category matchingCategory = categories.firstWhere(
              (element) =>
          element.categoryType == categoryType &&
              element.name == categoryName,
          orElse: null);
      currentRowMap["category"] = matchingCategory;
      return RecurrentRecordPattern.fromMap(currentRowMap);
    });

    // Extract optional packageName and version
    String? packageName = nonEmptyStringValue(map, 'package_name');
    String? version = nonEmptyStringValue(map, 'version');
    String? databaseVersion = nonEmptyStringValue(map, 'database_version');

    return Backup(packageName, version, databaseVersion, categories, records, recurrentRecordsPattern);
  }

  static String? nonEmptyStringValue(Map<String, dynamic> map, String key) {
    String? value;
    if (map.containsKey(key)) {
      if (map[key] != null && map[key].isNotEmpty) {
        value = map[key];
      }
    }
    return value;
  }

}
