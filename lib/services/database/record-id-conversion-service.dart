import 'package:sqflite/sqflite.dart';

import '../logger.dart';

/// Size of the data stored in the tables a record id conversion rebuilds.
typedef _RecordCounts = ({int records, int tags});

/// Converts the integer record ids of a database to uuids.
///
/// Record ids became uuids in a newer database version, so the migration has to
/// rewrite the two tables that reference them. There is no reverse conversion:
/// a build that still expects integer ids cannot read this schema, and a
/// downgrade is not supported.
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
  /// The check is on the schema, not on `user_version`, so running the
  /// conversion again on a converted database is a no-op instead of a second
  /// rewrite of the ids.
  static Future<bool> convertToUuidIds(Database db) async {
    if (!await _usesIntegerIds(db)) {
      _logger.info('Record ids are not integers, nothing to convert to uuids');
      return false;
    }

    _logger.info('Migrating record ids to uuids');
    final countsBefore = await _countRecordsAndTags(db);
    await _mapIntegerIdsToUuids(db);
    await _createUuidTables(db);
    await _copyRecordsAndTags(db);
    await _replaceOldTables(db);
    await _verifyConversion(db, countsBefore);
    await _dropIdMap(db);
    _logger.info('Record ids migrated to uuids');
    return true;
  }

  static Future<void> _mapIntegerIdsToUuids(Database db) async {
    await _createIdMap(db, 'old_id INTEGER PRIMARY KEY, new_id TEXT NOT NULL');
    await db.execute('INSERT INTO records_id_map (old_id, new_id) '
        'SELECT id, $uuidV4Sql FROM records ORDER BY id');
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

  /// Copies both tables through the id map. Ordering by the old id keeps the
  /// creation order, so the `rowid` sequence of the rebuilt table keeps
  /// matching the original insertion order.
  static Future<void> _copyRecordsAndTags(Database db) async {
    await db.execute(
      'INSERT INTO records_new (id, $_copiedRecordColumns) '
      'SELECT m.new_id, r.$_copiedRecordColumns '
      'FROM records r JOIN records_id_map m ON m.old_id = r.id '
      'ORDER BY r.id',
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
  /// opens for the migration.
  ///
  /// The checks are deliberately cheap facts about the whole table, not a
  /// sample: every record survives, the ids are text, none is missing, and
  /// SQLite's own structural check passes.
  static Future<void> _verifyConversion(
    Database db,
    _RecordCounts before,
  ) async {
    final after = await _countRecordsAndTags(db);
    if (after != before) {
      throw StateError('Record id conversion lost data: '
          '${before.records} -> ${after.records} records, '
          '${before.tags} -> ${after.tags} tag associations');
    }

    final idType = await _recordIdType(db);
    if (idType != 'TEXT') {
      throw StateError(
          'Record id conversion produced $idType ids instead of TEXT');
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

  static Future<bool> _usesIntegerIds(Database db) async =>
      await _recordIdType(db) == 'INTEGER';
}
