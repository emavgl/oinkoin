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

/// Test to verify the fix for the user's issue with messed-up labels/tags during import
///
/// The original problem: When importing records, the records get new auto-increment IDs
/// from the destination database, but the record_tag_associations still reference
/// the original record IDs from the source database. This causes tags to be
/// associated with wrong records!
///
/// The fix: Before calling addRecordsInBatch, we populate record.tags from the
/// backup's record_tag_associations. This way, addRecordsInBatch's Phase 2
/// correctly maps tags to the new record IDs.
@GenerateMocks([DatabaseInterface])
void main() {
  late MockDatabaseInterface mockDatabase;
  late Directory testDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    mockDatabase = MockDatabaseInterface();

    // Swap database
    BackupService.database = mockDatabase;

    testDir = Directory("test/temp_import_issue");
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

  testlib.test(
      'import should maintain correct tag associations when record IDs change',
      () async {
    // Create test data simulating a backup from source device
    // Record IDs are 1, 2, 3 on source device
    final categories = [
      Category("Food", iconCodePoint: 1, categoryType: CategoryType.expense),
      Category("Salary", iconCodePoint: 2, categoryType: CategoryType.income)
    ];

    final records = [
      Record(-10, "Lunch", categories[0], DateTime.parse("2024-01-01 12:00:00"),
          id: 1), // Original ID: 1
      Record(-20, "Dinner", categories[0], DateTime.parse("2024-01-01 19:00:00"),
          id: 2), // Original ID: 2
      Record(1000, "Salary", categories[1], DateTime.parse("2024-01-01 09:00:00"),
          id: 3), // Original ID: 3
    ];

    // Tags associated with specific record IDs from source device
    final recordTagAssociations = [
      RecordTagAssociation(recordId: 1, tagName: "food-tag-for-lunch"),
      RecordTagAssociation(recordId: 2, tagName: "food-tag-for-dinner"),
      RecordTagAssociation(recordId: 3, tagName: "income-tag-for-salary"),
    ];

    final capturedRecords = <Record?>[];

    when(mockDatabase.getAllRecords()).thenAnswer((_) async => records);
    when(mockDatabase.getAllCategories()).thenAnswer((_) async => categories);
    when(mockDatabase.getRecurrentRecordPatterns())
        .thenAnswer((_) async => []);
    when(mockDatabase.getAllRecordTagAssociations())
        .thenAnswer((_) async => recordTagAssociations);

    when(mockDatabase.addCategory(any)).thenAnswer((_) async => 0);

    when(mockDatabase.addRecordsInBatch(any))
        .thenAnswer((Invocation invocation) async {
      final List<Record?> incomingRecords = invocation.positionalArguments[0];
      for (int i = 0; i < incomingRecords.length; i++) {
        final record = incomingRecords[i];
        if (record != null) {
          capturedRecords.add(record);
        }
      }
    });

    when(mockDatabase.getRecurrentRecordPattern(any))
        .thenAnswer((_) async => null);

    // Create backup file
    final backupFile = await BackupService.createJsonBackupFile(
      directoryPath: testDir.path,
    );

    // Import the backup
    final result = await BackupService.importDataFromBackupFile(backupFile);

    expect(result, isTrue);

    // Verify that records passed to addRecordsInBatch have their tags populated
    // from the backup's record_tag_associations
    expect(capturedRecords.length, 3);

    final lunchRecord = capturedRecords.firstWhere((r) => r!.title == "Lunch");
    final dinnerRecord = capturedRecords.firstWhere((r) => r!.title == "Dinner");
    final salaryRecord = capturedRecords.firstWhere((r) => r!.title == "Salary");

    expect(lunchRecord!.tags, contains("food-tag-for-lunch"),
        reason: "Lunch record should have its tag populated from associations");
    expect(dinnerRecord!.tags, contains("food-tag-for-dinner"),
        reason: "Dinner record should have its tag populated from associations");
    expect(salaryRecord!.tags, contains("income-tag-for-salary"),
        reason: "Salary record should have its tag populated from associations");
  });

  testlib.test(
      'demonstrate the label mismatch issue from user report is fixed',
      () async {
    // This test simulates the exact scenario from the user's report:
    // Labels (tags) should be correctly preserved during restore

    // Setup: Source device has records with tags
    final categories = [
      Category("Santé", iconCodePoint: 1, categoryType: CategoryType.expense),
      Category("Alimentation", iconCodePoint: 2, categoryType: CategoryType.expense),
      Category("Retraite", iconCodePoint: 3, categoryType: CategoryType.income),
    ];

    final records = [
      Record(-218, "Prestation Dentiste", categories[0],
          DateTime.parse("2024-01-10 10:00:00"), id: 6),
      Record(-17.74, "Alimentation", categories[1],
          DateTime.parse("2024-01-09 10:00:00"), id: 7),
      Record(1829, null, categories[2],
          DateTime.parse("2024-01-10 10:00:00"), id: 8),
    ];

    // Tags on source device
    final recordTagAssociations = [
      RecordTagAssociation(recordId: 6, tagName: "dentist-tag"),
      RecordTagAssociation(recordId: 7, tagName: "food-tag"),
      RecordTagAssociation(recordId: 8, tagName: "pension-tag"),
    ];

    final capturedRecords = <Record?>[];

    when(mockDatabase.getAllRecords()).thenAnswer((_) async => records);
    when(mockDatabase.getAllCategories()).thenAnswer((_) async => categories);
    when(mockDatabase.getRecurrentRecordPatterns())
        .thenAnswer((_) async => []);
    when(mockDatabase.getAllRecordTagAssociations())
        .thenAnswer((_) async => recordTagAssociations);

    when(mockDatabase.addCategory(any)).thenAnswer((_) async => 0);

    when(mockDatabase.addRecordsInBatch(any))
        .thenAnswer((Invocation invocation) async {
      final List<Record?> incomingRecords = invocation.positionalArguments[0];
      for (int i = 0; i < incomingRecords.length; i++) {
        final record = incomingRecords[i];
        if (record != null) {
          capturedRecords.add(record);
        }
      }
    });

    when(mockDatabase.getRecurrentRecordPattern(any))
        .thenAnswer((_) async => null);

    final backupFile = await BackupService.createJsonBackupFile(
      directoryPath: testDir.path,
    );

    await BackupService.importDataFromBackupFile(backupFile);

    // Verify tags are correctly populated on records
    final dentistRecord = capturedRecords.firstWhere(
        (r) => r!.title == "Prestation Dentiste");
    final foodRecord = capturedRecords.firstWhere(
        (r) => r!.title == "Alimentation");
    final retirementRecord = capturedRecords.firstWhere(
        (r) => r!.title == null);

    expect(dentistRecord!.tags, contains("dentist-tag"),
        reason: "Dentist record should have dentist-tag");
    expect(foodRecord!.tags, contains("food-tag"),
        reason: "Food record should have food-tag");
    expect(retirementRecord!.tags, contains("pension-tag"),
        reason: "Retirement record should have pension-tag");
  });
}
