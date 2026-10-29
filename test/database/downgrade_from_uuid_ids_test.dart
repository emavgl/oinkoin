import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/services/database/record-id-conversion-service.dart';
import 'package:piggybank/services/database/sqlite-database.dart';
import 'package:piggybank/services/database/sqlite-migration-service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// uuid v4 expression used by the uuid schema as id default.
const String _uuidDefault = "lower(hex(randomblob(4))) || '-' || "
    "lower(hex(randomblob(2))) || '-4' || "
    "substr(lower(hex(randomblob(2))), 2) || '-' || "
    "substr('89ab', abs(random()) % 4 + 1, 1) || "
    "substr(lower(hex(randomblob(2))), 2) || '-' || "
    "lower(hex(randomblob(6)))";

/// The tables a record id conversion touches, as written by the uuid release.
/// Other tables are left alone by the conversion.
const List<String> _uuidSchema = [
  '''
  CREATE TABLE categories (
      name TEXT,
      category_type INTEGER,
      last_used INTEGER,
      record_count INTEGER DEFAULT 0,
      PRIMARY KEY (name, category_type)
  )
  ''',
  '''
  CREATE TABLE records (
      id TEXT PRIMARY KEY NOT NULL DEFAULT ($_uuidDefault),
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
      record_id TEXT NOT NULL,
      tag_name TEXT NOT NULL,
      PRIMARY KEY (record_id, tag_name)
  )
  ''',
];

const String _uuid1 = '11111111-1111-4111-8111-111111111111';
const String _uuid2 = '22222222-2222-4222-8222-222222222222';
const String _uuid3 = '33333333-3333-4333-8333-333333333333';

