import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/services/database/sqlite-database.dart';
import 'package:piggybank/services/database/sqlite-migration-service.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:sqflite_common/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timezone/data/latest_all.dart' as tz;

/// Simulates a v17 database schema (before wallet support).
Future<Database> _openV17Database() async {
  final db = await databaseFactory.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(version: 17),
  );

  // Create the v17 schema (without wallets table / wallet_id)
  await db.execute("""
    CREATE TABLE IF NOT EXISTS categories (
      name TEXT,
      color TEXT,
      icon INTEGER,
      category_type INTEGER,
      last_used INTEGER,
      record_count INTEGER DEFAULT 0,
      is_archived INTEGER DEFAULT 0,
      sort_order INTEGER DEFAULT 0,
      icon_emoji TEXT,
      PRIMARY KEY (name, category_type)
    );
  """);

  await db.execute("""
    CREATE TABLE IF NOT EXISTS records (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      datetime INTEGER,
      timezone TEXT,
      value REAL,
      title TEXT,
      description TEXT,
      category_name TEXT,
      category_type INTEGER,
      recurrence_id TEXT
    );
  """);

  await db.execute("""
    CREATE TABLE IF NOT EXISTS records_tags (
      record_id INTEGER NOT NULL,
      tag_name TEXT NOT NULL,
      PRIMARY KEY (record_id, tag_name)
    );
  """);

  await db.execute("""
    CREATE TABLE IF NOT EXISTS recurrent_record_patterns (
      id TEXT PRIMARY KEY,
      datetime INTEGER,
      timezone TEXT,
      value REAL,
      title TEXT,
      description TEXT,
      category_name TEXT,
      category_type INTEGER,
      last_update INTEGER,
      recurrent_period INTEGER,
      recurrence_id TEXT,
      date_str TEXT,
      tags TEXT,
      end_date INTEGER
    );
  """);

  return db;
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tz.initializeTimeZones();
    ServiceConfig.localTimezone = "Europe/Vienna";
  });

  test('migration 17 -> 18 creates Default Wallet and backfills records',
      () async {
    // Open a v17 database with some pre-existing records
    final db = await _openV17Database();

    // Insert some records (no wallet_id column yet)
    await db.insert('records', {
      'datetime': DateTime.now().millisecondsSinceEpoch,
      'timezone': 'UTC',
      'value': -50.0,
      'title': 'Groceries',
      'category_name': 'Food',
      'category_type': 1,
    });
    await db.insert('records', {
      'datetime': DateTime.now().millisecondsSinceEpoch,
      'timezone': 'UTC',
      'value': 1000.0,
      'title': 'Salary',
      'category_name': 'Income',
      'category_type': 0,
    });

    // Run migration to v18
    await SqliteMigrationService.onUpgrade(db, 17, 18);

    // Verify wallets table exists and has exactly one default wallet
    final wallets = await db.query('wallets');
    expect(wallets.length, 1, reason: 'Should have created one Default Wallet');
    expect(wallets.first['is_default'], 1,
        reason: 'The wallet should be marked as default');
    expect(wallets.first['name'], isNotNull);

    final defaultWalletId = wallets.first['id'] as int;

    // Verify all records were backfilled with the default wallet id
    final records = await db.query('records');
    expect(records.length, 2);
    for (final record in records) {
      expect(record['wallet_id'], defaultWalletId,
          reason:
              'Record "${record['title']}" should be assigned to the Default Wallet');
    }

    await db.close();
  });

  test('migration 17 -> 18 works when there are no existing records', () async {
    final db = await _openV17Database();

    // No records inserted

    await SqliteMigrationService.onUpgrade(db, 17, 18);

    final wallets = await db.query('wallets');
    expect(wallets.length, 1);
    expect(wallets.first['is_default'], 1);

    final records = await db.query('records');
    expect(records.isEmpty, true);

    await db.close();
  });

  test('fresh install at v18 has Default Wallet and records include wallet_id',
      () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: SqliteDatabase.version,
        onCreate: SqliteMigrationService.onCreate,
        onUpgrade: SqliteMigrationService.onUpgrade,
      ),
    );

    SqliteDatabase.setDatabaseForTesting(db);

    final wallets = await db.query('wallets');
    expect(wallets.any((w) => w['is_default'] == 1), true,
        reason: 'Fresh install should have a Default Wallet');

    // records table should have wallet_id column (verified by inserting with it)
    await db.insert('records', {
      'datetime': DateTime.now().millisecondsSinceEpoch,
      'timezone': 'UTC',
      'value': -10.0,
      'title': 'Test',
      'category_name': 'Food',
      'category_type': 1,
      'wallet_id': wallets.first['id'],
    });

    final records = await db.query('records');
    expect(records.length, 1);
    expect(records.first['wallet_id'], wallets.first['id']);

    await db.close();
  });
}
