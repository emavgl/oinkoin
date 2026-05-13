import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/models/wallet.dart';
import 'package:piggybank/services/database/database-interface.dart';
import 'package:piggybank/services/database/sqlite-database.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/settings/constants/preferences-defaults-values.dart';
import 'package:piggybank/settings/constants/preferences-keys.dart';
import 'package:piggybank/settings/preferences-utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    SharedPreferences.setMockInitialValues({});
    await TestDatabaseHelper.setupTestDatabase();
  });

  Future<int> insertRecord(dynamic rawDb, int walletId, double value) async {
    return await rawDb.rawInsert("""
      INSERT INTO records (title, value, datetime, timezone, category_name, category_type, wallet_id)
      VALUES ('Record', ?, 1000000, 'UTC', 'Food', 0, ?)
    """, [value, walletId]);
  }

  // --- Preference tests ---

  group('restoreAmountOnDelete preference', () {
    test('default value is true', () {
      final defaultValue = PreferencesDefaultValues
          .defaultValues[PreferencesKeys.restoreAmountOnDelete];
      expect(defaultValue, true);
    });

    test('returns true when not explicitly set', () async {
      final prefs = await SharedPreferences.getInstance();
      final value = PreferencesUtils.getOrDefault<bool>(
          prefs, PreferencesKeys.restoreAmountOnDelete);
      expect(value, true);
    });

    test('returns false when set to false', () async {
      SharedPreferences.setMockInitialValues({
        PreferencesKeys.restoreAmountOnDelete: false,
      });
      final prefs = await SharedPreferences.getInstance();
      final value = PreferencesUtils.getOrDefault<bool>(
          prefs, PreferencesKeys.restoreAmountOnDelete);
      expect(value, false);
    });

    test('returns true when explicitly set to true', () async {
      SharedPreferences.setMockInitialValues({
        PreferencesKeys.restoreAmountOnDelete: true,
      });
      final prefs = await SharedPreferences.getInstance();
      final value = PreferencesUtils.getOrDefault<bool>(
          prefs, PreferencesKeys.restoreAmountOnDelete);
      expect(value, true);
    });
  });

  // --- DB-level behaviour tests ---

  group('restore amount on delete = true (default)', () {
    test('deleting an expense record increases wallet balance', () async {
      DatabaseInterface db = ServiceConfig.database;
      SqliteDatabase sqliteDb = db as SqliteDatabase;
      final rawDb = (await sqliteDb.database)!;

      final walletId = await db.addWallet(Wallet('Main', initialAmount: 100.0));
      final recordId = await insertRecord(rawDb, walletId, -30.0);

      // balance before = (-30) + 100 = 70
      final before = await db.getWalletById(walletId);
      expect(before!.balance, closeTo(70.0, 0.001));

      await db.deleteRecordById(recordId);
      // No initialAmount adjustment — money is restored.
      // balance after = 0 + 100 = 100
      final after = await db.getWalletById(walletId);
      expect(after!.balance, closeTo(100.0, 0.001));
    });

    test('deleting an income record decreases wallet balance', () async {
      DatabaseInterface db = ServiceConfig.database;
      SqliteDatabase sqliteDb = db as SqliteDatabase;
      final rawDb = (await sqliteDb.database)!;

      final walletId = await db.addWallet(Wallet('Main', initialAmount: 100.0));
      final recordId = await insertRecord(rawDb, walletId, 50.0);

      // balance before = 50 + 100 = 150
      final before = await db.getWalletById(walletId);
      expect(before!.balance, closeTo(150.0, 0.001));

      await db.deleteRecordById(recordId);
      // balance after = 0 + 100 = 100
      final after = await db.getWalletById(walletId);
      expect(after!.balance, closeTo(100.0, 0.001));
    });
  });

  group('restore amount on delete = false', () {
    // Simulates what edit-record-page does when the pref is false:
    //   1. deleteRecordById
    //   2. wallet.initialAmount += record.value
    //   3. updateWallet

    test('deleting an expense record keeps wallet balance unchanged', () async {
      DatabaseInterface db = ServiceConfig.database;
      SqliteDatabase sqliteDb = db as SqliteDatabase;
      final rawDb = (await sqliteDb.database)!;

      final walletId = await db.addWallet(Wallet('Main', initialAmount: 100.0));
      await insertRecord(rawDb, walletId, -30.0);

      // balance before = (-30) + 100 = 70
      final before = await db.getWalletById(walletId);
      expect(before!.balance, closeTo(70.0, 0.001));

      // Fetch record id and value before deletion
      final rows = await rawDb
          .rawQuery('SELECT id, value FROM records WHERE wallet_id = ?', [walletId]);
      final recordId = rows.first['id'] as int;
      final recordValue = (rows.first['value'] as num).toDouble();

      await db.deleteRecordById(recordId);

      // Compensate: initialAmount += recordValue  →  100 + (-30) = 70
      final wallet = await db.getWalletById(walletId);
      wallet!.initialAmount += recordValue;
      await db.updateWallet(walletId, wallet);

      // balance after = 0 + 70 = 70 (unchanged)
      final after = await db.getWalletById(walletId);
      expect(after!.balance, closeTo(70.0, 0.001));
    });

    test('deleting an income record keeps wallet balance unchanged', () async {
      DatabaseInterface db = ServiceConfig.database;
      SqliteDatabase sqliteDb = db as SqliteDatabase;
      final rawDb = (await sqliteDb.database)!;

      final walletId = await db.addWallet(Wallet('Main', initialAmount: 100.0));
      await insertRecord(rawDb, walletId, 50.0);

      // balance before = 50 + 100 = 150
      final before = await db.getWalletById(walletId);
      expect(before!.balance, closeTo(150.0, 0.001));

      final rows = await rawDb
          .rawQuery('SELECT id, value FROM records WHERE wallet_id = ?', [walletId]);
      final recordId = rows.first['id'] as int;
      final recordValue = (rows.first['value'] as num).toDouble();

      await db.deleteRecordById(recordId);

      final wallet = await db.getWalletById(walletId);
      wallet!.initialAmount += recordValue;
      await db.updateWallet(walletId, wallet);

      // balance after = 0 + 150 = 150 (unchanged)
      final after = await db.getWalletById(walletId);
      expect(after!.balance, closeTo(150.0, 0.001));
    });

    test('balance is unchanged after deleting multiple records', () async {
      DatabaseInterface db = ServiceConfig.database;
      SqliteDatabase sqliteDb = db as SqliteDatabase;
      final rawDb = (await sqliteDb.database)!;

      final walletId = await db.addWallet(Wallet('Main', initialAmount: 200.0));
      await insertRecord(rawDb, walletId, -40.0);
      await insertRecord(rawDb, walletId, -60.0);

      // balance before = (-40 + -60) + 200 = 100
      final before = await db.getWalletById(walletId);
      expect(before!.balance, closeTo(100.0, 0.001));

      final rows = await rawDb
          .rawQuery('SELECT id, value FROM records WHERE wallet_id = ?', [walletId]);

      for (final row in rows) {
        final recordId = row['id'] as int;
        final recordValue = (row['value'] as num).toDouble();
        await db.deleteRecordById(recordId);
        final wallet = await db.getWalletById(walletId);
        wallet!.initialAmount += recordValue;
        await db.updateWallet(walletId, wallet);
      }

      // balance after = 0 + (200 - 40 - 60) = 100 (unchanged)
      final after = await db.getWalletById(walletId);
      expect(after!.balance, closeTo(100.0, 0.001));
    });
  });

  group('restore vs no-restore produce different balances', () {
    test('same deletion with restore=true and restore=false gives different results',
        () async {
      DatabaseInterface db = ServiceConfig.database;
      SqliteDatabase sqliteDb = db as SqliteDatabase;
      final rawDb = (await sqliteDb.database)!;

      // Wallet A: restore = true
      final walletAId = await db.addWallet(Wallet('A', initialAmount: 100.0));
      await insertRecord(rawDb, walletAId, -30.0);

      // Wallet B: restore = false
      final walletBId = await db.addWallet(Wallet('B', initialAmount: 100.0));
      await insertRecord(rawDb, walletBId, -30.0);

      // Both start at 70
      final beforeA = await db.getWalletById(walletAId);
      final beforeB = await db.getWalletById(walletBId);
      expect(beforeA!.balance, closeTo(70.0, 0.001));
      expect(beforeB!.balance, closeTo(70.0, 0.001));

      // Delete from A — restore=true: just delete
      final rowsA = await rawDb.rawQuery(
          'SELECT id FROM records WHERE wallet_id = ?', [walletAId]);
      await db.deleteRecordById(rowsA.first['id'] as int);

      // Delete from B — restore=false: delete + adjust initialAmount
      final rowsB = await rawDb.rawQuery(
          'SELECT id, value FROM records WHERE wallet_id = ?', [walletBId]);
      final recordValue = (rowsB.first['value'] as num).toDouble();
      await db.deleteRecordById(rowsB.first['id'] as int);
      final walletB = await db.getWalletById(walletBId);
      walletB!.initialAmount += recordValue;
      await db.updateWallet(walletBId, walletB);

      final afterA = await db.getWalletById(walletAId);
      final afterB = await db.getWalletById(walletBId);

      // A restored to 100, B stayed at 70
      expect(afterA!.balance, closeTo(100.0, 0.001));
      expect(afterB!.balance, closeTo(70.0, 0.001));
    });
  });
}
