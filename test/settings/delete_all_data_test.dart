import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/models/profile.dart';
import 'package:piggybank/models/wallet.dart';
import 'package:piggybank/services/database/database-interface.dart';
import 'package:piggybank/services/database/sqlite-database.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:sqflite_common/sqflite.dart';
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

  test('deleteDatabase preserves the default profile', () async {
    DatabaseInterface db = ServiceConfig.database;
    SqliteDatabase sqliteDb = ServiceConfig.database as SqliteDatabase;
    final rawDb = (await sqliteDb.database)!;

    // Verify default profile exists before deletion
    final profilesBefore =
        await rawDb.query('profiles', where: 'is_default = 1');
    expect(profilesBefore.length, 1);

    // Add an extra non-default profile
    await db.addProfile(Profile('Extra Profile'));

    final allProfilesBefore = await rawDb.query('profiles');
    expect(allProfilesBefore.length, 2);

    await db.deleteDatabase();

    // Default profile should still exist
    final profilesAfter =
        await rawDb.query('profiles', where: 'is_default = 1');
    expect(profilesAfter.length, 1);

    // Non-default profiles should be gone
    final allProfilesAfter = await rawDb.query('profiles');
    expect(allProfilesAfter.length, 1);
    expect(allProfilesAfter.first['is_default'], 1);
  });

  test('deleteDatabase preserves the default wallet', () async {
    DatabaseInterface db = ServiceConfig.database;
    SqliteDatabase sqliteDb = ServiceConfig.database as SqliteDatabase;
    final rawDb = (await sqliteDb.database)!;

    // Verify default wallet exists before deletion
    final walletsBefore = await rawDb.query('wallets', where: 'is_default = 1');
    expect(walletsBefore.length, 1);

    // Add an extra non-default wallet
    await db.addWallet(Wallet('Extra Wallet'));

    final allWalletsBefore = await rawDb.query('wallets');
    expect(allWalletsBefore.length, 2);

    await db.deleteDatabase();

    // Default wallet should still exist
    final walletsAfter = await rawDb.query('wallets', where: 'is_default = 1');
    expect(walletsAfter.length, 1);

    // Only the default wallet should remain
    final allWalletsAfter = await rawDb.query('wallets');
    expect(allWalletsAfter.length, 1);
    expect(allWalletsAfter.first['is_default'], 1);
  });

  test('deleteDatabase removes all records', () async {
    DatabaseInterface db = ServiceConfig.database;
    SqliteDatabase sqliteDb = ServiceConfig.database as SqliteDatabase;
    final rawDb = (await sqliteDb.database)!;

    final wallet = await db.getDefaultWallet();

    // Insert a record via raw SQL
    await rawDb.rawInsert("""
      INSERT INTO records (title, value, datetime, timezone, category_name, category_type, wallet_id)
      VALUES ('Test Record', -10.0, 1000000, 'UTC', 'House', 0, ?)
    """, [wallet!.id]);

    final recordsBefore = await rawDb.query('records');
    expect(recordsBefore.length, 1);

    await db.deleteDatabase();

    final recordsAfter = await rawDb.query('records');
    expect(recordsAfter.length, 0);
  });

  test('deleteDatabase removes all categories', () async {
    DatabaseInterface db = ServiceConfig.database;
    SqliteDatabase sqliteDb = ServiceConfig.database as SqliteDatabase;
    final rawDb = (await sqliteDb.database)!;

    final categoriesBefore = await rawDb.query('categories');
    expect(categoriesBefore.length, greaterThan(0));

    await db.deleteDatabase();

    final categoriesAfter = await rawDb.query('categories');
    expect(categoriesAfter.length, 0);
  });

  test('deleteDatabase removes all recurrent record patterns', () async {
    DatabaseInterface db = ServiceConfig.database;
    SqliteDatabase sqliteDb = ServiceConfig.database as SqliteDatabase;
    final rawDb = (await sqliteDb.database)!;

    final wallet = await db.getDefaultWallet();
    final profile = await db.getDefaultProfile();

    // Insert a recurrent pattern via raw SQL
    await rawDb.rawInsert("""
      INSERT INTO recurrent_record_patterns (id, title, value, datetime, timezone, category_name, category_type, wallet_id, profile_id, recurrent_period)
      VALUES ('test-pattern-1', 'Recurrent', -5.0, 1000000, 'UTC', 'House', 0, ?, ?, 86400)
    """, [wallet!.id, profile!.id]);

    final patternsBefore = await rawDb.query('recurrent_record_patterns');
    expect(patternsBefore.length, 1);

    await db.deleteDatabase();

    final patternsAfter = await rawDb.query('recurrent_record_patterns');
    expect(patternsAfter.length, 0);
  });

  test('deleteDatabase removes all tags from records_tags', () async {
    DatabaseInterface db = ServiceConfig.database;
    SqliteDatabase sqliteDb = ServiceConfig.database as SqliteDatabase;
    final rawDb = (await sqliteDb.database)!;

    final wallet = await db.getDefaultWallet();

    // Insert a record
    final recordId = await rawDb.rawInsert("""
      INSERT INTO records (title, value, datetime, timezone, category_name, category_type, wallet_id)
      VALUES ('Tagged Record', -10.0, 1000000, 'UTC', 'House', 0, ?)
    """, [wallet!.id]);

    // Insert a tag association
    await rawDb.rawInsert("""
      INSERT INTO records_tags (record_id, tag_name)
      VALUES (?, 'TestTag')
    """, [recordId]);

    final tagsBefore = await rawDb.query('records_tags');
    expect(tagsBefore.length, 1);

    await db.deleteDatabase();

    final tagsAfter = await rawDb.query('records_tags');
    expect(tagsAfter.length, 0);
  });

  test('deleteDatabase resets auto-increment for cleared tables', () async {
    DatabaseInterface db = ServiceConfig.database;
    SqliteDatabase sqliteDb = ServiceConfig.database as SqliteDatabase;
    final rawDb = (await sqliteDb.database)!;

    final wallet = await db.getDefaultWallet();

    // Insert multiple records to increment the sequence
    for (int i = 0; i < 5; i++) {
      await rawDb.rawInsert("""
        INSERT INTO records (title, value, datetime, timezone, category_name, category_type, wallet_id)
        VALUES ('Record $i', -10.0, 1000000, 'UTC', 'House', 0, ?)
      """, [wallet!.id]);
    }

    await db.deleteDatabase();

    // Insert a new record after deletion
    final newRecordId = await rawDb.rawInsert("""
      INSERT INTO records (title, value, datetime, timezone, category_name, category_type, wallet_id)
      VALUES ('New Record', -10.0, 1000000, 'UTC', 'House', 0, ?)
    """, [wallet!.id]);

    // The id should be 1 since the sequence was reset
    expect(newRecordId, 1);
  });

  test('deleteDatabase preserves wallet-profile relationship', () async {
    DatabaseInterface db = ServiceConfig.database;
    SqliteDatabase sqliteDb = ServiceConfig.database as SqliteDatabase;
    final rawDb = (await sqliteDb.database)!;

    // Get the default wallet's profile_id before deletion
    final defaultWalletBefore =
        await rawDb.query('wallets', where: 'is_default = 1');
    final defaultProfileId = defaultWalletBefore.first['profile_id'];

    await db.deleteDatabase();

    // Default wallet should still reference the default profile
    final defaultWalletAfter =
        await rawDb.query('wallets', where: 'is_default = 1');
    expect(defaultWalletAfter.length, 1);
    expect(defaultWalletAfter.first['profile_id'], defaultProfileId);

    // The profile should still exist
    final profile = await rawDb
        .query('profiles', where: 'id = ?', whereArgs: [defaultProfileId]);
    expect(profile.length, 1);
  });
}
