import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/record-tag-association.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/services/backup-service.dart';
import 'package:piggybank/services/database/database-interface.dart';
import 'package:test/test.dart' as testlib;

import 'backup_service_test.mocks.dart';

/// This test verifies the backup import functionality with tags.
/// It creates a mock backup file programmatically instead of relying on external files.
///
/// Original issue: "The transaction labels on the tablet have been replaced by other
/// labels when restoring to the smartphone!"
///
/// Root cause: Record IDs in the backup file don't match the new record IDs
/// assigned during import, causing tags to be associated with wrong records.
@GenerateMocks([DatabaseInterface])
void main() {
  late MockDatabaseInterface mockDatabase;
  late Directory testDir;

  // Create a mock backup structure programmatically instead of relying on external files
  Map<String, dynamic> createMockBackupData() {
    return {
      "version": "2",
      "app_name": "piggybankpro",
      "app_version": "1.4.1",
      "export_date": "2026-02-14T12:07:48.000000",
      "records": [
        {
          "id": 1,
          "title": "Groceries",
          "value": -50.0,
          "category_name": "Food",
          "category_type": 1,
          "datetime": 1738407600000,
          "timezone": "UTC"
        },
        {
          "id": 2,
          "title": "Gas",
          "value": -30.0,
          "category_name": "Transport",
          "category_type": 1,
          "datetime": 1738494000000,
          "timezone": "UTC"
        },
        {
          "id": 3,
          "title": "Salary",
          "value": 2000.0,
          "category_name": "Income",
          "category_type": 0,
          "datetime": 1738404000000,
          "timezone": "UTC"
        },
        {
          "id": 4,
          "title": "Restaurant",
          "value": -80.0,
          "category_name": "Food",
          "category_type": 1,
          "datetime": 1738776000000,
          "timezone": "UTC"
        },
        {
          "id": 5,
          "title": "Uber",
          "value": -25.0,
          "category_name": "Transport",
          "category_type": 1,
          "datetime": 1738862400000,
          "timezone": "UTC"
        },
      ],
      "categories": [
        {
          "name": "Food",
          "icon": 58763,
          "color": "255:255:87:51",
          "category_type": 1
        },
        {
          "name": "Transport",
          "icon": 58790,
          "color": "255:51:255:87",
          "category_type": 1
        },
        {
          "name": "Income",
          "icon": 57896,
          "color": "255:51:87:255",
          "category_type": 0
        },
      ],
      "record_tag_associations": [
        {"record_id": 1, "tag_name": "weekly"},
        {"record_id": 1, "tag_name": "essential"},
        {"record_id": 2, "tag_name": "commute"},
        {"record_id": 4, "tag_name": "dining"},
        {"record_id": 4, "tag_name": "social"},
      ],
      "recurrent_record_patterns": [],
      "tags": [
        {"name": "weekly"},
        {"name": "essential"},
        {"name": "commute"},
        {"name": "dining"},
        {"name": "social"},
      ],
    };
  }

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    mockDatabase = MockDatabaseInterface();

    // Swap database
    BackupService.database = mockDatabase;

    testDir = Directory("test/temp_user_data");
    const MethodChannel channel =
        MethodChannel('dev.fluttercommunity.plus/package_info');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      if (methodCall.method == 'getAll') {
        return <String, dynamic>{
          'appName': 'ABC',
          'packageName': 'A.B.C',
          'version': '1.0.0',
          'buildNumber': '67'
        };
      }
    });
    const MethodChannel channel2 =
        MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel2, (MethodCall methodCall) async {
      return testDir;
    });
  });

  tearDownAll(() async {
    if (await testDir.exists()) {
      await testDir.delete(recursive: true);
    }
  });

  testlib.setUp(() async {
    if (await testDir.exists()) {
      await testDir.delete(recursive: true);
    }
    await testDir.create(recursive: true);
  });

  testlib.test('verify backup file structure is correct', () async {
    // Create test backup file with mock data
    final testBackupFilePath = '${testDir.path}/test_backup.json';
    final mockData = createMockBackupData();
    final testFile = File(testBackupFilePath);
    await testFile.writeAsString(jsonEncode(mockData));

    // Verify the test backup file exists and has correct structure
    expect(await testFile.exists(), isTrue,
        reason: 'Test backup file should exist');

    final content = await testFile.readAsString();
    final jsonMap = jsonDecode(content);

    // Verify all required fields exist
    expect(jsonMap.containsKey('records'), isTrue);
    expect(jsonMap.containsKey('categories'), isTrue);
    expect(jsonMap.containsKey('record_tag_associations'), isTrue);

    // Verify data structure
    final records = jsonMap['records'] as List;
    final categories = jsonMap['categories'] as List;
    final associations = jsonMap['record_tag_associations'] as List;

    print('\n=== Test Backup File Analysis ===');
    print('Records count: ${records.length}');
    print('Categories count: ${categories.length}');
    print('Tag associations count: ${associations.length}');

    // Show sample records and their IDs
    print('\nSample records from backup:');
    for (var i = 0; i < min(5, records.length); i++) {
      final record = records[i];
      print(
          '  Record ID: ${record['id']}, Title: ${record['title'] ?? "(null)"}, '
          'Category: ${record['category_name']}');
    }

    // Show sample tag associations
    print('\nSample tag associations from backup:');
    for (var i = 0; i < min(5, associations.length); i++) {
      final assoc = associations[i];
      print('  Tag: ${assoc['tag_name']} -> Record ID: ${assoc['record_id']}');
    }

    // Verify that tag associations reference actual record IDs
    final recordIds = records.map((r) => r['id'] as int).toSet();
    final associationRecordIds =
        associations.map((a) => a['record_id'] as int).toSet();

    print('\nRecord IDs in backup: ${recordIds.length} unique IDs');
    print(
        'Record IDs referenced by tags: ${associationRecordIds.length} unique IDs');

    // All association record IDs should exist in the records list
    final invalidAssociations = associationRecordIds.difference(recordIds);
    if (invalidAssociations.isNotEmpty) {
      print(
          'WARNING: Tag associations reference non-existent record IDs: $invalidAssociations');
    }

    expect(invalidAssociations.isEmpty, isTrue,
        reason: 'All tag associations should reference existing record IDs');

    print('\n✓ Backup file structure is valid');
  });

  testlib.test('verify import fix - tags are correctly populated on records',
      () async {
    // Create test backup file with mock data
    final testBackupFilePath = '${testDir.path}/test_backup.json';
    final mockData = createMockBackupData();
    final testFile = File(testBackupFilePath);
    await testFile.writeAsString(jsonEncode(mockData));

    // Read the test backup file
    final content = await testFile.readAsString();
    final jsonMap = jsonDecode(content);

    final originalAssociations = (jsonMap['record_tag_associations'] as List)
        .map((a) => RecordTagAssociation.fromMap(a))
        .toList();

    // Build expected mapping: record ID -> set of tags
    final expectedTagsByRecordId = <int, Set<String>>{};
    for (var assoc in originalAssociations) {
      expectedTagsByRecordId
          .putIfAbsent(assoc.recordId, () => <String>{})
          .add(assoc.tagName);
    }

    // Mock the database to simulate what happens during import
    final capturedRecords = <Record?>[];

    // Setup mock responses based on the user's data
    final categories = (jsonMap['categories'] as List)
        .map((c) => Category.fromMap(c))
        .toList();
    final records = (jsonMap['records'] as List).map((r) {
      final row = Map<String, dynamic>.from(r);
      row['category'] = categories.firstWhere(
        (c) =>
            c.name == row['category_name'] &&
            c.categoryType?.index == row['category_type'],
        orElse: () => Category(row['category_name'],
            categoryType: CategoryType.values[row['category_type']]),
      );
      return Record.fromMap(row);
    }).toList();

    when(mockDatabase.getAllRecords()).thenAnswer((_) async => records);
    when(mockDatabase.getAllCategories()).thenAnswer((_) async => categories);
    when(mockDatabase.getRecurrentRecordPatterns()).thenAnswer((_) async => []);
    when(mockDatabase.getAllRecordTagAssociations())
        .thenAnswer((_) async => originalAssociations);
    when(mockDatabase.addCategory(any)).thenAnswer((_) async => 0);

    when(mockDatabase.addRecordsInBatch(any))
        .thenAnswer((Invocation invocation) async {
      final List<Record?> incomingRecords = invocation.positionalArguments[0];
      capturedRecords.addAll(incomingRecords.where((r) => r != null));
    });

    when(mockDatabase.getRecurrentRecordPattern(any))
        .thenAnswer((_) async => null);

    // Import the backup
    final result = await BackupService.importDataFromBackupFile(testFile);
    expect(result, isTrue);

    // Verify that records passed to addRecordsInBatch have their tags populated
    // from the backup's record_tag_associations
    final recordsWithTags =
        capturedRecords.where((r) => r!.tags.isNotEmpty).toList();
    expect(recordsWithTags.length, expectedTagsByRecordId.length,
        reason: 'Number of records with tags should match number of records '
            'referenced in tag associations');

    // Verify each record that should have tags has the correct ones
    for (var record in capturedRecords) {
      final expected = expectedTagsByRecordId[record!.id];
      if (expected != null) {
        expect(record.tags, equals(expected),
            reason: 'Record "${record.title}" (id=${record.id}) should have '
                'tags $expected but got ${record.tags}');
      }
    }
  });
}

int min(int a, int b) => a < b ? a : b;
