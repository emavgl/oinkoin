import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:path/path.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/movement.dart';
import 'package:piggybank/models/movements-per-category.dart';
import 'package:piggybank/models/movements-summary-by-category.dart';
import 'package:piggybank/services/database-service.dart';
import 'package:sqflite/sqflite.dart';

class SqliteDatabase implements DatabaseService {

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
        String _path = join(await getDatabasesPath(), 'movements3.db');
        return await openDatabase(_path, version: _version, onCreate: onCreate);
    }

    static void onCreate(Database db, int version) async {

        await db.execute("""CREATE TABLE IF NOT EXISTS categories (
            id    INTEGER PRIMARY KEY AUTOINCREMENT
            NOT NULL,
            name  TEXT,
            color TEXT,
            icon INTEGER,
            category_type INTEGER
        );
        """);

        await db.execute("""
        CREATE TABLE IF NOT EXISTS  movements (
                id          INTEGER  PRIMARY KEY AUTOINCREMENT,
                datetime    INTEGER,
                value       REAL,
                description TEXT,
                category_id INTEGER  REFERENCES categories (id) 
            );
        """);
    }

    Future<Category> getCategoryById(int id) async {
        final db = await database;
        List<Map> results = await db.query("categories", where: "id = ?",
        whereArgs: [id]);
        return results.isNotEmpty ? Category.fromMap(results[0]) : null;
    }

    Future<Movement> getMovementById(int id) async {
        final db = await database;
        var maps = await db.rawQuery("""
            SELECT m.id, m.datetime, m.value, m.description, m.category_id, c.color, c.name
            FROM movements as m LEFT JOIN categories as c ON m.category_id = c.id
            WHERE m.id = ?
        """, [id]);

        var results = List.generate(maps.length, (i) {
            Map<String, dynamic> currentRowMap = Map<String, dynamic>.from(maps[i]);
            currentRowMap["category"] = Category.fromMap(currentRowMap);
            return Movement.fromMap(currentRowMap);
        });

        return results.isNotEmpty ? results[0] : null;
    }

    Future<List<Category>> getAllCategories() async {
        final db = await database;
        List<Map> results = await db.query("categories");

        // Convert the List<Map<String, dynamic> into a List<Dog>. // TODO woof woof
        return List.generate(results.length, (i) {
            return Category.fromMap(results[i]);
        });
    }

    Future<Category> getCategoryByName(String categoryName) async {
        final db = await database;
        List<Map> results = await db.query("categories", where: "name = ?", whereArgs: [categoryName]);
        return results.isNotEmpty ? Category.fromMap(results[0]) : null;
    }

    Future<int> addCategoryIfNotExists(Category category) async {
        final db = await database;
        var existingCategory = await getCategoryByName(category.name);
        if (existingCategory != null) {
            return existingCategory.id;
        } else {
            return await db.insert("categories", category.toMap());
        }
    }

    Future<int> addMovement(Movement movement) async {
        final db = await database;
        int categoryId = await addCategoryIfNotExists(movement.category);
        movement.category.id = categoryId;
        return await db.insert("movements", movement.toMap());
    }

    Future<List<Movement>> getAllMovements() async {
        final db = await database;
        var maps = await db.rawQuery("""
            SELECT m.id, m.datetime, m.value, m.description, m.category_id, c.color, c.name
            FROM movements as m LEFT JOIN categories as c ON m.category_id = c.id
        """);
        
        // Convert the List<Map<String, dynamic> into a List<Dog>. // TODO woof woof
        return List.generate(maps.length, (i) {
            Map<String, dynamic> currentRowMap = Map<String, dynamic>.from(maps[i]);
            currentRowMap["category"] = Category.fromMap(currentRowMap);
            return Movement.fromMap(currentRowMap);
        });
    }

    @override
    Future<List<Movement>> getAllMovementsInInterval(DateTime from, DateTime to) async {
        final db = await database;
        final from_unix = from.millisecondsSinceEpoch;
        final to_unix = to.millisecondsSinceEpoch;

        var maps = await db.rawQuery("""
            SELECT m.id, m.datetime, m.value, m.description, m.category_id, c.color, c.name
            FROM movements as m LEFT JOIN categories as c ON m.category_id = c.id
            WHERE m.datetime >= ? AND m.datetime <= ? 
        """, [from_unix, to_unix]);

        // Convert the List<Map<String, dynamic> into a List<Dog>. // TODO woof woof
        return List.generate(maps.length, (i) {
            Map<String, dynamic> currentRowMap = Map<String, dynamic>.from(maps[i]);
            currentRowMap["category"] = Category.fromMap(currentRowMap);
            return Movement.fromMap(currentRowMap);
        });
    }

    Future<void> deleteTables() async {
        final db = await database;
        await db.execute("DELETE FROM movements");
        await db.execute("DELETE FROM categories");
        await db.execute("UPDATE SQLITE_SEQUENCE SET SEQ=0 WHERE NAME='movements'");
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

      @override
      void deleteCategoryById(int id) {
        // TODO: implement deleteCategoryById
      }

      @override
      Future<int> upsertCategory(Category category) {
        // TODO: implement upsertCategory
      }




    // TODO Stefano: I'm working on it. The method is to be tested
    @override
    Future<List<MovementsSummaryPerCategory>> getExpensesInIntervalByCategory(DateTime from, DateTime to) async {
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
            return MovementsSummaryPerCategory.fromMap(currentRowMap);
        });
    }

  @override
  Future<int> updateMovementById(int movementId, Movement newMovement) {
    // TODO: implement updateMovementById
    throw UnimplementedError();
  }

}