import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/profile.dart';
import 'package:piggybank/models/record-tag-association.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/models/recurrent-record-pattern.dart';
import 'package:piggybank/models/wallet.dart';

import 'category.dart';
import 'model.dart';

class Backup extends Model {
  List<Record?> records;
  List<Category?> categories;
  List<RecurrentRecordPattern> recurrentRecordsPattern;
  List<RecordTagAssociation> recordTagAssociations;
  List<Wallet> wallets;
  List<Profile> profiles;
  var created_at;

  String? packageName;
  String? version;
  String? databaseVersion;

  /// Raw JSON string of user-defined currencies from SharedPreferences.
  String? userCurrencies;

  /// Portable application preferences captured from SharedPreferences.
  Map<String, dynamic> preferences;

  Backup(this.packageName, this.version, this.databaseVersion, this.categories,
      this.records, this.recurrentRecordsPattern, this.recordTagAssociations,
      {List<Wallet>? wallets,
      List<Profile>? profiles,
      this.userCurrencies,
      Map<String, dynamic>? preferences})
      : wallets = wallets ?? [],
        profiles = profiles ?? [],
        preferences = preferences ?? {} {
    created_at = new DateTime.now().millisecondsSinceEpoch;
  }

  Map<String, dynamic> toMap() {
    Map<String, dynamic> map = {
      'records':
          List.generate(records.length, (index) => records[index]!.toMap()),
      'categories': List.generate(
          categories.length, (index) => categories[index]!.toMap()),
      'recurrent_record_patterns': List.generate(recurrentRecordsPattern.length,
          (index) => recurrentRecordsPattern[index].toMap()),
      'record_tag_associations': List.generate(recordTagAssociations.length,
          (index) => recordTagAssociations[index].toMap()),
      'wallets': wallets.map((w) => w.toMap()).toList(),
      'profiles': profiles.map((p) => p.toMap()).toList(),
      'created_at': created_at,
      'package_name': packageName ?? '',
      'version': version ?? '',
      'database_version': databaseVersion ?? '',
      if (userCurrencies != null) 'user_currencies': userCurrencies,
      'preferences': preferences,
    };
    return map;
  }

  static Backup fromMap(Map<String, dynamic> map) {
    // Step 0: load profiles (backward compat: key may not exist in old backups)
    List<Profile> profiles = [];
    if (map.containsKey('profiles') && map['profiles'] != null) {
      profiles = List.generate(map['profiles'].length, (i) {
        return Profile.fromMap(Map<String, dynamic>.from(map['profiles'][i]));
      });
    }

    // Step 0b: load wallets
    List<Wallet> wallets = [];
    if (map.containsKey('wallets') && map['wallets'] != null) {
      wallets = List.generate(map['wallets'].length, (i) {
        return Wallet.fromMap(Map<String, dynamic>.from(map['wallets'][i]));
      });
    }

    // Step 1: load categories. Older backup formats always used this key,
    // but treating it as optional makes partially exported legacy files safe
    // to import as well.
    final categoryMaps = map["categories"] as List? ?? const [];
    var categories = List.generate(categoryMaps.length, (i) {
      return Category.fromMap(categoryMaps[i]);
    });

    // Step 2: load records (wallet_id is kept as-is for now; remapping happens in BackupService)
    final recordMaps = map["records"] as List? ?? const [];
    var records = List.generate(recordMaps.length, (i) {
      Map<String, dynamic> currentRowMap =
          Map<String, dynamic>.from(recordMaps[i]);
      String? categoryName = currentRowMap["category_name"];
      if (categoryName == null || currentRowMap["category_type"] == null) {
        currentRowMap["category"] = null;
      } else {
        CategoryType categoryType =
            CategoryType.values[currentRowMap["category_type"]];
        Category matchingCategory = categories.firstWhere(
            (element) =>
                element.categoryType == categoryType &&
                element.name == categoryName,
            orElse: () => throw Exception("Category not found"));
        currentRowMap["category"] = matchingCategory;
      }
      return Record.fromMap(currentRowMap);
    });

    // Step 3: load recurrent record patterns. This key was introduced after
    // the original backup format, so it may be absent in old backups.
    final recurrentPatternMaps =
        map["recurrent_record_patterns"] as List? ?? const [];
    var recurrentRecordsPattern =
        List.generate(recurrentPatternMaps.length, (i) {
      Map<String, dynamic> currentRowMap =
          Map<String, dynamic>.from(recurrentPatternMaps[i]);
      String? categoryName = currentRowMap["category_name"];
      if (categoryName == null || currentRowMap["category_type"] == null) {
        currentRowMap["category"] = null;
      } else {
        CategoryType categoryType =
            CategoryType.values[currentRowMap["category_type"]];
        Category matchingCategory = categories.firstWhere(
            (element) =>
                element.categoryType == categoryType &&
                element.name == categoryName,
            orElse: () => throw Exception("Category not found"));
        currentRowMap["category"] = matchingCategory;
      }
      return RecurrentRecordPattern.fromMap(currentRowMap);
    });

    // Step 4: load record tag associations
    List<RecordTagAssociation> recordTagAssociations = [];
    if (map.containsKey("record_tag_associations") &&
        map["record_tag_associations"] != null) {
      recordTagAssociations =
          List.generate(map["record_tag_associations"].length, (i) {
        return RecordTagAssociation.fromMap(map["record_tag_associations"][i]);
      });
    }

    // Extract optional packageName and version
    String? packageName = nonEmptyStringValue(map, 'package_name');
    String? version = nonEmptyStringValue(map, 'version');
    String? databaseVersion = nonEmptyStringValue(map, 'database_version');
    String? userCurrencies = nonEmptyStringValue(map, 'user_currencies');
    final preferences = _preferencesFromMap(map['preferences']);

    return Backup(packageName, version, databaseVersion, categories, records,
        recurrentRecordsPattern, recordTagAssociations,
        wallets: wallets,
        profiles: profiles,
        userCurrencies: userCurrencies,
        preferences: preferences);
  }

  static Map<String, dynamic> _preferencesFromMap(Object? rawPreferences) {
    if (rawPreferences is! Map) return {};
    final preferences = <String, dynamic>{};
    for (final entry in rawPreferences.entries) {
      if (entry.key is String) {
        preferences[entry.key as String] = entry.value;
      }
    }
    return preferences;
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
