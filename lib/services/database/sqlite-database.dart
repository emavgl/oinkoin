import 'dart:async';
import 'dart:io';

import 'package:piggybank/i18n.dart';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:piggybank/helpers/datetime-utility-functions.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/models/recurrent-record-pattern.dart';
import 'package:piggybank/services/database/database-interface.dart';
import 'package:piggybank/services/database/sqlite-migration-service.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common/sqflite_logger.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:uuid/uuid.dart';

import '../../models/profile.dart';
import '../../models/record-tag-association.dart';
import '../../models/wallet.dart';
import '../logger.dart';
import '../profile-service.dart';
import 'exceptions.dart';

class SqliteDatabase implements DatabaseInterface {
  /// SqliteDatabase is an implementation of DatabaseService using sqlite3 database.
  /// It is implemented using Singleton pattern.
  ///
  static final _logger = Logger.withClass(SqliteDatabase);

  SqliteDatabase._privateConstructor();
  static final SqliteDatabase instance = SqliteDatabase._privateConstructor();
  static int get version => 25;
  static Database? _db;

  /// For testing only: allows setting a custom database instance
  @visibleForTesting
  static void setDatabaseForTesting(Database? db) {
    _db = db;
  }

  Future<Database?> get database async {
    if (_db != null) return _db;

    // if _database is null we instantiate it
    _db = await init();
    return _db;
  }

  Future<Database> init() async {
    try {
      _logger.info('Initializing database...');

      // Initialize FFI for desktop platforms (Linux, Windows, macOS)
      if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
        _logger.debug('Initializing sqflite FFI for desktop platform');
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      }

      // Get proper database path
      String databasePath;
      if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
        // For desktop platforms, use application documents directory
        // This ensures we write to a writable location, not inside AppImage mount
        final appDocDir = await getApplicationDocumentsDirectory();
        databasePath = join(appDocDir.path, 'oinkoin');
        // Create directory if it doesn't exist
        final dir = Directory(databasePath);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
      } else {
        // For mobile platforms, use the default sqflite path
        databasePath = await getDatabasesPath();
      }

      String _path = join(databasePath, 'movements.db');
      _logger.debug('Database path: $_path');

