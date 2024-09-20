import 'dart:async';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:path/path.dart';
import 'package:piggybank/i18n.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/models/recurrent-record-pattern.dart';
import 'package:piggybank/services/database/database-interface.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'exceptions.dart';

class SqliteDatabase implements DatabaseInterface {
  /// SqliteDatabase is an implementation of DatabaseService using sqlite3 database.
  /// It is implemented using Singleton pattern.

  SqliteDatabase._privateConstructor();
  static final SqliteDatabase instance = SqliteDatabase._privateConstructor();
  static int get _version => 6;
  static Database? _db;

  Future<Database?> get database async {
    if (_db != null) return _db;

    // if _database is null we instantiate it
    _db = await init();
    return _db;
  }

  Future<Database> init() async {
    String databasePath = await getDatabasesPath();
    String _path = join(databasePath, 'movements.db');
    return await openDatabase(_path,
        version: _version, onCreate: onCreate, onUpgrade: onUpgrade);
  }

  static void onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (newVersion == 6) {
      await db.execute("""
                CREATE TABLE IF NOT EXISTS  recurrent_record_patterns (
                    id          TEXT  PRIMARY KEY,
                    datetime    INTEGER,
                    value       REAL,
                    title       TEXT,
                    description TEXT,
                    category_name TEXT,
                    category_type INTEGER,
                    last_update INTEGER,
                    recurrent_period INTEGER
                );
            """);
      try {
        await db.execute("ALTER TABLE records ADD COLUMN recurrence_id TEXT;");
      } catch (DatabaseException) {
        // so that this method is idempotent
      }
    }
  }

  static void onCreate(Database db, int version) async {
    await db.execute("""CREATE TABLE IF NOT EXISTS categories (
            name  TEXT,
            color TEXT,
            icon INTEGER,
            category_type INTEGER,
            PRIMARY KEY (name, category_type)
        );
        """);

    await db.execute("""
        CREATE TABLE IF NOT EXISTS  records (
                id          INTEGER  PRIMARY KEY AUTOINCREMENT,
                datetime    INTEGER,
                value       REAL,
                title       TEXT,
                description TEXT,
                category_name TEXT,
                category_type INTEGER,
                recurrence_id TEXT
            );
        """);

    await db.execute("""
        CREATE TABLE IF NOT EXISTS  recurrent_record_patterns (
                id          TEXT  PRIMARY KEY,
                datetime    INTEGER,
                value       REAL,
                title       TEXT,
                description TEXT,
                category_name TEXT,
                category_type INTEGER,
                last_update INTEGER,
                recurrent_period INTEGER
            );
        """);

    List<Category> defaultCategories = getDefaultCategories();
    for (var defaultCategory in defaultCategories) {
      await db.insert("categories", defaultCategory.toMap());
    }
  }

  static List<Category> getDefaultCategories() {
    List<Category> defaultCategories = <Category>[];
    defaultCategories.add(new Category("House".i18n,
        color: Category.colors[0],
        iconCodePoint: FontAwesomeIcons.house.codePoint,
        categoryType: CategoryType.expense));
    defaultCategories.add(new Category("Transport".i18n,
        color: Category.colors[1],
        iconCodePoint: FontAwesomeIcons.bus.codePoint,
        categoryType: CategoryType.expense));
    defaultCategories.add(new Category("Food".i18n,
        color: Category.colors[2],
        iconCodePoint: FontAwesomeIcons.burger.codePoint,
        categoryType: CategoryType.expense));
    defaultCategories.add(new Category("Salary".i18n,
        color: Category.colors[3],
        iconCodePoint: FontAwesomeIcons.wallet.codePoint,
        categoryType: CategoryType.income));
    return defaultCategories;
  }

  // Category implementation
  @override
  Future<List<Category>> getAllCategories() async {
    final db = (await database)!;
    List<Map> results = await db.query("categories");
    return List.generate(results.length, (i) {
      return Category.fromMap(results[i] as Map<String, dynamic>);
    });
  }

  @override
  Future<Category?> getCategory(
      String? categoryName, CategoryType categoryType) async {
    final db = (await database)!;
    List<Map> results = await db.query("categories",
        where: "name = ? AND category_type = ?",
        whereArgs: [categoryName, categoryType.index]);
    return results.isNotEmpty
        ? Category.fromMap(results[0] as Map<String, dynamic>)
        : null;
  }

  @override
  Future<int> addCategory(Category? category) async {
    final db = (await database)!;
    Category? foundCategory =
        await this.getCategory(category!.name, category.categoryType!);
    if (foundCategory != null) {
      throw ElementAlreadyExists();
    }
    return await db.insert("categories", category.toMap());
  }

  @override
  Future<void> deleteCategory(
      String? categoryName, CategoryType? categoryType) async {
    final db = (await database)!;
    var categoryIndex = categoryType!.index;
    await db.delete("categories",
        where: "name = ? AND category_type = ?",
        whereArgs: [categoryName, categoryIndex]);
    await db.delete("records",
        where: "category_name = ? AND category_type = ?",
        whereArgs: [categoryName, categoryIndex]);
    await db.delete("recurrent_record_patterns",
        where: "category_name = ? AND category_type = ?",
        whereArgs: [categoryName, categoryIndex]);
  }

  @override
  Future<int> updateCategory(String? existingCategoryName,
      CategoryType? existingCategoryType, Category? updatedCategory) async {
    final db = (await database)!;
    var categoryIndex = existingCategoryType!.index;
    int newIndex = await db.update("categories", updatedCategory!.toMap(),
        where: "name = ? AND category_type = ?",
        whereArgs: [existingCategoryName, categoryIndex]);
    await db.update("records", {"category_name": updatedCategory.name},
        where: "category_name = ? AND category_type = ?",
        whereArgs: [existingCategoryName, categoryIndex]);
    await db.update(
        "recurrent_record_patterns", {"category_name": updatedCategory.name},
        where: "category_name = ? AND category_type = ?",
        whereArgs: [existingCategoryName, categoryIndex]);
    return newIndex;
  }

  @override
  Future<int> addRecord(Record? record) async {
    final db = (await database)!;
    if (await getCategory(
            record!.category!.name, record.category!.categoryType!) ==
        null) {
      await addCategory(record.category);
    }
    return await db.insert("records", record.toMap());
  }

  @override
  Future<Record?> getMatchingRecord(Record? record) async {
    /// Check if there are records with the same title, value, category on the same day of :record
    /// If yes, return the first match. If no, null is returned.
    final db = await database;
    var sameDateTime = record!.dateTime!.millisecondsSinceEpoch;
    var sameValue = record.value;
    var sameTitle = record.title;
    var sameCategoryName = record.category!.name;
    var sameCategoryType = record.category!.categoryType!.index;
    var maps;
    if (sameTitle != null) {
      maps = await db!.rawQuery("""
            SELECT m.*, c.name, c.color, c.category_type, c.icon
            FROM records as m LEFT JOIN categories as c ON m.category_name = c.name
            WHERE m.datetime = ? AND m.value = ? AND m.title = ? AND c.name = ? AND c.category_type = ?
        """, [
        sameDateTime,
        sameValue,
        sameTitle,
        sameCategoryName,
        sameCategoryType
      ]);
    } else {
      maps = await db!.rawQuery("""
            SELECT m.*, c.name, c.color, c.category_type, c.icon
            FROM records as m LEFT JOIN categories as c ON m.category_name = c.name
            WHERE m.datetime = ? AND m.value = ? AND m.title IS NULL AND c.name = ? AND c.category_type = ?
        """, [sameDateTime, sameValue, sameCategoryName, sameCategoryType]);
    }
    var matching = List.generate(maps.length, (i) {
      Map<String, dynamic> currentRowMap = Map<String, dynamic>.from(maps[i]);
      currentRowMap["category"] = Category.fromMap(currentRowMap);
      return Record.fromMap(currentRowMap);
    });
    return (matching.isEmpty) ? null : matching.first;
  }

  @override
  Future<List<Record>> getAllRecords() async {
    final db = (await database)!;
    var maps = await db.rawQuery("""
            SELECT m.*, c.name, c.color, c.category_type, c.icon
            FROM records as m LEFT JOIN categories as c ON m.category_name = c.name AND m.category_type = c.category_type
        """);
    return List.generate(maps.length, (i) {
      Map<String, dynamic> currentRowMap = Map<String, dynamic>.from(maps[i]);
      currentRowMap["category"] = Category.fromMap(currentRowMap);
      return Record.fromMap(currentRowMap);
    });
  }

  Future<List<String>> suggestedRecordTitles(
      String search, String categoryName) async {
    final db = (await database)!;
    var maps = await db.rawQuery("""
            SELECT DISTINCT m.title 
            FROM records as m WHERE m.title LIKE ? AND m.category_name = ? 
        """, ["%$search%", categoryName]);
    return List.generate(maps.length, (i) {
      Map<String, dynamic> currentRowMap = Map<String, String>.from(maps[i]);
      return currentRowMap["title"];
    });
  }

  @override
  Future<List<Record>> getAllRecordsInInterval(
      DateTime? from, DateTime? to) async {
    final db = (await database)!;
    final fromUnix = from!.millisecondsSinceEpoch;
    final toUnix = to!.millisecondsSinceEpoch;

    var maps = await db.rawQuery("""
            SELECT m.*, c.name, c.color, c.category_type, c.icon
            FROM records as m LEFT JOIN categories as c ON m.category_name = c.name AND m.category_type = c.category_type
            WHERE m.datetime >= ? AND m.datetime <= ? 
        """, [fromUnix, toUnix]);

    return List.generate(maps.length, (i) {
      Map<String, dynamic> currentRowMap = Map<String, dynamic>.from(maps[i]);
      currentRowMap["category"] = Category.fromMap(currentRowMap);
      return Record.fromMap(currentRowMap);
    });
  }

  Future<void> deleteDatabase() async {
    final db = (await database)!;
    await db.execute("DELETE FROM records");
    await db.execute("DELETE FROM categories");
    await db.execute("DELETE FROM recurrent_record_patterns");
    await db.execute("UPDATE SQLITE_SEQUENCE SET SEQ=0 WHERE NAME='records'");
    await db
        .execute("UPDATE SQLITE_SEQUENCE SET SEQ=0 WHERE NAME='categories'");
    await db.execute(
        "UPDATE SQLITE_SEQUENCE SET SEQ=0 WHERE NAME='recurrent_record_patterns'");
    _db = null;
  }

  @override
  Future<List<Category>> getCategoriesByType(CategoryType categoryType) async {
    final db = (await database)!;
    List<Map> results = await db.query("categories",
        where: "category_type = ?", whereArgs: [categoryType.index]);
    return List.generate(results.length, (i) {
      return Category.fromMap(results[i] as Map<String, dynamic>);
    });
  }

  Future<Record?> getRecordById(int id) async {
    final db = (await database)!;
    var maps = await db.rawQuery("""
            SELECT m.*, c.name, c.color, c.category_type, c.icon
            FROM records as m LEFT JOIN categories as c ON m.category_name = c.name AND m.category_type = c.category_type
            WHERE m.id = ?
        """, [id]);

    var results = List.generate(maps.length, (i) {
      Map<String, dynamic> currentRowMap = Map<String, dynamic>.from(maps[i]);
      currentRowMap["category"] = Category.fromMap(currentRowMap);
      return Record.fromMap(currentRowMap);
    });

    return results.isNotEmpty ? results[0] : null;
  }

  @override
  Future<int> updateRecordById(int? movementId, Record? newMovement) async {
    final db = (await database)!;
    var recordMap = newMovement!.toMap();
    return await db
        .update("records", recordMap, where: "id = ?", whereArgs: [movementId]);
  }

  @override
  Future<void> deleteRecordById(int? id) async {
    final db = (await database)!;
    await db.delete("records", where: "id = ?", whereArgs: [id]);
  }

  @override
  Future<void> deleteFutureRecordsByPatternId(
      String recurrentPatternId, DateTime startingDate) async {
    final db = (await database)!;
    int millisecondsSinceEpoch = startingDate.millisecondsSinceEpoch;
    await db.delete("records",
        where: "recurrence_id = ? AND datetime >= ?",
        whereArgs: [recurrentPatternId, millisecondsSinceEpoch]);
  }

  @override
  Future<List<RecurrentRecordPattern>> getRecurrentRecordPatterns() async {
    final db = (await database)!;
    var maps = await db.rawQuery("""
            SELECT m.*, c.name, c.color, c.category_type, c.icon
            FROM recurrent_record_patterns as m LEFT JOIN categories as c ON m.category_name = c.name AND m.category_type = c.category_type
        """);

    var results = List.generate(maps.length, (i) {
      Map<String, dynamic> currentRowMap = Map<String, dynamic>.from(maps[i]);
      currentRowMap["category"] = Category.fromMap(currentRowMap);
      return RecurrentRecordPattern.fromMap(currentRowMap);
    });

    return results;
  }

  @override
  Future<RecurrentRecordPattern?> getRecurrentRecordPattern(
      String? recurrentPatternId) async {
    final db = (await database)!;
    var maps = await db.rawQuery("""
            SELECT m.*, c.name, c.color, c.category_type, c.icon
            FROM recurrent_record_patterns as m LEFT JOIN categories as c ON m.category_name = c.name AND m.category_type = c.category_type
            WHERE m.id = ?
        """, [recurrentPatternId]);

    var results = List.generate(maps.length, (i) {
      Map<String, dynamic> currentRowMap = Map<String, dynamic>.from(maps[i]);
      currentRowMap["category"] = Category.fromMap(currentRowMap);
      return RecurrentRecordPattern.fromMap(currentRowMap);
    });

    return results.isNotEmpty ? results[0] : null;
  }

  @override
  Future<int> addRecurrentRecordPattern(
      RecurrentRecordPattern recordPattern) async {
    final db = (await database)!;
    var uuid = Uuid().v4();
    recordPattern.id = uuid;
    return await db.insert("recurrent_record_patterns", recordPattern.toMap());
  }

  @override
  Future<void> deleteRecurrentRecordPatternById(
      String? recurrentPatternId) async {
    final db = (await database)!;
    await db.delete("recurrent_record_patterns",
        where: "id = ?", whereArgs: [recurrentPatternId]);
  }

  @override
  Future<int> updateRecordPatternById(
      String? recurrentPatternId, RecurrentRecordPattern pattern) async {
    final db = (await database)!;
    var patternMap = pattern.toMap();
    return await db.update("recurrent_record_patterns", patternMap,
        where: "id = ?", whereArgs: [recurrentPatternId]);
  }

  @override
  Future<DateTime?> getDateTimeFirstRecord() async {
    final db = await database; // Assuming you have a database connection
    final maps = await db?.rawQuery("""
        SELECT m.*, c.name, c.color, c.category_type, c.icon
        FROM records as m LEFT JOIN categories as c ON m.category_name = c.name AND m.category_type = c.category_type
        ORDER BY m.datetime ASC
        LIMIT 1
      """);

    var results = List.generate(maps!.length, (i) {
      Map<String, dynamic> currentRowMap = Map<String, dynamic>.from(maps[i]);
      currentRowMap["category"] = Category.fromMap(currentRowMap);
      return Record.fromMap(currentRowMap);
    });

    return results.isNotEmpty ? results[0].dateTime : null;
  }
}
