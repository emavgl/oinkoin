import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/models/backup.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/models/recurrent-period.dart';
import 'package:piggybank/models/recurrent-record-pattern.dart';
import 'package:piggybank/models/wallet.dart';
import 'package:piggybank/services/database/database-interface.dart';
import 'package:piggybank/services/database/sqlite-database.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timezone/data/latest_all.dart' as tz;

import '../helpers/test_database.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tz.initializeTimeZones();
    ServiceConfig.localTimezone = "Europe/Vienna";
  });

  setUp(() async {
    await TestDatabaseHelper.setupTestDatabase();
  });

  test('Backup.toMap includes wallets', () async {
    final category = Category('Food',
        categoryType: CategoryType.expense, color: Category.colors[0]);
    final wallet = Wallet('My Wallet', id: 1, initialAmount: 50.0);
    final record =
        Record(-10.0, 'Test', category, DateTime.now().toUtc(), walletId: 1);

    final backup = Backup(
      'com.example',
      '1.0.0',
      '18',
      [category],
      [record],
      [],
      [],
      wallets: [wallet],
    );

    final map = backup.toMap();
    expect(map.containsKey('wallets'), true);
    expect((map['wallets'] as List).length, 1);
    expect((map['wallets'] as List).first['name'], 'My Wallet');
  });

  test('Backup.fromMap restores wallets', () async {
    final category = Category('Food',
        categoryType: CategoryType.expense, color: Category.colors[0]);
    final wallet = Wallet('Restored Wallet', id: 1, initialAmount: 100.0);
    final record =
        Record(-15.0, 'Lunch', category, DateTime.now().toUtc(), walletId: 1);

    final backup = Backup(
      'com.example',
      '1.0.0',
      '18',
      [category],
      [record],
      [],
      [],
      wallets: [wallet],
    );

    final json = jsonEncode(backup.toMap());
    final restored = Backup.fromMap(jsonDecode(json));

    expect(restored.wallets.length, 1);
    expect(restored.wallets.first.name, 'Restored Wallet');
    expect(restored.wallets.first.initialAmount, 100.0);
    // wallet_id preserved in records
    expect(restored.records.first!.walletId, 1);
  });

  test('wallet_id remapping works during backup import', () async {
    DatabaseInterface db = ServiceConfig.database;
    SqliteDatabase sqliteDb = ServiceConfig.database as SqliteDatabase;

    // Delete the default wallet so we have a clean state
    await (await sqliteDb.database)!.delete('wallets');

    // Build a backup with wallet id=42 (an id that won't exist in the fresh DB)
    final category = Category('Food',
        categoryType: CategoryType.expense, color: Category.colors[0]);
    final backupWallet = Wallet('Import Wallet', id: 42, initialAmount: 0.0);
    final backupRecord =
        Record(-5.0, 'Test', category, DateTime.now().toUtc(), walletId: 42);

    final backup = Backup(
      'com.example',
      '1.0.0',
      '18',
      [category],
      [backupRecord],
      [],
      [],
      wallets: [backupWallet],
    );

    // Add category (ignore if already exists)
    try {
      await db.addCategory(category);
    } catch (_) {}

    // Simulate what BackupService.importDataFromBackupFile does:
    // Insert wallets and build id mapping
    final walletIdMap = <int, int>{};
    for (var w in backup.wallets) {
      final backupId = w.id;
      w.id = null;
      final newId = await db.addWallet(w);
      if (backupId != null) walletIdMap[backupId] = newId;
    }

    // Remap wallet_id in records
    for (var r in backup.records) {
      if (r == null) continue;
      if (r.walletId != null && walletIdMap.containsKey(r.walletId)) {
        r.walletId = walletIdMap[r.walletId];
      }
    }

    await db.addRecordsInBatch(backup.records);

    // Verify the imported wallet exists and records are linked
    final wallets = await db.getAllWallets();
    expect(wallets.any((w) => w.name == 'Import Wallet'), true);
    final importedWallet = wallets.firstWhere((w) => w.name == 'Import Wallet');

    final rawDb = (await sqliteDb.database)!;
    final linkedRecords = await rawDb.query('records',
        where: 'wallet_id = ?', whereArgs: [importedWallet.id]);
    expect(linkedRecords.isNotEmpty, true);
    // The old id 42 must NOT be used
    expect(importedWallet.id, isNot(42));
  });

  test(
      'backup import assigns fallback wallet_id to patterns whose wallet '
      'is not in the backup', () async {
    DatabaseInterface db = ServiceConfig.database;
    SqliteDatabase sqliteDb = ServiceConfig.database as SqliteDatabase;
    final rawDb = (await sqliteDb.database)!;

    // Clean slate
    await rawDb.delete('records');
    await rawDb.delete('recurrent_record_patterns');
    await rawDb.delete('wallets');

    // Build a backup with a wallet (id=10) and a pattern referencing a
    // *different* wallet (id=99) that does NOT exist in the backup.
    // After import the pattern should fall back to the default wallet.
    final category = Category('Food',
        categoryType: CategoryType.expense, color: Category.colors[0]);
    final backupWallet = Wallet('Only Wallet', id: 10, initialAmount: 0.0);

    final pattern = RecurrentRecordPattern(-50.0, 'Rent', category,
        DateTime.utc(2026, 1, 1), RecurrentPeriod.EveryMonth,
        id: 'pattern-missing-wallet', walletId: 99);

    final backup = Backup(
      'com.example',
      '1.0.0',
      '18',
      [category],
      [],
      [pattern],
      [],
      wallets: [backupWallet],
    );

    // Insert category
    try {
      await db.addCategory(category);
    } catch (_) {}

    // Simulate import logic:
    // 1. Insert wallets, build id map
    final walletIdMap = <int, int>{};
    for (var w in backup.wallets) {
      final backupId = w.id;
      w.id = null;
      final newId = await db.addWallet(w);
      if (backupId != null) walletIdMap[backupId] = newId;
    }

    // Mark the imported wallet as default so it can serve as fallback
    final importedId = walletIdMap[10]!;
    await db.setDefaultWallet(importedId);

    // 2. Get fallback wallet (default)
    final defaultWallet = await db.getDefaultWallet();
    final fallbackWalletId = defaultWallet?.id;

    // 3. Import patterns with wallet_id fallback
    for (var p in backup.recurrentRecordsPattern) {
      if (p.walletId != null && walletIdMap.containsKey(p.walletId)) {
        p.walletId = walletIdMap[p.walletId];
      } else if (fallbackWalletId != null) {
        // This is the fix: fall back to default wallet
        p.walletId = fallbackWalletId;
      }
      // Use raw insert to preserve the backup pattern's id
      // (addRecurrentRecordPattern would overwrite it with a new UUID).
      final map = p.toMap();
      await rawDb.insert('recurrent_record_patterns', map);
    }

    // Verify: pattern should have the default wallet's id, not 99
    final imported =
        await db.getRecurrentRecordPattern('pattern-missing-wallet');
    expect(imported, isNotNull);
    expect(imported!.walletId, isNotNull);
    expect(imported.walletId, isNot(99));
    expect(imported.walletId, fallbackWalletId);
  });

  test('Backup.toMap preserves isDefault and isPredefined fields', () async {
    final wallet =
        Wallet('Test Wallet', id: 1, isDefault: true, isPredefined: false);
    final backup = Backup(
      'com.example',
      '1.0.0',
      '18',
      [],
      [],
      [],
      [],
      wallets: [wallet],
    );

    final map = backup.toMap();
    final walletsList = map['wallets'] as List;
    expect(walletsList.first['is_default'], 1);
    expect(walletsList.first['is_predefined'], 0);
  });

  test('Backup.fromMap restores isDefault and isPredefined fields', () async {
    final wallet =
        Wallet('Restored Wallet', id: 1, isDefault: true, isPredefined: true);
    final backup = Backup(
      'com.example',
      '1.0.0',
      '18',
      [],
      [],
      [],
      [],
      wallets: [wallet],
    );

    final json = jsonEncode(backup.toMap());
    final restored = Backup.fromMap(jsonDecode(json));

    expect(restored.wallets.first.isDefault, true);
    expect(restored.wallets.first.isPredefined, true);
  });
}
