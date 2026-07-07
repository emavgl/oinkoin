import 'package:flutter_test/flutter_test.dart';
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

  // Fixed UTC millis reference points used across tests.
  final before = DateTime.utc(2023, 1, 10);
  final cutoff = DateTime.utc(2023, 1, 15);
  final after = DateTime.utc(2023, 1, 20);

  Future<void> _insertRecord(
      dynamic rawDb, int walletId, double value, DateTime datetime) async {
    await rawDb.rawInsert("""
      INSERT INTO records (title, value, datetime, timezone, category_name, category_type, wallet_id)
      VALUES ('Record', ?, ?, 'UTC', 'House', 0, ?)
    """, [value, datetime.millisecondsSinceEpoch, walletId]);
  }

  Future<void> _insertTransfer(dynamic rawDb, int srcWalletId,
      int destWalletId, double value, double? transferValue, DateTime datetime) async {
    await rawDb.rawInsert(
      """
      INSERT INTO records (title, value, datetime, timezone, category_name, category_type, wallet_id, transfer_wallet_id, transfer_value)
      VALUES ('Transfer', ?, ?, 'UTC', 'House', 0, ?, ?, ?)
    """,
      [value, datetime.millisecondsSinceEpoch, srcWalletId, destWalletId, transferValue],
    );
  }

  test('excludes records dated after the as-of cutoff', () async {
    DatabaseInterface db = ServiceConfig.database;
    SqliteDatabase sqliteDb = ServiceConfig.database as SqliteDatabase;
    final rawDb = (await sqliteDb.database)!;

    final walletId = await db.addWallet(Wallet('Test', initialAmount: 100.0));
    await _insertRecord(rawDb, walletId, -30.0, before);
    await _insertRecord(rawDb, walletId, 1000.0, after);

    final wallets = await db.getWalletsBalanceAsOf(cutoff);
    final wallet = wallets.firstWhere((w) => w.id == walletId);
    // balance = initial(100) + before(-30) = 70, excludes the after(1000) record
    expect(wallet.balance, closeTo(70.0, 0.001));
  });

  test('includes a record dated exactly at the cutoff (inclusive boundary)',
      () async {
    DatabaseInterface db = ServiceConfig.database;
    SqliteDatabase sqliteDb = ServiceConfig.database as SqliteDatabase;
    final rawDb = (await sqliteDb.database)!;

    final walletId = await db.addWallet(Wallet('Test', initialAmount: 0.0));
    await _insertRecord(rawDb, walletId, 42.0, cutoff);

    final wallets = await db.getWalletsBalanceAsOf(cutoff);
    final wallet = wallets.firstWhere((w) => w.id == walletId);
    expect(wallet.balance, closeTo(42.0, 0.001));
  });

  test('balance with no records before the cutoff equals initial_amount',
      () async {
    DatabaseInterface db = ServiceConfig.database;
    SqliteDatabase sqliteDb = ServiceConfig.database as SqliteDatabase;
    final rawDb = (await sqliteDb.database)!;

    final walletId =
        await db.addWallet(Wallet('Empty', initialAmount: 500.0));
    await _insertRecord(rawDb, walletId, -10.0, after);

    final wallets = await db.getWalletsBalanceAsOf(cutoff);
    final wallet = wallets.firstWhere((w) => w.id == walletId);
    expect(wallet.balance, closeTo(500.0, 0.001));
  });

  test('getWalletsBalanceAsOf computes each wallet independently', () async {
    DatabaseInterface db = ServiceConfig.database;
    SqliteDatabase sqliteDb = ServiceConfig.database as SqliteDatabase;
    final rawDb = (await sqliteDb.database)!;

    final id1 = await db.addWallet(Wallet('W1', initialAmount: 200.0));
    final id2 = await db.addWallet(Wallet('W2', initialAmount: 0.0));

    await _insertRecord(rawDb, id1, -50.0, before);
    await _insertRecord(rawDb, id1, -999.0, after);
    await _insertRecord(rawDb, id2, 300.0, before);

    final wallets = await db.getWalletsBalanceAsOf(cutoff);
    final w1 = wallets.firstWhere((w) => w.id == id1);
    final w2 = wallets.firstWhere((w) => w.id == id2);

    expect(w1.balance, closeTo(150.0, 0.001)); // -50 + 200, excludes -999
    expect(w2.balance, closeTo(300.0, 0.001)); // 300 + 0
  });

  group('transfers under an as-of cutoff', () {
    test('a transfer dated after the cutoff affects neither wallet',
        () async {
      DatabaseInterface db = ServiceConfig.database;
      SqliteDatabase sqliteDb = ServiceConfig.database as SqliteDatabase;
      final rawDb = (await sqliteDb.database)!;

      final srcId =
          await db.addWallet(Wallet('Src', initialAmount: 1000.0));
      final destId = await db.addWallet(Wallet('Dest', initialAmount: 0.0));

      await _insertTransfer(rawDb, srcId, destId, -200.0, null, after);

      final wallets = await db.getWalletsBalanceAsOf(cutoff);
      final src = wallets.firstWhere((w) => w.id == srcId);
      final dest = wallets.firstWhere((w) => w.id == destId);

      expect(src.balance, closeTo(1000.0, 0.001));
      expect(dest.balance, closeTo(0.0, 0.001));
    });

    test('a transfer dated before the cutoff moves both sides atomically',
        () async {
      DatabaseInterface db = ServiceConfig.database;
      SqliteDatabase sqliteDb = ServiceConfig.database as SqliteDatabase;
      final rawDb = (await sqliteDb.database)!;

      final srcId =
          await db.addWallet(Wallet('Src', initialAmount: 1000.0));
      final destId = await db.addWallet(Wallet('Dest', initialAmount: 0.0));

      await _insertTransfer(rawDb, srcId, destId, -200.0, null, before);

      final wallets = await db.getWalletsBalanceAsOf(cutoff);
      final src = wallets.firstWhere((w) => w.id == srcId);
      final dest = wallets.firstWhere((w) => w.id == destId);

      expect(src.balance, closeTo(800.0, 0.001)); // 1000 - 200
      expect(dest.balance, closeTo(200.0, 0.001)); // falls back to abs(value)
    });

    test(
        'cross-currency transfer_value is respected on the destination side, still bounded by cutoff',
        () async {
      DatabaseInterface db = ServiceConfig.database;
      SqliteDatabase sqliteDb = ServiceConfig.database as SqliteDatabase;
      final rawDb = (await sqliteDb.database)!;

      final usdWallet = await db
          .addWallet(Wallet('USD', currency: 'USD', initialAmount: 0));
      final eurWallet = await db
          .addWallet(Wallet('EUR', currency: 'EUR', initialAmount: 0));

      // Before the cutoff: should count.
      await _insertTransfer(rawDb, usdWallet, eurWallet, -100.0, 92.0, before);
      // After the cutoff: should not count.
      await _insertTransfer(rawDb, usdWallet, eurWallet, -50.0, 46.0, after);

      final wallets = await db.getWalletsBalanceAsOf(cutoff);
      final usd = wallets.firstWhere((w) => w.id == usdWallet);
      final eur = wallets.firstWhere((w) => w.id == eurWallet);

      expect(usd.balance, closeTo(-100.0, 0.001));
      expect(eur.balance, closeTo(92.0, 0.001));
    });
  });
}
