import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/services/database/sqlite-database.dart';
import 'package:piggybank/services/database/sqlite-migration-service.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:sqflite_common/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timezone/data/latest_all.dart' as tz;

/// Simulates a v17 database schema (before wallets/profiles/transfers/custom
/// intervals existed), mirroring test/wallets/wallet_migration_test.dart's
/// _openV17Database() helper.
Future<Database> _openV17Database() async {
  final db = await databaseFactory.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(version: 17),
  );

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

/// Simulates a v27 database schema (before the custom interval columns
/// were added to recurrent_record_patterns).
Future<Database> _openV27Database() async {
  final db = await databaseFactory.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(version: 27),
  );

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
      end_date INTEGER,
      wallet_id INTEGER,
      transfer_wallet_id INTEGER,
      transfer_value REAL,
      profile_id INTEGER
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

  test(
      'migration 27 -> 28 adds custom_interval_value and custom_interval_unit columns',
      () async {
    final db = await _openV27Database();

    // Insert a pre-migration pattern using the old fixed periods only.
    await db.insert('recurrent_record_patterns', {
      'id': 'pattern-1',
      'datetime': DateTime.now().millisecondsSinceEpoch,
      'timezone': 'UTC',
      'value': -50.0,
      'title': 'Rent',
      'category_name': 'House',
      'category_type': 1,
      'recurrent_period': 2, // RecurrentPeriod.EveryMonth
    });

    await SqliteMigrationService.onUpgrade(db, 27, 28);

    // The new columns should exist and be queryable (would throw otherwise).
    final rows = await db.query('recurrent_record_patterns');
    expect(rows.length, 1);
    expect(rows.first['custom_interval_value'], isNull);
    expect(rows.first['custom_interval_unit'], isNull);

    // A new pattern using a custom interval should now be insertable.
    await db.insert('recurrent_record_patterns', {
      'id': 'pattern-2',
      'datetime': DateTime.now().millisecondsSinceEpoch,
      'timezone': 'UTC',
      'value': -200.0,
      'title': 'Car insurance',
      'category_name': 'House',
      'category_type': 1,
      'recurrent_period': 8, // RecurrentPeriod.Custom
      'custom_interval_value': 6,
      'custom_interval_unit': 2, // CustomIntervalUnit.month
    });

    final customRows = await db.query('recurrent_record_patterns',
        where: 'id = ?', whereArgs: ['pattern-2']);
    expect(customRows.first['custom_interval_value'], 6);
    expect(customRows.first['custom_interval_unit'], 2);

    await db.close();
  });

  test('migration 27 -> 28 is idempotent when re-run', () async {
    final db = await _openV27Database();

    await SqliteMigrationService.onUpgrade(db, 27, 28);
    // Running the migration function again must not throw even though the
    // columns already exist (safeAlterTable swallows the DatabaseException).
    await SqliteMigrationService.onUpgrade(db, 27, 28);

    final rows = await db.query('recurrent_record_patterns');
    expect(rows, isEmpty);

    await db.close();
  });

  test(
      'multi-step upgrade from v17 through the current version preserves an old pattern and adds the custom interval columns',
      () async {
    final db = await _openV17Database();

    // Insert a pattern using the v17-era schema only (no wallet_id,
    // transfer_wallet_id, profile_id, or custom interval columns yet).
    await db.insert('recurrent_record_patterns', {
      'id': 'legacy-pattern',
      'datetime': DateTime.now().millisecondsSinceEpoch,
      'timezone': 'UTC',
      'value': -75.0,
      'title': 'Legacy Rent',
      'category_name': 'House',
      'category_type': 1,
      'recurrent_period': 2, // RecurrentPeriod.EveryMonth
    });

    // Run every migration from v17 to the current version in one go, the
    // same way a long-dormant install would upgrade in a single app launch.
    await SqliteMigrationService.onUpgrade(db, 17, SqliteDatabase.version);

    final rows = await db.query('recurrent_record_patterns',
        where: 'id = ?', whereArgs: ['legacy-pattern']);
    expect(rows.length, 1, reason: 'The pre-existing pattern must survive');
    expect(rows.first['title'], 'Legacy Rent');
    expect(rows.first['recurrent_period'], 2);
    // Backfilled by the v20/v22 migrations.
    expect(rows.first['wallet_id'], isNotNull);
    // Not set by any migration: must default to NULL, not throw.
    expect(rows.first['custom_interval_value'], isNull);
    expect(rows.first['custom_interval_unit'], isNull);

    // A new Custom-interval pattern must be insertable after the full chain.
    await db.insert('recurrent_record_patterns', {
      'id': 'new-custom-pattern',
      'datetime': DateTime.now().millisecondsSinceEpoch,
      'timezone': 'UTC',
      'value': -20.0,
      'title': 'Streaming bundle',
      'category_name': 'House',
      'category_type': 1,
      'recurrent_period': 8, // RecurrentPeriod.Custom
      'custom_interval_value': 6,
      'custom_interval_unit': 2, // CustomIntervalUnit.month
    });

    final customRows = await db.query('recurrent_record_patterns',
        where: 'id = ?', whereArgs: ['new-custom-pattern']);
    expect(customRows.first['custom_interval_value'], 6);
    expect(customRows.first['custom_interval_unit'], 2);

    await db.close();
  });

  test('fresh install at the current version has the custom interval columns',
      () async {
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: SqliteDatabase.version,
        onCreate: SqliteMigrationService.onCreate,
        onUpgrade: SqliteMigrationService.onUpgrade,
      ),
    );

    SqliteDatabase.setDatabaseForTesting(db);

    await db.insert('recurrent_record_patterns', {
      'id': 'pattern-fresh',
      'datetime': DateTime.now().millisecondsSinceEpoch,
      'timezone': 'UTC',
      'value': -30.0,
      'title': 'Subscription',
      'category_name': 'House',
      'category_type': 1,
      'recurrent_period': 8,
      'custom_interval_value': 4,
      'custom_interval_unit': 3, // CustomIntervalUnit.year
    });

    final rows = await db.query('recurrent_record_patterns',
        where: 'id = ?', whereArgs: ['pattern-fresh']);
    expect(rows.length, 1);
    expect(rows.first['custom_interval_value'], 4);
    expect(rows.first['custom_interval_unit'], 3);

    await db.close();
  });
}
