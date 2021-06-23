import 'dart:async';
import 'dart:convert';
import 'dart:html';

import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/models/records-summary-by-category.dart';
import 'package:piggybank/models/recurrent-record-pattern.dart';
import 'package:piggybank/services/database/database-interface.dart';
import 'exceptions.dart';
import 'i18n/default-category-names.i18n.dart';
import 'package:uuid/uuid.dart';

import 'database-interface.dart';

class LocalStorageDatabase implements DatabaseInterface {

    static List<Category> getDefaultCategories() {
        List<Category> defaultCategories = [];
        defaultCategories.add(new Category("House".i18n,
            color: Category.colors[0],
            iconCodePoint: FontAwesomeIcons.home.codePoint,
            categoryType: CategoryType.expense
        ));
        defaultCategories.add(new Category("Transports".i18n,
            color: Category.colors[1],
            iconCodePoint: FontAwesomeIcons.bus.codePoint,
            categoryType: CategoryType.expense
        ));
        defaultCategories.add(new Category("Food".i18n,
            color: Category.colors[2],
            iconCodePoint: FontAwesomeIcons.hamburger.codePoint,
            categoryType: CategoryType.expense
        ));
        defaultCategories.add(new Category("Salary".i18n,
            color: Category.colors[3],
            iconCodePoint: FontAwesomeIcons.wallet.codePoint,
            categoryType: CategoryType.income
        ));
        return defaultCategories;
    }

    // Category implementation
    @override
    Future<List<Category>> getAllCategories() {
        String categoriesJSON = window.localStorage['categories'];
        List<dynamic> results = json.decode(categoriesJSON);
        return Future.value(List.generate(results.length, (i) {
            return Category.fromMap(results[i]);
        }));
    }

    Future<List<Category>> getCategoriesByType(CategoryType categoryType) async {
        List<Category> _categories = await getAllCategories();
        return Future<List<Category>>.value(_categories.where((x) => x.categoryType == categoryType).toList());
    }

    Future<Category> getCategory(String name, CategoryType categoryType) async {
        List<Category> _categories = await getAllCategories();
        var matching = _categories.where((x) => x.name == name && x.categoryType == categoryType).toList();
        return (matching.isEmpty) ? Future<Category>.value(null): Future<Category>.value(matching[0]);
    }

    @override
    Future<int> addCategory(Category category) async {
        Category foundCategory = await this.getCategory(category.name, category.categoryType);
        if (foundCategory != null) {
            throw ElementAlreadyExists();
        }
        List<Category> _categories = await getAllCategories();
        _categories.add(category);
        window.localStorage['categories'] = json.encode(_categories);
    }

    @override
    Future<void> deleteCategory(String categoryName, CategoryType categoryType) async {
        List<Category> _categories = await getAllCategories();
        _categories.removeWhere((x) => x.name == categoryName && x.categoryType == categoryType);
        // TODO: implement delete cascade in records and recurrent_record_patterns
        await db.delete("records", where: "category_name = ? AND category_type = ?", whereArgs: [categoryName, categoryIndex]);
        await db.delete("recurrent_record_patterns", where: "category_name = ? AND category_type = ?", whereArgs: [categoryName, categoryIndex]);
    }

    Future<int> updateCategory(String existingCategoryName, CategoryType existingCategoryType, Category updatedCategory) async {
        var categoryWithTheSameName = await getCategory(
            existingCategoryName, existingCategoryType);
        if (categoryWithTheSameName == null) {
            throw NotFoundException();
        }
        List<Category> _categories = await getAllCategories();
        var index = _categories.indexOf(categoryWithTheSameName);
        _categories[index] = updatedCategory;
        window.localStorage['categories'] = json.encode(_categories);
        // TODO: update records and recurrent_record_patterns?
        return Future<int>.value(index);
    }

    @override
    Future<int> addRecord(Record record) async {
        if (await getCategory(record.category.name, record.category.categoryType) == null){
            await addCategory(record.category);
        }
        List<Record> _records = await getAllRecords();
        _records.add(record);
        window.localStorage['records'] = json.encode(_records);
        return _records.length;
    }

