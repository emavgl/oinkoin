import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/models/backup.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/record-tag-association.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/services/backup-service.dart';
import 'package:piggybank/services/database/database-interface.dart';
import 'package:piggybank/services/database/sqlite-database.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timezone/data/latest_all.dart' as tz;

import 'helpers/test_database.dart';

/// This test reproduces the bug reported by a user:
///
/// "I backed up data from my tablet, and when I restore this data to my
/// smartphone, I do not have the same thing! The transaction labels on the
/// tablet have been replaced by other labels when restoring to the smartphone!"
///
/// ROOT CAUSE (now fixed):
/// During backup import, records get NEW auto-increment IDs but the
/// record_tag_associations in the backup reference the ORIGINAL IDs.
/// Record.toMap() does NOT serialize tags, so Record.fromMap() during
/// backup deserialization creates records with empty tag sets.
///
/// THE FIX: Before calling addRecordsInBatch, importDataFromBackupFile now
/// populates record.tags from the backup's record_tag_associations. This way,
/// addRecordsInBatch's Phase 2 correctly maps tags to the new record IDs.
void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tz.initializeTimeZones();
    ServiceConfig.localTimezone = "Europe/Vienna";
  });

  setUp(() async {
    await TestDatabaseHelper.setupTestDatabase();
  });

  /// Helper: simulates what BackupService.importDataFromBackupFile does.
  /// This is a copy of the import logic from backup-service.dart.
  Future<void> simulateImport(Backup backup, DatabaseInterface database) async {
    // Add categories
    for (var backupCategory in backup.categories) {
      try {
        await database.addCategory(backupCategory);
      } catch (_) {
        // already exists
      }
    }

    // Build a map of record ID -> tags from the backup's tag associations
    final recordIdToTags = <int, Set<String>>{};
    for (var assoc in backup.recordTagAssociations) {
      recordIdToTags.putIfAbsent(assoc.recordId, () => <String>{}).add(assoc.tagName);
    }

    // Populate record.tags so addRecordsInBatch Phase 2 handles ID remapping
    for (var record in backup.records) {
      if (record?.id != null && recordIdToTags.containsKey(record!.id)) {
        record.tags = recordIdToTags[record.id]!;
      }
    }

    // Add records in batch — Phase 2 will correctly map tags to new IDs
    await database.addRecordsInBatch(backup.records);
  }

  test(
      'BUG: importing backup into clean DB causes tags to be assigned to wrong records',
      () async {
    // Setup: create a backup with non-sequential record IDs (simulating a real
    // device where records have been added and deleted over time).
    final DatabaseInterface db = ServiceConfig.database;

    final category = Category('Food',
        categoryType: CategoryType.expense, iconEmoji: '🍔');

    // Create records with gaps in IDs (like a real device would have).
    // We'll manually build the backup JSON to control the IDs.
    final now = DateTime.now().toUtc();

    // Simulate 3 records with IDs 10, 20, 30 (gaps in IDs, as on a real device)
    final backupMap = {
      'records': [
        {
          'id': 10,
          'title': 'Groceries at Lidl',
          'value': -25.0,
          'datetime': now.millisecondsSinceEpoch,
          'timezone': 'Europe/Vienna',
          'category_name': 'Food',
          'category_type': 0,
          'description': '',
          'recurrence_id': null,
        },
        {
          'id': 20,
          'title': 'Groceries at Aldi',
          'value': -30.0,
          'datetime':
              now.add(Duration(hours: 1)).millisecondsSinceEpoch,
          'timezone': 'Europe/Vienna',
          'category_name': 'Food',
          'category_type': 0,
          'description': '',
          'recurrence_id': null,
        },
        {
          'id': 30,
          'title': 'Groceries at Colruyt',
          'value': -15.0,
          'datetime':
              now.add(Duration(hours: 2)).millisecondsSinceEpoch,
          'timezone': 'Europe/Vienna',
          'category_name': 'Food',
          'category_type': 0,
          'description': '',
          'recurrence_id': null,
        },
      ],
      'categories': [category.toMap()],
      'recurrent_record_patterns': [],
      'record_tag_associations': [
        // Tags reference ORIGINAL record IDs from the source device
        {'record_id': 10, 'tag_name': 'Lidl'},
        {'record_id': 20, 'tag_name': 'Aldi'},
        {'record_id': 30, 'tag_name': 'Colruyt'},
      ],
      'created_at': now.millisecondsSinceEpoch,
      'package_name': 'com.github.emavgl.piggybankpro',
      'version': '1.4.1',
      'database_version': '17',
    };

    final backup = Backup.fromMap(backupMap);

    // Verify that records deserialized from backup have EMPTY tags
    // (because Record.toMap() doesn't include tags, so Record.fromMap()
    //  gets no tags field)
    for (var record in backup.records) {
      expect(record!.tags, isEmpty,
          reason: 'Records from backup should have empty tags '
              'because toMap() does not serialize tags');
    }

    // Verify that the tag associations are deserialized correctly
    expect(backup.recordTagAssociations.length, 3);
    expect(backup.recordTagAssociations[0].recordId, 10);
    expect(backup.recordTagAssociations[0].tagName, 'Lidl');

    // Perform the import (same logic as BackupService.importDataFromBackupFile)
    await simulateImport(backup, db);

    // Now verify what happened: records should have been assigned new IDs
    final allRecords = await db.getAllRecords();
    expect(allRecords.length, 3);

    // The new IDs should be 1, 2, 3 (sequential autoincrement on clean DB)
    final recordIds = allRecords.map((r) => r!.id!).toList()..sort();
    expect(recordIds, [1, 2, 3],
        reason: 'Records should get new sequential IDs on import');

    // Build a map from record title to its tags
    final titleToTags = <String, Set<String>>{};
    for (var record in allRecords) {
      titleToTags[record!.title ?? ''] = record.tags;
    }

    // THE BUG: tags are associated using ORIGINAL IDs (10, 20, 30) but records
    // got NEW IDs (1, 2, 3). So:
    //  - Tag association (record_id=10, tag_name='Lidl') is inserted into records_tags
    //    but there is NO record with id=10 in the new DB → tag is orphaned/lost
    //  - Same for record_id=20 and record_id=30
    //
    // If there were enough records that some new IDs overlapped with old IDs,
    // tags would be assigned to the WRONG records instead of being lost.

    // Check: 'Groceries at Lidl' should have tag 'Lidl'
    // This FAILS because of the bug
    expect(titleToTags['Groceries at Lidl'], contains('Lidl'),
        reason: 'BUG: "Groceries at Lidl" should have tag "Lidl" '
            'but tags are lost/misassigned due to ID mismatch');
    expect(titleToTags['Groceries at Aldi'], contains('Aldi'),
        reason: 'BUG: "Groceries at Aldi" should have tag "Aldi"');
    expect(titleToTags['Groceries at Colruyt'], contains('Colruyt'),
        reason: 'BUG: "Groceries at Colruyt" should have tag "Colruyt"');
  });

  test(
      'BUG: importing backup with overlapping IDs causes tags assigned to WRONG records',
      () async {
    // This test shows the more insidious variant: when new IDs happen to overlap
    // with old IDs, tags don't just get lost — they go to the WRONG records.
    final DatabaseInterface db = ServiceConfig.database;

    final category = Category('Food',
        categoryType: CategoryType.expense, iconEmoji: '🍔');

    final now = DateTime.now().toUtc();

    // Create 5 records with IDs 3, 4, 5, 6, 7
    // After import into clean DB, they'll get IDs 1, 2, 3, 4, 5
    // Tag associations reference IDs 3, 4, 5 — which will exist but point
    // to the WRONG records (3rd, 4th, 5th imported instead of 1st, 2nd, 3rd)
    final backupMap = {
      'records': [
        {
          'id': 3,
          'title': 'Record A',
          'value': -10.0,
          'datetime': now.millisecondsSinceEpoch,
          'timezone': 'Europe/Vienna',
          'category_name': 'Food',
          'category_type': 0,
          'description': '',
          'recurrence_id': null,
        },
        {
          'id': 4,
          'title': 'Record B',
          'value': -20.0,
          'datetime':
              now.add(Duration(hours: 1)).millisecondsSinceEpoch,
          'timezone': 'Europe/Vienna',
          'category_name': 'Food',
          'category_type': 0,
          'description': '',
          'recurrence_id': null,
        },
        {
          'id': 5,
          'title': 'Record C',
          'value': -30.0,
          'datetime':
              now.add(Duration(hours: 2)).millisecondsSinceEpoch,
          'timezone': 'Europe/Vienna',
          'category_name': 'Food',
          'category_type': 0,
          'description': '',
          'recurrence_id': null,
        },
        {
          'id': 6,
          'title': 'Record D',
          'value': -40.0,
          'datetime':
              now.add(Duration(hours: 3)).millisecondsSinceEpoch,
          'timezone': 'Europe/Vienna',
          'category_name': 'Food',
          'category_type': 0,
          'description': '',
          'recurrence_id': null,
        },
        {
          'id': 7,
          'title': 'Record E',
          'value': -50.0,
          'datetime':
              now.add(Duration(hours: 4)).millisecondsSinceEpoch,
          'timezone': 'Europe/Vienna',
          'category_name': 'Food',
          'category_type': 0,
          'description': '',
          'recurrence_id': null,
        },
      ],
      'categories': [category.toMap()],
      'recurrent_record_patterns': [],
      'record_tag_associations': [
        // Only the first 3 records have tags, referencing original IDs 3, 4, 5
        {'record_id': 3, 'tag_name': 'Tag_for_A'},
        {'record_id': 4, 'tag_name': 'Tag_for_B'},
        {'record_id': 5, 'tag_name': 'Tag_for_C'},
      ],
      'created_at': now.millisecondsSinceEpoch,
      'package_name': 'com.github.emavgl.piggybankpro',
      'version': '1.4.1',
      'database_version': '17',
    };

    final backup = Backup.fromMap(backupMap);
    await simulateImport(backup, db);

    final allRecords = await db.getAllRecords();
    expect(allRecords.length, 5);

    // New IDs: Record A=1, Record B=2, Record C=3, Record D=4, Record E=5
    // Tag associations reference IDs 3, 4, 5 which now point to Record C, D, E
    // instead of Record A, B, C!

    final idToRecord = <int, Record>{};
    for (var r in allRecords) {
      idToRecord[r!.id!] = r;
    }

    // Verify IDs are sequential
    final ids = idToRecord.keys.toList()..sort();
    expect(ids, [1, 2, 3, 4, 5]);

    // Find records by title
    final titleToRecord = <String, Record>{};
    for (var r in allRecords) {
      titleToRecord[r!.title ?? ''] = r;
    }

    // BUG MANIFESTATION:
    // Record A (orig id=3, new id=1) should have 'Tag_for_A' but has NO tags
    // Record C (orig id=5, new id=3) should have 'Tag_for_C' but has 'Tag_for_A'
    // Record D (orig id=6, new id=4) should have NO tags but has 'Tag_for_B'
    // Record E (orig id=7, new id=5) should have NO tags but has 'Tag_for_C'

    // Expected behavior (what SHOULD happen):
    expect(titleToRecord['Record A']!.tags, contains('Tag_for_A'),
        reason: 'BUG: Record A should have Tag_for_A but it was assigned to Record C');
    expect(titleToRecord['Record B']!.tags, contains('Tag_for_B'),
        reason: 'BUG: Record B should have Tag_for_B but it was assigned to Record D');
    expect(titleToRecord['Record C']!.tags, contains('Tag_for_C'),
        reason: 'BUG: Record C should have Tag_for_C but it was assigned to Record E');
    expect(titleToRecord['Record D']!.tags, isEmpty,
        reason: 'BUG: Record D should have no tags but got Tag_for_B');
    expect(titleToRecord['Record E']!.tags, isEmpty,
        reason: 'BUG: Record E should have no tags but got Tag_for_C');
  });

  test('Verify backup JSON matches the database for user-reported data',
      () async {
    // This test loads the actual user-provided backup file and verifies that
    // the exported data is internally consistent (tag associations reference
    // valid record IDs within the backup itself).
    final backupFile = File('debug/piggybankpro_1.4.1_2026-02-14T12-07-48_obackup.json');
    if (!backupFile.existsSync()) {
      // Skip if debug file not available (e.g., in CI)
      return;
    }

    final backupJson = jsonDecode(await backupFile.readAsString());
    final backup = Backup.fromMap(backupJson);

    // All record IDs in the backup
    final recordIds = backup.records.map((r) => r!.id).toSet();

    // All record IDs referenced by tag associations
    final tagRecordIds =
        backup.recordTagAssociations.map((a) => a.recordId).toSet();

    // Every tag association should reference a valid record ID
    final orphanedTagIds = tagRecordIds.difference(recordIds);
    expect(orphanedTagIds, isEmpty,
        reason: 'All tag associations in the backup should reference '
            'existing record IDs. The backup file is internally consistent.');

    // Verify counts match the user's database
    expect(backup.records.length, 475);
    expect(backup.recordTagAssociations.length, 307);
  });

  test(
      'Verify records in backup have no tags field (root cause of the bug)',
      () async {
    // This test verifies the root cause: Record.toMap() does not serialize
    // the tags field, so when backup is deserialized, records have empty tags.
    // The fix in importDataFromBackupFile populates record.tags from the
    // backup's record_tag_associations before calling addRecordsInBatch.

    final category = Category('Food',
        categoryType: CategoryType.expense, iconEmoji: '🍔');
    final now = DateTime.now().toUtc();

    // Create a record with tags
    final record = Record(-25.0, 'Test', category, now,
        tags: {'Lidl', 'Weekly'});
    expect(record.tags, {'Lidl', 'Weekly'});

    // Serialize it (as the backup does)
    final map = record.toMap();

    // The 'tags' field is NOT in the serialized map
    expect(map.containsKey('tags'), isFalse,
        reason: 'Record.toMap() does not include tags — '
            'this is why records in backup have no tags');

    // Deserialize it back (as Backup.fromMap does)
    map['category'] = category;
    final restored = Record.fromMap(map);

    // Tags are lost!
    expect(restored.tags, isEmpty,
        reason: 'Tags are lost during serialization round-trip '
            'because toMap() excludes them');
  });

  test('Merge import: existing records keep tags, new records get correct tags',
      () async {
    final DatabaseInterface db = ServiceConfig.database;

    final category = Category('Dining',
        categoryType: CategoryType.expense, iconEmoji: '🍽');

    // Pre-populate DB with a category and a record + tag
    await db.addCategory(category);
    final existingRecord = Record(-25.0, 'Existing Meal', category,
        DateTime.utc(2024, 1, 1, 12, 0, 0),
        tags: {'existing-tag'});
    await db.addRecordsInBatch([existingRecord]);

    // Verify pre-existing data
    var allRecords = await db.getAllRecords();
    expect(allRecords.length, 1);
    expect(allRecords.first!.tags, contains('existing-tag'));

    // Import a backup containing the same record (should be skipped) plus a new one
    final now = DateTime.utc(2024, 1, 1, 12, 0, 0);
    final backupMap = {
      'records': [
        {
          'id': 100,
          'title': 'Existing Meal',
          'value': -25.0,
          'datetime': now.millisecondsSinceEpoch,
          'timezone': 'Europe/Vienna',
          'category_name': 'Dining',
          'category_type': 0,
          'description': '',
          'recurrence_id': null,
        },
        {
          'id': 200,
          'title': 'New Meal',
          'value': -15.0,
          'datetime': now.add(Duration(hours: 2)).millisecondsSinceEpoch,
          'timezone': 'Europe/Vienna',
          'category_name': 'Dining',
          'category_type': 0,
          'description': '',
          'recurrence_id': null,
        },
      ],
      'categories': [category.toMap()],
      'recurrent_record_patterns': [],
      'record_tag_associations': [
        {'record_id': 100, 'tag_name': 'duplicate-tag'},
        {'record_id': 200, 'tag_name': 'new-tag'},
      ],
      'created_at': now.millisecondsSinceEpoch,
      'package_name': 'com.test',
      'version': '1.0.0',
      'database_version': '17',
    };

    final backup = Backup.fromMap(backupMap);
    await simulateImport(backup, db);

    allRecords = await db.getAllRecords();
    expect(allRecords.length, 2, reason: 'Duplicate should be skipped');

    final titleToTags = <String, Set<String>>{};
    for (var r in allRecords) {
      titleToTags[r!.title ?? ''] = r.tags;
    }

    // Existing record keeps its original tag
    expect(titleToTags['Existing Meal'], contains('existing-tag'));
    // New record gets its tag from the import
    expect(titleToTags['New Meal'], contains('new-tag'));
  });

  test('Multiple tags per record are all correctly associated', () async {
    final DatabaseInterface db = ServiceConfig.database;

    final category = Category('Food',
        categoryType: CategoryType.expense, iconEmoji: '🍔');

    final now = DateTime.utc(2024, 2, 1, 10, 0, 0);
    final backupMap = {
      'records': [
        {
          'id': 50,
          'title': 'Big Grocery Trip',
          'value': -120.0,
          'datetime': now.millisecondsSinceEpoch,
          'timezone': 'Europe/Vienna',
          'category_name': 'Food',
          'category_type': 0,
          'description': '',
          'recurrence_id': null,
        },
      ],
      'categories': [category.toMap()],
      'recurrent_record_patterns': [],
      'record_tag_associations': [
        {'record_id': 50, 'tag_name': 'groceries'},
        {'record_id': 50, 'tag_name': 'weekly'},
        {'record_id': 50, 'tag_name': 'organic'},
      ],
      'created_at': now.millisecondsSinceEpoch,
      'package_name': 'com.test',
      'version': '1.0.0',
      'database_version': '17',
    };

    final backup = Backup.fromMap(backupMap);
    await simulateImport(backup, db);

    final allRecords = await db.getAllRecords();
    expect(allRecords.length, 1);
    expect(allRecords.first!.tags, containsAll(['groceries', 'weekly', 'organic']));
    expect(allRecords.first!.tags.length, 3);
  });

  test('Mixed tagged and untagged records are imported correctly', () async {
    final DatabaseInterface db = ServiceConfig.database;

    final category = Category('Food',
        categoryType: CategoryType.expense, iconEmoji: '🍔');

    final now = DateTime.utc(2024, 3, 1, 10, 0, 0);
    final backupMap = {
      'records': [
        {
          'id': 10,
          'title': 'Tagged Record',
          'value': -20.0,
          'datetime': now.millisecondsSinceEpoch,
          'timezone': 'Europe/Vienna',
          'category_name': 'Food',
          'category_type': 0,
          'description': '',
          'recurrence_id': null,
        },
        {
          'id': 11,
          'title': 'Untagged Record',
          'value': -30.0,
          'datetime': now.add(Duration(hours: 1)).millisecondsSinceEpoch,
          'timezone': 'Europe/Vienna',
          'category_name': 'Food',
          'category_type': 0,
          'description': '',
          'recurrence_id': null,
        },
        {
          'id': 12,
          'title': 'Another Tagged',
          'value': -40.0,
          'datetime': now.add(Duration(hours: 2)).millisecondsSinceEpoch,
          'timezone': 'Europe/Vienna',
          'category_name': 'Food',
          'category_type': 0,
          'description': '',
          'recurrence_id': null,
        },
      ],
      'categories': [category.toMap()],
      'recurrent_record_patterns': [],
      'record_tag_associations': [
        {'record_id': 10, 'tag_name': 'lunch'},
        {'record_id': 12, 'tag_name': 'dinner'},
      ],
      'created_at': now.millisecondsSinceEpoch,
      'package_name': 'com.test',
      'version': '1.0.0',
      'database_version': '17',
    };

    final backup = Backup.fromMap(backupMap);
    await simulateImport(backup, db);

    final allRecords = await db.getAllRecords();
    expect(allRecords.length, 3);

    final titleToTags = <String, Set<String>>{};
    for (var r in allRecords) {
      titleToTags[r!.title ?? ''] = r.tags;
    }

    expect(titleToTags['Tagged Record'], contains('lunch'));
    expect(titleToTags['Untagged Record'], isEmpty);
    expect(titleToTags['Another Tagged'], contains('dinner'));
  });

  test('Backup.fromMap/toMap serialization roundtrip preserves all fields',
      () async {
    final category = Category('Food',
        categoryType: CategoryType.expense, iconEmoji: '🍔');

    final now = DateTime.utc(2024, 4, 1, 10, 0, 0);
    final backupMap = {
      'records': [
        {
          'id': 1,
          'title': 'Test Record',
          'value': -42.5,
          'datetime': now.millisecondsSinceEpoch,
          'timezone': 'Europe/Vienna',
          'category_name': 'Food',
          'category_type': 0,
          'description': 'test desc',
          'recurrence_id': null,
        },
      ],
      'categories': [category.toMap()],
      'recurrent_record_patterns': [],
      'record_tag_associations': [
        {'record_id': 1, 'tag_name': 'roundtrip-tag'},
      ],
      'created_at': now.millisecondsSinceEpoch,
      'package_name': 'com.test.roundtrip',
      'version': '2.0.0',
      'database_version': '17',
    };

    // Deserialize
    final backup = Backup.fromMap(backupMap);

    // Serialize back
    final serialized = backup.toMap();

    // Deserialize again
    final restored = Backup.fromMap(serialized);

    // Verify all fields match
    expect(restored.records.length, backup.records.length);
    expect(restored.categories.length, backup.categories.length);
    expect(restored.recurrentRecordsPattern.length,
        backup.recurrentRecordsPattern.length);
    expect(restored.recordTagAssociations.length,
        backup.recordTagAssociations.length);

    expect(restored.packageName, backup.packageName);
    expect(restored.version, backup.version);
    expect(restored.databaseVersion, backup.databaseVersion);

    // Verify record data
    expect(restored.records.first!.title, 'Test Record');
    expect(restored.records.first!.value, -42.5);

    // Verify tag association data
    expect(restored.recordTagAssociations.first.recordId, 1);
    expect(restored.recordTagAssociations.first.tagName, 'roundtrip-tag');

    // Verify category data
    expect(restored.categories.first!.name, 'Food');
  });

  test('BackupService.isEncrypted returns false for valid JSON file', () async {
    final tempFile = File('${Directory.systemTemp.path}/test_plain.json');
    await tempFile.writeAsString('{"records": [], "categories": []}');
    try {
      expect(await BackupService.isEncrypted(tempFile), isFalse);
    } finally {
      await tempFile.delete();
    }
  });

  test('BackupService.isEncrypted returns true for encrypted/non-JSON file',
      () async {
    final tempFile = File('${Directory.systemTemp.path}/test_encrypted.json');
    await tempFile.writeAsString('U2FsdGVkX1+not_valid_json_at_all==');
    try {
      expect(await BackupService.isEncrypted(tempFile), isTrue);
    } finally {
      await tempFile.delete();
    }
  });
}
