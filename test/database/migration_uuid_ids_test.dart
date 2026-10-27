import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/services/database/sqlite-migration-service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

/// The records table and its triggers as created by database version 33,
/// i.e. before record ids became uuids.
const List<String> _v33Schema = [
  '''
  CREATE TABLE categories (
      name TEXT,
      color TEXT,
      icon INTEGER,
      category_type INTEGER,
      last_used INTEGER,
      record_count INTEGER DEFAULT 0,
      is_archived INTEGER DEFAULT 0,
      sort_order INTEGER DEFAULT 0,
      icon_emoji TEXT,
      PRIMARY KEY (name, category_type)
  )
  ''',
  '''
  CREATE TABLE records (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      datetime INTEGER,
      timezone TEXT,
      value REAL,
      title TEXT,
      description TEXT,
      category_name TEXT,
      category_type INTEGER,
      recurrence_id TEXT,
      wallet_id INTEGER,
      transfer_wallet_id INTEGER,
      transfer_value REAL,
      profile_id INTEGER
  )
  ''',
  '''
  CREATE TABLE records_tags (
      record_id INTEGER NOT NULL,
      tag_name TEXT NOT NULL,
      PRIMARY KEY (record_id, tag_name)
  )
  ''',
  '''
  CREATE TABLE wallets (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT,
      color TEXT,
      icon INTEGER,
      icon_emoji TEXT,
      initial_amount REAL DEFAULT 0,
      is_archived INTEGER DEFAULT 0,
      is_hidden INTEGER DEFAULT 0,
      is_default INTEGER DEFAULT 0,
      is_predefined INTEGER DEFAULT 0,
      sort_order INTEGER DEFAULT 0,
      currency TEXT,
      profile_id INTEGER
  )
  ''',
  '''
  CREATE TABLE profiles (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      is_default INTEGER DEFAULT 0,
      color TEXT,
      sort_order INTEGER DEFAULT 0
  )
  ''',
  '''
  CREATE TABLE recurrent_record_patterns (
      id TEXT PRIMARY KEY,
      datetime INTEGER,
      timezone TEXT,
      value REAL,
      title TEXT,
      description TEXT,
      category_name TEXT,
      category_type INTEGER,
      last_update INTEGER,
      recurrent_period INTEGER,
      recurrence_id TEXT,
      date_str TEXT,
      tags TEXT,
      end_date INTEGER,
      wallet_id INTEGER,
      transfer_wallet_id INTEGER,
      transfer_value REAL,
      profile_id INTEGER,
      custom_interval_value INTEGER,
      custom_interval_unit INTEGER
  )
  ''',
  '''
  CREATE TABLE budgets (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      target_amount REAL NOT NULL,
      budget_type INTEGER NOT NULL,
      start_date INTEGER NOT NULL,
      end_date INTEGER,
      recurrent_period INTEGER,
      custom_interval_value INTEGER,
      custom_interval_unit INTEGER,
      category_names TEXT NOT NULL DEFAULT '[]',
      tags TEXT NOT NULL DEFAULT '[]',
      wallet_ids TEXT NOT NULL DEFAULT '[]',
      category_tag_or_logic INTEGER NOT NULL DEFAULT 1,
      tag_or_logic INTEGER NOT NULL DEFAULT 0,
      is_archived INTEGER NOT NULL DEFAULT 0,
      profile_id INTEGER,
      timezone TEXT
  )
  ''',
  '''
  CREATE TRIGGER update_category_usage
  AFTER INSERT ON records
  FOR EACH ROW
  BEGIN
      UPDATE categories
      SET record_count = record_count + 1
      WHERE name = NEW.category_name AND category_type = NEW.category_type;
  END
  ''',
  '''
  CREATE TRIGGER update_category_usage_on_update
  AFTER UPDATE ON records
  FOR EACH ROW
  BEGIN
      UPDATE categories
      SET record_count = record_count + 1
      WHERE name = NEW.category_name AND category_type = NEW.category_type;
  END
  ''',
  '''
  CREATE TRIGGER update_category_usage_on_delete
  AFTER DELETE ON records
  FOR EACH ROW
  BEGIN
      UPDATE categories
      SET record_count = record_count - 1
      WHERE name = OLD.category_name AND category_type = OLD.category_type;
  END
  ''',
  '''
  CREATE TRIGGER delete_record_tags
  AFTER DELETE ON records
  FOR EACH ROW
  BEGIN
      DELETE FROM records_tags WHERE record_id = OLD.id;
  END
  ''',
];

/// Ids of the three records created by [_createV33Database], in creation order.
const List<int> _legacyIds = [1, 2, 3];

