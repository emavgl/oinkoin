import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/services/database/sqlite-database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late SqliteDatabase db;

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
    // Reset the database before each test to ensure a clean state
    DatabaseInterface db = ServiceConfig.database;
    await db.deleteDatabase();
  });

  group('Tag Management', () {
    test('renameTag should rename a tag_name', () async {
      // Insert initial data
      await db.addRecordTagAssociationsInBatch([
        RecordTagAssociation(recordId: 1, tagName: 'old_tag'),
        RecordTagAssociation(recordId: 2, tagName: 'old_tag'),
      ]);

      // Rename the tag
      await db.renameTag('old_tag', 'new_tag');

      // Verify the rename
      final associations = await db.getAllRecordTagAssociations();
      expect(associations.every((a) => a.tagName == 'new_tag'), isTrue);
    });

    test('deleteTag should remove all entries with a given tag_name', () async {
      // Insert initial data
      await db.addRecordTagAssociationsInBatch([
        RecordTagAssociation(recordId: 1, tagName: 'tag_to_delete'),
        RecordTagAssociation(recordId: 2, tagName: 'tag_to_delete'),
      ]);

      // Delete the tag
      await db.deleteTag('tag_to_delete');

      // Verify deletion
      final associations = await db.getAllRecordTagAssociations();
      expect(associations.any((a) => a.tagName == 'tag_to_delete'), isFalse);
    });

    test('addRecordTagAssociationsInBatch should not add tags with null recordId', () async {
      // Attempt to add invalid data
      await db.addRecordTagAssociationsInBatch([
        RecordTagAssociation(recordId: null, tagName: 'invalid_tag'),
        RecordTagAssociation(recordId: 1, tagName: 'valid_tag'),
      ]);

      // Verify that only valid tags are added
      final associations = await db.getAllRecordTagAssociations();
      expect(associations.length, 1);
      expect(associations.first.tagName, 'valid_tag');
    });
  });
}