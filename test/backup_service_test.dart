import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mockito/annotations.dart';
import 'package:piggybank/models/backup.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/models/recurrent-record-pattern.dart';
import 'package:piggybank/services/backup-service.dart';
import 'package:piggybank/services/database/database-interface.dart';
import 'package:test/test.dart' as testlib;
import 'package:mockito/mockito.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

// Assuming that you have generated a mock using `mockito`
import 'backup_service_test.mocks.dart';

@GenerateMocks([DatabaseInterface])
void main() {
  late MockDatabaseInterface mockDatabase;
  late Directory testDir;

  late List<Category?> categories;
  late List<Record?> records;
  late List<RecurrentRecordPattern> recurrentPatterns;

  setUpAll(() async {
    DartPluginRegistrant.ensureInitialized();
    TestWidgetsFlutterBinding.ensureInitialized();
    testDir = Directory("oinkoindata");
    // expose path_provider
    const MethodChannel channel =
    MethodChannel('dev.fluttercommunity.plus/package_info');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      if (methodCall.method == 'getAll') {
        return <String, dynamic>{
          'appName': 'ABC',  // <--- set initial values here
          'packageName': 'A.B.C',  // <--- set initial values here
          'version': '1.0.0',  // <--- set initial values here
          'buildNumber': '67'  // <--- set initial values here
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

  testlib.setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    mockDatabase = MockDatabaseInterface();


    // Mock data
    categories =  [
      Category("Rent",
          iconCodePoint: FontAwesomeIcons.home.codePoint,
          categoryType: CategoryType.expense),
      Category("Food",
          iconCodePoint: FontAwesomeIcons.hamburger.codePoint,
          categoryType: CategoryType.expense),
      Category("Salary",
          iconCodePoint: FontAwesomeIcons.wallet.codePoint,
          categoryType: CategoryType.income)
    ];
    records = [
      Record(-300, "April Rent", categories[0],
          DateTime.parse("2020-04-02 10:30:00"),
          id: 1),
      Record(
          -300, "May Rent", categories[0], DateTime.parse("2020-05-01 10:30:00"),
          id: 2),
      Record(-30, "Pizza", categories[1], DateTime.parse("2020-05-01 09:30:00"),
          id: 3),
      Record(
          1700, "Salary", categories[2], DateTime.parse("2020-05-02 09:30:00"),
          id: 4),
      Record(-30, "Restaurant", categories[1],
          DateTime.parse("2020-05-02 10:30:00"),
          id: 5),
      Record(-60.5, "Groceries", categories[1],
          DateTime.parse("2020-05-03 10:30:00"),
          id: 6),
    ];
    recurrentPatterns = [];

    when(mockDatabase.getAllRecords()).thenAnswer((_) async => records);
    when(mockDatabase.getAllCategories()).thenAnswer((_) async => categories);
    when(mockDatabase.getRecurrentRecordPatterns()).thenAnswer((_) async => recurrentPatterns);

    // Swap database
    BackupService.database = mockDatabase;
  });

  group('BackupService', () {
    test('createJsonBackupFile creates an encrypted backup file', () async {
      var encryptionPassword = 'testpassword';

      // Act
      var backupFile = await BackupService.createJsonBackupFile(
        directoryPath: testDir.path,
        encryptionPassword: encryptionPassword,
      );

      // Assert
      expect(await backupFile.exists(), true);

      var fileContent = await backupFile.readAsString();

      // Verify that the content is not plain JSON due to encryption
      expect(() {
        jsonDecode(fileContent);
      }, throwsFormatException);

      // Decrypt the file content manually to verify encryption
      final key = encrypt.Key.fromUtf8(encryptionPassword.padRight(32, '*').substring(0, 32));
      final iv = encrypt.IV.fromLength(16);
      final encrypter = encrypt.Encrypter(encrypt.AES(key));

      // Try to decrypt the content and verify it's a valid JSON
      final decrypted = encrypter.decrypt64(fileContent, iv: iv);
      var backupMap = jsonDecode(decrypted);

      expect(backupMap, isA<Map>()); // Check if the content is a valid JSON map
    });

    test('importDataFromBackupFile imports data from an encrypted backup file', () async {
      // Arrange
      var encryptionPassword = 'testpassword';
      var backup = Backup([], [], []); // Empty backup for simplicity
      var backupJsonStr = jsonEncode(backup.toMap());

      // Encrypt the JSON string to simulate an encrypted backup file
      final key = encrypt.Key.fromUtf8(encryptionPassword.padRight(32, '*').substring(0, 32));
      final iv = encrypt.IV.fromLength(16);
      final encrypter = encrypt.Encrypter(encrypt.AES(key));
      final encrypted = encrypter.encrypt(backupJsonStr, iv: iv);

      var backupFile = File('${testDir.path}/test_backup.json');
      await backupFile.writeAsString(encrypted.base64);

      // Act
      var result = await BackupService.importDataFromBackupFile(
        backupFile,
        encryptionPassword: encryptionPassword,
      );

      // Assert
      expect(result, true);

      // Verify that the import functions were called as expected
      verify(mockDatabase.addCategory(any)).called(0); // Expected times based on your mock data
      verify(mockDatabase.addRecord(any)).called(0);
      verify(mockDatabase.addRecurrentRecordPattern(any)).called(0);
    });

    test('importDataFromBackupFile fails with incorrect decryption password', () async {
      // Arrange
      var correctPassword = 'correctpassword';
      var incorrectPassword = 'wrongpassword';
      var backup = Backup([], [], []);
      var backupJsonStr = jsonEncode(backup.toMap());

      final key = encrypt.Key.fromUtf8(correctPassword.padRight(32, '*').substring(0, 32));
      final iv = encrypt.IV.fromLength(16);
      final encrypter = encrypt.Encrypter(encrypt.AES(key));
      final encrypted = encrypter.encrypt(backupJsonStr, iv: iv);

      var backupFile = File('${testDir.path}/test_backup.json');
      await backupFile.writeAsString(encrypted.base64);

      // Act
      var result = await BackupService.importDataFromBackupFile(
        backupFile,
        encryptionPassword: incorrectPassword,
      );

      // Assert
      expect(result, false); // Should fail due to incorrect password
    });
  });
}