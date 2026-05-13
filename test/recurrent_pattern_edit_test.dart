import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/models/recurrent-period.dart';
import 'package:piggybank/models/recurrent-record-pattern.dart';
import 'package:piggybank/models/wallet.dart';
import 'package:piggybank/services/database/database-interface.dart';
import 'package:piggybank/services/recurrent-record-service.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timezone/data/latest_all.dart' as tz;

import 'helpers/test_database.dart';

void main() {
  final testCategoryExpense = Category(
    "Rent",
    iconCodePoint: 1,
    categoryType: CategoryType.expense,
    color: Colors.blue,
  );

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

  group('Recurrent pattern editing preserves past records', () {
    test('editing metadata (amount/title) should preserve past records',
        () async {
      final db = ServiceConfig.database;
      await db.addCategory(testCategoryExpense);

      // Create a recurrent pattern that started 6 months ago
      final patternId = "pattern-edit-test";
      final patternStartDate = DateTime.utc(2023, 1, 1);
      final pattern = RecurrentRecordPattern(
        100.0,
        "Monthly Rent",
        testCategoryExpense,
        patternStartDate,
        RecurrentPeriod.EveryMonth,
        id: patternId,
      );
      await db.addRecurrentRecordPattern(pattern);

      // Insert past records linked to the pattern (Jan through May = 5 records)
      final pastRecords = [
        Record(100.0, "Rent", testCategoryExpense, DateTime.utc(2023, 1, 1),
            recurrencePatternId: patternId),
        Record(100.0, "Rent", testCategoryExpense, DateTime.utc(2023, 2, 1),
            recurrencePatternId: patternId),
        Record(100.0, "Rent", testCategoryExpense, DateTime.utc(2023, 3, 1),
            recurrencePatternId: patternId),
        Record(100.0, "Rent", testCategoryExpense, DateTime.utc(2023, 4, 1),
            recurrencePatternId: patternId),
        Record(100.0, "Rent", testCategoryExpense, DateTime.utc(2023, 5, 1),
            recurrencePatternId: patternId),
      ];
      await db.addRecordsInBatch(pastRecords);

      // Insert one future record (July - beyond the "now" cutoff)
      final futureRecord = Record(
          100.0, "Rent", testCategoryExpense, DateTime.utc(2023, 7, 1),
          recurrencePatternId: patternId);
      await db.addRecord(futureRecord);

      // Simulate editing the pattern: use "now" as the cutoff for deleting
      // future records, NOT the pattern's start date (the fix for #350).
      final now = DateTime.utc(2023, 6, 15);
      await db.deleteFutureRecordsByPatternId(patternId, now);

      // Update the pattern with new values (e.g., user changed the amount)
      final updatedPattern = RecurrentRecordPattern(
        200.0,
        "Updated Rent",
        testCategoryExpense,
        patternStartDate,
        RecurrentPeriod.EveryMonth,
        id: patternId,
      );
      await db.updateRecordPatternById(patternId, updatedPattern);

      // Verify the pattern was updated
      final retrievedPattern = await db.getRecurrentRecordPattern(patternId);
      expect(retrievedPattern?.value, 200.0);
      expect(retrievedPattern?.title, "Updated Rent");

      // Key assertion: all 5 past records are preserved
      final allRecords = await db.getAllRecords();
      expect(allRecords.length, 5);
      for (var r in allRecords) {
        expect(r!.utcDateTime.isBefore(now), isTrue,
            reason: 'Record at ${r.utcDateTime} should be before cutoff $now');
      }
    });

    test('editing with period change should preserve past records', () async {
      final db = ServiceConfig.database;
      await db.addCategory(testCategoryExpense);

      final patternId = "pattern-period-change-test";
      final patternStartDate = DateTime.utc(2023, 1, 1);
      final pattern = RecurrentRecordPattern(
        50.0,
        "Weekly",
        testCategoryExpense,
        patternStartDate,
        RecurrentPeriod.EveryWeek,
        id: patternId,
      );
      await db.addRecurrentRecordPattern(pattern);

      // Insert 3 past records and 1 future record
      await db.addRecordsInBatch([
        Record(50.0, "Weekly", testCategoryExpense, DateTime.utc(2023, 1, 1),
            recurrencePatternId: patternId),
        Record(50.0, "Weekly", testCategoryExpense, DateTime.utc(2023, 1, 8),
            recurrencePatternId: patternId),
        Record(50.0, "Weekly", testCategoryExpense, DateTime.utc(2023, 1, 15),
            recurrencePatternId: patternId),
      ]);
      await db.addRecord(Record(
          50.0, "Weekly", testCategoryExpense, DateTime.utc(2023, 3, 1),
          recurrencePatternId: patternId));

      // Simulate period change: delete future records + delete old pattern +
      // create a new pattern (period change creates a new UUID).
      final now = DateTime.utc(2023, 2, 1);
      await db.deleteFutureRecordsByPatternId(patternId, now);
      await db.deleteRecurrentRecordPatternById(patternId);
      // Create a replacement pattern (new UUID auto-assigned)
      await db.addRecurrentRecordPattern(RecurrentRecordPattern(
        75.0,
        "Monthly",
        testCategoryExpense,
        patternStartDate,
        RecurrentPeriod.EveryMonth,
      ));

      // Verify the 3 past records from the old pattern are preserved
      final allRecords = await db.getAllRecords();
      expect(allRecords.length, 3);
      for (var r in allRecords) {
        expect(r!.utcDateTime.isBefore(now), isTrue,
            reason: 'Record at ${r.utcDateTime} should be before cutoff $now');
      }
    });

    test(
        'deleteFutureRecordsByPatternId with pattern start date '
        'deletes past records (demonstrating the bug)', () async {
      // This test demonstrates the buggy behavior: if the pattern's start
      // date is used as the cutoff instead of "now", past records are deleted.
      final db = ServiceConfig.database;
      await db.addCategory(testCategoryExpense);

      final patternId = "pattern-bug-demo";
      // Pattern started in January
      final patternStartDate = DateTime.utc(2023, 1, 1);
      final pattern = RecurrentRecordPattern(
        100.0,
        "Rent",
        testCategoryExpense,
        patternStartDate,
        RecurrentPeriod.EveryMonth,
        id: patternId,
      );
      await db.addRecurrentRecordPattern(pattern);

      // Insert records for Jan, Feb, Mar (all past relative to June)
      await db.addRecordsInBatch([
        Record(100.0, "Rent", testCategoryExpense, DateTime.utc(2023, 1, 1),
            recurrencePatternId: patternId),
        Record(100.0, "Rent", testCategoryExpense, DateTime.utc(2023, 2, 1),
            recurrencePatternId: patternId),
        Record(100.0, "Rent", testCategoryExpense, DateTime.utc(2023, 3, 1),
            recurrencePatternId: patternId),
      ]);

      // Using the pattern's start date as cutoff (the old buggy behavior)
      await db.deleteFutureRecordsByPatternId(patternId, patternStartDate);

      // All records including past ones would be deleted
      final allRecords = await db.getAllRecords();
      expect(allRecords.length, 0);
    });
  });

  group('Recurrent pattern wallet update', () {
    late DatabaseInterface db;
    late RecurrentRecordService service;
    late Category testCategory;

    setUp(() async {
      await TestDatabaseHelper.setupTestDatabase();
      db = ServiceConfig.database;
      service = RecurrentRecordService();

      testCategory = Category("Rent",
          categoryType: CategoryType.expense, color: Colors.blue);
      await db.addCategory(testCategory);
    });

    test('changing pattern wallet preserves past records with old wallet',
        () async {
      // Create two wallets
      final walletA = Wallet("Checking", initialAmount: 0);
      final walletB = Wallet("Savings", initialAmount: 0);
      final walletAId = await db.addWallet(walletA);
      final walletBId = await db.addWallet(walletB);

      // Create a recurrent pattern assigned to walletA
      final patternId = "pattern-wallet-change-1";
      final patternStartDate = DateTime.utc(2023, 1, 1);
      final pattern = RecurrentRecordPattern(
        -50.0,
        "Monthly Bill",
        testCategory,
        patternStartDate,
        RecurrentPeriod.EveryMonth,
        walletId: walletAId,
        id: patternId,
      );
      await db.addRecurrentRecordPattern(pattern);

      // Generate past records (Jan-May 2023) with walletA
      await service.updateRecurrentRecords(DateTime.utc(2023, 5, 31));

      // Verify past records have walletA
      var allRecords = await db.getAllRecords();
      expect(allRecords.length, 5);
      for (var r in allRecords) {
        expect(r!.walletId, walletAId,
            reason: 'Past record should have original walletA');
      }

      // Simulate user changing the pattern's wallet to walletB
      // (mirrors what addOrUpdateRecurrentPattern does without period change)
      final now = DateTime.utc(2023, 6, 15);
      await db.deleteFutureRecordsByPatternId(patternId, now);

      final updatedPattern = RecurrentRecordPattern(
        -50.0,
        "Monthly Bill",
        testCategory,
        patternStartDate,
        RecurrentPeriod.EveryMonth,
        walletId: walletBId,
        id: patternId,
      );
      updatedPattern.utcLastUpdate = DateTime.utc(2023, 5, 31);
      await db.updateRecordPatternById(patternId, updatedPattern);

      // Verify the pattern now references walletB
      final retrieved = await db.getRecurrentRecordPattern(patternId);
      expect(retrieved!.walletId, walletBId,
          reason: 'Pattern should be updated to walletB');

      // Key assertion: past records still have walletA (no regression)
      allRecords = await db.getAllRecords();
      expect(allRecords.length, 5);
      for (var r in allRecords) {
        expect(r!.walletId, walletAId,
            reason:
                'Past record must retain original walletA after pattern wallet change');
      }
    });

    test('newly generated records after wallet change use new wallet',
        () async {
      // Create two wallets
      final walletA = Wallet("Checking", initialAmount: 0);
      final walletB = Wallet("Savings", initialAmount: 0);
      final walletAId = await db.addWallet(walletA);
      final walletBId = await db.addWallet(walletB);

      // Create a pattern with walletA and generate past records
      final patternId = "pattern-wallet-change-2";
      final patternStartDate = DateTime.utc(2023, 1, 1);
      final pattern = RecurrentRecordPattern(
        -50.0,
        "Monthly Bill",
        testCategory,
        patternStartDate,
        RecurrentPeriod.EveryMonth,
        walletId: walletAId,
        id: patternId,
      );
      await db.addRecurrentRecordPattern(pattern);

      // Generate records Jan-May (past)
      await service.updateRecurrentRecords(DateTime.utc(2023, 5, 31));

      // Verify initial records all have walletA
      var allRecords = await db.getAllRecords();
      final initialCount = allRecords.length;
      expect(initialCount, greaterThan(0));
      for (var r in allRecords) {
        expect(r!.walletId, walletAId,
            reason: 'Initial records should all have walletA');
      }

      // Change the pattern's wallet to walletB
      final now = DateTime.utc(2023, 6, 15);
      await db.deleteFutureRecordsByPatternId(patternId, now);

      final updatedPattern = RecurrentRecordPattern(
        -50.0,
        "Monthly Bill",
        testCategory,
        patternStartDate,
        RecurrentPeriod.EveryMonth,
        walletId: walletBId,
        id: patternId,
      );
      updatedPattern.utcLastUpdate = DateTime.utc(2023, 5, 31);
      await db.updateRecordPatternById(patternId, updatedPattern);

      // Generate records again with extended end date
      await service.updateRecurrentRecords(DateTime.utc(2023, 8, 31));

      // Retrieve all records and count by wallet
      allRecords = await db.getAllRecords();
      expect(allRecords.length, greaterThan(initialCount),
          reason: 'Should have generated new records');

      // Records with walletA should be the original set
      final walletARecords =
          allRecords.where((r) => r!.walletId == walletAId).toList();
      expect(walletARecords.length, initialCount,
          reason: 'Past records with walletA should be preserved');

      // Records with walletB should be the newly generated ones
      final walletBRecords =
          allRecords.where((r) => r!.walletId == walletBId).toList();
      expect(walletBRecords.length, greaterThan(0),
          reason: 'New records should use the updated walletB');
      expect(walletBRecords.length, allRecords.length - initialCount,
          reason: 'All records beyond the initial set should use walletB');

      // No records should be null-wallet or other
      for (var r in allRecords) {
        expect(r!.walletId, anyOf(walletAId, walletBId),
            reason:
                'All records must be assigned to either walletA or walletB');
      }
    });

    test('pattern created without walletId gets default wallet from migration',
        () async {
      // onCreate already inserts a default wallet via SqliteMigrationService
      final defaultWallet = await db.getDefaultWallet();
      expect(defaultWallet, isNotNull);

      // Access the raw database through SqliteDatabase to insert
      // a pattern with null wallet_id (simulating pre-v20 state)
      final dbRaw = await (db as dynamic).database;

      final patternId = "pattern-no-wallet";
      await dbRaw.rawInsert(
        "INSERT INTO recurrent_record_patterns "
        "(id, datetime, value, title, category_name, category_type, "
        "last_update, recurrent_period, wallet_id) "
        "VALUES (?, ?, ?, ?, ?, ?, ?, ?, NULL)",
        [
          patternId,
          DateTime.utc(2023, 1, 1).millisecondsSinceEpoch,
          -30.0,
          "Pre-migration pattern",
          testCategory.name,
          testCategory.categoryType!.index,
          DateTime.utc(2023, 1, 1).millisecondsSinceEpoch,
          RecurrentPeriod.EveryMonth.index,
        ],
      );

      // Verify pattern has null walletId before backfill
      var retrieved = await db.getRecurrentRecordPattern(patternId);
      expect(retrieved!.walletId, isNull,
          reason: 'Pattern should have no walletId before backfill');

      // Run the backfill logic directly
      final defaultWalletId = defaultWallet!.id;
      await dbRaw.rawUpdate(
        "UPDATE recurrent_record_patterns SET wallet_id = ? WHERE wallet_id IS NULL",
        [defaultWalletId],
      );

      // Verify pattern now has the default wallet
      retrieved = await db.getRecurrentRecordPattern(patternId);
      expect(retrieved!.walletId, defaultWalletId,
          reason: 'Pattern should have default wallet after backfill');
    });
  });

  group('Recurrent pattern wallet init', () {
    late DatabaseInterface db;
    late Category testCategory;

    setUp(() async {
      await TestDatabaseHelper.setupTestDatabase();
      db = ServiceConfig.database;

      testCategory = Category('Rent',
          categoryType: CategoryType.expense, color: Colors.blue);
      await db.addCategory(testCategory);
    });

    test('RecurrentRecordPattern.fromRecord copies walletId', () async {
      final wallet = Wallet('Checking', initialAmount: 0);
      final walletId = await db.addWallet(wallet);

      final record = Record(
        -50.0,
        'Bill',
        testCategory,
        DateTime.utc(2023, 1, 1),
        walletId: walletId,
      );

      final pattern =
          RecurrentRecordPattern.fromRecord(record, RecurrentPeriod.EveryMonth);

      expect(pattern.walletId, walletId,
          reason:
              'fromRecord must copy walletId from the source Record');
    });

    test('RecurrentRecordPattern.fromRecord copies transferWalletId and transferValue',
        () async {
      final src = Wallet('Checking', initialAmount: 0);
      final dst = Wallet('Savings', initialAmount: 0);
      final srcId = await db.addWallet(src);
      final dstId = await db.addWallet(dst);

      final record = Record(
        -50.0,
        'Transfer',
        testCategory,
        DateTime.utc(2023, 1, 1),
        walletId: srcId,
        transferWalletId: dstId,
        transferValue: 50.0,
      );

      final pattern =
          RecurrentRecordPattern.fromRecord(record, RecurrentPeriod.EveryMonth);

      expect(pattern.walletId, srcId,
          reason: 'fromRecord must copy walletId');
      expect(pattern.transferWalletId, dstId,
          reason: 'fromRecord must copy transferWalletId');
      expect(pattern.transferValue, 50.0,
          reason: 'fromRecord must copy transferValue');
    });

    test(
        'editing pattern preserves walletId through deleteFuture + update cycle',
        () async {
      final walletA = Wallet('Checking', initialAmount: 0);
      final walletB = Wallet('Savings', initialAmount: 0);
      final walletAId = await db.addWallet(walletA);
      await db.addWallet(walletB);

      // Create pattern with walletA
      final patternId = 'pattern-preserve-wallet-edit';
      const patternValue = -50.0;
      const patternTitle = 'Bill';
      final patternStartDate = DateTime.utc(2023, 1, 1);
      final pattern = RecurrentRecordPattern(
        patternValue,
        patternTitle,
        testCategory,
        patternStartDate,
        RecurrentPeriod.EveryMonth,
        walletId: walletAId,
        id: patternId,
      );
      await db.addRecurrentRecordPattern(pattern);

      // Generate some past records
      final service = RecurrentRecordService();
      await service.updateRecurrentRecords(DateTime.utc(2023, 5, 31));

      // Simulate the edit-record-page flow:
      // 1. Load the pattern from DB
      final loaded = await db.getRecurrentRecordPattern(patternId);
      expect(loaded, isNotNull);
      expect(loaded!.walletId, walletAId,
          reason: 'Pattern should have walletA before edit');

      // 2. Create a new Record from the loaded pattern with the same walletId
      //    (this mirrors initState in EditRecordPage)
      final recordFromPattern = Record(
        loaded.value,
        loaded.title,
        loaded.category,
        loaded.utcDateTime,
        timeZoneName: loaded.timeZoneName,
        description: loaded.description,
        tags: loaded.tags,
        walletId: loaded.walletId, // <-- the fix: copy walletId from pattern
        transferWalletId: loaded.transferWalletId,
        transferValue: loaded.transferValue,
        profileId: loaded.profileId,
      );

      // 3. Create an updated pattern from that Record
      //    (mirrors addOrUpdateRecurrentPattern)
      final updatedPattern = RecurrentRecordPattern.fromRecord(
        recordFromPattern,
        loaded.recurrentPeriod!,
        id: loaded.id,
        utcEndDate: loaded.utcEndDate,
      );

      // 4. Delete future records (no period change, just save)
      final now = DateTime.utc(2023, 6, 15);
      await db.deleteFutureRecordsByPatternId(patternId, now);

      // 5. Update the pattern
      await db.updateRecordPatternById(patternId, updatedPattern);

      // Verify walletId survived the full cycle
      final result = await db.getRecurrentRecordPattern(patternId);
      expect(result!.walletId, walletAId,
          reason:
              'walletId must be preserved through deleteFuture + update cycle');
    });

    test('getPredefinedWallet returns correct wallet after setPredefinedWallet',
        () async {
      // onCreate creates a default wallet with is_default=1 but
      // is_predefined is not set (fresh DBs don't run migrations).
      final defaultWallet = await db.getDefaultWallet();
      expect(defaultWallet, isNotNull,
          reason: 'precondition: default wallet must exist');

      final walletA = Wallet('Wallet A', initialAmount: 0);
      final walletB = Wallet('Wallet B', initialAmount: 0);
      final walletAId = await db.addWallet(walletA);
      final walletBId = await db.addWallet(walletB);

      // No wallet is predefined initially (fresh DB)
      final before = await db.getPredefinedWallet();
      expect(before, isNull,
          reason:
              'Fresh DB has no predefined wallet until one is explicitly set');

      // Set walletA as predefined
      await db.setPredefinedWallet(walletAId);

      var predefinedA = await db.getPredefinedWallet();
      expect(predefinedA, isNotNull);
      expect(predefinedA!.id, walletAId,
          reason: 'getPredefinedWallet should return walletA after setting it');

      // Set walletB as predefined (replaces walletA)
      await db.setPredefinedWallet(walletBId);

      final predefinedB = await db.getPredefinedWallet();
      expect(predefinedB, isNotNull);
      expect(predefinedB!.id, walletBId,
          reason: 'getPredefinedWallet should return walletB after setting it');

      // Verify walletA is NO longer predefined
      predefinedA = await db.getPredefinedWallet();
      expect(predefinedA!.id, walletBId,
          reason:
              'After reassigning, the predefined wallet should be walletB, not walletA');

      // Default wallet should NOT change
      final defaultW = await db.getDefaultWallet();
      expect(defaultW, isNotNull);
      expect(defaultW!.id, isNot(walletBId),
          reason:
              'Changing predefined wallet must NOT change the default wallet');
    });

    test('new record without wallet uses predefined wallet (not default)',
        () async {
      // Setup: create walletA as predefined, walletB as default
      final walletA = Wallet('Wallet A', initialAmount: 0);
      final walletB = Wallet('Wallet B', initialAmount: 0);
      final walletAId = await db.addWallet(walletA);
      final walletBId = await db.addWallet(walletB);

      await db.setPredefinedWallet(walletAId);

      // Verify the two are distinct
      final predefined = await db.getPredefinedWallet();
      final defaultW = await db.getDefaultWallet();
      expect(predefined!.id, walletAId,
          reason: 'precondition: walletA should be predefined');
      expect(defaultW!.id, isNot(walletAId),
          reason: 'precondition: default should be different from predefined');

      // Simulate _initWallet() logic for a NEW record (record.walletId == null):
      Wallet? walletToSelect;
      walletToSelect = await db.getPredefinedWallet();
      if (walletToSelect == null) {
        walletToSelect = defaultW;
      }

      expect(walletToSelect.id, walletAId,
          reason:
              'A new record should use the predefined wallet, not the default');
    });

    test(
        'new record without predefined wallet and only one wallet uses that wallet',
        () async {
      // There's already a default wallet from test setup.
      // Delete all wallets and create exactly one.
      final wallets = await db.getAllWallets();
      for (final w in wallets) {
        if (w.id != null) {
          await db.deleteWalletAndRecords(w.id!);
        }
      }

      final walletA = Wallet('Solo Wallet', initialAmount: 0);
      final walletAId = await db.addWallet(walletA);

      // Verify no predefined wallet exists
      final predefined = await db.getPredefinedWallet();
      expect(predefined, isNull,
          reason: 'precondition: no predefined wallet should exist');

      // Simulate _initWallet() fallback logic for a NEW record:
      final allWallets = await db.getAllWallets();
      final activeWallets = allWallets.where((w) => !w.isArchived).toList();

      Wallet? walletToSelect;
      walletToSelect = await db.getPredefinedWallet();
      if (walletToSelect == null && activeWallets.length == 1) {
        walletToSelect = activeWallets.first;
      }
      walletToSelect ??= await db.getDefaultWallet();

      expect(walletToSelect, isNotNull);
      expect(walletToSelect!.id, walletAId,
          reason:
              'With one wallet and no predefined, the solo wallet should be selected');
    });
  });
}