Future<void> _createUuidDatabase(Database db) async {
  for (final statement in _uuidSchema) {
    await db.execute(statement);
  }
  await db.insert('categories', {'name': 'Food', 'category_type': 0});
  // The two 'Test record' rows are identical except for their tags: the case
  // that broke the content based duplicate check (#452).
  final sameTime = DateTime.utc(2026, 10, 23, 20, 0).millisecondsSinceEpoch;
  for (final id in [_uuid1, _uuid2]) {
    await db.insert('records', {
      'id': id,
      'datetime': sameTime,
      'timezone': 'UTC',
      'value': -10.0,
      'title': 'Test record',
      'category_name': 'Food',
      'category_type': 0,
    });
  }
  await db.insert('records', {
    'id': _uuid3,
    'datetime': sameTime + 1000,
    'timezone': 'UTC',
    'value': -5.0,
    'title': 'Coffee',
    'category_name': 'Food',
    'category_type': 0,
  });
  await db.insert('records_tags', {'record_id': _uuid1, 'tag_name': 'first'});
  await db.insert('records_tags', {'record_id': _uuid2, 'tag_name': 'second'});
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
      // every open must be a fresh connection: the schema version of the file
      // drives the migration callbacks.
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
    testDir = Directory('test/temp_downgrade_from_uuid_ids');
  });

  setUp(() async {
    if (await testDir.exists()) await testDir.delete(recursive: true);
    await testDir.create(recursive: true);
    // Absolute path: sqflite_common_ffi rewrites relative database paths into
    // its own directory, which would defeat deleting the fixture between tests.
    dbPath = '${testDir.absolute.path}/movements.db';

    final db = await _open(
      dbPath,
      version: 35,
      onCreate: (db, version) => _createUuidDatabase(db),
      onUpgrade: (db, from, to) async {},
      onDowngrade: (db, from, to) async {},
    );
    await db.close();
  });

  tearDownAll(() async {
    if (await testDir.exists()) await testDir.delete(recursive: true);
  });

  /// Opens the database the way this version (integer record ids) does.
  Future<Database> openCurrentVersion() => _open(
        dbPath,
        version: SqliteDatabase.version,
        onCreate: (db, version) async {},
        onUpgrade: (db, from, to) async {},
        onDowngrade: SqliteMigrationService.onDowngrade,
      );

  Future<String> idColumnType(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(records)');
    return columns.firstWhere((column) => column['name'] == 'id')['type']
        as String;
  }

  Future<List<Map<String, Object?>>> recordsWithTags(Database db) {
    return db.rawQuery('''
      SELECT r.id AS id, r.title AS title,
             GROUP_CONCAT(rt.tag_name) AS tags
      FROM records r LEFT JOIN records_tags rt ON rt.record_id = r.id
      GROUP BY r.id ORDER BY r.id
    ''');
  }

  test('a uuid database is converted to integer ids when opened by this version',
      () async {
    final db = await openCurrentVersion();
    addTearDown(db.close);

    expect(await idColumnType(db), 'INTEGER');

    final rows = await recordsWithTags(db);
    expect(rows.map((row) => row['id']).toList(), [1, 2, 3],
        reason: 'ids are assigned in creation (rowid) order');
    expect(rows.map((row) => row['title']).toList(),
        ['Test record', 'Test record', 'Coffee']);
    expect(rows.map((row) => row['tags']).toList(),
        ['first', 'second', null],
        reason: 'each tag association follows its own record');
  });

  test('the converted rows are readable by the current record model', () async {
    final db = await openCurrentVersion();
    addTearDown(db.close);

    final maps = await db.rawQuery('SELECT * FROM records ORDER BY id');
    final records = maps.map((row) {
      final map = Map<String, dynamic>.from(row)..['category'] = null;
      return Record.fromMap(map);
    }).toList();

    expect(records.map((record) => record.id).toList(), [1, 2, 3]);
    expect(records.first.title, 'Test record');
    expect(records.last.value, -5.0);
  });

  test('the conversion recreates the record triggers', () async {
    final db = await openCurrentVersion();
    addTearDown(db.close);

    Future<int> foodRecordCount() async {
      final rows =
          await db.query('categories', where: 'name = ?', whereArgs: ['Food']);
      return rows.first['record_count'] as int;
    }

    final countBefore = await foodRecordCount();
    await db.insert('records', {
      'datetime': 1,
      'value': -1.0,
      'title': 'Another',
      'category_name': 'Food',
      'category_type': 0,
    });
    expect(await foodRecordCount(), countBefore + 1,
        reason: 'the insert trigger maintains the category usage counter');

    final tagged =
        await db.rawQuery('SELECT record_id FROM records_tags LIMIT 1');
    final recordId = tagged.first['record_id'] as int;
    await db.delete('records', where: 'id = ?', whereArgs: [recordId]);
    expect(
      await db.query('records_tags',
          where: 'record_id = ?', whereArgs: [recordId]),
      isEmpty,
      reason: 'the delete trigger cleans up the tags',
    );
  });

  test('the file is left at this schema version and reopens unchanged',
      () async {
    var db = await openCurrentVersion();
    final version = await db.rawQuery('PRAGMA user_version');
    expect(version.first['user_version'], SqliteDatabase.version);
    await db.close();

    db = await openCurrentVersion();
    addTearDown(db.close);
    final rows = await recordsWithTags(db);
    expect(rows.map((row) => row['id']).toList(), [1, 2, 3]);
  });

  test('converting an integer database is a no-op', () async {
    var db = await openCurrentVersion();
    final before = await recordsWithTags(db);
    await db.close();

    db = await openCurrentVersion();
    addTearDown(db.close);
    expect(await RecordIdConversionService.convertToIntegerIds(db), isFalse);

    final after = await recordsWithTags(db);
    expect(after.map((row) => row['id']).toList(),
        before.map((row) => row['id']).toList());
    expect(after.map((row) => row['tags']).toList(),
        before.map((row) => row['tags']).toList());
  });

  test('every record column survives the downgrade', () async {
    // Fill a record with every column: a column missing from the copied-column
    // list would otherwise be dropped without any test noticing.
    final fullRow = <String, Object?>{
      'id': 'eeeeeeee-1111-4111-8111-111111111111',
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

    var db = await _open(
      dbPath,
      version: 35,
      onCreate: (db, version) async {},
      onUpgrade: (db, from, to) async {},
      onDowngrade: (db, from, to) async {},
    );
    await db.insert('records', fullRow);
    await db.close();

    db = await openCurrentVersion();
    addTearDown(db.close);

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
    final stored = Map<String, dynamic>.from(rows.single);
    expect(stored['id'], isA<int>());
    stored.remove('id');
    final expected = Map<String, Object?>.from(fullRow)..remove('id');
    expect(stored, expected);
  });

  test('an empty uuid database downgrades to an empty integer one', () async {
    var db = await _open(
      dbPath,
      version: 35,
      onCreate: (db, version) async {},
      onUpgrade: (db, from, to) async {},
      onDowngrade: (db, from, to) async {},
    );
    await db.delete('records');
    await db.close();

    db = await openCurrentVersion();
    addTearDown(db.close);

    expect(await idColumnType(db), 'INTEGER');
    expect(await db.query('records'), isEmpty);
  });
}
