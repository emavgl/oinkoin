import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/services/database/sqlite-database.dart';
import 'package:piggybank/services/database/sqlite-migration-service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Guards the promise behind every schema change: the user's data exists in a
/// copy taken *before* the migration, so a migration that fails, or that
/// commits something wrong, can never be the only copy of it.
void main() {
  late Directory testDir;
  late String dbPath;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    testDir = Directory('test/temp_pre_migration_snapshot');
  });

  setUp(() async {
    if (await testDir.exists()) await testDir.delete(recursive: true);
    await testDir.create(recursive: true);
    dbPath = '${testDir.absolute.path}/movements.db';
  });

  tearDownAll(() async {
    if (await testDir.exists()) await testDir.delete(recursive: true);
  });

  /// A database at the version the app releases before the uuid schema.
  Future<Database> createPreviousVersionDatabase() {
    return databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        singleInstance: false,
        version: 34,
        onCreate: (db, version) async {
          await db.execute('CREATE TABLE records ('
              'id INTEGER PRIMARY KEY AUTOINCREMENT, '
              'datetime INTEGER, title TEXT)');
          await db.execute('CREATE TABLE records_tags ('
              'record_id INTEGER NOT NULL, tag_name TEXT NOT NULL, '
              'PRIMARY KEY (record_id, tag_name))');
        },
      ),
    );
  }

  Future<Database> openExisting() {
    return databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
  }

  Future<List<Map<String, Object?>>> records(Database db) =>
      db.rawQuery('SELECT id, title FROM records ORDER BY id');

  test('reads the schema version from the file header', () async {
    expect(await SqliteDatabase.readFileSchemaVersion(dbPath), isNull);

    final db = await createPreviousVersionDatabase();
    await db.close();
    expect(await SqliteDatabase.readFileSchemaVersion(dbPath), 34);

    final notSqlite = File('${testDir.path}/not_sqlite.db');
    await notSqlite.writeAsString('this is not a database');
    expect(
      await SqliteDatabase.readFileSchemaVersion(notSqlite.path),
      isNull,
    );
  });

  test('the pre-migration copy holds the data and leaves the file untouched',
      () async {
    final db = await createPreviousVersionDatabase();
    await db.insert('records', {'datetime': 1, 'title': 'Coffee'});
    await db.insert('records', {'datetime': 2, 'title': 'Rent'});
    await db.insert('records_tags', {'record_id': 1, 'tag_name': 'food'});
    await db.close();

    final copy = await SqliteDatabase.createPreMigrationSnapshot(dbPath, 34);

    expect(copy, isNotNull);
    expect(copy!.existsSync(), isTrue);
    expect(copy.path, SqliteDatabase.preMigrationSnapshotPath(dbPath, 34));
    expect(await SqliteDatabase.readFileSchemaVersion(copy.path), 34);

    // The source is untouched: reading the copy is only about the copy.
    final original = await openExisting();
    addTearDown(original.close);
    expect(await records(original), hasLength(2));
    expect(await original.rawQuery('SELECT * FROM records_tags'), hasLength(1));
  });

  test('the copy restores a database whose migration went wrong', () async {
    final db = await createPreviousVersionDatabase();
    await db.insert('records', {'datetime': 1, 'title': 'Coffee'});
    await db.insert('records', {'datetime': 2, 'title': 'Rent'});
    await db.close();

    final copy = await SqliteDatabase.createPreMigrationSnapshot(dbPath, 34);

    // Simulate a migration that commits damage.
    final damaged = await openExisting();
    await damaged.delete('records');
    await damaged.close();

    expect(
      await SqliteDatabase.restorePreMigrationSnapshot(dbPath, copy!),
      isTrue,
    );

    final restored = await openExisting();
    addTearDown(restored.close);
    expect(await records(restored), hasLength(2));
    expect(await SqliteDatabase.readFileSchemaVersion(dbPath), 34);
  });

  test('a failing upgrade leaves the file at the previous version', () async {
    final db = await createPreviousVersionDatabase();
    await db.insert('records', {'datetime': 1, 'title': 'Coffee'});
    await db.close();

    await expectLater(
      databaseFactory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          singleInstance: false,
          version: 35,
          onUpgrade: (db, from, to) async {
            // Any migration can fail halfway through; sqflite runs it in a
            // transaction, so the file must be unchanged afterwards.
            await db.execute('CREATE TABLE scratch (x INTEGER)');
            throw StateError('migration bug');
          },
        ),
      ),
      throwsA(isA<StateError>()),
    );

    expect(await SqliteDatabase.readFileSchemaVersion(dbPath), 34);
    final reopened = await openExisting();
    addTearDown(reopened.close);
    expect(await records(reopened), hasLength(1));
  });

  test('a conversion that cannot rebuild the table rolls back', () async {
    // A records table missing a column the rebuild copies: the conversion
    // fails inside the migration transaction instead of committing a table
    // with the data dropped.
    final db = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        singleInstance: false,
        version: 34,
        onCreate: (db, version) async {
          await db.execute('CREATE TABLE records ('
              'id INTEGER PRIMARY KEY AUTOINCREMENT, '
              'datetime INTEGER, title TEXT)');
          await db.execute('CREATE TABLE records_tags ('
              'record_id INTEGER NOT NULL, tag_name TEXT NOT NULL, '
              'PRIMARY KEY (record_id, tag_name))');
        },
      ),
    );
    await db.insert('records', {'datetime': 1, 'title': 'Coffee'});
    await db.close();

    await expectLater(
      databaseFactory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          singleInstance: false,
          version: 35,
          onUpgrade: SqliteMigrationService.onUpgrade,
        ),
      ),
      throwsA(anything),
    );

    expect(await SqliteDatabase.readFileSchemaVersion(dbPath), 34);
    final reopened = await openExisting();
    addTearDown(reopened.close);
    expect(await records(reopened), [
      {'id': 1, 'title': 'Coffee'}
    ]);
    final columns = await reopened.rawQuery('PRAGMA table_info(records)');
    expect(
      columns.firstWhere((column) => column['name'] == 'id')['type'],
      'INTEGER',
    );
  });

  test('copies older than the retention are pruned', () async {
    final db = await createPreviousVersionDatabase();
    await db.close();

    final stale =
        File('${dbPath}${SqliteDatabase.preMigrationSnapshotSuffix}33.db');
    await stale.writeAsBytes([0, 1, 2, 3]);
    await stale.setLastModified(
        DateTime.now().subtract(const Duration(days: 30)));

    final fresh = File(SqliteDatabase.preMigrationSnapshotPath(dbPath, 34));
    await fresh.writeAsBytes([0, 1, 2, 3]);

    await SqliteDatabase.prunePreMigrationSnapshots(dbPath);

    expect(stale.existsSync(), isFalse);
    expect(fresh.existsSync(), isTrue);
  });
}