      var factoryWithLogs = SqfliteDatabaseFactoryLogger(databaseFactory,
          options:
              SqfliteLoggerOptions(type: SqfliteDatabaseFactoryLoggerType.all));
      var db = await factoryWithLogs.openDatabase(
        _path,
        options: OpenDatabaseOptions(
            version: version,
            onCreate: SqliteMigrationService.onCreate,
            onUpgrade: SqliteMigrationService.onUpgrade,
            onDowngrade: SqliteMigrationService.onUpgrade),
      );
      _logger.info('Database initialized successfully (version: $version)');
      return db;
    } catch (e, st) {
      _logger.handle(e, st, 'Failed to initialize database');
      rethrow;
    }
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
    try {
      _logger.debug('Adding category: ${category?.name}');
      final db = (await database)!;
      Category? foundCategory =
          await this.getCategory(category!.name, category.categoryType!);
      if (foundCategory != null) {
        throw ElementAlreadyExists();
      }
      int result = await db.insert("categories", category.toMap());
      _logger.info('Category added: ${category.name}');
      return result;
    } catch (e, st) {
      if (e is ElementAlreadyExists) {
        _logger.warning('Category already exists: ${category?.name}');
      } else {
        _logger.handle(e, st, 'Failed to add category: ${category?.name}');
      }
      rethrow;
    }
  }

  @override
  Future<void> deleteCategory(
      String? categoryName, CategoryType? categoryType) async {
    try {
      _logger.debug('Deleting category: $categoryName');
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
      _logger.info('Category deleted: $categoryName');
    } catch (e, st) {
      _logger.handle(e, st, 'Failed to delete category: $categoryName');
      rethrow;
    }
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
    try {
      _logger.debug('Adding record: ${record?.title} (${record?.value})');
      final db = (await database)!;
      record!.profileId ??= ProfileService.instance.activeProfileId;
      if (await getCategory(
              record.category!.name, record.category!.categoryType!) ==
          null) {
        await addCategory(record.category);
      }
      int recordId = await db.insert("records", record.toMap());

      // Insert tags into records_tags table
      for (String? tag in record.tags) {
        if (tag != null && tag.trim().isNotEmpty) {
          await db.insert(
            "records_tags",
            {'record_id': recordId, 'tag_name': tag},
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
      }
      _logger.info('Record added: ID $recordId');
      return recordId;
    } catch (e, st) {
      _logger.handle(e, st, 'Failed to add record: ${record?.title}');
      rethrow;
    }
  }

  @override
  Future<void> addRecordsInBatch(List<Record?> records) async {
    try {
      _logger.debug('Adding ${records.length} records in batch...');
      final db = (await database)!;
      Batch batch = db.batch();

      for (var record in records) {
        if (record == null) {
          continue;
        }
        record.id = null;

        record.profileId ??= ProfileService.instance.activeProfileId;
        batch.rawInsert("""
      INSERT OR IGNORE INTO records (title, value, datetime, timezone, category_name, category_type, description, recurrence_id, wallet_id, transfer_wallet_id, transfer_value, profile_id)
      SELECT ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
      WHERE NOT EXISTS (
        SELECT 1 FROM records
        WHERE datetime = ?
          AND value = ?
          AND title IS ?
          AND category_name = ?
          AND category_type = ?
          AND wallet_id IS ?
          AND (profile_id IS NULL OR profile_id = ?)
      )
    """, [
          record.title,
          record.value,
          record.utcDateTime.millisecondsSinceEpoch,
          record.timeZoneName,
          record.category!.name,
          record.category!.categoryType!.index,
          record.description,
          record.recurrencePatternId,
          record.walletId,
          record.transferWalletId,
          record.transferValue,
          record.profileId,

          // Duplicate check values
          record.utcDateTime.millisecondsSinceEpoch,
          record.value,
          record.title,
          record.category!.name,
          record.category!.categoryType!.index,
          record.walletId,
          record.profileId,
        ]);
      }

      await batch.commit(noResult: true);
      _logger.info('Batch insert committed: ${records.length} records');

      // Insert tags for each record in a second batch after getting record IDs
      Batch tagBatch = db.batch();
      for (var record in records) {
        if (record == null || record.tags.isEmpty) {
          continue;
        }

        // Find the record ID by querying for the record we just inserted
        var recordId = await db.rawQuery("""
        SELECT id FROM records
        WHERE datetime = ?
          AND value = ?
          AND title IS ?
          AND category_name = ?
          AND category_type = ?
          AND wallet_id IS ?
          AND (profile_id IS NULL OR profile_id = ?)
        LIMIT 1
      """, [
          record.utcDateTime.millisecondsSinceEpoch,
          record.value,
          record.title,
          record.category!.name,
          record.category!.categoryType!.index,
          record.walletId,
          record.profileId,
        ]);

        if (recordId.isNotEmpty) {
          final id = recordId.first['id'] as int;
          for (String tag in record.tags) {
            if (tag.trim().isNotEmpty) {
              tagBatch.insert(
                "records_tags",
                {'record_id': id, 'tag_name': tag},
                conflictAlgorithm: ConflictAlgorithm.ignore,
              );
            }
          }
        }
      }

      await tagBatch.commit(noResult: true);
      _logger.info('Batch complete with tags');
    } catch (e, st) {
      _logger.handle(e, st, 'Failed to add records in batch');
      rethrow;
    }
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
  Future<List<Record>> getAllRecords({int? profileId}) async {
    final db = (await database)!;
    final profileFilter =
        profileId != null ? "WHERE m.profile_id = $profileId" : "";
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
            $profileFilter
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
    final List<RecordTagAssociation> associations = [];

    final cursor = await db.rawQueryCursor('SELECT * FROM records_tags', null);
    while (await cursor.moveNext()) {
      final row = cursor.current;
      if (row['record_id'] != null && row['tag_name'] != null) {
        associations.add(RecordTagAssociation.fromMap(row));
      }
    }
    cursor.close();

    return associations;
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
      DateTime? localDateTimeFrom, DateTime? localDateTimeTo,
      {int? profileId}) async {
    final db = (await database)!;

    final fromUtc =
        localDateTimeFrom!.subtract(const Duration(days: 1)).toUtc();
    final toUtc = localDateTimeTo!.add(const Duration(days: 1)).toUtc();

    final fromUnix = fromUtc.millisecondsSinceEpoch;
    final toUnix = toUtc.millisecondsSinceEpoch;

    final profileFilter =
        profileId != null ? "AND m.profile_id = $profileId" : "";

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
            $profileFilter
            GROUP BY m.id
        """, [fromUnix, toUnix]);

    final records = List.generate(maps.length, (i) {
      Map<String, dynamic> currentRowMap = Map<String, dynamic>.from(maps[i]);
      currentRowMap["category"] = Category.fromMap(currentRowMap);
      return Record.fromMap(currentRowMap);
    });

    final filteredRecords = records.where((record) {
      // Get the record's local date based on its stored timeZoneName.
      final recordLocation = getLocation(record.timeZoneName!);
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

    // Step 1: delete everything
    await db.execute("DELETE FROM records");
    await db.execute("DELETE FROM records_tags");
    await db.execute("DELETE FROM recurrent_record_patterns");
    await db.execute("DELETE FROM categories");
    await db.execute("DELETE FROM wallets");
    await db.execute("DELETE FROM profiles");

    // Reset all auto-increment sequences to 0
    for (final table in [
      'records', 'records_tags', 'recurrent_record_patterns',
      'categories', 'wallets', 'profiles',
    ]) {
      await db.execute(
          "UPDATE SQLITE_SEQUENCE SET SEQ=0 WHERE NAME='$table'");
    }

    // Step 2: recreate Default Profile and its Default Wallet
    final defaultProfileId = await db.rawInsert(
      "INSERT INTO profiles (name, is_default) VALUES (?, 1)",
      ["Default Profile".i18n],
    );
    await db.rawInsert(
      "INSERT INTO wallets (name, is_default, is_predefined, sort_order, profile_id) VALUES (?, 1, 1, 0, ?)",
      ["Default Wallet".i18n, defaultProfileId],
    );

    _db = null;
  }

  // Profile CRUD
  @override
  Future<List<Profile>> getAllProfiles() async {
    final db = (await database)!;
    final maps = await db.query('profiles', orderBy: 'id');
    return maps
        .map((m) => Profile.fromMap(Map<String, dynamic>.from(m)))
        .toList();
  }

  @override
  Future<Profile?> getDefaultProfile() async {
    final db = (await database)!;
    final maps = await db.query('profiles', where: 'is_default = 1', limit: 1);
    if (maps.isEmpty) return null;
    return Profile.fromMap(Map<String, dynamic>.from(maps.first));
  }

  @override
  Future<void> setDefaultProfile(int id) async {
    final db = (await database)!;
    await db.rawUpdate('UPDATE profiles SET is_default = 0');
    await db.rawUpdate('UPDATE profiles SET is_default = 1 WHERE id = ?', [id]);
  }

  @override
  Future<Profile?> getProfileById(int id) async {
    final db = (await database)!;
    final maps = await db.query('profiles', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Profile.fromMap(Map<String, dynamic>.from(maps.first));
  }

  @override
  Future<int> addProfile(Profile profile) async {
    final db = (await database)!;
    final map = profile.toMap()..remove('id');
    final profileId = await db.insert('profiles', map);
    await db.rawInsert(
      "INSERT INTO wallets (name, is_default, is_predefined, sort_order, profile_id, color) VALUES (?, 1, 1, 0, ?, ?)",
      ["Default Wallet".i18n, profileId, "255:129:199:132"],
    );
    return profileId;
  }

  @override
  Future<void> updateProfile(Profile profile) async {
    final db = (await database)!;
    final map = profile.toMap()..remove('id');
    await db.update('profiles', map, where: 'id = ?', whereArgs: [profile.id]);
  }

  @override
  Future<void> deleteProfileAndRecords(int id) async {
    final db = (await database)!;
    for (final table in ['records', 'recurrent_record_patterns', 'wallets']) {
      await db.delete(table, where: 'profile_id = ?', whereArgs: [id]);
    }
    await db.delete('profiles', where: 'id = ?', whereArgs: [id]);
  }

  // Wallet implementation

  static String _walletBalanceQuery({int? profileId}) {
    final profileFilter =
        profileId != null ? "WHERE w.profile_id = $profileId" : "";
    return """
    SELECT w.*,
           COALESCE(SUM(r.value), 0) +
           COALESCE((SELECT SUM(ABS(COALESCE(t.transfer_value, t.value))) FROM records t WHERE t.transfer_wallet_id = w.id), 0) +
           w.initial_amount AS balance
    FROM wallets w
    LEFT JOIN records r ON r.wallet_id = w.id
    $profileFilter
    GROUP BY w.id
    ORDER BY w.sort_order
  """;
  }

  @override
  Future<List<Wallet>> getAllWallets({int? profileId}) async {
    final db = (await database)!;
    final maps = await db.rawQuery(_walletBalanceQuery(profileId: profileId));
    return maps
        .map((m) => Wallet.fromMap(Map<String, dynamic>.from(m)))
        .toList();
  }

  @override
  Future<Wallet?> getWalletById(int id) async {
    final db = (await database)!;
    final maps = await db.rawQuery("""
      SELECT w.*,
             COALESCE(SUM(r.value), 0) +
             COALESCE((SELECT SUM(ABS(COALESCE(t.transfer_value, t.value))) FROM records t WHERE t.transfer_wallet_id = w.id), 0) +
             w.initial_amount AS balance
      FROM wallets w
      LEFT JOIN records r ON r.wallet_id = w.id
      WHERE w.id = ?
      GROUP BY w.id
    """, [id]);
    if (maps.isEmpty) return null;
    return Wallet.fromMap(Map<String, dynamic>.from(maps.first));
  }

  @override
  Future<Wallet?> getWalletByName(String name, int? profileId) async {
    final db = (await database)!;
    final maps = await db.rawQuery("""
      SELECT w.*,
             COALESCE(SUM(r.value), 0) +
             COALESCE((SELECT SUM(ABS(COALESCE(t.transfer_value, t.value))) FROM records t WHERE t.transfer_wallet_id = w.id), 0) +
             w.initial_amount AS balance
      FROM wallets w
      LEFT JOIN records r ON r.wallet_id = w.id
      WHERE w.name = ? AND w.profile_id IS ?
      GROUP BY w.id
    """, [name, profileId]);
    if (maps.isEmpty) return null;
    return Wallet.fromMap(Map<String, dynamic>.from(maps.first));
  }

  @override
  Future<int> addWallet(Wallet wallet) async {
    _logger.debug('Adding wallet: ${wallet.name}');
    final db = (await database)!;
    wallet.profileId ??= ProfileService.instance.activeProfileId;
    final map = wallet.toMap()..remove('id');
    final id = await db.insert('wallets', map);
    _logger.info('Wallet added: ID $id (${wallet.name})');
    return id;
  }

  @override
  Future<void> updateWallet(int id, Wallet wallet) async {
    _logger.debug('Updating wallet ID $id: ${wallet.name}');
    final db = (await database)!;
    final map = wallet.toMap()..remove('id');
    await db.update('wallets', map, where: 'id = ?', whereArgs: [id]);
    _logger.info('Wallet updated: ID $id (${wallet.name})');
  }

  @override
  Future<void> deleteWalletAndRecords(int id) async {
    _logger.debug('Deleting wallet ID $id and its records');
    final db = (await database)!;
    final wasSystemDefault = Sqflite.firstIntValue(await db
            .rawQuery('SELECT is_default FROM wallets WHERE id = ?', [id])) ==
        1;
    final wasPredefined = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT is_predefined FROM wallets WHERE id = ?', [id])) ==
        1;

    // Collect recurrence_ids from patterns being deleted so we can also
    // clean up records that may have been generated with a mismatched
    // wallet_id (e.g. NULL wallet due to a past import bug).
    final patternRows = await db.query('recurrent_record_patterns',
        columns: ['id'], where: 'wallet_id = ?', whereArgs: [id]);
    final recurrenceIds = patternRows.map((r) => r['id'] as String).toList();

    for (final table in ['records', 'recurrent_record_patterns']) {
      await db.delete(table, where: 'wallet_id = ?', whereArgs: [id]);
      await db.delete(table, where: 'transfer_wallet_id = ?', whereArgs: [id]);
    }
    await db.delete('wallets', where: 'id = ?', whereArgs: [id]);

    // Delete any remaining records generated from the deleted patterns
    // whose wallet_id may not match (e.g. NULL wallet).
    if (recurrenceIds.isNotEmpty) {
      final placeholders = recurrenceIds.map((_) => '?').join(',');
      await db.delete('records',
          where: 'recurrence_id IN ($placeholders)', whereArgs: recurrenceIds);
    }

    if (wasSystemDefault) await _ensureDefaultWallet(db);
    if (wasPredefined) await _ensurePredefinedWallet(db);
    _logger.info('Wallet ID $id deleted');
  }

  @override
  Future<void> moveRecordsToWallet(int fromId, int toId) async {
    _logger.debug('Moving records from wallet ID $fromId to wallet ID $toId');
    final db = (await database)!;
    for (final table in ['records', 'recurrent_record_patterns']) {
      await _migrateWalletRefsInTable(db, table, fromId, toId);
    }
    _logger.info('Records moved from wallet ID $fromId to wallet ID $toId');
  }

  /// Migrates all wallet references from [fromId] to [toId] in [table].
  ///
  /// Transfers that would become self-referential (source == destination) are
  /// deleted on both sides. All other wallet_id and transfer_wallet_id
  /// references are updated to point to [toId].
  Future<void> _migrateWalletRefsInTable(
      dynamic db, String table, int fromId, int toId) async {
    // Transfers between the two wallets would become self-transfers — delete both sides.
    await db.delete(table,
        where: 'wallet_id = ? AND transfer_wallet_id = ?',
        whereArgs: [fromId, toId]);
    await db.delete(table,
        where: 'wallet_id = ? AND transfer_wallet_id = ?',
        whereArgs: [toId, fromId]);
    await db.rawUpdate(
        'UPDATE $table SET wallet_id = ? WHERE wallet_id = ?', [toId, fromId]);
    await db.rawUpdate(
        'UPDATE $table SET transfer_wallet_id = ? WHERE transfer_wallet_id = ?',
        [toId, fromId]);
  }

  @override
  Future<void> archiveWallet(int id, bool isArchived) async {
    _logger.debug('${isArchived ? 'Archiving' : 'Unarchiving'} wallet ID $id');
    final db = (await database)!;
    final wasSystemDefault = Sqflite.firstIntValue(await db
            .rawQuery('SELECT is_default FROM wallets WHERE id = ?', [id])) ==
        1;
    final wasPredefined = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT is_predefined FROM wallets WHERE id = ?', [id])) ==
        1;
    await db.update(
      'wallets',
      {'is_archived': isArchived ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
    if (isArchived && wasSystemDefault) await _ensureDefaultWallet(db);
    if (isArchived && wasPredefined) await _ensurePredefinedWallet(db);
    _logger.info('Wallet ID $id ${isArchived ? 'archived' : 'unarchived'}');
  }

  /// Promotes the first active wallet to default.
  /// The original Default Wallet cannot be deleted, so there is always at least
  /// one active wallet available.
  Future<void> _ensureDefaultWallet(dynamic db) async {
    final rows = await db.rawQuery(
        'SELECT id FROM wallets WHERE is_archived = 0 ORDER BY sort_order LIMIT 1');
    if (rows.isNotEmpty) {
      final nextId = rows.first['id'] as int;
      await db.rawUpdate('UPDATE wallets SET is_default = 0');
      await db.rawUpdate(
          'UPDATE wallets SET is_default = 1 WHERE id = ?', [nextId]);
    }
  }

  Future<void> _ensurePredefinedWallet(dynamic db) async {
    // If no predefined wallet, set the first non-archived wallet as predefined
    final existingPredefined =
        await db.rawQuery('SELECT id FROM wallets WHERE is_predefined = 1');
    if (existingPredefined.isEmpty) {
      final rows = await db.rawQuery(
          'SELECT id FROM wallets WHERE is_archived = 0 ORDER BY sort_order LIMIT 1');
      if (rows.isNotEmpty) {
        final nextId = rows.first['id'] as int;
        await db.rawUpdate(
            'UPDATE wallets SET is_predefined = 1 WHERE id = ?', [nextId]);
      }
    }
  }

  @override
  Future<void> setDefaultWallet(int id) async {
    final db = (await database)!;
    await db.rawUpdate('UPDATE wallets SET is_default = 0');
    await db.rawUpdate('UPDATE wallets SET is_default = 1 WHERE id = ?', [id]);
  }

  @override
  Future<void> setPredefinedWallet(int id) async {
    final db = (await database)!;
    await db.rawUpdate('UPDATE wallets SET is_predefined = 0');
    await db
        .rawUpdate('UPDATE wallets SET is_predefined = 1 WHERE id = ?', [id]);
  }

  @override
  Future<Wallet?> getPredefinedWallet() async {
    final db = (await database)!;
    final maps = await db.rawQuery("""
      SELECT w.*,
             COALESCE(SUM(r.value), 0) +
             COALESCE((SELECT SUM(ABS(COALESCE(t.transfer_value, t.value))) FROM records t WHERE t.transfer_wallet_id = w.id), 0) +
             w.initial_amount AS balance
      FROM wallets w
      LEFT JOIN records r ON r.wallet_id = w.id
      WHERE w.is_predefined = 1
      GROUP BY w.id
      LIMIT 1
    """);
    if (maps.isEmpty) return null;
    return Wallet.fromMap(Map<String, dynamic>.from(maps.first));
  }

  @override
  Future<void> resetWalletOrderIndexes(List<Wallet> ordered) async {
    final db = (await database)!;
    final batch = db.batch();
    for (int i = 0; i < ordered.length; i++) {
      batch.update('wallets', {'sort_order': i},
          where: 'id = ?', whereArgs: [ordered[i].id]);
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<Wallet?> getDefaultWallet() async {
    final db = (await database)!;
    final maps = await db.rawQuery("""
      SELECT w.*,
             COALESCE(SUM(r.value), 0) +
             COALESCE((SELECT SUM(ABS(COALESCE(t.transfer_value, t.value))) FROM records t WHERE t.transfer_wallet_id = w.id), 0) +
             w.initial_amount AS balance
      FROM wallets w
      LEFT JOIN records r ON r.wallet_id = w.id
      WHERE w.is_default = 1
      GROUP BY w.id
      LIMIT 1
    """);
    if (maps.isEmpty) return null;
    return Wallet.fromMap(Map<String, dynamic>.from(maps.first));
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
      if (movementId != null && tag.trim().isNotEmpty) {
        await db.insert(
          "records_tags",
          {'record_id': movementId, 'tag_name': tag},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
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
  Future<void> deleteRecordsInBatch(List<int> ids) async {
    if (ids.isEmpty) return;
    _logger.debug('Batch deleting ${ids.length} records');
    final db = (await database)!;
    final placeholders = List.filled(ids.length, '?').join(',');
    await db.delete("records", where: "id IN ($placeholders)", whereArgs: ids);
    _logger.info('Batch deleted ${ids.length} records');
    // There is a db trigger, deleting a record automatically delete the associated tags
  }

  @override
  Future<void> updateRecordWalletInBatch(List<int> ids, int? walletId) async {
    if (ids.isEmpty) return;
    _logger.debug('Batch moving ${ids.length} records to wallet ID $walletId');
    final db = (await database)!;
    final placeholders = List.filled(ids.length, '?').join(',');
    await db.update("records", {"wallet_id": walletId},
        where: "id IN ($placeholders)", whereArgs: ids);
    _logger.info('Batch moved ${ids.length} records to wallet ID $walletId');
  }

  @override
  Future<void> duplicateRecordsInBatch(List<int> ids) async {
    if (ids.isEmpty) return;
    _logger.debug('Batch duplicating ${ids.length} records');
    final now = DateTime.now().toUtc();

    for (final id in ids) {
      final record = await getRecordById(id);
      if (record == null) continue;

      final duplicate = Record(
        record.value,
        record.title,
        record.category,
        now,
        description: record.description,
        tags: Set.from(record.tags),
        walletId: record.walletId,
        transferWalletId: record.transferWalletId,
        transferValue: record.transferValue,
        recurrencePatternId: record.recurrencePatternId,
        profileId: record.profileId,
        timeZoneName: record.timeZoneName,
      );
      await addRecord(duplicate);
    }
    _logger.info('Batch duplicated ${ids.length} records');
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
  Future<List<RecurrentRecordPattern>> getRecurrentRecordPatterns(
      {int? profileId}) async {
    final db = (await database)!;
    final profileFilter =
        profileId != null ? "WHERE m.profile_id = $profileId" : "";
    var maps = await db.rawQuery("""
            SELECT m.*, c.name, c.color, c.category_type, c.icon, c.icon_emoji, c.is_archived, m.tags
            FROM recurrent_record_patterns as m LEFT JOIN categories as c ON m.category_name = c.name AND m.category_type = c.category_type
            $profileFilter
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
    recordPattern.id ??= Uuid().v4();
    recordPattern.profileId ??= ProfileService.instance.activeProfileId;
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

  Future<void> renameTag(String oldTagName, String newTagName) async {
    final db = (await database)!;

    await db.transaction((txn) async {
      // 1. Find all record IDs associated with the old tag.
      final recordsWithOldTag = await txn.query(
        'records_tags',
        columns: ['record_id'],
        where: 'tag_name = ?',
        whereArgs: [oldTagName],
      );

      // 2. Delete all existing associations for the old tag.
      await txn.delete(
        'records_tags',
        where: 'tag_name = ?',
        whereArgs: [oldTagName],
      );

      // 3. Insert the associations with the new tag name.
      final batch = txn.batch();
      for (var row in recordsWithOldTag) {
        batch.insert(
          'records_tags',
          {'record_id': row['record_id'], 'tag_name': newTagName},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit();
    });
  }

  Future<void> deleteTag(String tagName) async {
    final db = (await database)!;

    // Delete all entries with the given tag_name in records_tags
    await db.delete(
      'records_tags',
      where: 'tag_name = ?',
      whereArgs: [tagName],
    );
  }
}