Future<void> _createV33Database(Database db) async {
  for (final statement in _v33Schema) {
    await db.execute(statement);
  }
  await db.insert('categories', {
    'name': 'Food',
    'category_type': 0,
    'color': '255:0:0:0',
    'icon': 1,
  });
  // Records 1 and 2 are identical except for their tags: exactly the case that
  // content based duplicate matching could not tell apart.
  final sameTime = DateTime.utc(2026, 10, 23, 20, 0).millisecondsSinceEpoch;
  await db.insert('records', {
    'datetime': sameTime,
    'timezone': 'UTC',
    'value': -10.0,
    'title': 'Test record',
    'category_name': 'Food',
    'category_type': 0,
    'description': null,
  });
  await db.insert('records', {
    'datetime': sameTime,
    'timezone': 'UTC',
    'value': -10.0,
    'title': 'Test record',
    'category_name': 'Food',
    'category_type': 0,
    'description': null,
  });
  await db.insert('records', {
    'datetime': sameTime + 1000,
    'timezone': 'UTC',
    'value': -5.0,
    'title': 'Coffee',
    'category_name': 'Food',
    'category_type': 0,
    'description': null,
  });
  await db.insert('records_tags', {'record_id': 1, 'tag_name': 'first'});
  await db.insert('records_tags', {'record_id': 2, 'tag_name': 'second'});
}

Future<Database> _open(
  String path, {
  required int version,
  required OnDatabaseCreateFn onCreate,
  required OnDatabaseVersionChangeFn onUpgrade,
  required OnDatabaseVersionChangeFn onDowngrade,
}) {
  return databaseFactory.openDatabase(
    path,
    options: OpenDatabaseOptions(
      // every open in these tests must be a fresh connection: the schema
      // version of the file drives the migration callbacks.
      singleInstance: false,
      version: version,
      onCreate: onCreate,
      onUpgrade: onUpgrade,
      onDowngrade: onDowngrade,
    ),
  );
}

