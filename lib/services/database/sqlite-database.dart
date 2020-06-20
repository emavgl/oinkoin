import 'dart:async';
import 'package:path/path.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/models/records-summary-by-category.dart';
import 'package:piggybank/services/database/database-interface.dart';
import 'package:sqflite/sqflite.dart';

import 'exceptions.dart';

class SqliteDatabase implements DatabaseInterface {

    /// SqliteDatabase is an implementation of DatabaseService using sqlite3 database.
    /// It is implemented using Singleton pattern.

    SqliteDatabase._privateConstructor();
    static final SqliteDatabase instance = SqliteDatabase._privateConstructor();
    static int get _version => 1;
    static Database _db;

    Future<Database> get database async {
        if (_db != null)
            return _db;

        // if _database is null we instantiate it
        _db = await init();
        return _db;
    }

    Future<Database> init() async {
        String databasePath = await getDatabasesPath();
        String _path = join(databasePath, 'movements.db');
        return await openDatabase(_path, version: _version, onCreate: onCreate);
    }

    static void onCreate(Database db, int version) async {

        await db.execute("""CREATE TABLE IF NOT EXISTS categories (
            name  TEXT PRIMARY KEY,
            color TEXT,
            icon INTEGER,
            category_type INTEGER
        );
        """);

        await db.execute("""
        CREATE TABLE IF NOT EXISTS  records (
                id          INTEGER  PRIMARY KEY AUTOINCREMENT,
                datetime    INTEGER,
                value       REAL,
                title       TEXT,
                description TEXT,
                category_name TEXT REFERENCES categories (name)
            );
        """);
    }

    // Category implementation
    @override
    Future<List<Category>> getAllCategories() async {
        final db = await database;
        List<Map> results = await db.query("categories");
        return List.generate(results.length, (i) {
            return Category.fromMap(results[i]);
        });
    }

    @override
    Future<Category> getCategoryByName(String categoryName) async {
        final db = await database;
        List<Map> results = await db.query("categories", where: "name = ?", whereArgs: [categoryName]);
        return results.isNotEmpty ? Category.fromMap(results[0]) : null;
    }

    @override
    Future<int> addCategory(Category category) async {
        final db = await database;
        Category foundCategory = await this.getCategoryByName(category.name);
        if (foundCategory != null) {
            throw ElementAlreadyExists();
        }
        return await db.insert("categories", category.toMap());
    }

    @override
    Future<void> deleteCategoryByName(String categoryName) async {
        final db = await database;
        await db.delete("categories", where: "name = ?", whereArgs: [categoryName]);
        await db.delete("records", where: "category_name = ?", whereArgs: [categoryName]);
    }

    @override
    Future<int> updateCategory(Category category) async {
        final db = await database;
        String categoryName = category.name;
        return await db.update("categories", category.toMap(),
            where: "name = ?", whereArgs: [categoryName]);
    }

    @override
    Future<int> addRecord(Record record) async {
        final db = await database;
        if (await getCategoryByName(record.category.name) == null){
            await addCategory(record.category);
        }
        return await db.insert("records", record.toMap());
    }

    Future<List<Record>> getAllRecords() async {
        final db = await database;
        var maps = await db.rawQuery("""
            SELECT m.id, m.datetime, m.value, m.description, c.name, c.color, c.category_type, c.icon
            FROM records as m LEFT JOIN categories as c ON m.category_name = c.name
        """);
        return List.generate(maps.length, (i) {
            Map<String, dynamic> currentRowMap = Map<String, dynamic>.from(maps[i]);
            currentRowMap["category"] = Category.fromMap(currentRowMap);
            return Record.fromMap(currentRowMap);
        });
    }

    @override
    Future<List<Record>> getAllRecordsInInterval(DateTime from, DateTime to) async {
        final db = await database;
        final from_unix = from.millisecondsSinceEpoch;
        final to_unix = to.millisecondsSinceEpoch;

        var maps = await db.rawQuery("""
            SELECT m.id, m.datetime, m.value, m.description, c.name, c.color, c.category_type, c.icon
            FROM records as m LEFT JOIN categories as c ON m.category_name = c.name
            WHERE m.datetime >= ? AND m.datetime <= ? 
        """, [from_unix, to_unix]);

        // Convert the List<Map<String, dynamic> into a List<Dog>. // TODO woof woof
        return List.generate(maps.length, (i) {
            Map<String, dynamic> currentRowMap = Map<String, dynamic>.from(maps[i]);
            currentRowMap["category"] = Category.fromMap(currentRowMap);
            return Record.fromMap(currentRowMap);
        });
    }

    Future<void> deleteTables() async {
        final db = await database;
        await db.execute("DELETE FROM records");
        await db.execute("DELETE FROM categories");
        await db.execute("UPDATE SQLITE_SEQUENCE SET SEQ=0 WHERE NAME='records'");
        await db.execute("UPDATE SQLITE_SEQUENCE SET SEQ=0 WHERE NAME='categories'");
        _db = null;
    }

      @override
      Future<List<Category>> getCategoriesByType(int categoryType) async {
          final db = await database;
          List<Map> results = await db.query("categories", where: "category_type = ?", whereArgs: [categoryType]);

          return List.generate(results.length, (i) {
              return Category.fromMap(results[i]);
          });
      }

    Future<Record> getRecordById(int id) async {
        final db = await database;
        var maps = await db.rawQuery("""
            SELECT m.id, m.datetime, m.value, m.description, c.name, c.color, c.category_type, c.icon
            FROM records as m LEFT JOIN categories as c ON m.category_name = c.name
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
    Future<int> updateRecordById(int movementId, Record newMovement) async {
        final db = await database;
        return await db.update("records", newMovement.toMap(),
            where: "id = ?", whereArgs: [movementId]);
    }

    @override
    Future<void> deleteRecordById(int id) async {
        final db = await database;
        await db.delete("records", where: "id = ?", whereArgs: [id]);
    }

    // TODO Stefano: I'm working on it. The method is to be tested
    @override
    Future<List<RecordsSummaryPerCategory>> getExpensesInIntervalByCategory(DateTime from, DateTime to) async {
        final db = await database;
        final from_unix = from.millisecondsSinceEpoch;
        final to_unix = to.millisecondsSinceEpoch;

        var maps = await db.rawQuery("""
            SELECT SUM(m.value), c.color, c.name
            FROM movements as m LEFT JOIN categories as c ON m.category_id = c.id
            WHERE m.value < 0 AND m.datetime >= ? AND m.datetime <= ? 
            GROUP BY c.id
        """, [from_unix, to_unix]);

        // Convert the List<Map<String, dynamic> into a List<MovementsPerCategory>.
        return List.generate(maps.length, (i) {
            Map<String, dynamic> currentRowMap = Map<String, dynamic>.from(maps[i]);
            currentRowMap["category"] = Category.fromMap(currentRowMap);
            return RecordsSummaryPerCategory.fromMap(currentRowMap);
        });
    }

}