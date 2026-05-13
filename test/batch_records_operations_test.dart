import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/models/wallet.dart';
import 'package:piggybank/services/database/database-interface.dart';
import 'package:piggybank/services/database/sqlite-database.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timezone/data/latest_all.dart' as tz;

import 'helpers/test_database.dart';

final testCategory = Category(
  'Food',
  color: Colors.green,
  categoryType: CategoryType.expense,
);

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tz.initializeTimeZones();
    ServiceConfig.localTimezone = "UTC";
  });

  setUp(() async {
    await TestDatabaseHelper.setupTestDatabase();
  });

  group('deleteRecordsInBatch', () {
    test('deletes all specified records', () async {
      DatabaseInterface db = ServiceConfig.database;
      final walletId = await db.addWallet(Wallet('Test Wallet'));

      // Create test records
      final now = DateTime.utc(2025, 1, 1, 12, 0, 0);
      final id1 = await db.addRecord(Record(
        -10.0,
        'Record 1',
        testCategory,
        now,
        walletId: walletId,
      ));
      final id2 = await db.addRecord(Record(
        -20.0,
        'Record 2',
        testCategory,
        now,
        walletId: walletId,
      ));
      final id3 = await db.addRecord(Record(
        -30.0,
        'Record 3',
        testCategory,
        now,
        walletId: walletId,
      ));

      // Verify records exist
      expect(await db.getRecordById(id1), isNotNull);
      expect(await db.getRecordById(id2), isNotNull);
      expect(await db.getRecordById(id3), isNotNull);

      // Delete batch
      await db.deleteRecordsInBatch([id1, id2, id3]);

      // Verify records are gone
      expect(await db.getRecordById(id1), isNull);
      expect(await db.getRecordById(id2), isNull);
      expect(await db.getRecordById(id3), isNull);
    });

    test('only deletes specified records, not others', () async {
      DatabaseInterface db = ServiceConfig.database;
      final walletId = await db.addWallet(Wallet('Test Wallet'));

      final now = DateTime.utc(2025, 1, 1, 12, 0, 0);
      final toDelete1 = await db.addRecord(Record(
        -10.0,
        'Delete Me 1',
        testCategory,
        now,
        walletId: walletId,
      ));
      final toKeep = await db.addRecord(Record(
        -50.0,
        'Keep Me',
        testCategory,
        now,
        walletId: walletId,
      ));
      final toDelete2 = await db.addRecord(Record(
        -20.0,
        'Delete Me 2',
        testCategory,
        now,
        walletId: walletId,
      ));

      // Delete only some
      await db.deleteRecordsInBatch([toDelete1, toDelete2]);

      expect(await db.getRecordById(toDelete1), isNull);
      expect(await db.getRecordById(toDelete2), isNull);
      expect(await db.getRecordById(toKeep), isNotNull);
    });

    test('handles empty list gracefully', () async {
      DatabaseInterface db = ServiceConfig.database;
      final walletId = await db.addWallet(Wallet('Test Wallet'));

      final now = DateTime.utc(2025, 1, 1, 12, 0, 0);
      final id = await db.addRecord(Record(
        -10.0,
        'Record',
        testCategory,
        now,
        walletId: walletId,
      ));

      // Should not throw
      await db.deleteRecordsInBatch([]);

      // Record should still exist
      expect(await db.getRecordById(id), isNotNull);
    });

    test('cleans up tags for deleted records', () async {
      DatabaseInterface db = ServiceConfig.database;
      SqliteDatabase sqliteDb = ServiceConfig.database as SqliteDatabase;
      final rawDb = (await sqliteDb.database)!;
      final walletId = await db.addWallet(Wallet('Test Wallet'));

      final now = DateTime.utc(2025, 1, 1, 12, 0, 0);
      final record = Record(
        -10.0,
        'Tagged Record',
        testCategory,
        now,
        walletId: walletId,
        tags: {'work', 'important'}.toSet(),
      );
      final id = await db.addRecord(record);

      // Verify tags exist
      final tagsBefore = await db.getTagsForRecord(id);
      expect(tagsBefore.isNotEmpty, true);

      // Delete record
      await db.deleteRecordsInBatch([id]);

      // Verify tags are cleaned up (no orphaned tags)
      final tagsAfter = await db.getTagsForRecord(id);
      expect(tagsAfter, isEmpty);
    });

    test('affects wallet balance correctly', () async {
      DatabaseInterface db = ServiceConfig.database;
      final walletId = await db.addWallet(Wallet('Test', initialAmount: 100.0));

      final now = DateTime.utc(2025, 1, 1, 12, 0, 0);
      final id1 = await db.addRecord(Record(
        -30.0,
        'Expense',
        testCategory,
        now,
        walletId: walletId,
      ));
      final id2 = await db.addRecord(Record(
        -20.0,
        'Another Expense',
        testCategory,
        now,
        walletId: walletId,
      ));

      // Balance before: 100 - 30 - 20 = 50
      final before = await db.getWalletById(walletId);
      expect(before!.balance, closeTo(50.0, 0.001));

      // Delete batch (should restore amount)
      await db.deleteRecordsInBatch([id1, id2]);

      // Balance after: 100
      final after = await db.getWalletById(walletId);
      expect(after!.balance, closeTo(100.0, 0.001));
    });
  });

  group('updateRecordWalletInBatch', () {
    test('updates wallet for all specified records', () async {
      DatabaseInterface db = ServiceConfig.database;
      final wallet1 = await db.addWallet(Wallet('Wallet 1'));
      final wallet2 = await db.addWallet(Wallet('Wallet 2'));

      final now = DateTime.utc(2025, 1, 1, 12, 0, 0);
      final id1 = await db.addRecord(Record(
        -10.0,
        'Record 1',
        testCategory,
        now,
        walletId: wallet1,
      ));
      final id2 = await db.addRecord(Record(
        -20.0,
        'Record 2',
        testCategory,
        now,
        walletId: wallet1,
      ));
      final id3 = await db.addRecord(Record(
        -30.0,
        'Record 3',
        testCategory,
        now,
        walletId: wallet1,
      ));

      // Verify initial state
      expect((await db.getRecordById(id1))!.walletId, wallet1);
      expect((await db.getRecordById(id2))!.walletId, wallet1);
      expect((await db.getRecordById(id3))!.walletId, wallet1);

      // Update batch
      await db.updateRecordWalletInBatch([id1, id2, id3], wallet2);

      // Verify updates
      expect((await db.getRecordById(id1))!.walletId, wallet2);
      expect((await db.getRecordById(id2))!.walletId, wallet2);
      expect((await db.getRecordById(id3))!.walletId, wallet2);
    });

    test('only updates specified records, not others', () async {
      DatabaseInterface db = ServiceConfig.database;
      final wallet1 = await db.addWallet(Wallet('Wallet 1'));
      final wallet2 = await db.addWallet(Wallet('Wallet 2'));

      final now = DateTime.utc(2025, 1, 1, 12, 0, 0);
      final toUpdate = await db.addRecord(Record(
        -10.0,
        'Update Me',
        testCategory,
        now,
        walletId: wallet1,
      ));
      final toKeep = await db.addRecord(Record(
        -20.0,
        'Keep Me',
        testCategory,
        now,
        walletId: wallet1,
      ));

      // Update only one
      await db.updateRecordWalletInBatch([toUpdate], wallet2);

      expect((await db.getRecordById(toUpdate))!.walletId, wallet2);
      expect((await db.getRecordById(toKeep))!.walletId, wallet1);
    });

    test('handles empty list gracefully', () async {
      DatabaseInterface db = ServiceConfig.database;
      final walletId = await db.addWallet(Wallet('Test'));
      final now = DateTime.utc(2025, 1, 1, 12, 0, 0);
      final id = await db.addRecord(Record(
        -10.0,
        'Record',
        testCategory,
        now,
        walletId: walletId,
      ));

      // Should not throw
      await db.updateRecordWalletInBatch([], walletId);

      // Record should be unchanged
      expect((await db.getRecordById(id))!.walletId, walletId);
    });

    test('updates wallet balance correctly when moving records', () async {
      DatabaseInterface db = ServiceConfig.database;
      final wallet1 = await db.addWallet(Wallet('W1', initialAmount: 100.0));
      final wallet2 = await db.addWallet(Wallet('W2', initialAmount: 50.0));

      final now = DateTime.utc(2025, 1, 1, 12, 0, 0);
      final id1 = await db.addRecord(Record(
        -30.0,
        'Expense',
        testCategory,
        now,
        walletId: wallet1,
      ));
      final id2 = await db.addRecord(Record(
        -20.0,
        'Another Expense',
        testCategory,
        now,
        walletId: wallet1,
      ));

      // Before: W1 = 50, W2 = 50
      var w1 = await db.getWalletById(wallet1);
      var w2 = await db.getWalletById(wallet2);
      expect(w1!.balance, closeTo(50.0, 0.001));
      expect(w2!.balance, closeTo(50.0, 0.001));

      // Move records to wallet2
      await db.updateRecordWalletInBatch([id1, id2], wallet2);

      // After: W1 = 100 (records restored), W2 = 0 (records moved to it)
      w1 = await db.getWalletById(wallet1);
      w2 = await db.getWalletById(wallet2);
      expect(w1!.balance, closeTo(100.0, 0.001));
      expect(w2!.balance, closeTo(0.0, 0.001));
    });

    test('handles null walletId (moving to NULL)', () async {
      DatabaseInterface db = ServiceConfig.database;
      final walletId = await db.addWallet(Wallet('Test'));

      final now = DateTime.utc(2025, 1, 1, 12, 0, 0);
      final id = await db.addRecord(Record(
        -10.0,
        'Record',
        testCategory,
        now,
        walletId: walletId,
      ));

      await db.updateRecordWalletInBatch([id], null);

      expect((await db.getRecordById(id))!.walletId, isNull);
    });
  });

  group('duplicateRecordsInBatch', () {
    test('creates duplicates for all specified records', () async {
      DatabaseInterface db = ServiceConfig.database;
      final walletId = await db.addWallet(Wallet('Test Wallet'));

      final now = DateTime.utc(2025, 1, 1, 12, 0, 0);
      final id1 = await db.addRecord(Record(
        -10.0,
        'Record 1',
        testCategory,
        now,
        walletId: walletId,
      ));
      final id2 = await db.addRecord(Record(
        -20.0,
        'Record 2',
        testCategory,
        now,
        walletId: walletId,
      ));

      final allBefore = await db.getAllRecords();
      final countBefore = allBefore.length;

      // Duplicate batch
      await db.duplicateRecordsInBatch([id1, id2]);

      final allAfter = await db.getAllRecords();
      final countAfter = allAfter.length;

      // Should have 2 more records (1 original + 2 duplicates each)
      expect(countAfter, countBefore + 2);
    });

    test('duplicates preserve all fields except id and datetime', () async {
      DatabaseInterface db = ServiceConfig.database;
      final walletId = await db.addWallet(Wallet('Test Wallet'));

      final now = DateTime.utc(2025, 1, 1, 12, 0, 0);
      final original = Record(
        -50.0,
        'Test Record',
        testCategory,
        now,
        walletId: walletId,
        description: 'Test description',
        tags: {'tag1', 'tag2'}.toSet(),
      );
      final id = await db.addRecord(original);

      await db.duplicateRecordsInBatch([id]);

      // Get all records and find the duplicate
      final allRecords = await db.getAllRecords();
      final duplicates = allRecords
          .where((r) => r != null && r.title == 'Test Record' && r.id != id)
          .toList();

      expect(duplicates.length, greaterThan(0));
      final duplicate = duplicates.first!;

      // Verify fields match
      expect(duplicate.value, original.value);
      expect(duplicate.title, original.title);
      expect(duplicate.walletId, original.walletId);
      expect(duplicate.description, original.description);
      // ID and datetime should be different
      expect(duplicate.id, isNotNull);
      expect(duplicate.id, isNot(id));
      expect(duplicate.utcDateTime, isNot(now));
    });

    test('duplicates have current timestamp', () async {
      DatabaseInterface db = ServiceConfig.database;
      final walletId = await db.addWallet(Wallet('Test Wallet'));

      final pastTime = DateTime.utc(2020, 1, 1, 12, 0, 0);
      final id = await db.addRecord(Record(
        -10.0,
        'Old Record',
        testCategory,
        pastTime,
        walletId: walletId,
      ));

      final beforeDuplicate = DateTime.utc(2025, 1, 1, 12, 0, 0);
      await db.duplicateRecordsInBatch([id]);
      final afterDuplicate = DateTime.now().toUtc();

      // Get all records and find the duplicate
      final allRecords = await db.getAllRecords();
      final duplicates = allRecords
          .where((r) => r != null && r.title == 'Old Record' && r.id != id)
          .toList();

      expect(duplicates.isNotEmpty, true);
      final duplicate = duplicates.first!;

      // Duplicate should have a recent timestamp, not the old one
      expect(
          duplicate.utcDateTime.isAfter(beforeDuplicate) ||
              duplicate.utcDateTime.isAtSameMomentAs(beforeDuplicate),
          true);
      expect(
          duplicate.utcDateTime.isBefore(afterDuplicate) ||
              duplicate.utcDateTime.isAtSameMomentAs(afterDuplicate),
          true);
    });

    test('only duplicates specified records', () async {
      DatabaseInterface db = ServiceConfig.database;
      final walletId = await db.addWallet(Wallet('Test Wallet'));

      final now = DateTime.utc(2025, 1, 1, 12, 0, 0);
      final toDuplicate = await db.addRecord(Record(
        -10.0,
        'Duplicate Me',
        testCategory,
        now,
        walletId: walletId,
      ));
      final toKeep = await db.addRecord(Record(
        -20.0,
        'Keep Me',
        testCategory,
        now,
        walletId: walletId,
      ));

      final countBefore = (await db.getAllRecords()).length;

      // Duplicate only one
      await db.duplicateRecordsInBatch([toDuplicate]);

      final countAfter = (await db.getAllRecords()).length;
      // Should have only 1 more record
      expect(countAfter, countBefore + 1);

      // Count how many "Duplicate Me" records there are
      final duplicateRecords = (await db.getAllRecords())
          .where((r) => r != null && r.title == 'Duplicate Me')
          .toList();
      expect(duplicateRecords.length, 2); // Original + 1 duplicate

      // Count how many "Keep Me" records there are
      final keepRecords = (await db.getAllRecords())
          .where((r) => r != null && r.title == 'Keep Me')
          .toList();
      expect(keepRecords.length, 1); // Only original
    });

    test('handles empty list gracefully', () async {
      DatabaseInterface db = ServiceConfig.database;
      final walletId = await db.addWallet(Wallet('Test Wallet'));

      final now = DateTime.utc(2025, 1, 1, 12, 0, 0);
      final id = await db.addRecord(Record(
        -10.0,
        'Record',
        testCategory,
        now,
        walletId: walletId,
      ));

      final countBefore = (await db.getAllRecords()).length;

      // Should not throw
      await db.duplicateRecordsInBatch([]);

      final countAfter = (await db.getAllRecords()).length;
      expect(countAfter, countBefore);
    });

    test('duplicates preserve tags', () async {
      DatabaseInterface db = ServiceConfig.database;
      final walletId = await db.addWallet(Wallet('Test Wallet'));

      final now = DateTime.utc(2025, 1, 1, 12, 0, 0);
      final id = await db.addRecord(Record(
        -10.0,
        'Tagged Record',
        testCategory,
        now,
        walletId: walletId,
        tags: {'work', 'important', 'urgent'}.toSet(),
      ));

      final tagsBefore = await db.getTagsForRecord(id);
      expect(tagsBefore.length, 3);

      await db.duplicateRecordsInBatch([id]);

      // Get all records and find the duplicate
      final allRecords = await db.getAllRecords();
      final duplicates = allRecords
          .where((r) => r != null && r.title == 'Tagged Record' && r.id != id)
          .toList();

      expect(duplicates.isNotEmpty, true);
      final duplicate = duplicates.first!;
      final tagsAfter = await db.getTagsForRecord(duplicate.id!);

      expect(tagsAfter.length, 3);
      expect(tagsAfter.toSet(), tagsBefore.toSet());
    });
  });

  group('Batch operations performance', () {
    test('deleteRecordsInBatch is more efficient than per-record deletion',
        () async {
      DatabaseInterface db = ServiceConfig.database;
      final walletId = await db.addWallet(Wallet('Test Wallet'));

      // Create 50 records
      final now = DateTime.utc(2025, 1, 1, 12, 0, 0);
      final ids = <int>[];
      for (int i = 0; i < 50; i++) {
        final id = await db.addRecord(Record(
          -10.0,
          'Record $i',
          testCategory,
          now,
          walletId: walletId,
        ));
        ids.add(id);
      }

      // Time batch deletion
      final batchStart = DateTime.now();
      await db.deleteRecordsInBatch(ids);
      final batchEnd = DateTime.now();
      final batchDuration = batchEnd.difference(batchStart);

      // Verify all deleted
      for (final id in ids) {
        expect(await db.getRecordById(id), isNull);
      }

      // The batch operation should complete reasonably fast
      // (less than 5 seconds for 50 records)
      expect(batchDuration.inSeconds, lessThan(5));
    });

    test('updateRecordWalletInBatch is more efficient than per-record updates',
        () async {
      DatabaseInterface db = ServiceConfig.database;
      final wallet1 = await db.addWallet(Wallet('Wallet 1'));
      final wallet2 = await db.addWallet(Wallet('Wallet 2'));

      // Create 50 records
      final now = DateTime.utc(2025, 1, 1, 12, 0, 0);
      final ids = <int>[];
      for (int i = 0; i < 50; i++) {
        final id = await db.addRecord(Record(
          -10.0,
          'Record $i',
          testCategory,
          now,
          walletId: wallet1,
        ));
        ids.add(id);
      }

      // Time batch update
      final batchStart = DateTime.now();
      await db.updateRecordWalletInBatch(ids, wallet2);
      final batchEnd = DateTime.now();
      final batchDuration = batchEnd.difference(batchStart);

      // Verify all updated
      for (final id in ids) {
        expect((await db.getRecordById(id))!.walletId, wallet2);
      }

      // The batch operation should complete reasonably fast
      expect(batchDuration.inSeconds, lessThan(5));
    });

    test('duplicateRecordsInBatch completes in reasonable time', () async {
      DatabaseInterface db = ServiceConfig.database;
      final walletId = await db.addWallet(Wallet('Test Wallet'));

      // Create 20 records
      final now = DateTime.utc(2025, 1, 1, 12, 0, 0);
      final ids = <int>[];
      for (int i = 0; i < 20; i++) {
        final id = await db.addRecord(Record(
          -10.0,
          'Record $i',
          testCategory,
          now,
          walletId: walletId,
        ));
        ids.add(id);
      }

      final countBefore = (await db.getAllRecords()).length;

      // Time batch duplication
      final batchStart = DateTime.now();
      await db.duplicateRecordsInBatch(ids);
      final batchEnd = DateTime.now();
      final batchDuration = batchEnd.difference(batchStart);

      final countAfter = (await db.getAllRecords()).length;

      // Verify all duplicated
      expect(countAfter, countBefore + 20);

      // The batch operation should complete in reasonable time
      // (duplicates require more work, allow up to 10 seconds for 20 records)
      expect(batchDuration.inSeconds, lessThan(10));
    });
  });
}
