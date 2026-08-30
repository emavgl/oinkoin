import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/services/database/sqlite-migration-service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Opens an in-memory database that mirrors the v31 profiles schema (no
/// sort_order column yet) and seeds it with a couple of existing profiles.
Future<Database> _openV31DatabaseWithProfiles() async {
  final db = await databaseFactory.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(version: 31),
  );

  await db.execute("""
    CREATE TABLE IF NOT EXISTS profiles (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      is_default INTEGER DEFAULT 0,
      color TEXT
    );
  """);

  await db.rawInsert(
    "INSERT INTO profiles (name, is_default) VALUES ('Default Profile', 1)",
  );
  await db.rawInsert(
    "INSERT INTO profiles (name, is_default) VALUES ('Side Hustle', 0)",
  );

  return db;
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Migration v31 -> v32 (profile sort_order)', () {
    test('adds a sort_order column defaulting to 0', () async {
      final db = await _openV31DatabaseWithProfiles();
      await SqliteMigrationService.onUpgrade(db, 31, 32);

      final columns = await db.rawQuery("PRAGMA table_info(profiles)");
      final columnNames = columns.map((c) => c['name'] as String).toSet();
      expect(columnNames, contains('sort_order'));

      final rows = await db.query('profiles', orderBy: 'id');
      for (final row in rows) {
        expect(row['sort_order'], equals(0));
      }

      await db.close();
    });

    test('preserves existing profile data', () async {
      final db = await _openV31DatabaseWithProfiles();
      await SqliteMigrationService.onUpgrade(db, 31, 32);

      final rows = await db.query('profiles', orderBy: 'id');
      expect(rows.length, equals(2));
      expect(rows[0]['name'], equals('Default Profile'));
      expect(rows[0]['is_default'], equals(1));
      expect(rows[1]['name'], equals('Side Hustle'));
      expect(rows[1]['is_default'], equals(0));

      await db.close();
    });

    test('is idempotent when run twice', () async {
      final db = await _openV31DatabaseWithProfiles();
      await SqliteMigrationService.onUpgrade(db, 31, 32);
      // Re-running the same migration step should not throw even though the
      // column already exists (mirrors safeAlterTable's existing guarantee).
      await SqliteMigrationService.onUpgrade(db, 31, 32);

      final rows = await db.query('profiles', orderBy: 'id');
      expect(rows.length, equals(2));

      await db.close();
    });
  });
}
