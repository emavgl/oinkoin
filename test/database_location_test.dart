import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' show join;
import 'package:piggybank/models/record.dart';
import 'package:piggybank/models/wallet.dart';
import 'package:piggybank/services/database/database-interface.dart';
import 'package:piggybank/services/database/sqlite-database.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/settings/constants/preferences-keys.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'helpers/test_database.dart';

/// Custom database folder behavior: path resolution with fallback and
/// file relocation with journal sidecars. Desktop-only code paths run
/// natively on the Linux test host.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory sandbox;
  late Directory appDocs;

  setUpAll(() async {
    const MethodChannel pathProvider =
        MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProvider, (MethodCall call) async {
      return appDocs.path;
    });
  });

  setUp(() async {
    sandbox =
        await Directory.systemTemp.createTemp('oinkoin_db_location_test');
    appDocs = Directory(join(sandbox.path, 'app_docs'));
    await appDocs.create(recursive: true);
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    if (await sandbox.exists()) {
      await sandbox.delete(recursive: true);
    }
  });

  test('uses the platform default when no custom folder is set', () async {
    final dir = await SqliteDatabase.getDatabaseDirectory();

    expect(dir, join(appDocs.path, 'oinkoin'));
    expect(await Directory(dir).exists(), isTrue);
  });

  test('uses the custom folder when it exists', () async {
    final custom = Directory(join(sandbox.path, 'sync'));
    await custom.create();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(PreferencesKeys.databaseFolderPath, custom.path);

    expect(await SqliteDatabase.getDatabaseDirectory(), custom.path);
  });

  test('falls back to the default when the custom folder is gone', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      PreferencesKeys.databaseFolderPath,
      join(sandbox.path, 'deleted'),
    );

    expect(
      await SqliteDatabase.getDatabaseDirectory(),
      join(appDocs.path, 'oinkoin'),
    );
  });

  test('relocates the database file with its journal sidecars', () async {
    final source = Directory(join(appDocs.path, 'oinkoin'));
    await source.create(recursive: true);
    await File(join(source.path, SqliteDatabase.databaseFileName))
        .writeAsString('db-bytes');
    await File(join(source.path, '${SqliteDatabase.databaseFileName}-wal'))
        .writeAsString('wal-bytes');
    final target = join(sandbox.path, 'sync', 'nested');

    expect(await SqliteDatabase.relocateDatabase(target), isTrue);
    expect(
      await File(join(target, SqliteDatabase.databaseFileName)).readAsString(),
      'db-bytes',
    );
    expect(
      await File(join(target, '${SqliteDatabase.databaseFileName}-wal'))
          .readAsString(),
      'wal-bytes',
    );
    // The source is left untouched for the user to clean up.
    expect(
      await File(join(source.path, SqliteDatabase.databaseFileName)).exists(),
      isTrue,
    );
  });

  test('relocate reports false when there is no database file', () async {
    expect(
      await SqliteDatabase.relocateDatabase(join(sandbox.path, 'empty')),
      isFalse,
    );
  });

  group('write notifications', () {
    var notifications = 0;

    setUpAll(() async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      await TestDatabaseHelper.setupTestDatabase();
      SqliteDatabase.onDatabaseChanged = () => notifications++;
    });

    tearDownAll(() {
      SqliteDatabase.onDatabaseChanged = null;
    });

    test('record and wallet writes notify exactly once each', () async {
      DatabaseInterface db = ServiceConfig.database;

      final walletId = await db.addWallet(Wallet('Cash', initialAmount: 10.0));
      final recordId = await db.addRecord(
        Record(-5.0, 'groceries', null, DateTime.utc(2026, 9, 1)),
      );
      await db.deleteRecordById(recordId);
      await db.deleteWalletAndRecords(walletId);

      expect(notifications, 4);
    });
  });
}
