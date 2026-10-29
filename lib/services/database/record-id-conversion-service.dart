import 'package:sqflite/sqflite.dart';

import '../logger.dart';

/// Size of the data stored in the tables a record id conversion rebuilds.
typedef _RecordCounts = ({int records, int tags});

/// Converts the record id representation of a database, so that a build that
/// expects a different one can open it.
///
/// Record ids became uuids in a newer database version. The conversion runs in
/// both directions:
///
/// * up, from the uuid migration (integer ids -> uuid);
/// * down, from the `onDowngrade` callback (uuid -> integer ids), because a
///   build that still expects integer ids cannot read uuids and a released
///   binary cannot be patched afterwards.
///
/// Callers must recreate the record triggers after a conversion: they are
/// dropped together with the table.
class RecordIdConversionService {
  static final _logger = Logger.withClass(RecordIdConversionService);

  /// SQL expression generating a random uuid v4. The application generates ids
  /// with `Uuid().v4()`; the conversions do it in SQL.
  static const String uuidV4Sql = "lower(hex(randomblob(4))) || '-' || "
      "lower(hex(randomblob(2))) || '-4' || "
      "substr(lower(hex(randomblob(2))), 2) || '-' || "
      "substr('89ab', abs(random()) % 4 + 1, 1) || "
      "substr(lower(hex(randomblob(2))), 2) || '-' || "
      "lower(hex(randomblob(6)))";

  /// Columns of `records` that are copied when the table is rebuilt. `id` is
  /// remapped, the other columns are carried over unchanged.
  static const String _copiedRecordColumns =
      'datetime, timezone, value, title, description, category_name, '
      'category_type, recurrence_id, wallet_id, transfer_wallet_id, '
      'transfer_value, profile_id';

  /// Replaces integer record ids with generated uuids and returns whether
  /// the database was converted (it is not when the ids are already uuids).
  ///
  /// Safe to run repeatedly: opening a database with an older version resets
  /// `user_version`, so the migration can run again on a converted database.
  static Future<bool> convertToUuidIds(Database db) async {
    if (!await _usesIntegerIds(db)) {
      _logger.info('Record ids are not integers, nothing to convert to uuids');
      return false;
    }

    _logger.info('Migrating record ids to uuids');
    final countsBefore = await _countRecordsAndTags(db);
    await _mapIntegerIdsToUuids(db);
    await _createUuidTables(db);
    await _copyRecordsAndTags(db, orderBy: 'r.id');
    await _replaceOldTables(db);
    await _verifyConversion(db, countsBefore, expectUuids: true);
    await _dropIdMap(db);
    _logger.info('Record ids migrated to uuids');
    return true;
  }

  /// Replaces uuid record ids with integer ids and returns whether the database
  /// was converted (it is not when the ids are already integers).
  ///
  /// The new ids are assigned in creation (`rowid`) order, so the record
  /// ordering used as tie-break stays the same.
  static Future<bool> convertToIntegerIds(Database db) async {
    if (!await _usesUuidIds(db)) {
      _logger.info('Record ids are not uuids, nothing to convert to integers');
      return false;
    }

    _logger.info('Converting record ids back to integers');
    final countsBefore = await _countRecordsAndTags(db);
    await _mapUuidIdsToIntegers(db);
    await _createIntegerTables(db);
    await _copyRecordsAndTags(db, orderBy: 'm.new_id');
    await _replaceOldTables(db);
    await _verifyConversion(db, countsBefore, expectUuids: false);
    await _dropIdMap(db);
    _logger.info('Record ids converted back to integers');
    return true;
  }

  static Future<void> _mapIntegerIdsToUuids(Database db) async {
    await _createIdMap(db, 'old_id INTEGER PRIMARY KEY, new_id TEXT NOT NULL');
    await db.execute('INSERT INTO records_id_map (old_id, new_id) '
        'SELECT id, $uuidV4Sql FROM records ORDER BY id');
  }

  static Future<void> _mapUuidIdsToIntegers(Database db) async {
    await _createIdMap(db,
        'new_id INTEGER PRIMARY KEY AUTOINCREMENT, old_id TEXT NOT NULL UNIQUE');
    await db.execute('INSERT INTO records_id_map (old_id) '
        'SELECT id FROM records ORDER BY rowid');
  }

  /// Temporary `old id -> new id` map used while the tables are rebuilt.
  static Future<void> _createIdMap(Database db, String columns) async {
    await db.execute('DROP TABLE IF EXISTS records_id_map');
    await db.execute('CREATE TEMP TABLE records_id_map ($columns)');
  }