    @override
    Future<Record> getMatchingRecord(Record record) async {
        /// Check if there are records with the same title, value, category on the same day of :record
        /// If yes, return the first match. If no, null is returned.
        var sameDateTime = record.dateTime.millisecondsSinceEpoch;
        var sameValue = record.value;
        var sameTitle = record.title;
        var sameCategoryName = record.category.name;
        var sameCategoryType = record.category.categoryType.index;
        var maps;
        List<Record> _records = await getAllRecords();
        if (sameTitle != null) {
            _records.where((x) => x.title == sameTitle && x.value == sameValue && x.category.name == sameCategoryName && x.category.categoryType.index == x)
            maps = await db.rawQuery("""
            SELECT m.*, c.name, c.color, c.category_type, c.icon
            FROM records as m LEFT JOIN categories as c ON m.category_name = c.name
            WHERE m.datetime = ? AND m.value = ? AND m.title = ? AND c.name = ? AND c.category_type = ?
        """, [sameDateTime, sameValue, sameTitle, sameCategoryName, sameCategoryType]);
        } else {
            maps = await db.rawQuery("""
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
        final db = await database;
        var maps = await db.rawQuery("""
            SELECT m.*, c.name, c.color, c.category_type, c.icon
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
        final fromUnix = from.millisecondsSinceEpoch;
        final toUnix = to.millisecondsSinceEpoch;

        var maps = await db.rawQuery("""
            SELECT m.*, c.name, c.color, c.category_type, c.icon
            FROM records as m LEFT JOIN categories as c ON m.category_name = c.name
            WHERE m.datetime >= ? AND m.datetime <= ? 
        """, [fromUnix, toUnix]);

        return List.generate(maps.length, (i) {
            Map<String, dynamic> currentRowMap = Map<String, dynamic>.from(maps[i]);
            currentRowMap["category"] = Category.fromMap(currentRowMap);
            return Record.fromMap(currentRowMap);
        });
    }

    Future<void> deleteDatabase() async {
        final db = await database;
        await db.execute("DELETE FROM records");
        await db.execute("DELETE FROM categories");
        await db.execute("DELETE FROM recurrent_records");
        await db.execute("UPDATE SQLITE_SEQUENCE SET SEQ=0 WHERE NAME='records'");
        await db.execute("UPDATE SQLITE_SEQUENCE SET SEQ=0 WHERE NAME='categories'");
        await db.execute("UPDATE SQLITE_SEQUENCE SET SEQ=0 WHERE NAME='recurrent_record_patterns'");
        _db = null;
    }

    @override
    Future<List<Category>> getCategoriesByType(CategoryType categoryType) async {
      final db = await database;
      List<Map> results = await db.query("categories", where: "category_type = ?", whereArgs: [categoryType.index]);
      return List.generate(results.length, (i) {
          return Category.fromMap(results[i]);
      });
    }

    Future<Record> getRecordById(int id) async {
        final db = await database;
        var maps = await db.rawQuery("""
            SELECT m.*, c.name, c.color, c.category_type, c.icon
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
        var recordMap = newMovement.toMap();
        return await db.update("records", recordMap,
            where: "id = ?", whereArgs: [movementId]);
    }

    @override
    Future<void> deleteRecordById(int id) async {
        final db = await database;
        await db.delete("records", where: "id = ?", whereArgs: [id]);
    }

    @override
    Future<List<RecurrentRecordPattern>> getRecurrentRecordPatterns() async {
        final db = await database;
        var maps = await db.rawQuery("""
            SELECT m.*, c.name, c.color, c.category_type, c.icon
            FROM recurrent_record_patterns as m LEFT JOIN categories as c ON m.category_name = c.name
        """);

        var results = List.generate(maps.length, (i) {
            Map<String, dynamic> currentRowMap = Map<String, dynamic>.from(maps[i]);
            currentRowMap["category"] = Category.fromMap(currentRowMap);
            return RecurrentRecordPattern.fromMap(currentRowMap);
        });

        return results;
    }

    @override
    Future<RecurrentRecordPattern> getRecurrentRecordPattern(String recurrentPatternId) async {
        final db = await database;
        var maps = await db.rawQuery("""
            SELECT m.*, c.name, c.color, c.category_type, c.icon
            FROM recurrent_record_patterns as m LEFT JOIN categories as c ON m.category_name = c.name
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
    Future<void> addRecurrentRecordPattern(RecurrentRecordPattern recordPattern) async {
        final db = await database;
        var uuid = Uuid().v4();
        recordPattern.id = uuid;
        return await db.insert("recurrent_record_patterns", recordPattern.toMap());
    }

    @override
    Future<void> deleteRecurrentRecordPatternById(String recurrentPatternId) async {
        final db = await database;
        await db.delete("recurrent_record_patterns",
            where: "id = ?", whereArgs: [recurrentPatternId]);
    }

    @override
    Future<void> updateRecordPatternById(String recurrentPatternId, RecurrentRecordPattern pattern) async {
        final db = await database;
        var patternMap = pattern.toMap();
        return await db.update("recurrent_record_patterns", patternMap,
            where: "id = ?", whereArgs: [recurrentPatternId]);
    }

    // TODO Stefano: I'm working on it. The method is to be tested
    @override
    Future<List<RecordsSummaryPerCategory>> getExpensesInIntervalByCategory(DateTime from, DateTime to) async {
        final db = await database;
        final fromUnix = from.millisecondsSinceEpoch;
        final toUnix = to.millisecondsSinceEpoch;

        var maps = await db.rawQuery("""
            SELECT SUM(m.value), c.color, c.name
            FROM movements as m LEFT JOIN categories as c ON m.category_id = c.id
            WHERE m.value < 0 AND m.datetime >= ? AND m.datetime <= ? 
            GROUP BY c.id
        """, [fromUnix, toUnix]);

        // Convert the List<Map<String, dynamic> into a List<MovementsPerCategory>.
        return List.generate(maps.length, (i) {
            Map<String, dynamic> currentRowMap = Map<String, dynamic>.from(maps[i]);
            currentRowMap["category"] = Category.fromMap(currentRowMap);
            return RecordsSummaryPerCategory.fromMap(currentRowMap);
        });
    }


}