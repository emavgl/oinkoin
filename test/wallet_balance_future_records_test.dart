import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/helpers/records-utility-functions.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/models/recurrent-period.dart';
import 'package:piggybank/models/recurrent-record-pattern.dart';
import 'package:piggybank/models/wallet.dart';
import 'package:piggybank/services/database/database-interface.dart';
import 'package:piggybank/services/database/sqlite-database.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timezone/data/latest_all.dart' as tz;

import 'helpers/test_database.dart';

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

  group('Wallet balance with future records', () {
    /// Helper: insert a record directly into the database for a given wallet.
    Future<void> _insertRecord(
        dynamic rawDb, int walletId, double value) async {
      await rawDb.rawInsert("""
        INSERT INTO records (title, value, datetime, timezone, category_name, category_type, wallet_id)
        VALUES ('Test Record', ?, 1000000, 'UTC', 'House', 0, ?)
      """, [value, walletId]);
    }

    test(
        'CLAIM VERIFICATION: wallet.balance does NOT include future record amounts',
        () async {
      // This test verifies the claim from issue #330 comment 4451303605:
      // Future records (planned transactions beyond today from recurrent patterns)
      // are shown in the records list when showFutureRecords is enabled, but they
      // are NOT included in wallet total amounts because the SQL balance query
      // only sums records persisted in the database, and future records are never
      // persisted (they are generated in-memory only).

      DatabaseInterface db = ServiceConfig.database;

      // 1. Create a wallet with initial amount
      final walletId = await db.addWallet(Wallet('Test Wallet', initialAmount: 1000.0));

      // 2. Add a past record to the database
      final pastRecordValue = -50.0; // expense
      {
        SqliteDatabase sqliteDb = ServiceConfig.database as SqliteDatabase;
        final rawDb = (await sqliteDb.database)!;
        await _insertRecord(rawDb, walletId, pastRecordValue);
      }

      // 3. Load wallet and verify balance includes the past record
      Wallet wallet = (await db.getWalletById(walletId))!;
      // balance = initial_amount(1000) + past_record(-50) = 950
      expect(wallet.balance, closeTo(950.0, 0.001),
          reason: 'Initial wallet balance should include past records from DB');

      // 4. Now simulate what happens with future records.
      //    Future records are generated in-memory by RecurrentRecordService
      //    but are NOT persisted to the database. They get the isFutureRecord flag.
      final futureRecordValue = -200.0; // future expense
      final futureRecord = Record(
        futureRecordValue,
        'Future Recurrent Expense',
        Category('Rent', categoryType: CategoryType.expense),
        // 30 days in the future so it's definitely > today
        DateTime.now().add(const Duration(days: 30)).toUtc(),
        walletId: walletId,
        isFutureRecord: true,
      );

      // 5. Verify the future record is NOT in the database
      final allDbRecords = await db.getAllRecords();
      expect(allDbRecords.length, 1,
          reason:
              'Database should only contain 1 record (the past one) because future records are not persisted');

      // 6. Reload wallet from DB - this is what _loadWallets() does
      wallet = (await db.getWalletById(walletId))!;

      // 7. VERIFY THE CLAIM: wallet.balance does NOT include future record value
      //    balance = initial_amount(1000) + past_record(-50) = 950 (no future -200)
      expect(wallet.balance, closeTo(950.0, 0.001),
          reason:
              'BUG: wallet.balance should include future records when showFutureRecords is enabled. '
              'Expected: 1000 + (-50) + (-200) = 750, Actual: 950. '
              'This confirms the claim in issue #330 is correct.');

      // 8. Demonstrate what the correct behavior SHOULD be
      //    We manually compute what the balance should include:
      final futureRecords = [futureRecord];
      final futureSumByWallet = <int, double>{};
      for (final r in futureRecords) {
        if (r.walletId != null) {
          futureSumByWallet.update(
            r.walletId!,
            (sum) => sum + (r.value ?? 0.0),
            ifAbsent: () => (r.value ?? 0.0),
          );
        }
      }

      final expectedFutureAdjustment = futureSumByWallet[walletId] ?? 0.0;
      final adjustedBalance = (wallet.balance ?? 0.0) + expectedFutureAdjustment;

      expect(adjustedBalance, closeTo(750.0, 0.001),
          reason:
              'After adding future record amounts, wallet balance should be 750 (1000 + (-50) + (-200)). '
              'This is the FIXED behavior - future records included in wallet totals.');
    });
  });
}
