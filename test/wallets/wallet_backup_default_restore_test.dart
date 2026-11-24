import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/models/budget-type.dart';
import 'package:piggybank/models/budget.dart';
import 'package:piggybank/models/profile.dart';
import 'package:piggybank/models/recurrent-period.dart';
import 'package:piggybank/models/wallet.dart';
import 'package:piggybank/services/backup-service.dart';
import 'package:piggybank/services/database/sqlite-database.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:test/test.dart' as testlib;
import 'package:timezone/data/latest_all.dart' as tz;

import '../helpers/test_database.dart';
import 'package:uuid/uuid.dart';

/// Regression coverage for issue #445: restoring a backup into a fresh
/// install (whose database already contains the auto-created Default Profile
/// and Default Wallet) must replace the placeholder Default Wallet with the
/// backup's real data (name, color, currency, initial amount, predefined
/// flag) instead of silently discarding it.
void main() {
  late Directory testDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tz.initializeTimeZones();
    ServiceConfig.localTimezone = 'Europe/Vienna';

    testDir = Directory('test/temp_wallets_default_restore');

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

  testlib.group('Restore default wallet into a fresh install', () {
    testlib.test(
      'the auto-created placeholder Default Wallet is replaced by the '
      'backup\'s real name, color, currency, initial amount and flags',
      () async {
        final db = ServiceConfig.database;
        final rawDb = (await (db as SqliteDatabase).database)!;

        // The backed-up device's Default Wallet was used and customized:
        // renamed, colored, given a currency, a starting balance and the
        // predefined flag; one expense made its balance positive (1000-300).
        final defaultWallet = (await db.getAllWallets()).firstWhere(
          (w) => w.isDefault,
        );
        await db.updateWallet(
          defaultWallet.id!,
          Wallet(
            'Cartera',
            id: defaultWallet.id,
            color: const Color(0xFFFF0000),
            initialAmount: 1000.0,
            isDefault: true,
            isPredefined: true,
            currency: 'EUR',
          ),
        );
        await rawDb.rawInsert(
          "INSERT INTO records (id, title, value, datetime, timezone, category_name, category_type, wallet_id) "
          "VALUES ('${Uuid().v4()}', 'Groceries', -300.0, 1000000, 'UTC', 'House', 0, ?)",
          [defaultWallet.id],
        );

        final backupFile = await BackupService.createJsonBackupFile(
          directoryPath: testDir.path,
        );

        // Restore into a fresh install: the database already contains its
        // auto-created Default Profile and Default Wallet, nothing else.
        await TestDatabaseHelper.setupTestDatabase();
        BackupService.database = ServiceConfig.database;

        expect(
          await BackupService.importDataFromBackupFile(backupFile),
          isTrue,
        );

        final restored = (await ServiceConfig.database.getAllWallets())
            .firstWhere((w) => w.isDefault);
        expect(restored.name, 'Cartera');
        expect(restored.currency, 'EUR');
        expect(restored.initialAmount, closeTo(1000.0, 0.001));
        expect(restored.isPredefined, isTrue);
        expect(restored.color, const Color(0xFFFF0000));
        expect(
          restored.balance,
          closeTo(700.0, 0.001),
          reason: 'balance must include the restored initial amount',
        );
      },
    );

    testlib.test(
      'a Default Wallet with records already on the device is preserved',
      () async {
        final db = ServiceConfig.database;
        final rawDb = (await (db as SqliteDatabase).database)!;

        // Source device: customized Default Wallet with one expense.
        final sourceDefault = (await db.getAllWallets()).firstWhere(
          (w) => w.isDefault,
        );
        await db.updateWallet(
          sourceDefault.id!,
          Wallet(
            'Cartera',
            id: sourceDefault.id,
            initialAmount: 1000.0,
            isDefault: true,
            currency: 'EUR',
          ),
        );
        await rawDb.rawInsert(
          "INSERT INTO records (id, title, value, datetime, timezone, category_name, category_type, wallet_id) "
          "VALUES ('${Uuid().v4()}', 'Groceries', -300.0, 1000000, 'UTC', 'House', 0, ?)",
          [sourceDefault.id],
        );

        final backupFile = await BackupService.createJsonBackupFile(
          directoryPath: testDir.path,
        );

        // Destination device: genuine user data already on the Default
        // Wallet — its metadata must be kept when merging the backup.
        await TestDatabaseHelper.setupTestDatabase();
        BackupService.database = ServiceConfig.database;
        final destDb = ServiceConfig.database;
        final destRawDb = (await (destDb as SqliteDatabase).database)!;
        final destDefault = (await destDb.getAllWallets()).firstWhere(
          (w) => w.isDefault,
        );
        await destDb.updateWallet(
          destDefault.id!,
          Wallet(
            'Existing wallet',
            id: destDefault.id,
            profileId: destDefault.profileId,
            initialAmount: 50.0,
            isDefault: true,
            currency: 'USD',
          ),
        );
        await destRawDb.rawInsert(
          "INSERT INTO records (id, title, value, datetime, timezone, category_name, category_type, wallet_id, profile_id) "
          "VALUES ('${Uuid().v4()}', 'Existing expense', -20.0, 900000, 'UTC', 'House', 0, ?, ?)",
          [destDefault.id, destDefault.profileId],
        );

        expect(
          await BackupService.importDataFromBackupFile(backupFile),
          isTrue,
        );

        final restored = (await destDb.getAllWallets()).firstWhere(
          (w) => w.isDefault,
        );
        expect(
          restored.name,
          'Existing wallet',
          reason: 'pre-existing device data must not be overwritten',
        );
        expect(restored.currency, 'USD');
        expect(restored.initialAmount, closeTo(50.0, 0.001));
      },
    );

    testlib.test(
      'a backup Default Wallet is not merged into another profile\'s '
      'default wallet',
      () async {
        final db = ServiceConfig.database;
        final rawDb = (await (db as SqliteDatabase).database)!;

        // Source device: customized Default Wallet with one expense.
        final sourceDefault = (await db.getAllWallets()).firstWhere(
          (w) => w.isDefault,
        );
        await db.updateWallet(
          sourceDefault.id!,
          Wallet(
            'Cartera',
            id: sourceDefault.id,
            initialAmount: 1000.0,
            isDefault: true,
            currency: 'EUR',
          ),
        );
        await rawDb.rawInsert(
          "INSERT INTO records (id, title, value, datetime, timezone, category_name, category_type, wallet_id) "
          "VALUES ('${Uuid().v4()}', 'Groceries', -300.0, 1000000, 'UTC', 'House', 0, ?)",
          [sourceDefault.id],
        );

        final backupFile = await BackupService.createJsonBackupFile(
          directoryPath: testDir.path,
        );

        // Destination device with two profiles where the single global
        // default wallet (returned by getDefaultWallet) belongs to the
        // non-default profile - a state upgraded installs can reach.
        await TestDatabaseHelper.setupTestDatabase();
        BackupService.database = ServiceConfig.database;
        final destDb = ServiceConfig.database;
        final defaultProfileId = (await destDb.getDefaultProfile())!.id;
        final businessProfileId = await destDb.addProfile(Profile('Business'));
        final businessWallet =
            (await destDb.getAllWallets(profileId: businessProfileId)).first;
        await destDb.setDefaultWallet(businessWallet.id!);

        expect(
          await BackupService.importDataFromBackupFile(backupFile),
          isTrue,
        );

        // The backup's Default Wallet must be restored into its own profile
        // (the existing Default Profile), never into the business profile's
        // wallet.
        final restoredWallets = await destDb.getAllWallets();
        final cartera = restoredWallets.firstWhere(
          (w) => w.name == 'Cartera',
        );
        expect(cartera.profileId, defaultProfileId);
        expect(cartera.currency, 'EUR');
        expect(cartera.initialAmount, closeTo(1000.0, 0.001));
        expect(cartera.balance, closeTo(700.0, 0.001));

        final restoredRecord = (await destDb.getAllRecords()).firstWhere(
          (record) => record?.title == 'Groceries',
        );
        expect(restoredRecord!.walletId, cartera.id);

        final businessWalletAfterRestore =
            (await destDb.getAllWallets(profileId: businessProfileId)).first;
        expect(
          businessWalletAfterRestore.balance,
          closeTo(0.0, 0.001),
          reason: 'another profile\'s wallet must not receive the records',
        );
      },
    );
  });

  testlib.group('Placeholder detection considers every reference type', () {
    Future<File> createBackupWithCartera() async {
      final db = ServiceConfig.database;
      final rawDb = (await (db as SqliteDatabase).database)!;
      final sourceDefault = (await db.getAllWallets()).firstWhere(
        (w) => w.isDefault,
      );
      await db.updateWallet(
        sourceDefault.id!,
        Wallet(
          'Cartera',
          id: sourceDefault.id,
          profileId: sourceDefault.profileId,
          initialAmount: 1000.0,
          isDefault: true,
          currency: 'EUR',
        ),
      );
      await rawDb.rawInsert(
        "INSERT INTO records (id, title, value, datetime, timezone, category_name, category_type, wallet_id, profile_id) "
        "VALUES ('${Uuid().v4()}', 'Groceries', -300.0, 1000000, 'UTC', 'House', 0, ?, ?)",
        [sourceDefault.id, sourceDefault.profileId],
      );
      return BackupService.createJsonBackupFile(directoryPath: testDir.path);
    }

    Future<Wallet> prepareDestination() async {
      await TestDatabaseHelper.setupTestDatabase();
      BackupService.database = ServiceConfig.database;
      final db = ServiceConfig.database;
      final destDefault = (await db.getAllWallets()).firstWhere(
        (w) => w.isDefault,
      );
      await db.updateWallet(
        destDefault.id!,
        Wallet(
          'Existing wallet',
          id: destDefault.id,
          profileId: destDefault.profileId,
          isDefault: true,
          currency: 'USD',
        ),
      );
      return destDefault;
    }

    Future<void> expectDestinationPreserved() async {
      final restored = (await ServiceConfig.database.getAllWallets())
          .firstWhere((w) => w.isDefault);
      expect(
        restored.name,
        'Existing wallet',
        reason: 'a wallet referenced by device data must not be replaced',
      );
      expect(restored.currency, 'USD');
    }

    testlib.test('a wallet referenced only as a transfer destination is kept',
        () async {
      final backupFile = await createBackupWithCartera();

      final destDefault = await prepareDestination();
      final destDb = ServiceConfig.database;
      final destRawDb = (await (destDb as SqliteDatabase).database)!;
      final otherWalletId = await destDb.addWallet(
        Wallet('Other', profileId: destDefault.profileId),
      );
      await destRawDb.rawInsert(
        "INSERT INTO records (id, title, value, datetime, timezone, category_name, category_type, wallet_id, transfer_wallet_id, profile_id) "
        "VALUES ('${Uuid().v4()}', 'Transfer', -10.0, 900000, 'UTC', 'House', 0, ?, ?, ?)",
        [otherWalletId, destDefault.id, destDefault.profileId],
      );

      expect(await BackupService.importDataFromBackupFile(backupFile), isTrue);
      await expectDestinationPreserved();
    });

    testlib.test('a wallet referenced only by a recurrent pattern is kept',
        () async {
      final backupFile = await createBackupWithCartera();

      final destDefault = await prepareDestination();
      final destRawDb =
          (await (ServiceConfig.database as SqliteDatabase).database)!;
      await destRawDb.rawInsert(
        "INSERT INTO recurrent_record_patterns (id, datetime, timezone, value, title, category_name, category_type, recurrent_period, wallet_id, profile_id) "
        "VALUES (?, 900000, 'UTC', -10.0, 'Rent', 'House', 0, ?, ?, ?)",
        [
          'pattern-1',
          RecurrentPeriod.EveryMonth.index,
          destDefault.id,
          destDefault.profileId,
        ],
      );

      expect(await BackupService.importDataFromBackupFile(backupFile), isTrue);
      await expectDestinationPreserved();
    });

    testlib.test('a wallet referenced only by a budget is kept', () async {
      final backupFile = await createBackupWithCartera();

      final destDefault = await prepareDestination();
      await ServiceConfig.database.addBudget(Budget(
        name: 'Test budget',
        targetAmount: 100.0,
        budgetType: BudgetType.expense,
        startDate: DateTime(2024, 1, 1),
        walletIds: [destDefault.id!],
        profileId: destDefault.profileId,
      ));

      expect(await BackupService.importDataFromBackupFile(backupFile), isTrue);
      await expectDestinationPreserved();
    });

    testlib.test(
      'a customized but unreferenced default wallet is replaced by the '
      'backup\'s wallet data',
      () async {
        final backupFile = await createBackupWithCartera();

        final destDefault = await prepareDestination();
        final destDb = ServiceConfig.database;
        await destDb.updateWallet(
          destDefault.id!,
          Wallet(
            'Renamed wallet',
            id: destDefault.id,
            profileId: destDefault.profileId,
            initialAmount: 50.0,
            isDefault: true,
            currency: 'USD',
          ),
        );

        expect(await BackupService.importDataFromBackupFile(backupFile), isTrue);

        final restored = (await ServiceConfig.database.getAllWallets())
            .firstWhere((w) => w.isDefault);
        expect(
          restored.name,
          'Cartera',
          reason: 'without device data the wallet counts as a placeholder',
        );
        expect(restored.currency, 'EUR');
        expect(restored.initialAmount, closeTo(1000.0, 0.001));
      },
    );
  });
}
