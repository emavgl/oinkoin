import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/models/recurrent-period.dart';
import 'package:piggybank/models/recurrent-record-pattern.dart';
import 'package:piggybank/models/wallet.dart';
import 'package:piggybank/services/backup-service.dart';
import 'package:piggybank/services/recurrent-record-service.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:test/test.dart' as testlib;
import 'package:timezone/data/latest_all.dart' as tz;

import '../helpers/test_database.dart';

void main() {
  late Directory testDir;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tz.initializeTimeZones();
    ServiceConfig.localTimezone = 'UTC';

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
    testDir = Directory('test/temp_null_category_backup');
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

  testlib.test(
      'real SQLite backup and restore preserves uncategorized transfers and recurrent patterns',
      () async {
    final sourceDatabase = ServiceConfig.database;
    final category = Category('Round-trip category');
    await sourceDatabase.addCategory(category);

    final originId = await sourceDatabase.addWallet(Wallet('Round-trip origin'));
    final destinationId =
        await sourceDatabase.addWallet(Wallet('Round-trip destination'));

    await sourceDatabase.addRecord(Record(
      -42.5,
      'Uncategorized transfer',
      null,
      DateTime.utc(2026, 1, 2, 10, 30),
      walletId: originId,
      transferWalletId: destinationId,
      transferValue: 42.5,
    ));
    await sourceDatabase.addRecord(Record(
      -3.5,
      'Categorized record',
      category,
      DateTime.utc(2026, 1, 3, 10, 30),
      walletId: originId,
    ));

    final recurrentPattern = RecurrentRecordPattern(
      -17.5,
      'Uncategorized recurrent transfer',
      null,
      DateTime.utc(2026, 2, 1, 9),
      RecurrentPeriod.EveryMonth,
      id: 'uncategorized-round-trip-pattern',
      walletId: originId,
      transferWalletId: destinationId,
      transferValue: 17.5,
    );
    await sourceDatabase.addRecurrentRecordPattern(recurrentPattern);

    final backupFile = await BackupService.createJsonBackupFile(
      directoryPath: testDir.path,
      backupFileName: 'sqlite_round_trip.obackup.json',
    );

    // Restore into a fresh in-memory database rather than the source database.
    await TestDatabaseHelper.setupTestDatabase();
    final restoredDatabase = ServiceConfig.database;
    BackupService.database = restoredDatabase;

    expect(await BackupService.importDataFromBackupFile(backupFile), isTrue);

    final restoredOrigin = (await restoredDatabase.getAllWallets())
        .firstWhere((wallet) => wallet.name == 'Round-trip origin');
    final restoredDestination = (await restoredDatabase.getAllWallets())
        .firstWhere((wallet) => wallet.name == 'Round-trip destination');

    final restoredRecords = await restoredDatabase.getAllRecords();
    final restoredTransfer = restoredRecords
        .where((record) => record?.title == 'Uncategorized transfer')
        .single!;
    final restoredCategorizedRecord = restoredRecords
        .where((record) => record?.title == 'Categorized record')
        .single!;

    expect(restoredTransfer.category, isNull);
    expect(restoredTransfer.isTransfer, isTrue);
    expect(restoredTransfer.value, -42.5);
    expect(restoredTransfer.transferValue, 42.5);
    expect(restoredTransfer.walletId, restoredOrigin.id);
    expect(restoredTransfer.transferWalletId, restoredDestination.id);
    expect(restoredCategorizedRecord.category?.name, 'Round-trip category');

    final restoredPattern = (await restoredDatabase.getRecurrentRecordPatterns())
        .singleWhere((pattern) => pattern.id == recurrentPattern.id);
    expect(restoredPattern.category, isNull);
    expect(restoredPattern.walletId, restoredOrigin.id);
    expect(restoredPattern.transferWalletId, restoredDestination.id);
    expect(restoredPattern.transferValue, 17.5);

    // Recurrent generation must also preserve the absent category and transfer
    // fields, not only database serialization.
    final generatedRecords = RecurrentRecordService()
        .generateRecurrentRecordsFromDateTime(
            restoredPattern, DateTime.utc(2026, 3, 1, 9));
    expect(generatedRecords, isNotEmpty);
    for (final generatedRecord in generatedRecords) {
      expect(generatedRecord.category, isNull);
      expect(generatedRecord.isTransfer, isTrue);
      expect(generatedRecord.walletId, restoredOrigin.id);
      expect(generatedRecord.transferWalletId, restoredDestination.id);
      expect(generatedRecord.transferValue, 17.5);
    }
  });

  testlib.test(
      'legacy backup without wallets, profiles, or tag associations restores inline tags',
      () async {
    final database = ServiceConfig.database;
    final category = Category('Legacy Food');
    final legacyBackup = <String, dynamic>{
      'version': '2',
      'app_name': 'piggybankpro',
      'app_version': '1.4.1',
      'export_date': '2020-01-01T00:00:00.000000',
      'categories': [category.toMap()],
      'records': [
        {
          'id': 41,
          'title': 'Legacy lunch',
          'value': -12.0,
          'datetime': 1577874600000,
          'timezone': 'UTC',
          'category_name': 'Legacy Food',
          'category_type': 0,
          'tags': 'legacy-tag,legacy-two',
        },
      ],
      'recurrent_record_patterns': [
        {
          'id': 'legacy-pattern',
          'title': 'Legacy recurring lunch',
          'value': -12.0,
          'datetime': 1577874600000,
          'timezone': 'UTC',
          'category_name': 'Legacy Food',
          'category_type': 0,
          'recurrent_period': RecurrentPeriod.EveryMonth.index,
          'tags': 'legacy-pattern-tag',
        },
      ],
      'created_at': 1577874600000,
      // wallets, profiles, record_tag_associations, and user_currencies are
      // intentionally absent: these fields did not exist in older backups.
    };
    final file = File('${testDir.path}/legacy_backup.json');
    await file.writeAsString(jsonEncode(legacyBackup));

    expect(await BackupService.importDataFromBackupFile(file), isTrue);

    final defaultWalletId = (await database.getDefaultWallet())!.id;
    final restoredRecord = (await database.getAllRecords())
        .singleWhere((record) => record?.title == 'Legacy lunch')!;
    expect(restoredRecord.category?.name, 'Legacy Food');
    expect(restoredRecord.tags, containsAll(['legacy-tag', 'legacy-two']));
    expect(restoredRecord.walletId, defaultWalletId);

    final restoredPattern = (await database.getRecurrentRecordPatterns())
        .singleWhere((pattern) => pattern.id == 'legacy-pattern');
    expect(restoredPattern.category?.name, 'Legacy Food');
    expect(restoredPattern.tags, contains('legacy-pattern-tag'));
    expect(restoredPattern.walletId, defaultWalletId);
  });

  testlib.test(
      'very old backup without recurrent_record_patterns remains importable',
      () async {
    final database = ServiceConfig.database;
    final category = Category('Very Old Food');
    final legacyBackup = <String, dynamic>{
      'version': '1',
      'app_name': 'piggybank',
      'app_version': '0.9.0',
      'export_date': '2018-01-01T00:00:00.000000',
      'categories': [category.toMap()],
      'records': [
        {
          'id': 7,
          'title': 'Very old record',
          'value': -4.0,
          'datetime': 1514806200000,
          'timezone': 'UTC',
          'category_name': 'Very Old Food',
          'category_type': 0,
        },
      ],
      // The recurrent_record_patterns key is intentionally absent.
    };
    final file = File('${testDir.path}/very_old_backup.json');
    await file.writeAsString(jsonEncode(legacyBackup));

    expect(await BackupService.importDataFromBackupFile(file), isTrue);
    expect((await database.getAllRecords())
        .singleWhere((record) => record?.title == 'Very old record')
        ?.category
        ?.name, 'Very Old Food');
    expect(await database.getRecurrentRecordPatterns(), isEmpty);
  });
}
