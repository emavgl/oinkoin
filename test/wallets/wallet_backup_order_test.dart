import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/models/wallet.dart';
import 'package:piggybank/services/backup-service.dart';
import 'package:piggybank/services/database/sqlite-database.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:test/test.dart' as testlib;
import 'package:timezone/data/latest_all.dart' as tz;

import '../helpers/test_database.dart';

/// Full BackupService round-trip coverage for wallet sort_order, mirroring
/// test/profiles/profile_backup_test.dart's "Backup preserves custom profile
/// order" group.
void main() {
  late Directory testDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tz.initializeTimeZones();
    ServiceConfig.localTimezone = 'Europe/Vienna';

    testDir = Directory('test/temp_wallets_backup');

    const packageChannel = MethodChannel(
      'dev.fluttercommunity.plus/package_info',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(packageChannel, (call) async {
          if (call.method == 'getAll') {
            return {
              'appName': 'TestApp',
              'packageName': 'com.test.app',
              'version': '1.0.0',
              'buildNumber': '1',
            };
          }
          return null;
        });

    const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (_) async => testDir);

    const prefsChannel = MethodChannel('plugins.flutter.io/shared_preferences');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(prefsChannel, (call) async {
          if (call.method == 'getAll') return <String, dynamic>{};
          if (call.method == 'setString') return true;
          if (call.method == 'getString') return null;
          if (call.method == 'remove') return true;
          if (call.method == 'clear') return true;
          return null;
        });
  });

  setUp(() async {
    await TestDatabaseHelper.setupTestDatabase();
    BackupService.database = ServiceConfig.database;

    if (await testDir.exists()) {
      await testDir.delete(recursive: true);
    }
    await testDir.create(recursive: true);
  });

  tearDownAll(() async {
    if (await testDir.exists()) {
      await testDir.delete(recursive: true);
    }
  });

  testlib.group('Backup preserves custom wallet order', () {
    testlib.test('backup JSON carries each wallet\'s sort_order', () async {
      final db = ServiceConfig.database;
      await db.addWallet(Wallet('Savings'));
      await db.addWallet(Wallet('Cash'));

      // Reorder: Cash, Default Wallet, Savings (drag-to-reorder result)
      final all = await db.getAllWallets();
      final cash = all.firstWhere((w) => w.name == 'Cash');
      final savings = all.firstWhere((w) => w.name == 'Savings');
      final defaultWallet = all.firstWhere((w) => w.isDefault);
      await db.resetWalletOrderIndexes([cash, defaultWallet, savings]);

      final backupFile = await BackupService.createJsonBackupFile(
        directoryPath: testDir.path,
      );
      final backupJson =
          jsonDecode(await backupFile.readAsString()) as Map<String, dynamic>;
      final backedUpWallets = backupJson['wallets'] as List;

      final byName = {
        for (final w in backedUpWallets) w['name'] as String: w['sort_order'],
      };
      expect(byName['Cash'], 0);
      expect(byName[defaultWallet.name], 1);
      expect(byName['Savings'], 2);
    });

    testlib.test(
      'restoring a backup preserves the custom wallet order, not creation order',
      () async {
        final db = ServiceConfig.database;
        await db.addWallet(Wallet('Savings'));
        await db.addWallet(Wallet('Cash'));

        final all = await db.getAllWallets();
        final cash = all.firstWhere((w) => w.name == 'Cash');
        final savings = all.firstWhere((w) => w.name == 'Savings');
        final defaultWallet = all.firstWhere((w) => w.isDefault);
        await db.resetWalletOrderIndexes([cash, defaultWallet, savings]);

        final backupFile = await BackupService.createJsonBackupFile(
          directoryPath: testDir.path,
        );

        // Restore into a fresh, empty DB so every backed-up wallet is
        // freshly inserted and getAllWallets reflects the restored order.
        await TestDatabaseHelper.setupTestDatabase();
        BackupService.database = ServiceConfig.database;
        final rawRestore =
            (await (ServiceConfig.database as SqliteDatabase).database)!;
        await rawRestore.rawDelete('DELETE FROM wallets');
        await rawRestore.rawDelete('DELETE FROM profiles');

        await BackupService.importDataFromBackupFile(backupFile);

        final restoredNames = (await ServiceConfig.database.getAllWallets())
            .map((w) => w.name)
            .toList();
        expect(
          restoredNames,
          ['Cash', defaultWallet.name, 'Savings'],
          reason: 'getAllWallets orders by sort_order, which must reflect '
              'the order the user had before backing up, not insertion order',
        );
      },
    );

    testlib.test(
      'restoring into a DB with no existing profile does not silently '
      'discard the default wallet\'s isPredefined flag',
      () async {
        // Regression: addProfile() auto-creates a placeholder "Default
        // Wallet" (isPredefined: true) for any freshly-inserted profile.
        // Before the fix, the wallet dedup logic mistook that placeholder
        // for genuine pre-existing device data and reused it as-is,
        // discarding the backup's real field values for the default wallet.
        final db = ServiceConfig.database;
        final all = await db.getAllWallets();
        final defaultWallet = all.firstWhere((w) => w.isDefault);
        final updated = Wallet(
          defaultWallet.name,
          id: defaultWallet.id,
          isDefault: true,
          isPredefined: false,
          sortOrder: defaultWallet.sortOrder,
        );
        await db.updateWallet(defaultWallet.id!, updated);

        final backupFile = await BackupService.createJsonBackupFile(
          directoryPath: testDir.path,
        );
        final backupJson =
            jsonDecode(await backupFile.readAsString()) as Map<String, dynamic>;
        final backedUpDefault = (backupJson['wallets'] as List)
            .firstWhere((w) => w['is_default'] == 1);
        expect(backedUpDefault['is_predefined'], 0,
            reason: 'sanity check on the backup itself before restoring');

        await TestDatabaseHelper.setupTestDatabase();
        BackupService.database = ServiceConfig.database;
        final rawRestore =
            (await (ServiceConfig.database as SqliteDatabase).database)!;
        await rawRestore.rawDelete('DELETE FROM wallets');
        await rawRestore.rawDelete('DELETE FROM profiles');

        await BackupService.importDataFromBackupFile(backupFile);

        final restoredDefault = (await ServiceConfig.database.getAllWallets())
            .firstWhere((w) => w.isDefault);
        expect(restoredDefault.isPredefined, isFalse);
      },
    );
  });
}