void main() {
  late Directory testDir;
  late String dbPath;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    testDir = Directory('test/temp_uuid_migration');
  });

  setUp(() async {
    if (await testDir.exists()) await testDir.delete(recursive: true);
    await testDir.create(recursive: true);
    // Absolute path: sqflite_common_ffi rewrites relative database paths into
    // its own directory, which would defeat deleting the fixture between tests.
    dbPath = '${testDir.absolute.path}/movements.db';

    final db = await _open(
      dbPath,
      version: 33,
      onCreate: (db, version) => _createV33Database(db),
      onUpgrade: (db, from, to) async {},
      onDowngrade: (db, from, to) async {},
    );
    await db.close();
  });

  tearDownAll(() async {
    if (await testDir.exists()) await testDir.delete(recursive: true);
  });

  Future<Database> openAsV34() => _open(
        dbPath,
        version: 34,
        onCreate: (db, version) async {},
        onUpgrade: SqliteMigrationService.onUpgrade,
        onDowngrade: SqliteMigrationService.onDowngrade,
      );

  Future<Database> openAsV33() => _open(
        dbPath,
        version: 33,
        onCreate: (db, version) async {},
        onUpgrade: SqliteMigrationService.onUpgrade,
        onDowngrade: SqliteMigrationService.onDowngrade,
      );

  Future<String> idColumnType(Database db) async {
    final rows = await db.rawQuery('PRAGMA table_info(records)');
    return rows.firstWhere((row) => row['name'] == 'id')['type'] as String;
  }

  Future<List<Map<String, Object?>>> tagsByTitle(Database db) {
    return db.rawQuery('''
      SELECT r.title AS title, GROUP_CONCAT(rt.tag_name) AS tags
      FROM records r LEFT JOIN records_tags rt ON rt.record_id = r.id
      GROUP BY r.id ORDER BY r.datetime, r.rowid
    ''');
  }

  test('migrating to 34 turns record ids into unique uuids and keeps the data',
      () async {
    final db = await openAsV34();
    addTearDown(db.close);

    expect(await idColumnType(db), 'TEXT');

    final rows = await db.rawQuery('SELECT id, title FROM records ORDER BY rowid');
    expect(rows.length, 3);
    final ids = rows.map((row) => row['id'] as String).toList();
    expect(ids.every((id) => id.isNotEmpty), isTrue);
    expect(ids.toSet().length, 3, reason: 'ids must be unique');
    expect(ids.any((id) => id.contains('-')), isTrue,
        reason: 'ids should look like uuids');

    // One-to-one tag associations survived the rebuild, including the two
    // records that are otherwise identical.
    final tagged = await tagsByTitle(db);
    expect(tagged.map((row) => row['tags']).toList(),
        ['first', 'second', null]);

    // Creation order survived (rowid order matches insertion order).
    expect(rows.map((row) => row['title']).toList(),
        ['Test record', 'Test record', 'Coffee']);
  });

  test('migrating to 34 recreates the record triggers', () async {
    final db = await openAsV34();
    addTearDown(db.close);

    // The insert trigger still maintains the category usage counter.
    await db.insert('records', {
      'id': Uuid().v4(),
      'datetime': 1,
      'value': -1.0,
      'title': 'Another',
      'category_name': 'Food',
      'category_type': 0,
    });
    final category = await db.query('categories', where: 'name = ?', whereArgs: ['Food']);
    expect(category.first['record_count'], 4);

    // The delete trigger still removes the tags of a deleted record.
    final tagged = await db.rawQuery('SELECT record_id FROM records_tags LIMIT 1');
    final recordId = tagged.first['record_id'] as String;
    await db.delete('records', where: 'id = ?', whereArgs: [recordId]);
    final remaining = await db
        .query('records_tags', where: 'record_id = ?', whereArgs: [recordId]);
    expect(remaining, isEmpty);

    // Records must always carry their own id: the schema does not invent one,
    // so a raw insert that forgets it fails instead of storing an anonymous row.
    await expectLater(
      db.insert('records', {'datetime': 2, 'value': -2.0, 'title': 'No id'}),
      throwsA(anything),
    );
  });

  test('running the migration again on a migrated database is a no-op',
      () async {
    var db = await openAsV34();
    final before =
        await db.rawQuery('SELECT id FROM records ORDER BY rowid');
    await db.close();

    // A downgrade resets user_version, so the upgrade runs again on the same
    // (already migrated) schema.
    db = await openAsV34();
    addTearDown(db.close);
    final after = await db.rawQuery('SELECT id FROM records ORDER BY rowid');

    expect(after.map((row) => row['id']).toList(),
        before.map((row) => row['id']).toList());
  });

  test('downgrading from 34 restores integer ids in creation order', () async {
    var db = await openAsV34();
    final uuidIds = (await db.rawQuery('SELECT id FROM records ORDER BY rowid'))
        .map((row) => row['id'] as String)
        .toList();
    await db.close();

    db = await openAsV33();
    addTearDown(db.close);

    expect(await idColumnType(db), 'INTEGER');
    final rows = await db.rawQuery('SELECT id, title FROM records ORDER BY id');
    expect(rows.map((row) => row['id']).toList(), _legacyIds);
    expect(rows.map((row) => row['title']).toList(),
        ['Test record', 'Test record', 'Coffee']);
    expect(uuidIds.length, 3);

    // Tags follow their records.
    final tagged = await tagsByTitle(db);
    expect(tagged.map((row) => row['tags']).toList(),
        ['first', 'second', null]);
  });

  test('a downgrade followed by an upgrade is lossless', () async {
    var db = await openAsV34();
    await db.close();

    db = await openAsV33();
    await db.close();

    db = await openAsV34();
    addTearDown(db.close);

    expect(await idColumnType(db), 'TEXT');
    final rows = await db.rawQuery('SELECT id, title FROM records ORDER BY rowid');
    expect(rows.length, 3);
    expect(rows.map((row) => row['title']).toList(),
        ['Test record', 'Test record', 'Coffee']);
    final ids = rows.map((row) => row['id'] as String).toSet();
    expect(ids.length, 3);

    final tagged = await tagsByTitle(db);
    expect(tagged.map((row) => row['tags']).toList(),
        ['first', 'second', null]);
  });

  test('every record column survives both conversion directions', () async {
    // Fill a record with every column before the conversion: a column that is
    // missing or misspelled in the copy list would otherwise pass unnoticed.
    final fullRow = <String, Object?>{
      'datetime': 1234567890,
      'timezone': 'Europe/Vienna',
      'value': -12.5,
      'title': 'Full row',
      'description': 'a description',
      'category_name': 'Food',
      'category_type': 0,
      'recurrence_id': 'pattern-1',
      'wallet_id': 7,
      'transfer_wallet_id': 8,
      'transfer_value': 11.0,
      'profile_id': 2,
    };

    var db = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(version: 33, singleInstance: false),
    );
    await db.insert('records', fullRow);
    await db.close();

    Future<void> expectFullRow(Database db) async {
      // Guard the copied-column list: the rebuilt table must have exactly the
      // columns this fixture fills, so adding a column to the schema without
      // converting it fails here.
      final columns = await db.rawQuery('PRAGMA table_info(records)');
      expect(
        columns.map((column) => column['name']).toSet(),
        {'id', ...fullRow.keys},
      );

      final rows =
          await db.query('records', where: 'title = ?', whereArgs: ['Full row']);
      expect(rows, hasLength(1));
      final stored = Map<String, dynamic>.from(rows.single)..remove('id');
      expect(stored, fullRow);
    }

    db = await openAsV34();
    await expectFullRow(db);
    await db.close();

    db = await openAsV33();
    await expectFullRow(db);
    await db.close();
  });

  test('an empty database converts without error', () async {
    var db = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(version: 33, singleInstance: false),
    );
    await db.delete('records');
    expect(await db.query('records'), isEmpty);
    await db.close();

    db = await openAsV34();
    expect(await idColumnType(db), 'TEXT');
    expect(await db.query('records'), isEmpty);
    await db.close();

    db = await openAsV33();
    expect(await idColumnType(db), 'INTEGER');
    expect(await db.query('records'), isEmpty);
    await db.close();
  });
}
