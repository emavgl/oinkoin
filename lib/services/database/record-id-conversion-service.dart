import 'package:sqflite/sqflite.dart';

import '../logger.dart';

/// Size of the data stored in the tables a record id conversion rebuilds.
typedef _RecordCounts = ({int records, int tags});

/// Converts the record id representation of a database, so that a build that
/// expects a different one can open it.
///
/// Record ids became uuids in a newer database version. A build that still
/// expects integer ids cannot read such a database, and a released binary
/// cannot be patched afterwards, so this conversion ships one release before
/// the uuid schema and runs from the `onDowngrade` callback.
class RecordIdConversionService {
  static final _logger = Logger.withClass(RecordIdConversionService);

  /// Columns of `records` that are copied when the table is rebuilt. `id` is
  /// remapped, the other columns are carried over unchanged.
  static const String _copiedRecordColumns =
      'datetime, timezone, value, title, description, category_name, '
      'category_type, recurrence_id, wallet_id, transfer_wallet_id, '
      'transfer_value, profile_id';

  /// Rebuilds `records` and `records_tags` with integer record ids and returns
  /// whether the database was converted.
  ///
  /// Safe to run more than once: it does nothing when the ids are already
  /// integers. The new ids are assigned in creation (`rowid`) order, so the
  /// record ordering used as tie-break stays the same, and the tag
  /// associations are remapped together with the records.
  ///
  /// The caller must recreate the record triggers when this returns true: they
  /// are dropped together with the table.
  static Future<bool> convertToIntegerIds(Database db) async {
    if (!await _usesUuidIds(db)) {
      _logger.info('Record ids are not uuids, nothing to convert');
      return false;
    }

    _logger.info('Converting record ids back to integers');
    final countsBefore = await _countRecordsAndTags(db);
    await _createIdMap(db);
    await _rebuildRecordsTable(db);
    await _rebuildRecordsTagsTable(db);
    await _replaceOldTables(db);
    await _requireNothingWasLost(db, countsBefore);
    await _dropIdMap(db);
    _logger.info('Record ids converted back to integers');
    return true;
  }

  static Future<bool> _usesUuidIds(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(records)');
    for (final column in columns) {
      if (column['name'] == 'id') {
        return (column['type'] as String?)?.toUpperCase() == 'TEXT';
      }
    }
    return false;
  }

  /// `old id -> new integer id`, assigned in creation (`rowid`) order.
  static Future<void> _createIdMap(Database db) async {
    await db.execute('DROP TABLE IF EXISTS records_id_map');
    await db.execute('CREATE TEMP TABLE records_id_map ('
        'new_id INTEGER PRIMARY KEY AUTOINCREMENT, old_id TEXT NOT NULL UNIQUE)');
    await db.execute('INSERT INTO records_id_map (old_id) '
        'SELECT id FROM records ORDER BY rowid');
  }

  static Future<void> _rebuildRecordsTable(Database db) async {
    await db.execute('CREATE TABLE records_new ('
        'id INTEGER PRIMARY KEY AUTOINCREMENT, $_copiedRecordColumns)');
    await db.execute(
      'INSERT INTO records_new (id, $_copiedRecordColumns) '
      'SELECT m.new_id, r.$_copiedRecordColumns '
      'FROM records r JOIN records_id_map m ON m.old_id = r.id '
      'ORDER BY m.new_id',
    );
  }

  static Future<void> _rebuildRecordsTagsTable(Database db) async {
    await db.execute('CREATE TABLE records_tags_new ('
        'record_id INTEGER NOT NULL, tag_name TEXT NOT NULL, '
        'PRIMARY KEY (record_id, tag_name))');
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
    final records = await db
        .rawQuery('SELECT COUNT(*) AS occurrences FROM records');
    final tags = await db.rawQuery('SELECT COUNT(*) AS occurrences '
        'FROM records_tags rt '
        'WHERE EXISTS (SELECT 1 FROM records r WHERE r.id = rt.record_id)');
    return (
      records: (records.first['occurrences'] as int?) ?? 0,
      tags: (tags.first['occurrences'] as int?) ?? 0,
    );
  }

  /// Aborts the downgrade (rolling back the transaction sqflite opens for it)
  /// instead of leaving the user with missing records or tags.
  static Future<void> _requireNothingWasLost(
      Database db, _RecordCounts before) async {
    final after = await _countRecordsAndTags(db);
    if (after != before) {
      throw StateError('Record id downgrade lost data: '
          '${before.records} -> ${after.records} records, '
          '${before.tags} -> ${after.tags} tag associations');
    }
  }

  static Future<void> _dropIdMap(Database db) async {
    await db.execute('DROP TABLE records_id_map');
  }
}
