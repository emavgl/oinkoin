import 'dart:async';

import 'package:path/path.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/models/recurrent-record-pattern.dart';
import 'package:piggybank/services/database/database-interface.dart';
import 'package:piggybank/services/database/sqlite-migration-service.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common/sqflite_logger.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:uuid/uuid.dart';

import '../../models/record-tag-association.dart';
import 'exceptions.dart';

class SqliteDatabase implements DatabaseInterface {
  /// SqliteDatabase is an implementation of DatabaseService using sqlite3 database.
  /// It is implemented using Singleton pattern.
  ///
  SqliteDatabase._privateConstructor();
  static final SqliteDatabase instance = SqliteDatabase._privateConstructor();
  static int get version => 15;
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
    var factoryWithLogs = SqfliteDatabaseFactoryLogger(databaseFactory,
        options:
            SqfliteLoggerOptions(type: SqfliteDatabaseFactoryLoggerType.all));
    return await factoryWithLogs.openDatabase(
      _path,
      options: OpenDatabaseOptions(
          version: version,
          onCreate: SqliteMigrationService.onCreate,
          onUpgrade: SqliteMigrationService.onUpgrade,
          onDowngrade: SqliteMigrationService.onUpgrade),
    );
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
    int recordId = await db.insert("records", record.toMap());

