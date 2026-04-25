import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/models/profile.dart';
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
    ServiceConfig.localTimezone = 'Europe/Vienna';
  });

  setUp(() async {
    await TestDatabaseHelper.setupTestDatabase();
  });

  // ---------------------------------------------------------------------------
  // Fresh install
  // ---------------------------------------------------------------------------
  group('Fresh install', () {
    test('creates exactly one Default Profile', () async {
      final db = ServiceConfig.database;
      final profiles = await db.getAllProfiles();
      expect(profiles.where((p) => p.isDefault).length, 1,
          reason: 'onCreate must insert exactly one default profile');
    });

    test('Default Profile has a non-empty name and is marked isDefault', () async {
      final db = ServiceConfig.database;
      final defaultProfile = await db.getDefaultProfile();
      expect(defaultProfile, isNotNull,
          reason: 'getDefaultProfile() should return a profile on a fresh DB');
      expect(defaultProfile!.isDefault, isTrue);
      expect(defaultProfile.name.trim(), isNotEmpty);
    });

    test('Default Wallet is linked to the Default Profile', () async {
      final db = ServiceConfig.database;
      final defaultProfile = await db.getDefaultProfile();
      final defaultWallet = await db.getDefaultWallet();
      expect(defaultWallet, isNotNull);
      expect(defaultWallet!.profileId, defaultProfile!.id,
          reason: 'Default Wallet must belong to the Default Profile');
    });
  });

  // ---------------------------------------------------------------------------
  // Profile CRUD
  // ---------------------------------------------------------------------------
  group('Profile CRUD', () {
    test('addProfile returns a positive id', () async {
      final db = ServiceConfig.database;
      final id = await db.addProfile(Profile('Work'));
      expect(id, greaterThan(0));
    });

    test('addProfile new profile is not marked as default', () async {
      final db = ServiceConfig.database;
      final id = await db.addProfile(Profile('Side Project'));
      final retrieved = await db.getProfileById(id);
      expect(retrieved!.isDefault, isFalse,
          reason: 'Newly created profiles must never become the default '
              'automatically — that would break the single-default invariant');
    });

    test('getAllProfiles returns Default Profile plus any added profiles', () async {
      final db = ServiceConfig.database;
      await db.addProfile(Profile('Work'));
      await db.addProfile(Profile('Family'));

      final profiles = await db.getAllProfiles();
      // onCreate creates 1 default; we added 2 more
      expect(profiles.length, 3);
      expect(profiles.any((p) => p.name == 'Work'), isTrue);
      expect(profiles.any((p) => p.name == 'Family'), isTrue);
    });

    test('getDefaultProfile always returns the single default profile', () async {
      final db = ServiceConfig.database;
      await db.addProfile(Profile('Work'));
      await db.addProfile(Profile('Travel'));

      final defaultProfile = await db.getDefaultProfile();
      expect(defaultProfile, isNotNull);
      expect(defaultProfile!.isDefault, isTrue);
    });

    test('getProfileById returns the correct profile', () async {
      final db = ServiceConfig.database;
      final id = await db.addProfile(Profile('Travel'));
      final retrieved = await db.getProfileById(id);
      expect(retrieved, isNotNull);
      expect(retrieved!.name, 'Travel');
      expect(retrieved.id, id);
    });

    test('getProfileById returns null for a non-existent id', () async {
      final db = ServiceConfig.database;
      final retrieved = await db.getProfileById(999999);
      expect(retrieved, isNull);
    });

    test('multiple profiles can coexist without interfering', () async {
      final db = ServiceConfig.database;
      final idA = await db.addProfile(Profile('Alice'));
      final idB = await db.addProfile(Profile('Bob'));

      final alice = await db.getProfileById(idA);
      final bob = await db.getProfileById(idB);

      expect(alice!.name, 'Alice');
      expect(bob!.name, 'Bob');
      expect(alice.id, isNot(bob.id));
    });
  });

  // ---------------------------------------------------------------------------
  // Data isolation — records
  // ---------------------------------------------------------------------------
  group('Record isolation between profiles', () {
    late int profileAId;
    late int profileBId;

    setUp(() async {
      final db = ServiceConfig.database;
      profileAId = await db.addProfile(Profile('Alice'));
      profileBId = await db.addProfile(Profile('Bob'));
    });

    test('records added under Profile A are not visible when querying Profile B',
        () async {
      final db = ServiceConfig.database;
      final raw = (await (db as SqliteDatabase).database)!;

      await raw.rawInsert("""
        INSERT INTO records (title, value, datetime, timezone, category_name, category_type, profile_id)
        VALUES ('Alice Salary', 2000.0, 1000000, 'UTC', 'Salary', 1, ?)
      """, [profileAId]);

      final forA = await db.getAllRecords(profileId: profileAId);
      final forB = await db.getAllRecords(profileId: profileBId);

      expect(forA.length, 1);
      expect(forA.first!.title, 'Alice Salary');
      expect(forB.length, 0,
          reason: "Bob must not see Alice's records");
    });

    test('records added under Profile B are not visible when querying Profile A',
        () async {
      final db = ServiceConfig.database;
      final raw = (await (db as SqliteDatabase).database)!;

      await raw.rawInsert("""
        INSERT INTO records (title, value, datetime, timezone, category_name, category_type, profile_id)
        VALUES ('Bob Groceries', -50.0, 2000000, 'UTC', 'Food', 0, ?)
      """, [profileBId]);

      final forA = await db.getAllRecords(profileId: profileAId);
      final forB = await db.getAllRecords(profileId: profileBId);

      expect(forA.length, 0,
          reason: "Alice must not see Bob's records");
      expect(forB.length, 1);
      expect(forB.first!.title, 'Bob Groceries');
    });

    test('records from each profile are correctly separated when both have data',
        () async {
      final db = ServiceConfig.database;
      final raw = (await (db as SqliteDatabase).database)!;

      await raw.rawInsert("""
        INSERT INTO records (title, value, datetime, timezone, category_name, category_type, profile_id)
        VALUES ('Alice Rent', -800.0, 1000000, 'UTC', 'House', 0, ?)
      """, [profileAId]);
      await raw.rawInsert("""
        INSERT INTO records (title, value, datetime, timezone, category_name, category_type, profile_id)
        VALUES ('Bob Transport', -30.0, 2000000, 'UTC', 'Transport', 0, ?)
      """, [profileBId]);

      final forA = await db.getAllRecords(profileId: profileAId);
      final forB = await db.getAllRecords(profileId: profileBId);

      expect(forA.length, 1);
      expect(forA.first!.title, 'Alice Rent');
      expect(forB.length, 1);
      expect(forB.first!.title, 'Bob Transport');
    });

    test('getAllRecords without profileId returns records from all profiles',
        () async {
      final db = ServiceConfig.database;
      final raw = (await (db as SqliteDatabase).database)!;

      await raw.rawInsert("""
        INSERT INTO records (title, value, datetime, timezone, category_name, category_type, profile_id)
        VALUES ('Alice Record', -10.0, 1000000, 'UTC', 'House', 0, ?)
      """, [profileAId]);
      await raw.rawInsert("""
        INSERT INTO records (title, value, datetime, timezone, category_name, category_type, profile_id)
        VALUES ('Bob Record', -20.0, 2000000, 'UTC', 'Food', 0, ?)
      """, [profileBId]);

      final all = await db.getAllRecords();
      final titles = all.map((r) => r!.title).toSet();
      expect(titles, containsAll(['Alice Record', 'Bob Record']));
    });
  });

  // ---------------------------------------------------------------------------
  // Data isolation — wallets
  // ---------------------------------------------------------------------------
  group('Wallet isolation between profiles', () {
    late int profileAId;
    late int profileBId;

    setUp(() async {
      final db = ServiceConfig.database;
      profileAId = await db.addProfile(Profile('Alice'));
      profileBId = await db.addProfile(Profile('Bob'));
    });

    test('wallet added to Profile A is not visible when querying Profile B',
        () async {
      final db = ServiceConfig.database;
      final walletA = Wallet('Alice Savings', initialAmount: 500.0);
      walletA.profileId = profileAId;
      await db.addWallet(walletA);

      final walletsForA = await db.getAllWallets(profileId: profileAId);
      final walletsForB = await db.getAllWallets(profileId: profileBId);

      expect(walletsForA.any((w) => w.name == 'Alice Savings'), isTrue);
      expect(walletsForB.any((w) => w.name == 'Alice Savings'), isFalse,
          reason: "Bob must not see Alice's wallet");
    });

    test('wallet added to Profile B is not visible when querying Profile A',
        () async {
      final db = ServiceConfig.database;
      final walletB = Wallet('Bob Cash', initialAmount: 100.0);
      walletB.profileId = profileBId;
      await db.addWallet(walletB);

      final walletsForA = await db.getAllWallets(profileId: profileAId);
      final walletsForB = await db.getAllWallets(profileId: profileBId);

      expect(walletsForA.any((w) => w.name == 'Bob Cash'), isFalse,
          reason: "Alice must not see Bob's wallet");
      expect(walletsForB.any((w) => w.name == 'Bob Cash'), isTrue);
    });

    test('getAllWallets without profileId returns wallets from all profiles',
        () async {
      final db = ServiceConfig.database;
      final walletA = Wallet('Alice Wallet');
      walletA.profileId = profileAId;
      await db.addWallet(walletA);

      final walletB = Wallet('Bob Wallet');
      walletB.profileId = profileBId;
      await db.addWallet(walletB);

      final all = await db.getAllWallets();
      final names = all.map((w) => w.name).toSet();
      expect(names, containsAll(['Alice Wallet', 'Bob Wallet']));
    });
  });

  // ---------------------------------------------------------------------------
  // Data isolation — recurrent patterns
  // ---------------------------------------------------------------------------
  group('Recurrent pattern isolation between profiles', () {
    late int profileAId;
    late int profileBId;

    setUp(() async {
      final db = ServiceConfig.database;
      profileAId = await db.addProfile(Profile('Alice'));
      profileBId = await db.addProfile(Profile('Bob'));
    });

    test('pattern added to Profile A is not visible when querying Profile B',
        () async {
      final db = ServiceConfig.database;
      final raw = (await (db as SqliteDatabase).database)!;

      await raw.rawInsert("""
        INSERT INTO recurrent_record_patterns
          (id, datetime, timezone, value, category_name, category_type, recurrent_period, profile_id)
        VALUES ('pattern-alice', 1000000, 'UTC', -100.0, 'House', 0, 4, ?)
      """, [profileAId]);

      final forA =
          await db.getRecurrentRecordPatterns(profileId: profileAId);
      final forB =
          await db.getRecurrentRecordPatterns(profileId: profileBId);

      expect(forA.length, 1);
      expect(forB.length, 0,
          reason: "Bob must not see Alice's recurrent patterns");
    });

    test('getRecurrentRecordPatterns without profileId returns all patterns',
        () async {
      final db = ServiceConfig.database;
      final raw = (await (db as SqliteDatabase).database)!;

      await raw.rawInsert("""
        INSERT INTO recurrent_record_patterns
          (id, datetime, timezone, value, category_name, category_type, recurrent_period, profile_id)
        VALUES ('pattern-a', 1000000, 'UTC', -100.0, 'House', 0, 4, ?)
      """, [profileAId]);
      await raw.rawInsert("""
        INSERT INTO recurrent_record_patterns
          (id, datetime, timezone, value, category_name, category_type, recurrent_period, profile_id)
        VALUES ('pattern-b', 2000000, 'UTC', -50.0, 'Food', 0, 4, ?)
      """, [profileBId]);

      final all = await db.getRecurrentRecordPatterns();
      expect(all.length, greaterThanOrEqualTo(2));
    });
  });

  // ---------------------------------------------------------------------------
  // Profile deletion
  // ---------------------------------------------------------------------------
  group('Profile deletion', () {
    test('deleteProfileAndRecords removes the profile row', () async {
      final db = ServiceConfig.database;
      final id = await db.addProfile(Profile('Temporary'));
      await db.deleteProfileAndRecords(id);
      expect(await db.getProfileById(id), isNull);
    });

    test('deleteProfileAndRecords removes all records belonging to that profile',
        () async {
      final db = ServiceConfig.database;
      final raw = (await (db as SqliteDatabase).database)!;

      final profileId = await db.addProfile(Profile('To Delete'));

      await raw.rawInsert("""
        INSERT INTO records (title, value, datetime, timezone, category_name, category_type, profile_id)
        VALUES ('Record 1', -10.0, 1000000, 'UTC', 'House', 0, ?)
      """, [profileId]);
      await raw.rawInsert("""
        INSERT INTO records (title, value, datetime, timezone, category_name, category_type, profile_id)
        VALUES ('Record 2', -20.0, 2000000, 'UTC', 'Food', 0, ?)
      """, [profileId]);

      await db.deleteProfileAndRecords(profileId);

      final remaining = await raw.query('records',
          where: 'profile_id = ?', whereArgs: [profileId]);
      expect(remaining, isEmpty,
          reason: 'Deleting a profile must wipe all its records');
    });

    test('deleteProfileAndRecords removes all wallets belonging to that profile',
        () async {
      final db = ServiceConfig.database;
      final profileId = await db.addProfile(Profile('To Delete'));

      final wallet = Wallet('Doomed Wallet');
      wallet.profileId = profileId;
      final walletId = await db.addWallet(wallet);

      await db.deleteProfileAndRecords(profileId);

      expect(await db.getWalletById(walletId), isNull,
          reason: 'Deleting a profile must wipe all its wallets');
    });

    test(
        'deleteProfileAndRecords removes all recurrent patterns belonging to that profile',
        () async {
      final db = ServiceConfig.database;
      final raw = (await (db as SqliteDatabase).database)!;

      final profileId = await db.addProfile(Profile('To Delete'));

      await raw.rawInsert("""
        INSERT INTO recurrent_record_patterns
          (id, datetime, timezone, value, category_name, category_type, recurrent_period, profile_id)
        VALUES ('doomed-pattern', 1000000, 'UTC', -100.0, 'House', 0, 4, ?)
      """, [profileId]);

      await db.deleteProfileAndRecords(profileId);

      final remaining = await raw.query('recurrent_record_patterns',
          where: 'profile_id = ?', whereArgs: [profileId]);
      expect(remaining, isEmpty,
          reason: 'Deleting a profile must wipe all its recurrent patterns');
    });

    test('deleteProfileAndRecords does NOT touch records from other profiles',
        () async {
      final db = ServiceConfig.database;
      final raw = (await (db as SqliteDatabase).database)!;

      final toDelete = await db.addProfile(Profile('To Delete'));
      final toKeep = await db.addProfile(Profile('To Keep'));

      await raw.rawInsert("""
        INSERT INTO records (title, value, datetime, timezone, category_name, category_type, profile_id)
        VALUES ('Doomed', -10.0, 1000000, 'UTC', 'House', 0, ?)
      """, [toDelete]);
      await raw.rawInsert("""
        INSERT INTO records (title, value, datetime, timezone, category_name, category_type, profile_id)
        VALUES ('Survivor', -20.0, 2000000, 'UTC', 'Food', 0, ?)
      """, [toKeep]);

      await db.deleteProfileAndRecords(toDelete);

      final survivors = await db.getAllRecords(profileId: toKeep);
      expect(survivors.length, 1);
      expect(survivors.first!.title, 'Survivor',
          reason: "The other profile's records must be untouched");
    });

    test('deleteProfileAndRecords does NOT touch wallets from other profiles',
        () async {
      final db = ServiceConfig.database;
      final toDelete = await db.addProfile(Profile('To Delete'));
      final toKeep = await db.addProfile(Profile('To Keep'));

      final safeWallet = Wallet('Safe Wallet');
      safeWallet.profileId = toKeep;
      final keepId = await db.addWallet(safeWallet);

      final doomedWallet = Wallet('Gone Wallet');
      doomedWallet.profileId = toDelete;
      await db.addWallet(doomedWallet);

      await db.deleteProfileAndRecords(toDelete);

      final survived = await db.getWalletById(keepId);
      expect(survived, isNotNull);
      expect(survived!.name, 'Safe Wallet',
          reason: "The other profile's wallet must survive the deletion");
    });

    test('after deleting Profile A, Profile B data is fully intact', () async {
      final db = ServiceConfig.database;
      final raw = (await (db as SqliteDatabase).database)!;

      final aId = await db.addProfile(Profile('Alice'));
      final bId = await db.addProfile(Profile('Bob'));

      // Add data to both profiles
      await raw.rawInsert("""
        INSERT INTO records (title, value, datetime, timezone, category_name, category_type, profile_id)
        VALUES ('A Record', -5.0, 1000000, 'UTC', 'House', 0, ?)
      """, [aId]);
      await raw.rawInsert("""
        INSERT INTO records (title, value, datetime, timezone, category_name, category_type, profile_id)
        VALUES ('B Record 1', -15.0, 2000000, 'UTC', 'Food', 0, ?)
      """, [bId]);
      await raw.rawInsert("""
        INSERT INTO records (title, value, datetime, timezone, category_name, category_type, profile_id)
        VALUES ('B Record 2', -25.0, 3000000, 'UTC', 'Transport', 0, ?)
      """, [bId]);

      final walletB = Wallet('Bob Main');
      walletB.profileId = bId;
      final walletBId = await db.addWallet(walletB);

      await db.deleteProfileAndRecords(aId);

      // Bob's data must be completely intact
      final bobRecords = await db.getAllRecords(profileId: bId);
      expect(bobRecords.length, 2);
      expect(bobRecords.map((r) => r!.title),
          containsAll(['B Record 1', 'B Record 2']));

      final bobWallet = await db.getWalletById(walletBId);
      expect(bobWallet, isNotNull);
      expect(bobWallet!.name, 'Bob Main');

      // Alice's profile must be gone
      expect(await db.getProfileById(aId), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // Wallet balance scope
  // ---------------------------------------------------------------------------
  group('Wallet balance scoped to profile', () {
    test('balance of a wallet reflects only its own profile records', () async {
      final db = ServiceConfig.database;
      final raw = (await (db as SqliteDatabase).database)!;

      final profileA = await db.addProfile(Profile('Alice'));
      final profileB = await db.addProfile(Profile('Bob'));

      // Alice has a wallet with an initial amount of 0
      final walletA = Wallet('Alice Checking', initialAmount: 0.0);
      walletA.profileId = profileA;
      final walletAId = await db.addWallet(walletA);

      // Insert a record against Alice's wallet
      await raw.rawInsert("""
        INSERT INTO records (title, value, datetime, timezone, category_name, category_type, wallet_id, profile_id)
        VALUES ('Alice Income', 500.0, 1000000, 'UTC', 'Salary', 1, ?, ?)
      """, [walletAId, profileA]);

      // getWalletById should show Alice's balance, not polluted by Bob
      final retrieved = await db.getWalletById(walletAId);
      expect(retrieved!.balance, closeTo(500.0, 0.01));

      // getAllWallets filtered to Bob must not include Alice's wallet
      final bobWallets = await db.getAllWallets(profileId: profileB);
      expect(bobWallets.any((w) => w.id == walletAId), isFalse);
    });
  });
}
