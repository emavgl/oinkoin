import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/services/database/database-interface.dart';
import 'package:piggybank/services/database/sqlite-database.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timezone/data/latest_all.dart' as tz;

import 'helpers/test_database.dart';

void main() {

  // Setup sqflite_common_ffi for flutter test
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Initialize FFI
    sqfliteFfiInit();
    // Change the default factory
    databaseFactory = databaseFactoryFfi;

    tz.initializeTimeZones();
    ServiceConfig.localTimezone = "Europe/Vienna";
  });

  setUp(() async {
    // Create a new isolated in-memory database for each test
    await TestDatabaseHelper.setupTestDatabase();
  });

  test('renameTag should rename a tag_name', () async {
    SqliteDatabase sqliteDb = ServiceConfig.database as SqliteDatabase;
    var database = await sqliteDb.database;
    DatabaseInterface db = ServiceConfig.database;

    // Insert initial data via raw SQL
    await database?.insert('records_tags', {'record_id': 1, 'tag_name': 'old_tag'});
    await database?.insert('records_tags', {'record_id': 2, 'tag_name': 'old_tag'});

    // Rename the tag
    await db.renameTag('old_tag', 'new_tag');

    // Verify the rename
    final associations = await db.getAllRecordTagAssociations();
    expect(associations.every((a) => a.tagName == 'new_tag'), isTrue);
  });

  test('deleteTag should remove all entries with a given tag_name', () async {
    SqliteDatabase sqliteDb = ServiceConfig.database as SqliteDatabase;
    var database = await sqliteDb.database;
    DatabaseInterface db = ServiceConfig.database;

    // Insert initial data via raw SQL
    await database?.insert('records_tags', {'record_id': 1, 'tag_name': 'tag_to_delete'});
    await database?.insert('records_tags', {'record_id': 2, 'tag_name': 'tag_to_delete'});

    // Delete the tag
    await db.deleteTag('tag_to_delete');

    // Verify deletion
    final associations = await db.getAllRecordTagAssociations();
    expect(associations.any((a) => a.tagName == 'tag_to_delete'), isFalse);
  });

  test('raw SQL insert should not add tags with null recordId',
      () async {
    SqliteDatabase sqliteDb = ServiceConfig.database as SqliteDatabase;
    var database = await sqliteDb.database;

    // Attempt to add invalid data
    await database?.insert(
      "records_tags",
      {'record_id': null, 'tag_name': "invalid_tag"},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    await database?.insert(
      "records_tags",
      {'record_id': 1, 'tag_name': null},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    await database?.insert(
      "records_tags",
      {'record_id': 1, 'tag_name': "valid_tag"},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    // Verify that only valid tags are added
    final associations = await sqliteDb.getAllRecordTagAssociations();
    expect(associations.length, 1);
    expect(associations.first.tagName, 'valid_tag');
  });
}