    // Insert tags into records_tags table
    for (String tag in record.tags) {
      if (tag.trim().isNotEmpty) {
        await db.insert(
          "records_tags",
          {'record_id': recordId, 'tag_name': tag},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    }
    return recordId;
  }

  @override
  Future<void> addRecordsInBatch(List<Record?> records) async {
    final db = (await database)!;
    Batch batch = db.batch();

    for (var record in records) {
      if (record == null) {
        continue;
      }
      record.id = null;

      // Update the INSERT statement to include the new column `time_zone_name`
      batch.rawInsert("""
      INSERT OR IGNORE INTO records (title, value, datetime, timezone, category_name, category_type, description, recurrence_id) 
      SELECT ?, ?, ?, ?, ?, ?, ?, ?
      WHERE NOT EXISTS (
        SELECT 1 FROM records 
        WHERE datetime = ? 
          AND value = ? 
          AND (title IS NULL OR title = ?) 
          AND category_name = ? 
          AND category_type = ?
      )
    """, [
        record.title,
        record.value,
        record.utcDateTime.millisecondsSinceEpoch, // Use utcDateTime
        record.timeZoneName, // Store the timezone name
        record.category!.name,
        record.category!.categoryType!.index,
        record.description,
        record.recurrencePatternId,

        // Duplicate check values
        record.utcDateTime.millisecondsSinceEpoch,
        record.value,
        record.title,
        record.category!.name,
        record.category!.categoryType!.index,
      ]);

      // Insert tags into records_tags table for each record in the batch
      for (String tag in record.tags) {
        batch.insert(
          "records_tags",
          {'record_id': record.id, 'tag_name': tag},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    }

    await batch.commit(noResult: true);
  }

  @override
  Future<Record?> getMatchingRecord(Record? record) async {
    final db = await database;
    var sameDateTime = record!.utcDateTime.millisecondsSinceEpoch;
    var sameValue = record.value;
    var sameTitle = record.title;
    var sameCategoryName = record.category!.name;
    var sameCategoryType = record.category!.categoryType!.index;
    var maps;
    if (sameTitle != null) {
      maps = await db!.rawQuery("""
            SELECT m.*, c.name, c.color, c.category_type, c.icon, c.icon_emoji
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
            SELECT m.*, c.name, c.color, c.category_type, c.icon, c.icon_emoji
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
            SELECT
                m.*,
                c.name,
                c.color,
                c.category_type,
                c.icon,
                c.icon_emoji,
                GROUP_CONCAT(rt.tag_name) AS tags
            FROM records AS m
            LEFT JOIN categories AS c
                ON m.category_name = c.name AND m.category_type = c.category_type
            LEFT JOIN records_tags AS rt
                ON m.id = rt.record_id
            GROUP BY m.id
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
  Future<List<String>> getTagsForRecord(int recordId) async {
    final db = (await database)!;
    final List<Map<String, dynamic>> maps = await db.query(
      'records_tags',
      columns: ['tag_name'],
      where: 'record_id = ?',
      whereArgs: [recordId],
    );
    return List.generate(maps.length, (i) => maps[i]['tag_name'] as String);
  }

  @override
  Future<Set<String>> getAllTags() async {
    final db = (await database)!;
    final List<Map<String, dynamic>> maps = await db.query(
      'records_tags',
      columns: ['tag_name'],
      distinct: true,
    );
    return List.generate(maps.length, (i) => maps[i]['tag_name'] as String)
        .toSet();
  }

  @override
  Future<List<RecordTagAssociation>> getAllRecordTagAssociations() async {
    final db = (await database)!;
    final List<Map<String, dynamic>> maps = await db.query('records_tags');
    return List.generate(
        maps.length, (i) => RecordTagAssociation.fromMap(maps[i]));
  }

  @override
  Future<void> addRecordTagAssociationsInBatch(
      List<RecordTagAssociation>? associations) async {
    final db = (await database)!;
    Batch batch = db.batch();
    for (var association in associations!) {
      batch.insert('records_tags', association.toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<Set<String>> getMostUsedTagsForCategory(
      String categoryName, CategoryType categoryType) async {
    final db = (await database)!;
    final List<Map<String, dynamic>> maps = await db.rawQuery("""
      SELECT rt.tag_name, COUNT(rt.tag_name) as tag_count
      FROM records_tags AS rt
      INNER JOIN records AS r
        ON rt.record_id = r.id
      WHERE r.category_name = ? AND r.category_type = ?
      GROUP BY rt.tag_name
      ORDER BY tag_count DESC
      LIMIT 5
    """, [categoryName, categoryType.index]);
    return List.generate(maps.length, (i) => maps[i]['tag_name'] as String)
        .toSet();
  }

  @override
  Future<List<Record>> getAllRecordsInInterval(
      DateTime? localDateTimeFrom, DateTime? localDateTimeTo) async {
    final db = (await database)!;

    final fromUtc =
        localDateTimeFrom!.subtract(const Duration(days: 1)).toUtc();
    final toUtc = localDateTimeTo!.add(const Duration(days: 1)).toUtc();

    final fromUnix = fromUtc.millisecondsSinceEpoch;
    final toUnix = toUtc.millisecondsSinceEpoch;

    var maps = await db.rawQuery("""
            SELECT
                m.*,
                c.name,
                c.color,
                c.category_type,
                c.icon,
                c.icon_emoji,
                c.is_archived,
                GROUP_CONCAT(rt.tag_name) AS tags
            FROM records AS m
            LEFT JOIN categories AS c
                ON m.category_name = c.name AND m.category_type = c.category_type
            LEFT JOIN records_tags AS rt
                ON m.id = rt.record_id
            WHERE m.datetime >= ? AND m.datetime <= ?
            GROUP BY m.id
        """, [fromUnix, toUnix]);

    final records = List.generate(maps.length, (i) {
      Map<String, dynamic> currentRowMap = Map<String, dynamic>.from(maps[i]);
      currentRowMap["category"] = Category.fromMap(currentRowMap);
      return Record.fromMap(currentRowMap);
    });

    final filteredRecords = records.where((record) {
      // Get the record's local date based on its stored timeZoneName.
      final recordLocation = tz.getLocation(record.timeZoneName!);
      final recordLocalTime =
          tz.TZDateTime.from(record.utcDateTime, recordLocation);
      final recordDate = DateTime(recordLocalTime.year, recordLocalTime.month,
          recordLocalTime.day, recordLocalTime.hour, recordLocalTime.minute);
      return !recordDate.isBefore(localDateTimeFrom) &&
          !recordDate.isAfter(localDateTimeTo);
    }).toList();

    return filteredRecords;
  }

  @override
  Future<List<Map<String, dynamic>>> getAggregatedRecordsByTagInInterval(
      DateTime? from, DateTime? to) async {
    final db = (await database)!;

    final fromUtc = from!.subtract(const Duration(days: 1)).toUtc();
    final toUtc = to!.add(const Duration(days: 1)).toUtc();

    final fromUnix = fromUtc.millisecondsSinceEpoch;
    final toUnix = toUtc.millisecondsSinceEpoch;

    final List<Map<String, dynamic>> maps = await db.rawQuery("""
      SELECT
        rt.tag_name AS key,
        SUM(r.value) AS value
      FROM records_tags AS rt
      INNER JOIN records AS r
        ON rt.record_id = r.id
      WHERE r.datetime >= ? AND r.datetime <= ?
      GROUP BY rt.tag_name
      ORDER BY value DESC
    """, [fromUnix, toUnix]);
    return maps;
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
            SELECT
                m.*,
                c.name,
                c.color,
                c.category_type,
                c.icon,
                c.icon_emoji,
                c.is_archived,
                GROUP_CONCAT(rt.tag_name) AS tags
            FROM records AS m
            LEFT JOIN categories AS c
                ON m.category_name = c.name AND m.category_type = c.category_type
            LEFT JOIN records_tags AS rt
                ON m.id = rt.record_id
            WHERE m.id = ?
            GROUP BY m.id
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
    if (recordMap['id'] == null) {
      recordMap['id'] = movementId;
    }
    int updatedRows = await db
        .update("records", recordMap, where: "id = ?", whereArgs: [movementId]);

    // Delete existing tags for the record
    await db.delete("records_tags",
        where: "record_id = ?", whereArgs: [movementId]);

    // Insert new tags into records_tags table
    for (String tag in newMovement.tags) {
      await db.insert(
        "records_tags",
        {'record_id': movementId, 'tag_name': tag},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    return updatedRows;
  }

  @override
  Future<void> deleteRecordById(int? id) async {
    final db = (await database)!;
    await db.delete("records", where: "id = ?", whereArgs: [id]);
    // There is a db trigger, deleting a record automatically delete the associated tags
  }

  @override
  Future<void> deleteFutureRecordsByPatternId(
      String recurrentPatternId, DateTime startingDate) async {
    final db = (await database)!;
    int millisecondsSinceEpoch = startingDate.millisecondsSinceEpoch;
    await db.delete("records",
        where: "recurrence_id = ? AND datetime >= ?",
        whereArgs: [recurrentPatternId, millisecondsSinceEpoch]);
    // There is a db trigger, deleting a record automatically delete the associated tags
  }

  @override
  Future<List<RecurrentRecordPattern>> getRecurrentRecordPatterns() async {
    final db = (await database)!;
    var maps = await db.rawQuery("""
            SELECT m.*, c.name, c.color, c.category_type, c.icon, c.icon_emoji, c.is_archived, m.tags
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
            SELECT m.*, c.name, c.color, c.category_type, c.icon, c.icon_emoji, m.tags
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
    final db = await database;
    final maps = await db?.rawQuery("""
        SELECT m.*, c.name, c.color, c.category_type, c.icon, c.icon_emoji
        FROM records as m LEFT JOIN categories as c ON m.category_name = c.name AND m.category_type = c.category_type
        ORDER BY m.datetime ASC
        LIMIT 1
      """);

    var results = List.generate(maps!.length, (i) {
      Map<String, dynamic> currentRowMap = Map<String, dynamic>.from(maps[i]);
      currentRowMap["category"] = Category.fromMap(currentRowMap);
      return Record.fromMap(currentRowMap);
    });

    return results.isNotEmpty ? results[0].utcDateTime : null;
  }

  Future<void> archiveCategory(
      String categoryName, CategoryType categoryType, bool isArchived) async {
    final db = (await database)!;

    // Convert the boolean `isArchived` to integer (1 for true, 0 for false)
    int isArchivedInt = isArchived ? 1 : 0;

    // Update the category in the database
    await db.update(
      "categories",
      {"is_archived": isArchivedInt},
      where: "name = ? AND category_type = ?",
      whereArgs: [categoryName, categoryType.index],
    );
  }

  @override
  Future<void> resetCategoryOrderIndexes(
      List<Category> orderedCategories) async {
    final db = (await database)!;

    // Update the sortOrder of each category based on its index in the ordered list
    for (int i = 0; i < orderedCategories.length; i++) {
      Category category = orderedCategories[i];
      int sortOrder =
          i; // Index of category in the ordered list is the sortOrder

      await db.update(
        "categories",
        {"sort_order": sortOrder},
        where: "name = ? AND category_type = ?",
        whereArgs: [category.name, category.categoryType!.index],
      );
    }
  }

  @override
  Future<Set<String>> getRecentlyUsedTags() async {
    final db = (await database)!;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT DISTINCT rt.tag_name
      FROM records_tags AS rt
      INNER JOIN records AS r
        ON rt.record_id = r.id
      ORDER BY r.datetime DESC
      LIMIT 10
    ''');
    return List.generate(maps.length, (i) => maps[i]['tag_name'] as String)
        .toSet();
  }
}
