import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/services/backup-service.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/settings/constants/preferences-keys.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:test/test.dart' as testlib;

import '../helpers/test_database.dart';

void main() {
  late Directory testDir;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    testDir = Directory('test/temp_preferences_backup');

    const packageInfoChannel =
        MethodChannel('dev.fluttercommunity.plus/package_info');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(packageInfoChannel, (call) async {
      if (call.method == 'getAll') {
        return <String, dynamic>{
          'appName': 'test',
          'packageName': 'com.example.oinkoin',
          'version': '1.0.0',
          'buildNumber': '1',
        };
      }
      return null;
    });

    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  setUp(() async {
    if (await testDir.exists()) {
      await testDir.delete(recursive: true);
    }
    await testDir.create(recursive: true);
    await TestDatabaseHelper.setupTestDatabase();
    BackupService.database = ServiceConfig.database;
  });

  tearDownAll(() async {
    if (await testDir.exists()) {
      await testDir.delete(recursive: true);
    }
  });

  testlib.test('backup includes portable preferences and restore applies them',
      () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(PreferencesKeys.themeColor, 2);
    await prefs.setBool(PreferencesKeys.showWalletBarOnHomepage, false);
    await prefs.setString(PreferencesKeys.backupPassword, 'must-not-copy');

    final backupFile = await BackupService.createJsonBackupFile(
      directoryPath: testDir.path,
      backupFileName: 'preferences.obackup.json',
    );
    final backupMap = jsonDecode(await backupFile.readAsString())
        as Map<String, dynamic>;
    final exported = backupMap['preferences'] as Map<String, dynamic>;

    expect(exported[PreferencesKeys.themeColor], 2);
    expect(exported[PreferencesKeys.showWalletBarOnHomepage], isFalse);
    expect(exported.containsKey(PreferencesKeys.backupPassword), isFalse);

    await prefs.remove(PreferencesKeys.themeColor);
    await prefs.remove(PreferencesKeys.showWalletBarOnHomepage);
    expect(await BackupService.importDataFromBackupFile(backupFile), isTrue);

    expect(prefs.getInt(PreferencesKeys.themeColor), 2);
    expect(prefs.getBool(PreferencesKeys.showWalletBarOnHomepage), isFalse);
    expect(prefs.containsKey(PreferencesKeys.backupPassword), isTrue);
  });

  testlib.test(
      'invalid and obsolete preference entries do not abort database restore',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final backupFile = await BackupService.createJsonBackupFile(
      directoryPath: testDir.path,
      backupFileName: 'mismatched_preferences.obackup.json',
    );
    final backupMap = jsonDecode(await backupFile.readAsString())
        as Map<String, dynamic>;
    backupMap['preferences'] = {
      PreferencesKeys.themeColor: 1,
      PreferencesKeys.walletBalanceMode: 'removed-value-type',
      PreferencesKeys.homepageTimeInterval: 999,
      'renamed_or_removed_preference': true,
      PreferencesKeys.showFutureRecords: false,
    };
    await backupFile.writeAsString(jsonEncode(backupMap));

    expect(await BackupService.importDataFromBackupFile(backupFile), isTrue);
    expect(prefs.getInt(PreferencesKeys.themeColor), 1);
    expect(prefs.getBool(PreferencesKeys.showFutureRecords), isFalse);
    expect(prefs.containsKey(PreferencesKeys.walletBalanceMode), isFalse);
    expect(prefs.containsKey(PreferencesKeys.homepageTimeInterval), isFalse);
    expect(prefs.containsKey('renamed_or_removed_preference'), isFalse);
  });

  testlib.test(
      'malformed legacy user currencies do not abort the database restore',
      () async {
    final backupFile = await BackupService.createJsonBackupFile(
      directoryPath: testDir.path,
      backupFileName: 'malformed_legacy_currencies.obackup.json',
    );
    final backupMap = jsonDecode(await backupFile.readAsString())
        as Map<String, dynamic>;
    backupMap['user_currencies'] = '{not valid json';
    backupMap.remove('preferences');
    await backupFile.writeAsString(jsonEncode(backupMap));

    expect(await BackupService.importDataFromBackupFile(backupFile), isTrue);
  });
}