  static Future<void> _createUuidTables(Database db) async {
    await db.execute('CREATE TABLE records_new ('
        'id TEXT PRIMARY KEY NOT NULL, $_copiedRecordColumns)');
    await db.execute('CREATE TABLE records_tags_new ('
        'record_id TEXT NOT NULL, tag_name TEXT NOT NULL, '
        'PRIMARY KEY (record_id, tag_name))');
  }

  static Future<void> _createIntegerTables(Database db) async {
    await db.execute('CREATE TABLE records_new ('
        'id INTEGER PRIMARY KEY AUTOINCREMENT, $_copiedRecordColumns)');
    await db.execute('CREATE TABLE records_tags_new ('
        'record_id INTEGER NOT NULL, tag_name TEXT NOT NULL, '
        'PRIMARY KEY (record_id, tag_name))');
  }

  /// Copies both tables through the id map. [orderBy] keeps the creation order,
  /// so the `rowid` sequence of the rebuilt table keeps matching the original
  /// insertion order.
  static Future<void> _copyRecordsAndTags(
    Database db, {
    required String orderBy,
  }) async {
    await db.execute(
      'INSERT INTO records_new (id, $_copiedRecordColumns) '
      'SELECT m.new_id, r.$_copiedRecordColumns '
      'FROM records r JOIN records_id_map m ON m.old_id = r.id '
      'ORDER BY $orderBy',
    );
    await db.execute('INSERT INTO records_tags_new (record_id, tag_name) '
        'SELECT m.new_id, rt.tag_name FROM records_tags rt '
        'JOIN records_id_map m ON m.old_id = rt.record_id');
  }

  static Future<void> _replaceOldTables(Database db) async {
    for (final table in ['records', 'records_tags']) {
      await db.execute('DROP TABLE $table');
      await db.execute('ALTER TABLE ${table}_new RENAME TO $table');
    }
  }

  /// Number of records and of tag associations that point at a record.
  /// Orphaned associations (possible in databases written by older versions)
  /// are ignored, so they cannot make the conversion fail.
  static Future<_RecordCounts> _countRecordsAndTags(Database db) async {
    final records =
        await db.rawQuery('SELECT COUNT(*) AS occurrences FROM records');
    final tags = await db.rawQuery('SELECT COUNT(*) AS occurrences '
        'FROM records_tags rt '
        'WHERE EXISTS (SELECT 1 FROM records r WHERE r.id = rt.record_id)');
    return (
      records: (records.first['occurrences'] as int?) ?? 0,
      tags: (tags.first['occurrences'] as int?) ?? 0,
    );
  }

  /// Checks the rebuilt tables before the transaction commits, so a conversion
  /// that lost or mangled data leaves the database as it was instead of
  /// committing the damage. Throwing here rolls back the transaction sqflite
  /// opens for the migration or the downgrade.
  ///
  /// The checks are deliberately cheap facts about the whole table, not a
  /// sample: every record survives, the ids have the expected type, none is
  /// missing, and SQLite's own structural check passes.
  static Future<void> _verifyConversion(
    Database db,
    _RecordCounts before, {
    required bool expectUuids,
  }) async {
    final after = await _countRecordsAndTags(db);
    if (after != before) {
      throw StateError('Record id conversion lost data: '
          '${before.records} -> ${after.records} records, '
          '${before.tags} -> ${after.tags} tag associations');
    }

    final expectedType = expectUuids ? 'TEXT' : 'INTEGER';
    final idType = await _recordIdType(db);
    if (idType != expectedType) {
      throw StateError(
          'Record id conversion produced $idType ids instead of $expectedType');
    }

    final missingIds = await db.rawQuery(
        'SELECT COUNT(*) AS occurrences FROM records WHERE id IS NULL');
    final missing = (missingIds.first['occurrences'] as int?) ?? 0;
    if (missing != 0) {
      throw StateError('Record id conversion left $missing records without id');
    }

    final integrity = await db.rawQuery('PRAGMA integrity_check');
    final problems = integrity
        .map((row) => row.values.first)
        .where((value) => value != 'ok')
        .toList();
    if (problems.isNotEmpty) {
      throw StateError(
          'Record id conversion left the database inconsistent: '
          '${problems.join('; ')}');
    }
  }

  static Future<void> _dropIdMap(Database db) async {
    await db.execute('DROP TABLE records_id_map');
  }

  /// Type of the `id` column of `records`, or null when the table is missing.
  static Future<String?> _recordIdType(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(records)');
    for (final column in columns) {
      if (column['name'] == 'id') {
        return (column['type'] as String?)?.toUpperCase();
      }
    }
    return null;
  }

  static Future<bool> _usesUuidIds(Database db) async =>
      await _recordIdType(db) == 'TEXT';

  static Future<bool> _usesIntegerIds(Database db) async =>
      await _recordIdType(db) == 'INTEGER';
}
