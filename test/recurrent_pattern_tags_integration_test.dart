import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/models/category.dart';
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
  group('Recurrent Pattern Tags Integration Test', () {
    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      tz.initializeTimeZones();
      ServiceConfig.localTimezone = "Europe/Vienna";
    });

    setUp(() async {
      // Create a new isolated in-memory database for each test
      await TestDatabaseHelper.setupTestDatabase();
    });

    test(
        'Records generated from recurrent patterns should have associated tags in database',
        () async {
      DatabaseInterface db = ServiceConfig.database;
      RecurrentRecordService service = RecurrentRecordService();

      // Create a category
      final category = Category("Subscription");
      await db.addCategory(category);

      // Create a recurrent pattern with tags
      final pattern = RecurrentRecordPattern(
        50.0,
        "Netflix",
        category,
        DateTime.utc(2023, 1, 1),
        RecurrentPeriod.EveryMonth,
        tags: {'streaming', 'entertainment', 'monthly'}.toSet(),
      );

      await db.addRecurrentRecordPattern(pattern);

      // Simulate the recurrent record service generating records
      await service.updateRecurrentRecords(DateTime.now().toUtc());

      // Retrieve all records from the database
      final allRecords = await db.getAllRecords();

      // Verify records were created
      expect(allRecords.isNotEmpty, true,
          reason: 'Records should have been generated from the pattern');

      // Verify each record has the tags from the pattern
      for (var record in allRecords) {
        expect(record?.tags, isNotEmpty,
            reason: 'Each generated record should have tags');
        expect(record?.tags,
            containsAll(['streaming', 'entertainment', 'monthly']),
            reason:
                'Each generated record should have all tags from the recurrent pattern');
      }

      // Verify we can query by tags
      final taggedRecords = await db.getAggregatedRecordsByTagInInterval(
          DateTime.utc(2023, 1, 1), DateTime.now().toUtc());

      expect(
          taggedRecords
              .any((element) => element['key'] == 'streaming'),
          true,
          reason: 'Should be able to find records by streaming tag');
      expect(
          taggedRecords
              .any((element) => element['key'] == 'entertainment'),
          true,
          reason: 'Should be able to find records by entertainment tag');
      expect(
          taggedRecords
              .any((element) => element['key'] == 'monthly'),
          true,
          reason: 'Should be able to find records by monthly tag');
    });

    test(
        'Records generated from a recurrent transfer pattern should have walletId and transferWalletId set',
        () async {
      DatabaseInterface db = ServiceConfig.database;
      RecurrentRecordService service = RecurrentRecordService();

      final category = Category("Bills");
      await db.addCategory(category);

      final sourceWallet = Wallet("Checking", initialAmount: 0);
      final destWallet = Wallet("Savings", initialAmount: 0);
      final sourceId = await db.addWallet(sourceWallet);
      final destId = await db.addWallet(destWallet);

      final pattern = RecurrentRecordPattern(
        -200.0,
        "Monthly savings transfer",
        category,
        DateTime.utc(2023, 1, 1),
        RecurrentPeriod.EveryMonth,
        walletId: sourceId,
        transferWalletId: destId,
      );
      await db.addRecurrentRecordPattern(pattern);

      await service.updateRecurrentRecords(DateTime.utc(2023, 3, 31));

      final allRecords = await db.getAllRecords();
      expect(allRecords.isNotEmpty, true);
      for (var record in allRecords) {
        expect(record?.walletId, sourceId,
            reason: 'Generated record should have the source walletId');
        expect(record?.transferWalletId, destId,
            reason: 'Generated record should have the destination transferWalletId');
        expect(record?.isTransfer, isTrue,
            reason: 'Generated record should be identified as a transfer');
      }
    });

    test(
        'Non-transfer recurrent pattern should produce records with null transferWalletId',
        () async {
      DatabaseInterface db = ServiceConfig.database;
      RecurrentRecordService service = RecurrentRecordService();

      final category = Category("Rent");
      await db.addCategory(category);

      final wallet = Wallet("Cash", initialAmount: 0);
      final walletId = await db.addWallet(wallet);

      final pattern = RecurrentRecordPattern(
        -800.0,
        "Monthly rent",
        category,
        DateTime.utc(2023, 1, 1),
        RecurrentPeriod.EveryMonth,
        walletId: walletId,
        // no transferWalletId
      );
      await db.addRecurrentRecordPattern(pattern);

      await service.updateRecurrentRecords(DateTime.utc(2023, 3, 31));

      final allRecords = await db.getAllRecords();
      expect(allRecords.isNotEmpty, true);
      for (var record in allRecords) {
        expect(record?.walletId, walletId);
        expect(record?.transferWalletId, isNull);
        expect(record?.isTransfer, isFalse);
      }
    });

    test(
        'Recurrent transfer pattern is persisted and reloaded correctly from database',
        () async {
      DatabaseInterface db = ServiceConfig.database;

      final category = Category("Investments");
      await db.addCategory(category);

      final sourceWallet = Wallet("Main", initialAmount: 0);
      final destWallet = Wallet("Investment", initialAmount: 0);
      final sourceId = await db.addWallet(sourceWallet);
      final destId = await db.addWallet(destWallet);

      final pattern = RecurrentRecordPattern(
        -500.0,
        "Investment transfer",
        category,
        DateTime.utc(2023, 6, 1),
        RecurrentPeriod.EveryMonth,
        walletId: sourceId,
        transferWalletId: destId,
      );
      // addRecurrentRecordPattern assigns a UUID to pattern.id in place
      await db.addRecurrentRecordPattern(pattern);

      final loaded = await db.getRecurrentRecordPattern(pattern.id);
      expect(loaded, isNotNull);
      expect(loaded!.walletId, sourceId);
      expect(loaded.transferWalletId, destId);
    });
  });
}
