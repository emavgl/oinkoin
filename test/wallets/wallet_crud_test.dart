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

  test('addWallet creates a wallet with correct fields', () async {
    DatabaseInterface db = ServiceConfig.database;
    final wallet = Wallet('Savings',
        color: null, initialAmount: 100.0, isDefault: false, sortOrder: 1);

    final id = await db.addWallet(wallet);
    expect(id, greaterThan(0));

    final retrieved = await db.getWalletById(id);
    expect(retrieved, isNotNull);
    expect(retrieved!.name, 'Savings');
    expect(retrieved.initialAmount, 100.0);
    expect(retrieved.isDefault, false);
    expect(retrieved.sortOrder, 1);
  });

  test('updateWallet modifies an existing wallet', () async {
    DatabaseInterface db = ServiceConfig.database;
    final wallet = Wallet('Cash', initialAmount: 50.0);
    final id = await db.addWallet(wallet);

    wallet.name = 'Cash Updated';
    wallet.initialAmount = 200.0;
    await db.updateWallet(id, wallet);

    final retrieved = await db.getWalletById(id);
    expect(retrieved!.name, 'Cash Updated');
    expect(retrieved.initialAmount, 200.0);
  });

  test('getAllWallets returns all wallets ordered by sort_order', () async {
    DatabaseInterface db = ServiceConfig.database;
    // Default wallet already exists from onCreate
    await db.addWallet(Wallet('B Wallet', sortOrder: 2));
    await db.addWallet(Wallet('A Wallet', sortOrder: 1));

    final wallets = await db.getAllWallets();
    // Default wallet (sort_order=0) created in onCreate comes first
    expect(wallets.first.isDefault, true);
    expect(wallets.length, greaterThanOrEqualTo(3));
  });

  test('deleteWalletAndRecords removes wallet and its records', () async {
    DatabaseInterface db = ServiceConfig.database;
    SqliteDatabase sqliteDb = ServiceConfig.database as SqliteDatabase;
    final rawDb = (await sqliteDb.database)!;

    final walletId = await db.addWallet(Wallet('To Delete'));

    // Insert a record linked to this wallet via raw SQL
    await rawDb.rawInsert("""
      INSERT INTO records (title, value, datetime, timezone, category_name, category_type, wallet_id)
      VALUES ('Test', -10.0, 1000000, 'UTC', 'House', 0, ?)
    """, [walletId]);

    await db.deleteWalletAndRecords(walletId);

    final wallet = await db.getWalletById(walletId);
    expect(wallet, isNull);

    final records = await rawDb
        .query('records', where: 'wallet_id = ?', whereArgs: [walletId]);
    expect(records, isEmpty);
  });

  test('setDefaultWallet makes only one wallet default', () async {
    DatabaseInterface db = ServiceConfig.database;
    final id1 = await db.addWallet(Wallet('Wallet 1'));
    final id2 = await db.addWallet(Wallet('Wallet 2'));

    await db.setDefaultWallet(id1);
    var wallets = await db.getAllWallets();
    expect(wallets.where((w) => w.isDefault).length, 1);
    expect(wallets.firstWhere((w) => w.id == id1).isDefault, true);
    expect(wallets.firstWhere((w) => w.id == id2).isDefault, false);

    await db.setDefaultWallet(id2);
    wallets = await db.getAllWallets();
    expect(wallets.where((w) => w.isDefault).length, 1);
    expect(wallets.firstWhere((w) => w.id == id2).isDefault, true);
    expect(wallets.firstWhere((w) => w.id == id1).isDefault, false);
  });

  test('archiveWallet toggles archived state', () async {
    DatabaseInterface db = ServiceConfig.database;
    final id = await db.addWallet(Wallet('Archived Wallet'));

    await db.archiveWallet(id, true);
    var wallet = await db.getWalletById(id);
    expect(wallet!.isArchived, true);

    await db.archiveWallet(id, false);
    wallet = await db.getWalletById(id);
    expect(wallet!.isArchived, false);
  });

  test('getDefaultWallet returns the default wallet', () async {
    DatabaseInterface db = ServiceConfig.database;
    // onCreate inserts a default wallet
    final defaultWallet = await db.getDefaultWallet();
    expect(defaultWallet, isNotNull);
    expect(defaultWallet!.isDefault, true);
  });

  test('resetWalletOrderIndexes reorders wallets', () async {
    DatabaseInterface db = ServiceConfig.database;
    final id1 = await db.addWallet(Wallet('W1', sortOrder: 0));
    final id2 = await db.addWallet(Wallet('W2', sortOrder: 1));
    final id3 = await db.addWallet(Wallet('W3', sortOrder: 2));

    final w1 = (await db.getWalletById(id1))!;
    final w2 = (await db.getWalletById(id2))!;
    final w3 = (await db.getWalletById(id3))!;

    // Reverse the order
    await db.resetWalletOrderIndexes([w3, w2, w1]);

    final reordered = (await db.getAllWallets())
        .where((w) => [id1, id2, id3].contains(w.id))
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    expect(reordered[0].id, id3);
    expect(reordered[1].id, id2);
    expect(reordered[2].id, id1);
  });

  test(
      'deleteWalletAndRecords removes partner transfer records in other wallets',
      () async {
    DatabaseInterface db = ServiceConfig.database;
    SqliteDatabase sqliteDb = ServiceConfig.database as SqliteDatabase;
    final rawDb = (await sqliteDb.database)!;

    final walletA = await db.addWallet(Wallet('Wallet A'));
    final walletB = await db.addWallet(Wallet('Wallet B'));

    // Transfer A→B: source record in A, partner record in B
    await rawDb.rawInsert("""
      INSERT INTO records (title, value, datetime, timezone, category_name, category_type, wallet_id, transfer_wallet_id)
      VALUES ('Transfer out', -50.0, 1000000, 'UTC', 'Transfer', 0, ?, ?)
    """, [walletA, walletB]);
    await rawDb.rawInsert("""
      INSERT INTO records (title, value, datetime, timezone, category_name, category_type, wallet_id, transfer_wallet_id)
      VALUES ('Transfer in', 50.0, 1000000, 'UTC', 'Transfer', 1, ?, ?)
    """, [walletB, walletA]);

    await db.deleteWalletAndRecords(walletA);

    // Both sides of the transfer should be gone
    final recordsInA = await rawDb
        .query('records', where: 'wallet_id = ?', whereArgs: [walletA]);
    expect(recordsInA, isEmpty);
    final orphanedInB = await rawDb.query('records',
        where: 'transfer_wallet_id = ?', whereArgs: [walletA]);
    expect(orphanedInB, isEmpty);
  });

  test(
      'moveRecordsToWallet deletes self-transfers and updates transfer references',
      () async {
    DatabaseInterface db = ServiceConfig.database;
    SqliteDatabase sqliteDb = ServiceConfig.database as SqliteDatabase;
    final rawDb = (await sqliteDb.database)!;

    final walletA = await db.addWallet(Wallet('Wallet A'));
    final walletB = await db.addWallet(Wallet('Wallet B'));
    final walletC = await db.addWallet(Wallet('Wallet C'));

    // Transfer A→B (would become self-transfer B→B if A merged into B)
    await rawDb.rawInsert("""
      INSERT INTO records (title, value, datetime, timezone, category_name, category_type, wallet_id, transfer_wallet_id)
      VALUES ('Transfer out', -50.0, 1000000, 'UTC', 'Transfer', 0, ?, ?)
    """, [walletA, walletB]);
    await rawDb.rawInsert("""
      INSERT INTO records (title, value, datetime, timezone, category_name, category_type, wallet_id, transfer_wallet_id)
      VALUES ('Transfer in', 50.0, 1000000, 'UTC', 'Transfer', 1, ?, ?)
    """, [walletB, walletA]);

    // Transfer A→C (should survive, with transfer_wallet_id updated from A to B)
    await rawDb.rawInsert("""
      INSERT INTO records (title, value, datetime, timezone, category_name, category_type, wallet_id, transfer_wallet_id)
      VALUES ('Transfer out', -30.0, 2000000, 'UTC', 'Transfer', 0, ?, ?)
    """, [walletA, walletC]);
    await rawDb.rawInsert("""
      INSERT INTO records (title, value, datetime, timezone, category_name, category_type, wallet_id, transfer_wallet_id)
      VALUES ('Transfer in', 30.0, 2000000, 'UTC', 'Transfer', 1, ?, ?)
    """, [walletC, walletA]);

    await db.moveRecordsToWallet(walletA, walletB);

    // A→B transfer should be deleted entirely (would have been a self-transfer)
    final selfTransfers = await rawDb.query('records',
        where: 'wallet_id = ? AND transfer_wallet_id = ?',
        whereArgs: [walletB, walletB]);
    expect(selfTransfers, isEmpty);

    // A→C transfer: source record now in B, partner in C still points to B
    final movedRecord = await rawDb.query('records',
        where: 'wallet_id = ? AND transfer_wallet_id = ?',
        whereArgs: [walletB, walletC]);
    expect(movedRecord.length, 1);
    final partnerRecord = await rawDb.query('records',
        where: 'wallet_id = ? AND transfer_wallet_id = ?',
        whereArgs: [walletC, walletB]);
    expect(partnerRecord.length, 1);
  });

  test('moveRecordsToWallet reassigns records', () async {
    DatabaseInterface db = ServiceConfig.database;
    SqliteDatabase sqliteDb = ServiceConfig.database as SqliteDatabase;
    final rawDb = (await sqliteDb.database)!;

    final fromId = await db.addWallet(Wallet('From'));
    final toId = await db.addWallet(Wallet('To'));

    await rawDb.rawInsert("""
      INSERT INTO records (title, value, datetime, timezone, category_name, category_type, wallet_id)
      VALUES ('R1', -5.0, 1000000, 'UTC', 'House', 0, ?)
    """, [fromId]);

    await db.moveRecordsToWallet(fromId, toId);

    final movedRecords =
        await rawDb.query('records', where: 'wallet_id = ?', whereArgs: [toId]);
    expect(movedRecords.isNotEmpty, true);
    final fromRecords = await rawDb
        .query('records', where: 'wallet_id = ?', whereArgs: [fromId]);
    expect(fromRecords, isEmpty);
  });

  test(
      'deleteWalletAndRecords deletes orphaned records with NULL wallet_id '
      'that belong to a pattern of the deleted wallet', () async {
    DatabaseInterface db = ServiceConfig.database;
    SqliteDatabase sqliteDb = ServiceConfig.database as SqliteDatabase;
    final rawDb = (await sqliteDb.database)!;

    final walletId = await db.addWallet(Wallet('My Wallet'));

    // Create a recurrent pattern linked to this wallet
    final patternId = 'test-pattern-orphan';
    await rawDb.insert('recurrent_record_patterns', {
      'id': patternId,
      'value': -10.0,
      'title': 'Recurring',
      'datetime': 1000000,
      'timezone': 'UTC',
      'category_name': 'Food',
      'category_type': 0,
      'recurrent_period': 2, // EveryMonth
      'wallet_id': walletId,
    });

    // Simulate the bug: records generated from the pattern ended up with
    // wallet_id = NULL instead of the pattern's wallet_id.
    await rawDb.rawInsert("""
      INSERT INTO records (title, value, datetime, timezone, category_name, category_type, wallet_id, recurrence_id)
      VALUES ('Orphan 1', -10.0, 1000000, 'UTC', 'Food', 0, NULL, ?)
    """, [patternId]);

    await rawDb.rawInsert("""
      INSERT INTO records (title, value, datetime, timezone, category_name, category_type, wallet_id, recurrence_id)
      VALUES ('Orphan 2', -10.0, 2000000, 'UTC', 'Food', 0, NULL, ?)
    """, [patternId]);

    // Also add a normal record that should be deleted by the usual path
    await rawDb.rawInsert("""
      INSERT INTO records (title, value, datetime, timezone, category_name, category_type, wallet_id)
      VALUES ('Normal', -5.0, 3000000, 'UTC', 'Food', 0, ?)
    """, [walletId]);

    await db.deleteWalletAndRecords(walletId);

    // Wallet gone
    expect(await db.getWalletById(walletId), isNull);

    // Pattern gone
    final patterns = await rawDb.query('recurrent_record_patterns',
        where: 'id = ?', whereArgs: [patternId]);
    expect(patterns, isEmpty);

    // Normal record (wallet_id matched) gone
    final normalRecords = await rawDb
        .query('records', where: 'wallet_id = ?', whereArgs: [walletId]);
    expect(normalRecords, isEmpty);

    // Orphaned records (wallet_id NULL but recurrence_id matched) also gone
    final orphanRecords = await rawDb
        .query('records', where: 'recurrence_id = ?', whereArgs: [patternId]);
    expect(orphanRecords, isEmpty);
  });

  test('deleteWalletAndRecords does not delete records from unrelated patterns',
      () async {
    DatabaseInterface db = ServiceConfig.database;
    SqliteDatabase sqliteDb = ServiceConfig.database as SqliteDatabase;
    final rawDb = (await sqliteDb.database)!;

    final walletToDelete = await db.addWallet(Wallet('ToDelete'));
    final otherWallet = await db.addWallet(Wallet('Other'));

    // Pattern belonging to another wallet — must survive
    final otherPatternId = 'other-pattern';
    await rawDb.insert('recurrent_record_patterns', {
      'id': otherPatternId,
      'value': -20.0,
      'title': 'Other recurring',
      'datetime': 1000000,
      'timezone': 'UTC',
      'category_name': 'Food',
      'category_type': 0,
      'recurrent_period': 2,
      'wallet_id': otherWallet,
    });

    await rawDb.rawInsert("""
      INSERT INTO records (title, value, datetime, timezone, category_name, category_type, wallet_id, recurrence_id)
      VALUES ('Other record', -20.0, 1000000, 'UTC', 'Food', 0, ?, ?)
    """, [otherWallet, otherPatternId]);

    await db.deleteWalletAndRecords(walletToDelete);

    // Other wallet and its pattern and record must still exist
    expect(await db.getWalletById(otherWallet), isNotNull);
    final otherPatterns = await rawDb.query('recurrent_record_patterns',
        where: 'id = ?', whereArgs: [otherPatternId]);
    expect(otherPatterns.length, 1);
    final otherRecords = await rawDb.query('records',
        where: 'recurrence_id = ?', whereArgs: [otherPatternId]);
    expect(otherRecords.length, 1);
  });

  test(
      'Default Wallet cannot be deleted - another wallet becomes default instead',
      () async {
    DatabaseInterface db = ServiceConfig.database;
    final defaultWallet = await db.getDefaultWallet();
    expect(defaultWallet, isNotNull);
    expect(defaultWallet!.name, 'Default Wallet');
    expect(defaultWallet.isDefault, true);

    // Create another wallet that can become the new default
    final newWalletId = await db.addWallet(Wallet('New Wallet'));

    // Attempt to delete the default wallet
    await db.deleteWalletAndRecords(defaultWallet.id!);

    // Default wallet should still exist (promoted from new wallet)
    final retrieved = await db.getDefaultWallet();
    expect(retrieved, isNotNull);
    expect(retrieved!.isDefault, true);
    expect(retrieved.id, newWalletId); // The new wallet was promoted
  });

  test('Non-default wallets can be deleted', () async {
    DatabaseInterface db = ServiceConfig.database;
    final id = await db.addWallet(Wallet('Test Wallet', isDefault: false));

    await db.deleteWalletAndRecords(id);

    final wallet = await db.getWalletById(id);
    expect(wallet, isNull);
  });

  test('setPredefinedWallet and getPredefinedWallet work', () async {
    DatabaseInterface db = ServiceConfig.database;

    final walletId1 = await db.addWallet(Wallet('Wallet 1'));
    final walletId2 = await db.addWallet(Wallet('Wallet 2'));

    await db.setPredefinedWallet(walletId1);
    var predefined = await db.getPredefinedWallet();
    expect(predefined, isNotNull);
    expect(predefined!.id, walletId1);
    expect(predefined.isPredefined, true);

    await db.setPredefinedWallet(walletId2);
    predefined = await db.getPredefinedWallet();
    expect(predefined!.id, walletId2);
    expect(predefined.isPredefined, true);
  });

  test('Deleting predefined wallet promotes another to predefined', () async {
    DatabaseInterface db = ServiceConfig.database;

    // Get the existing default wallet (created on init)
    final defaultWallet = await db.getDefaultWallet();
    expect(defaultWallet, isNotNull);

    // Create two new wallets
    final walletId1 = await db.addWallet(Wallet('Wallet 1'));
    final walletId2 = await db.addWallet(Wallet('Wallet 2'));

    // Set walletId1 as predefined
    await db.setPredefinedWallet(walletId1);

    // Delete the predefined wallet
    await db.deleteWalletAndRecords(walletId1);

    // Another wallet should now be predefined
    final predefined = await db.getPredefinedWallet();
    expect(predefined, isNotNull);
    // It could be either default wallet or walletId2 - just check something is predefined
    expect(predefined!.isPredefined, true);
  });
}
