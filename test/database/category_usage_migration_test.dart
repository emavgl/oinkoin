import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/services/database/sqlite-migration-service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The categories/records schema and the record triggers as they were before
/// database version 34, i.e. with the update trigger that counted every record
/// edit as a new record.
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
  CREATE TRIGGER update_category_usage
  AFTER INSERT ON records
  FOR EACH ROW
  BEGIN
      UPDATE categories
      SET record_count = record_count + 1,
          last_used = strftime('%s', 'now') * 1000
      WHERE name = NEW.category_name AND category_type = NEW.category_type;
  END
  ''',
  '''
  CREATE TRIGGER update_category_usage_on_update
  AFTER UPDATE ON records
  FOR EACH ROW
  BEGIN
      UPDATE categories
      SET record_count = record_count + 1,
          last_used = strftime('%s', 'now') * 1000
      WHERE name = NEW.category_name AND category_type = NEW.category_type;

      UPDATE categories
      SET record_count = record_count - 1
      WHERE name = OLD.category_name AND category_type = OLD.category_type
        AND (NEW.category_name != OLD.category_name
             OR NEW.category_type != OLD.category_type);
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

void main() {
  late Directory testDir;
  late String dbPath;

  Future<Database> open({
    required int version,
    OnDatabaseVersionChangeFn? onUpgrade,
    OnDatabaseCreateFn? onCreate,
  }) {
    return databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        // every open must be a fresh connection: the schema version of the
        // file drives the migration callbacks.
        singleInstance: false,
        version: version,
        onCreate: onCreate ?? (db, version) async {},
        onUpgrade: onUpgrade ?? (db, from, to) async {},
        onDowngrade: (db, from, to) async {},
      ),
    );
  }

  Future<Database> openV34() =>
      open(version: 34, onUpgrade: SqliteMigrationService.onUpgrade);

  Future<Map<String, int>> storedCounters(Database db) async {
    final rows = await db.rawQuery(
        'SELECT name, record_count FROM categories ORDER BY name');
    return {
      for (final row in rows)
        row['name'] as String: (row['record_count'] as int?) ?? -1,
    };
  }

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    testDir = Directory('test/temp_category_usage_migration');
  });

  setUp(() async {
    if (await testDir.exists()) await testDir.delete(recursive: true);
    await testDir.create(recursive: true);
    // Absolute path: sqflite_common_ffi rewrites relative database paths into
    // its own directory, which would defeat deleting the fixture between tests.
    dbPath = '${testDir.absolute.path}/movements.db';

    final db = await open(
      version: 33,
      onCreate: (db, version) async {
        for (final statement in _v33Schema) {
          await db.execute(statement);
        }
      },
    );
    await db.insert('categories', {
      'name': 'Food',
      'category_type': 0,
      // Drifted value, as a user who edited records would have.
      'record_count': 7,
    });
    await db.insert('categories', {
      'name': 'Rent',
      'category_type': 0,
      // What the app stored for a category created after the defaults: NULL.
      'record_count': null,
    });
    await db.insert('categories', {'name': 'Unused', 'category_type': 0});

    for (final title in ['Food 1', 'Food 2', 'Food 3', 'Rent 1']) {
      await db.insert('records', {
        'datetime': 1000,
        'timezone': 'UTC',
        'value': -10.0,
        'title': title,
        'category_name': title.startsWith('Food') ? 'Food' : 'Rent',
        'category_type': 0,
      });
    }
    await db.close();
  });

  tearDownAll(() async {
    if (await testDir.exists()) await testDir.delete(recursive: true);
  });

  test('migrating to 34 repairs the counters from the records', () async {
    final db = await openV34();
    addTearDown(db.close);

    expect(await storedCounters(db), {
      'Food': 3,
      'Rent': 1,
      'Unused': 0,
    });
  });

  test('migrating to 34 installs the fixed update trigger', () async {
    final db = await openV34();
    addTearDown(db.close);

    // Editing a record must not count it again.
    await db.update('records', {'value': -20.0},
        where: 'title = ?', whereArgs: ['Food 1']);
    expect((await storedCounters(db))['Food'], 3);

    // Moving a record to another category must move the count.
    await db.update('records', {'category_name': 'Rent'},
        where: 'title = ?', whereArgs: ['Food 1']);
    expect(await storedCounters(db), {
      'Food': 2,
      'Rent': 2,
      'Unused': 0,
    });
  });

  test('the migration is idempotent', () async {
    final db = await openV34();
    addTearDown(db.close);

    await SqliteMigrationService.onUpgrade(db, 33, 34);

    expect(await storedCounters(db), {
      'Food': 3,
      'Rent': 1,
      'Unused': 0,
    });
  });

  test('the repaired counter keeps following the records afterwards', () async {
    final db = await openV34();
    addTearDown(db.close);

    await db.insert('records', {
      'datetime': 2000,
      'timezone': 'UTC',
      'value': -5.0,
      'title': 'Food 4',
      'category_name': 'Food',
      'category_type': 0,
    });
    expect((await storedCounters(db))['Food'], 4);

    await db.delete('records', where: 'title = ?', whereArgs: ['Food 4']);
    expect((await storedCounters(db))['Food'], 3);
  });
}
