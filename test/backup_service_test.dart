import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/models/recurrent-period.dart';
import 'package:piggybank/models/recurrent-record-pattern.dart';
import 'package:piggybank/services/backup-service.dart';
import 'package:piggybank/services/database/database-interface.dart';
import 'package:piggybank/settings/backup-retention-period.dart';
import 'package:test/test.dart' as testlib;
import 'package:mockito/annotations.dart';
import 'backup_service_test.mocks.dart';

@GenerateMocks([DatabaseInterface])
void main() {
  late MockDatabaseInterface mockDatabase;
  late Directory testDir;

  late List<Category?> categories;
  late List<Record?> records;
  late List<RecurrentRecordPattern> recurrentPatterns;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    mockDatabase = MockDatabaseInterface();

    // Mock data
    categories = [
      Category("Rent",
          iconCodePoint: 1,
          categoryType: CategoryType.expense),
      Category("Food",
          iconCodePoint: 2,
          categoryType: CategoryType.expense),
      Category("Salary",
          iconCodePoint: 3,
          categoryType: CategoryType.income)
    ];
    records = [
      Record(-300, "April Rent", categories[0],
          DateTime.parse("2020-04-02 10:30:00"),
          id: 1),
      Record(-300, "May Rent", categories[0],
          DateTime.parse("2020-05-01 10:30:00"),
          id: 2),
      Record(-30, "Pizza", categories[1],
          DateTime.parse("2020-05-01 09:30:00"),
          id: 3),
      Record(1700, "Salary", categories[2],
          DateTime.parse("2020-05-02 09:30:00"),
          id: 4),
      Record(-30, "Restaurant", categories[1],
          DateTime.parse("2020-05-02 10:30:00"),
          id: 5),
      Record(-60.5, "Groceries", categories[1],
          DateTime.parse("2020-05-03 10:30:00"),
          id: 6),
    ];
    recurrentPatterns = [
      RecurrentRecordPattern(1, "Rent", categories[0], DateTime.parse("2020-05-03 10:30:00"),
       RecurrentPeriod.EveryMonth)
    ];

    when(mockDatabase.getAllRecords()).thenAnswer((_) async => records);
    when(mockDatabase.getAllCategories()).thenAnswer((_) async => categories);
    when(mockDatabase.getRecurrentRecordPatterns())
        .thenAnswer((_) async => recurrentPatterns);

    when(mockDatabase.addCategory(any)).thenAnswer((_) async => 0);
    when(mockDatabase.addRecord(any)).thenAnswer((_) async => 0);
    when(mockDatabase.addRecurrentRecordPattern(any)).thenAnswer((_) async => null);

    when(mockDatabase.getRecurrentRecordPattern(any)).thenAnswer((_) async => null);
    when(mockDatabase.getMatchingRecord(any)).thenAnswer((_) async => null);

    // Swap database
    BackupService.database = mockDatabase;

    testDir = Directory("test/temp");
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

  test('encryptData encrypts the data correctly', () {
    const data = 'This is a test string';
    const password = 'testpassword';

    final encryptedData = BackupService.encryptData(data, password);

    // Ensure the encrypted data is not the same as the original data
    expect(encryptedData, isNot(data));
    // Ensure the encrypted data is a valid Base64 string
    expect(() => base64.decode(encryptedData), returnsNormally);
  });

  test('decryptData decrypts the data correctly', () {
    const data = 'This is a test string';
    const password = 'testpassword';

    final encryptedData = BackupService.encryptData(data, password);
    final decryptedData = BackupService.decryptData(encryptedData, password);

    // Ensure the decrypted data matches the original data
    expect(decryptedData, data);
  });

  test('decryptData fails with incorrect password', () {
    const data = 'This is a test string';
    const password = 'testpassword';
    const wrongPassword = 'wrongpassword';

    final encryptedData = BackupService.encryptData(data, password);

    // Ensure decryption fails with the wrong password
    expect(() => BackupService.decryptData(encryptedData, wrongPassword), throwsA(isA<ArgumentError>()));
  });

  testlib.test('createJsonBackupFile creates a backup file', () async {
    final backupFile = await BackupService.createJsonBackupFile(
      directoryPath: testDir.path,
    );

    expect(await backupFile.exists(), isTrue);
    final backupContent = await backupFile.readAsString();
    final backupMap = jsonDecode(backupContent);

    expect(backupMap['categories'].length, categories.length);
    expect(backupMap['records'].length, records.length);
    expect(backupMap['recurrent_record_patterns'].length, recurrentPatterns.length);
  });

  testlib.test('createJsonBackupFile encrypts the backup file', () async {
    const encryptionPassword = 'testpassword';
    final backupFile = await BackupService.createJsonBackupFile(
      directoryPath: testDir.path,
      encryptionPassword: encryptionPassword,
    );

    expect(await backupFile.exists(), isTrue);
    final backupContent = await backupFile.readAsString();

    // Ensure the content is encrypted (not a valid JSON)
    expect(() => jsonDecode(backupContent), throwsFormatException);
  });

  testlib.test('importDataFromBackupFile imports data from a backup file', () async {
    final backupFile = await BackupService.createJsonBackupFile(
      directoryPath: testDir.path,
    );

    final result = await BackupService.importDataFromBackupFile(backupFile);

    expect(result, isTrue);
    verify(mockDatabase.addCategory(any)).called(categories.length);
    verify(mockDatabase.addRecord(any)).called(records.length);
    verify(mockDatabase.addRecurrentRecordPattern(any)).called(recurrentPatterns.length);
  });

  testlib.test('importDataFromBackupFile decrypts and imports data from an encrypted backup file', () async {
    const encryptionPassword = 'testpassword';
    final backupFile = await BackupService.createJsonBackupFile(
      directoryPath: testDir.path,
      encryptionPassword: encryptionPassword,
    );

    final result = await BackupService.importDataFromBackupFile(
      backupFile,
      encryptionPassword: encryptionPassword,
    );

    expect(result, isTrue);
    verify(mockDatabase.addCategory(any)).called(categories.length);
    verify(mockDatabase.addRecord(any)).called(records.length);
    verify(mockDatabase.addRecurrentRecordPattern(any)).called(recurrentPatterns.length);
  });

  testlib.test('importDataFromBackupFile fails with incorrect decryption password', () async {
    const encryptionPassword = 'testpassword';
    final backupFile = await BackupService.createJsonBackupFile(
      directoryPath: testDir.path,
      encryptionPassword: encryptionPassword,
    );

    final result = await BackupService.importDataFromBackupFile(
      backupFile,
      encryptionPassword: 'wrongpassword',
    );

    expect(result, isFalse);
  });

    testlib.test('removeOldBackups removes files older than one week', () async {
    // Create test files
    final now = DateTime.now();
    final oldFile = File('${testDir.path}/old_backup.json');
    final newFile = File('${testDir.path}/new_backup.json');

    await oldFile.writeAsString('Old backup');
    await newFile.writeAsString('New backup');

    // Set the creation date of the old file to more than one week ago
    final oldFileCreationDate = now.subtract(Duration(days: 8));
    await oldFile.setLastModified(oldFileCreationDate);

    // Ensure files exist
    expect(await oldFile.exists(), isTrue);
    expect(await newFile.exists(), isTrue);

    // Call the method
    await BackupService.removeOldBackups(BackupRetentionPeriod.WEEK, testDir);

    // Check results
    expect(await oldFile.exists(), isFalse);
    expect(await newFile.exists(), isTrue);
  });

  testlib.test('removeOldBackups removes files older than one month', () async {
    // Create test files
    final now = DateTime.now();
    final oldFile = File('${testDir.path}/old_backup.json');
    final newFile = File('${testDir.path}/new_backup.json');

    await oldFile.writeAsString('Old backup');
    await newFile.writeAsString('New backup');

    // Set the creation date of the old file to more than one month ago
    final oldFileCreationDate = now.subtract(Duration(days: 31));
    await oldFile.setLastModified(oldFileCreationDate);

    // Ensure files exist
    expect(await oldFile.exists(), isTrue);
    expect(await newFile.exists(), isTrue);

    // Call the method
    await BackupService.removeOldBackups(BackupRetentionPeriod.MONTH, testDir);

    // Check results
    expect(await oldFile.exists(), isFalse);
    expect(await newFile.exists(), isTrue);
  });
}
