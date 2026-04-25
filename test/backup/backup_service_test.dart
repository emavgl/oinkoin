import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/currency.dart';
import 'package:piggybank/models/record-tag-association.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/models/recurrent-period.dart';
import 'package:piggybank/models/recurrent-record-pattern.dart';
import 'package:piggybank/services/backup-service.dart';
import 'package:piggybank/services/database/database-interface.dart';
import 'package:piggybank/settings/backup-retention-period.dart';
import 'package:piggybank/settings/constants/preferences-keys.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test/test.dart' as testlib;

import './backup_service_test.mocks.dart';

@GenerateMocks([DatabaseInterface])
void main() {
  late MockDatabaseInterface mockDatabase;
  late Directory testDir;

  late List<Category?> categories;
  late List<Record?> records;
  late List<RecurrentRecordPattern> recurrentPatterns;
  late List<RecordTagAssociation> recordTagAssociations;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    mockDatabase = MockDatabaseInterface();

    // Mock data
    categories = [
      Category("Rent", iconCodePoint: 1, categoryType: CategoryType.expense),
      Category("Food", iconCodePoint: 2, categoryType: CategoryType.expense),
      Category("Salary", iconCodePoint: 3, categoryType: CategoryType.income)
    ];
    records = [
      Record(-300, "April Rent", categories[0],
          DateTime.parse("2020-04-02 10:30:00"),
          id: 1, tags: ["rent", "house"].toSet()),
      Record(-300, "May Rent", categories[0],
          DateTime.parse("2020-05-01 10:30:00"),
          id: 2, tags: ["rent", "monthly"].toSet()),
      Record(-30, "Pizza", categories[1], DateTime.parse("2020-05-01 09:30:00"),
          id: 3, tags: ["food", "dinner"].toSet()),
      Record(
          1700, "Salary", categories[2], DateTime.parse("2020-05-02 09:30:00"),
          id: 4, tags: ["income", "job"].toSet()),
      Record(-30, "Restaurant", categories[1],
          DateTime.parse("2020-05-02 10:30:00"),
          id: 5, tags: ["food", "lunch"].toSet()),
      Record(-60.5, "Groceries", categories[1],
          DateTime.parse("2020-05-03 10:30:00"),
          id: 6, tags: ["food", "supermarket"].toSet()),
    ];
    recurrentPatterns = [
      RecurrentRecordPattern(1, "Rent", categories[0],
          DateTime.parse("2020-05-03 10:30:00"), RecurrentPeriod.EveryMonth,
          tags: ["rent", "monthly"].toSet())
    ];

    recordTagAssociations = [
      RecordTagAssociation(recordId: 1, tagName: "rent"),
      RecordTagAssociation(recordId: 1, tagName: "house"),
      RecordTagAssociation(recordId: 2, tagName: "rent"),
      RecordTagAssociation(recordId: 2, tagName: "monthly"),
      RecordTagAssociation(recordId: 3, tagName: "food"),
      RecordTagAssociation(recordId: 3, tagName: "dinner"),
      RecordTagAssociation(recordId: 4, tagName: "income"),
      RecordTagAssociation(recordId: 4, tagName: "job"),
      RecordTagAssociation(recordId: 5, tagName: "food"),
      RecordTagAssociation(recordId: 5, tagName: "lunch"),
      RecordTagAssociation(recordId: 6, tagName: "food"),
      RecordTagAssociation(recordId: 6, tagName: "supermarket"),
    ];

    when(mockDatabase.getAllRecords()).thenAnswer((_) async => records);
    when(mockDatabase.getAllCategories()).thenAnswer((_) async => categories);
    when(mockDatabase.getRecurrentRecordPatterns())
        .thenAnswer((_) async => recurrentPatterns);
    when(mockDatabase.getAllRecordTagAssociations())
        .thenAnswer((_) async => recordTagAssociations);
    when(mockDatabase.getAllWallets()).thenAnswer((_) async => []);
    when(mockDatabase.addWallet(any)).thenAnswer((_) async => 1);
    when(mockDatabase.getDefaultWallet()).thenAnswer((_) async => null);
    when(mockDatabase.getAllProfiles()).thenAnswer((_) async => []);
    when(mockDatabase.getDefaultProfile()).thenAnswer((_) async => null);
    when(mockDatabase.addProfile(any)).thenAnswer((_) async => 1);

    when(mockDatabase.addCategory(any)).thenAnswer((_) async => 0);
    when(mockDatabase.addRecord(any)).thenAnswer((_) async => 0);
    when(mockDatabase.addRecordsInBatch(any)).thenAnswer((_) async => null);
    when(mockDatabase.addRecurrentRecordPattern(any))
        .thenAnswer((_) async => null);
    when(mockDatabase.getRecurrentRecordPattern(any))
        .thenAnswer((_) async => null);
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

    // Mock SharedPreferences
    final Map<String, Object> prefStore = {};
    const MethodChannel prefsChannel =
        MethodChannel('plugins.flutter.io/shared_preferences');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(prefsChannel, (MethodCall methodCall) async {
      if (methodCall.method == 'getAll') {
        return <String, dynamic>{};
      }
      if (methodCall.method == 'setString') {
        final args = methodCall.arguments as Map;
        prefStore[args['key'] as String] = args['value'] as String;
        return true;
      }
      if (methodCall.method == 'remove') {
        final args = methodCall.arguments as Map;
        prefStore.remove(args['key'] as String);
        return true;
      }
      if (methodCall.method == 'getString') {
        final args = methodCall.arguments as Map;
        return prefStore[args['key'] as String];
      }
      if (methodCall.method == 'clear') {
        prefStore.clear();
        return true;
      }
      return null;
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
    expect(() => BackupService.decryptData(encryptedData, wrongPassword),
        throwsA(isA<ArgumentError>()));
  });

  testlib.test('createJsonBackupFile creates a backup file with tags',
      () async {
    final backupFile = await BackupService.createJsonBackupFile(
      directoryPath: testDir.path,
    );

    expect(await backupFile.exists(), isTrue);
    final backupContent = await backupFile.readAsString();
    final backupMap = jsonDecode(backupContent);

    expect(backupMap['categories'].length, categories.length);
    expect(backupMap['records'].length, records.length);
    expect(backupMap['recurrent_record_patterns'].length,
        recurrentPatterns.length);
    expect(backupMap['record_tag_associations'].length,
        recordTagAssociations.length);

    // Verify tags are NOT in records (as they are now separate)
    expect(backupMap['records'][0], isNot(contains('tags')));
    expect(backupMap['records'][1], isNot(contains('tags')));

    // recurrent_patterns still have tags
    expect(backupMap['recurrent_record_patterns'][0], contains('tags'));

    // Verify record tag associations
    expect(backupMap['record_tag_associations'][0]['record_id'], 1);
    expect(backupMap['record_tag_associations'][0]['tag_name'], "rent");
    expect(backupMap['record_tag_associations'][1]['record_id'], 1);
    expect(backupMap['record_tag_associations'][1]['tag_name'], "house");
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

  testlib.test(
      'importDataFromBackupFile imports data from a backup file including tags',
      () async {
    // Mock addRecord and addRecurrentRecordPattern to capture arguments
    final capturedRecords = <Record?>[];
    final capturedRecurrentPatterns = <RecurrentRecordPattern>[];

    when(mockDatabase.addRecordsInBatch(any))
        .thenAnswer((Invocation invocation) async {
      final List<Record?> records = invocation.positionalArguments[0];
      capturedRecords.addAll(records);
    });

    when(mockDatabase.addRecurrentRecordPattern(any))
        .thenAnswer((Invocation invocation) async {
      final RecurrentRecordPattern pattern = invocation.positionalArguments[0];
      capturedRecurrentPatterns.add(pattern);
      return null;
    });

    final backupFile = await BackupService.createJsonBackupFile(
      directoryPath: testDir.path,
    );

    final result = await BackupService.importDataFromBackupFile(backupFile);

    expect(result, isTrue);
    verify(mockDatabase.addCategory(any)).called(categories.length);
    verify(mockDatabase.addRecordsInBatch(argThat(isA<List<Record?>>())))
        .called(1);
    verify(mockDatabase.addRecurrentRecordPattern(any))
        .called(recurrentPatterns.length);

    // Verify tags ARE populated on records from the backup's tag associations
    // (the fix populates record.tags before calling addRecordsInBatch)
    expect(capturedRecords[0]!.tags, isNotEmpty);
    expect(capturedRecords[0]!.tags, containsAll(['rent', 'house']));
    expect(capturedRecords[1]!.tags, containsAll(['rent', 'monthly']));

    // recurrent_pattern still have tags
    expect(capturedRecurrentPatterns[0].tags, isNotEmpty);
  });

  testlib.test(
      'importDataFromBackupFile decrypts and imports data from an encrypted backup file including tags',
      () async {
    const encryptionPassword = 'testpassword';
    final capturedRecords = <Record?>[];
    final capturedRecurrentPatterns = <RecurrentRecordPattern>[];

    when(mockDatabase.addRecordsInBatch(any))
        .thenAnswer((Invocation invocation) async {
      final List<Record?> records = invocation.positionalArguments[0];
      capturedRecords.addAll(records);
    });

    when(mockDatabase.addRecurrentRecordPattern(any))
        .thenAnswer((Invocation invocation) async {
      final RecurrentRecordPattern pattern = invocation.positionalArguments[0];
      capturedRecurrentPatterns.add(pattern);
      return null;
    });

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
    verify(mockDatabase.addRecurrentRecordPattern(any))
        .called(recurrentPatterns.length);

    // Verify tags ARE populated on records
    expect(capturedRecords[0]!.tags, isNotEmpty);
    expect(capturedRecords[0]!.tags, containsAll(['rent', 'house']));

    // Recurrent patterns still have tags
    expect(capturedRecurrentPatterns[0].tags, isNotEmpty);
  });

  testlib
      .test('importDataFromBackupFile fails with incorrect decryption password',
          () async {
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
    final oldFile = File('${testDir.path}/old_obackup.json');
    final newFile = File('${testDir.path}/new_obackup.json');

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
    final oldFile = File('${testDir.path}/old_obackup.json');
    final newFile = File('${testDir.path}/new_obackup.json');

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

  testlib
      .test('importDataFromBackupFile handles missing record_tag_associations',
          () async {
    // Create a backup file without record_tag_associations
    final backupMap = {
      'categories': categories.map((c) => c!.toMap()).toList(),
      'records': records.map((r) => r!.toMap()).toList(),
      'recurrent_record_patterns':
          recurrentPatterns.map((rp) => rp.toMap()).toList(),
      // Intentionally omitting record_tag_associations
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'package_name': 'com.example.test',
      'version': '1.0.0',
      'database_version': '1',
    };

    final backupFile = File('${testDir.path}/backup_no_tags.json');
    await backupFile.writeAsString(jsonEncode(backupMap));

    final result = await BackupService.importDataFromBackupFile(backupFile);

    expect(result, isTrue);
  });

  testlib.test(
      'importDataFromBackupFile handles empty record_tag_associations array',
      () async {
    // Create a backup file with empty record_tag_associations array
    final backupMap = {
      'categories': categories.map((c) => c!.toMap()).toList(),
      'records': records.map((r) => r!.toMap()).toList(),
      'recurrent_record_patterns':
          recurrentPatterns.map((rp) => rp.toMap()).toList(),
      'record_tag_associations': [], // Empty array
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'package_name': 'com.example.test',
      'version': '1.0.0',
      'database_version': '1',
    };

    final backupFile = File('${testDir.path}/backup_empty_tags.json');
    await backupFile.writeAsString(jsonEncode(backupMap));

    final result = await BackupService.importDataFromBackupFile(backupFile);

    expect(result, isTrue);
  });

  testlib.test('createJsonBackupFile includes user_currencies when set',
      () async {
    final prefs = await SharedPreferences.getInstance();
    const userCurrenciesJson =
        '{"mainCurrency":"EUR","currencies":[{"isoCode":"EUR","ratioToMain":1.0},{"isoCode":"USD","ratioToMain":0.92}]}';
    await prefs.setString(PreferencesKeys.userCurrencies, userCurrenciesJson);

    final backupFile = await BackupService.createJsonBackupFile(
      directoryPath: testDir.path,
    );

    expect(await backupFile.exists(), isTrue);
    final backupContent = await backupFile.readAsString();
    final backupMap = jsonDecode(backupContent);

    expect(backupMap, contains('user_currencies'));
    expect(backupMap['user_currencies'], userCurrenciesJson);

    await prefs.remove(PreferencesKeys.userCurrencies);
  });

  testlib.test('createJsonBackupFile omits user_currencies when not set',
      () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(PreferencesKeys.userCurrencies);

    final backupFile = await BackupService.createJsonBackupFile(
      directoryPath: testDir.path,
    );

    expect(await backupFile.exists(), isTrue);
    final backupContent = await backupFile.readAsString();
    final backupMap = jsonDecode(backupContent);

    expect(backupMap.containsKey('user_currencies'), isFalse);
  });

  testlib.test(
      'importDataFromBackupFile restores user_currencies to SharedPreferences',
      () async {
    const userCurrenciesJson =
        '{"mainCurrency":"USD","currencies":[{"isoCode":"USD","ratioToMain":1.0},{"isoCode":"EUR","ratioToMain":1.08}]}';

    final backupMap = {
      'categories': categories.map((c) => c!.toMap()).toList(),
      'records': records.map((r) => r!.toMap()).toList(),
      'recurrent_record_patterns':
          recurrentPatterns.map((rp) => rp.toMap()).toList(),
      'record_tag_associations':
          recordTagAssociations.map((a) => a.toMap()).toList(),
      'wallets': [],
      'user_currencies': userCurrenciesJson,
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'package_name': 'com.example.test',
      'version': '1.0.0',
      'database_version': '1',
    };

    final backupFile = File('${testDir.path}/backup_with_currencies.json');
    await backupFile.writeAsString(jsonEncode(backupMap));

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(PreferencesKeys.userCurrencies);

    final result = await BackupService.importDataFromBackupFile(backupFile);

    expect(result, isTrue);
    expect(prefs.getString(PreferencesKeys.userCurrencies), userCurrenciesJson);

    await prefs.remove(PreferencesKeys.userCurrencies);
  });

  testlib.test(
      'importDataFromBackupFile handles missing user_currencies gracefully',
      () async {
    final backupMap = {
      'categories': categories.map((c) => c!.toMap()).toList(),
      'records': records.map((r) => r!.toMap()).toList(),
      'recurrent_record_patterns':
          recurrentPatterns.map((rp) => rp.toMap()).toList(),
      'record_tag_associations':
          recordTagAssociations.map((a) => a.toMap()).toList(),
      'wallets': [],
      // No user_currencies key — simulating an old backup
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'package_name': 'com.example.test',
      'version': '1.0.0',
      'database_version': '1',
    };

    final backupFile = File('${testDir.path}/backup_no_currencies.json');
    await backupFile.writeAsString(jsonEncode(backupMap));

    final result = await BackupService.importDataFromBackupFile(backupFile);

    expect(result, isTrue);
  });

  testlib.test('user_currencies round-trip: backup and restore preserves data',
      () async {
    const userCurrenciesJson =
        '{"mainCurrency":"GBP","currencies":[{"isoCode":"GBP","ratioToMain":1.0},{"isoCode":"JPY","ratioToMain":190.5}]}';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(PreferencesKeys.userCurrencies, userCurrenciesJson);

    // Create backup
    final backupFile = await BackupService.createJsonBackupFile(
      directoryPath: testDir.path,
    );

    // Clear prefs to simulate fresh install
    await prefs.remove(PreferencesKeys.userCurrencies);
    expect(prefs.getString(PreferencesKeys.userCurrencies), isNull);

    // Restore
    final result = await BackupService.importDataFromBackupFile(backupFile);
    expect(result, isTrue);
    expect(prefs.getString(PreferencesKeys.userCurrencies), userCurrenciesJson);

    await prefs.remove(PreferencesKeys.userCurrencies);
  });

  testlib.test(
      'importDataFromBackupFile loads custom currencies into CurrencyInfo before restoring wallets',
      () async {
    const userCurrenciesJson =
        '{"mainCurrency":"USD","currencies":[{"isoCode":"USD","ratioToMain":1.0},{"isoCode":"MYC","ratioToMain":2.5,"customSymbol":"M","customName":"My Currency"}]}';

    final backupMap = {
      'categories': categories.map((c) => c!.toMap()).toList(),
      'records': records.map((r) => r!.toMap()).toList(),
      'recurrent_record_patterns':
          recurrentPatterns.map((rp) => rp.toMap()).toList(),
      'record_tag_associations':
          recordTagAssociations.map((a) => a.toMap()).toList(),
      'wallets': [],
      'user_currencies': userCurrenciesJson,
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'package_name': 'com.example.test',
      'version': '1.0.0',
      'database_version': '1',
    };

    final backupFile = File('${testDir.path}/backup_with_custom_currency.json');
    await backupFile.writeAsString(jsonEncode(backupMap));

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(PreferencesKeys.userCurrencies);

    final result = await BackupService.importDataFromBackupFile(backupFile);

    expect(result, isTrue);

    // Verify custom currency is loaded into CurrencyInfo
    final customCurrency = CurrencyInfo.byCode('MYC');
    expect(customCurrency, isNotNull);
    expect(customCurrency?.name, equals('My Currency'));
    expect(customCurrency?.symbol, equals('M'));

    // Verify regular currency still works
    final usd = CurrencyInfo.byCode('USD');
    expect(usd, isNotNull);

    await prefs.remove(PreferencesKeys.userCurrencies);
  });
}
