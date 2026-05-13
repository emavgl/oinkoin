import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/models/profile.dart';
import 'package:piggybank/models/wallet.dart';
import 'package:piggybank/services/backup-service.dart';
import 'package:piggybank/services/database/sqlite-database.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:test/test.dart' as testlib;
import 'package:timezone/data/latest_all.dart' as tz;

import '../helpers/test_database.dart';

void main() {
  late Directory testDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tz.initializeTimeZones();
    ServiceConfig.localTimezone = 'Europe/Vienna';

    testDir = Directory('test/temp_profiles_backup');

    // Mock PackageInfo (needed by createJsonBackupFile)
    const packageChannel =
        MethodChannel('dev.fluttercommunity.plus/package_info');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(packageChannel, (call) async {
      if (call.method == 'getAll') {
        return {
          'appName': 'TestApp',
          'packageName': 'com.test.app',
          'version': '1.0.0',
          'buildNumber': '1',
        };
      }
      return null;
    });

    // Mock path_provider (needed by createJsonBackupFile)
    const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (_) async => testDir);

    // Mock SharedPreferences (needed by createJsonBackupFile and importDataFromBackupFile)
    const prefsChannel = MethodChannel('plugins.flutter.io/shared_preferences');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(prefsChannel, (call) async {
      if (call.method == 'getAll') return <String, dynamic>{};
      if (call.method == 'setString') return true;
      if (call.method == 'getString') return null;
      if (call.method == 'remove') return true;
      if (call.method == 'clear') return true;
      return null;
    });
  });

  setUp(() async {
    await TestDatabaseHelper.setupTestDatabase();
    // Point BackupService at the fresh in-memory DB
    BackupService.database = ServiceConfig.database;

    if (await testDir.exists()) {
      await testDir.delete(recursive: true);
    }
    await testDir.create(recursive: true);
  });

  tearDownAll(() async {
    if (await testDir.exists()) {
      await testDir.delete(recursive: true);
    }
  });

  // ---------------------------------------------------------------------------
  // Backup creation
  // ---------------------------------------------------------------------------
  testlib.group('Backup creation includes profiles', () {
    testlib.test('backup JSON contains a profiles key', () async {
      final file =
          await BackupService.createJsonBackupFile(directoryPath: testDir.path);
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      expect(json.containsKey('profiles'), isTrue,
          reason: 'Backup must include the profiles key for future restores');
    });

    testlib.test(
        'backup JSON includes the Default Profile created during fresh install',
        () async {
      final file =
          await BackupService.createJsonBackupFile(directoryPath: testDir.path);
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final profiles = json['profiles'] as List;

      expect(profiles.length, 1,
          reason: 'Fresh install has exactly one profile');
      expect(profiles.first['is_default'], 1);
    });

    testlib.test('backup JSON includes all profiles when multiple exist',
        () async {
      final db = ServiceConfig.database;
      await db.addProfile(Profile('Work'));
      await db.addProfile(Profile('Family'));

      final file =
          await BackupService.createJsonBackupFile(directoryPath: testDir.path);
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final profiles = json['profiles'] as List;

      expect(profiles.length, 3); // Default + Work + Family
      final names = profiles.map((p) => p['name'] as String).toSet();
      expect(names, containsAll(['Work', 'Family']));
    });

    testlib.test(
        'each profile entry in the backup carries the correct is_default flag',
        () async {
      final db = ServiceConfig.database;
      await db.addProfile(Profile('Work')); // non-default

      final file =
          await BackupService.createJsonBackupFile(directoryPath: testDir.path);
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final profiles = json['profiles'] as List;

      final defaults = profiles.where((p) => p['is_default'] == 1).toList();
      final nonDefaults = profiles.where((p) => p['is_default'] == 0).toList();

      expect(defaults.length, 1,
          reason: 'Exactly one profile should be marked as default');
      expect(nonDefaults.length, 1,
          reason: '"Work" must be saved as non-default');
    });
  });

  // ---------------------------------------------------------------------------
  // Import — backup has profiles key (modern backup)
  // ---------------------------------------------------------------------------
  testlib.group('Import — modern backup with profiles', () {
    testlib.test('records are assigned to the remapped profile after import',
        () async {
      final db = ServiceConfig.database;
      final defaultProfile = await db.getDefaultProfile();
      final defaultProfileId = defaultProfile!.id!;

      // Craft a backup JSON with one profile (backup_id=99) and one record
      final backupJson = jsonEncode({
        'profiles': [
          {'id': 99, 'name': 'Alice Profile', 'is_default': 0}
        ],
        'wallets': [],
        'categories': [
          {'name': 'House', 'icon': 1, 'color': '255:0:0:0', 'category_type': 0}
        ],
        'records': [
          {
            'id': 1,
            'title': 'Alice Rent',
            'value': -800.0,
            'datetime': 1000000,
            'timezone': 'UTC',
            'category_name': 'House',
            'category_type': 0,
            'profile_id': 99, // backup profile id
          }
        ],
        'recurrent_record_patterns': [],
        'record_tag_associations': [],
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'package_name': 'com.test',
        'version': '1.0.0',
        'database_version': '23',
      });

      final file = File('${testDir.path}/backup_with_profiles.json');
      await file.writeAsString(backupJson);

      final result = await BackupService.importDataFromBackupFile(file);
      expect(result, isTrue);

      // A new profile named "Alice Profile" must have been created
      final profiles = await db.getAllProfiles();
      final aliceProfile =
          profiles.firstWhere((p) => p.name == 'Alice Profile');

      // The imported record must be under the new (remapped) profile id,
      // NOT the backup's original id (99)
      final aliceRecords = await db.getAllRecords(profileId: aliceProfile.id);
      expect(aliceRecords.length, 1);
      expect(aliceRecords.first!.title, 'Alice Rent');

      // The record must NOT appear under the Default Profile that already existed
      final defaultRecords =
          await db.getAllRecords(profileId: defaultProfileId);
      expect(defaultRecords.any((r) => r!.title == 'Alice Rent'), isFalse,
          reason:
              "Alice's record must not bleed into the pre-existing Default Profile");
    });

    testlib
        .test('records from two different profiles stay separated after import',
            () async {
      final db = ServiceConfig.database;

      final backupJson = jsonEncode({
        'profiles': [
          {'id': 10, 'name': 'Alice', 'is_default': 0},
          {'id': 20, 'name': 'Bob', 'is_default': 0},
        ],
        'wallets': [],
        'categories': [
          {'name': 'Food', 'icon': 1, 'color': '255:0:0:0', 'category_type': 0}
        ],
        'records': [
          {
            'id': 1,
            'title': 'Alice Groceries',
            'value': -50.0,
            'datetime': 1000000,
            'timezone': 'UTC',
            'category_name': 'Food',
            'category_type': 0,
            'profile_id': 10,
          },
          {
            'id': 2,
            'title': 'Bob Restaurant',
            'value': -80.0,
            'datetime': 2000000,
            'timezone': 'UTC',
            'category_name': 'Food',
            'category_type': 0,
            'profile_id': 20,
          }
        ],
        'recurrent_record_patterns': [],
        'record_tag_associations': [],
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'package_name': 'com.test',
        'version': '1.0.0',
        'database_version': '23',
      });

      final file = File('${testDir.path}/two_profiles_backup.json');
      await file.writeAsString(backupJson);

      expect(await BackupService.importDataFromBackupFile(file), isTrue);

      final profiles = await db.getAllProfiles();
      final alice = profiles.firstWhere((p) => p.name == 'Alice');
      final bob = profiles.firstWhere((p) => p.name == 'Bob');

      final aliceRecords = await db.getAllRecords(profileId: alice.id);
      final bobRecords = await db.getAllRecords(profileId: bob.id);

      expect(aliceRecords.length, 1);
      expect(aliceRecords.first!.title, 'Alice Groceries');
      expect(bobRecords.length, 1);
      expect(bobRecords.first!.title, 'Bob Restaurant');
    });

    testlib.test('wallets are assigned to the correct remapped profile',
        () async {
      final db = ServiceConfig.database;

      final backupJson = jsonEncode({
        'profiles': [
          {'id': 5, 'name': 'Carol', 'is_default': 0},
        ],
        'wallets': [
          {
            'id': 100,
            'name': 'Carol Checking',
            'initial_amount': 1000.0,
            'is_default': 0,
            'sort_order': 0,
            'is_archived': 0,
            'profile_id': 5,
          }
        ],
        'categories': [],
        'records': [],
        'recurrent_record_patterns': [],
        'record_tag_associations': [],
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'package_name': 'com.test',
        'version': '1.0.0',
        'database_version': '23',
      });

      final file = File('${testDir.path}/wallet_profile_backup.json');
      await file.writeAsString(backupJson);

      expect(await BackupService.importDataFromBackupFile(file), isTrue);

      final profiles = await db.getAllProfiles();
      final carol = profiles.firstWhere((p) => p.name == 'Carol');

      final carolWallets = await db.getAllWallets(profileId: carol.id);
      expect(carolWallets.any((w) => w.name == 'Carol Checking'), isTrue,
          reason: "Carol's wallet must be visible only under her profile");

      // The Default Profile should not see Carol's wallet
      final defaultProfile = await db.getDefaultProfile();
      final defaultWallets =
          await db.getAllWallets(profileId: defaultProfile!.id);
      expect(defaultWallets.any((w) => w.name == 'Carol Checking'), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // Import — old backup without profiles key
  // ---------------------------------------------------------------------------
  testlib.group('Import — old backup without profiles key', () {
    testlib.test(
        'records from an old backup are assigned to the existing Default Profile',
        () async {
      final db = ServiceConfig.database;
      final defaultProfile = await db.getDefaultProfile();

      final oldBackupJson = jsonEncode({
        // No 'profiles' key — simulates a pre-v23 backup
        'categories': [
          {'name': 'House', 'icon': 1, 'color': '255:0:0:0', 'category_type': 0}
        ],
        'records': [
          {
            'id': 1,
            'title': 'Old Rent',
            'value': -500.0,
            'datetime': 1000000,
            'timezone': 'UTC',
            'category_name': 'House',
            'category_type': 0,
          }
        ],
        'recurrent_record_patterns': [],
        'record_tag_associations': [],
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'package_name': 'com.test',
        'version': '1.0.0',
        'database_version': '22',
      });

      final file = File('${testDir.path}/old_backup.json');
      await file.writeAsString(oldBackupJson);

      expect(await BackupService.importDataFromBackupFile(file), isTrue);

      // The record must show up under the Default Profile
      final defaultRecords =
          await db.getAllRecords(profileId: defaultProfile!.id);
      expect(defaultRecords.any((r) => r!.title == 'Old Rent'), isTrue,
          reason:
              'Records from an old backup must be placed in the Default Profile');
    });

    testlib.test('old backup import does not create any new profile', () async {
      final db = ServiceConfig.database;
      final profilesBefore = await db.getAllProfiles();

      final oldBackupJson = jsonEncode({
        'categories': [],
        'records': [],
        'recurrent_record_patterns': [],
        'record_tag_associations': [],
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'package_name': 'com.test',
        'version': '1.0.0',
        'database_version': '22',
      });

      final file = File('${testDir.path}/empty_old_backup.json');
      await file.writeAsString(oldBackupJson);

      await BackupService.importDataFromBackupFile(file);

      final profilesAfter = await db.getAllProfiles();
      expect(profilesAfter.length, profilesBefore.length,
          reason: 'Importing an old backup must not create new profiles');
    });

    testlib
        .test('wallets from an old backup are assigned to the Default Profile',
            () async {
      final db = ServiceConfig.database;
      final defaultProfile = await db.getDefaultProfile();

      final oldBackupJson = jsonEncode({
        'categories': [],
        'wallets': [
          {
            'id': 1,
            'name': 'Legacy Wallet',
            'initial_amount': 200.0,
            'is_default': 0,
            'sort_order': 0,
            'is_archived': 0,
            // no profile_id key
          }
        ],
        'records': [],
        'recurrent_record_patterns': [],
        'record_tag_associations': [],
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'package_name': 'com.test',
        'version': '1.0.0',
        'database_version': '22',
      });

      final file = File('${testDir.path}/legacy_wallet_backup.json');
      await file.writeAsString(oldBackupJson);

      expect(await BackupService.importDataFromBackupFile(file), isTrue);

      final defaultWallets =
          await db.getAllWallets(profileId: defaultProfile!.id);
      expect(defaultWallets.any((w) => w.name == 'Legacy Wallet'), isTrue,
          reason:
              'Wallets from an old backup must be placed in the Default Profile');
    });
  });

  // ---------------------------------------------------------------------------
  // Full round-trip
  // ---------------------------------------------------------------------------
  testlib.group('Full backup/restore round-trip with multiple profiles', () {
    testlib.test(
        'after backup and restore, each profile contains only its own records',
        () async {
      final db = ServiceConfig.database;

      // Setup: add a second profile and records for each
      final workId = await db.addProfile(Profile('Work'));
      final sqliteDb = db as SqliteDatabase;
      final raw = (await sqliteDb.database)!;
      final defaultProfile = await db.getDefaultProfile();
      final defaultId = defaultProfile!.id!;

      await raw.rawInsert("""
        INSERT INTO records (title, value, datetime, timezone, category_name, category_type, profile_id)
        VALUES ('Personal Expense', -100.0, 1000000, 'UTC', 'House', 0, ?)
      """, [defaultId]);
      await raw.rawInsert("""
        INSERT INTO records (title, value, datetime, timezone, category_name, category_type, profile_id)
        VALUES ('Work Expense', -200.0, 2000000, 'UTC', 'Transport', 0, ?)
      """, [workId]);

      // Create backup
      final backupFile =
          await BackupService.createJsonBackupFile(directoryPath: testDir.path);

      // Verify backup JSON contains both profiles and both records
      final backupJson =
          jsonDecode(await backupFile.readAsString()) as Map<String, dynamic>;
      expect((backupJson['profiles'] as List).length, 2);
      expect((backupJson['records'] as List).length, 2);

      // Now reset the DB and restore
      await TestDatabaseHelper.setupTestDatabase();
      BackupService.database = ServiceConfig.database;

      // Clear the auto-created onCreate data (Default Profile + Default Wallet)
      // so the import starts with a clean slate and IDs don't collide.
      final rawRestore =
          (await (ServiceConfig.database as SqliteDatabase).database)!;
      await rawRestore.rawDelete('DELETE FROM profiles');
      await rawRestore.rawDelete('DELETE FROM wallets');
      await rawRestore.rawDelete('DELETE FROM records');

      final result = await BackupService.importDataFromBackupFile(backupFile);
      expect(result, isTrue);

      // Find the imported profiles by name
      final restoredProfiles = await ServiceConfig.database.getAllProfiles();
      final restoredDefault =
          restoredProfiles.firstWhere((p) => p.isDefault && p.name.isNotEmpty);
      final restoredWork = restoredProfiles.firstWhere((p) => p.name == 'Work');

      final defaultRecords = await ServiceConfig.database
          .getAllRecords(profileId: restoredDefault.id);
      final workRecords = await ServiceConfig.database
          .getAllRecords(profileId: restoredWork.id);

      // Each profile must have exactly its own records
      expect(defaultRecords.any((r) => r!.title == 'Personal Expense'), isTrue,
          reason: 'Default profile record must be restored');
      expect(workRecords.any((r) => r!.title == 'Work Expense'), isTrue,
          reason: 'Work profile record must be restored');

      // Cross-profile contamination check
      expect(defaultRecords.any((r) => r!.title == 'Work Expense'), isFalse,
          reason: 'Work expense must not appear in the Default profile');
      expect(workRecords.any((r) => r!.title == 'Personal Expense'), isFalse,
          reason: 'Personal expense must not appear in the Work profile');
    });

    testlib.test('restoring a backup does not lose any profiles', () async {
      final db = ServiceConfig.database;
      await db.addProfile(Profile('Project A'));
      await db.addProfile(Profile('Project B'));

      final backupFile =
          await BackupService.createJsonBackupFile(directoryPath: testDir.path);
      final backupJson =
          jsonDecode(await backupFile.readAsString()) as Map<String, dynamic>;
      final backedUpProfiles = backupJson['profiles'] as List;
      // Default + Project A + Project B = 3
      expect(backedUpProfiles.length, 3);

      // Restore into fresh DB
      await TestDatabaseHelper.setupTestDatabase();
      BackupService.database = ServiceConfig.database;
      await BackupService.importDataFromBackupFile(backupFile);

      final importedProfiles = await ServiceConfig.database.getAllProfiles();
      // onCreate created 1 (Default Profile reused), import added 2 more → 3 total
      expect(importedProfiles.length, 3,
          reason: 'Default Profile is reused, not duplicated');
      final importedNames = importedProfiles.map((p) => p.name).toSet();
      expect(importedNames, containsAll(['Project A', 'Project B']),
          reason: 'All backed-up profiles must survive a restore');
    });
  });

  // ---------------------------------------------------------------------------
  // Restoring backup into existing database — no duplicate Default Profile
  // ---------------------------------------------------------------------------
  testlib.group('Restore backup with existing Default Profile', () {
    testlib
        .test('restoring a backup does NOT create a duplicate Default Profile',
            () async {
      final db = ServiceConfig.database;

      // The test DB already has a Default Profile from onCreate
      final defaultProfileBefore = await db.getDefaultProfile();
      final defaultProfileIdBefore = defaultProfileBefore!.id!;
      final profilesBefore = await db.getAllProfiles();
      expect(profilesBefore.length, 1);

      // Craft a backup that contains a Default Profile
      final backupJson = jsonEncode({
        'profiles': [
          {'id': 1, 'name': 'Default Profile', 'is_default': 1}
        ],
        'wallets': [],
        'categories': [
          {'name': 'Food', 'icon': 1, 'color': '255:0:0:0', 'category_type': 0}
        ],
        'records': [
          {
            'id': 1,
            'title': 'Lunch',
            'value': -15.0,
            'datetime': 1000000,
            'timezone': 'UTC',
            'category_name': 'Food',
            'category_type': 0,
            'profile_id': 1,
          }
        ],
        'recurrent_record_patterns': [],
        'record_tag_associations': [],
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'package_name': 'com.test',
        'version': '1.0.0',
        'database_version': '23',
      });

      final file = File('${testDir.path}/default_profile_backup.json');
      await file.writeAsString(backupJson);

      expect(await BackupService.importDataFromBackupFile(file), isTrue);

      // There must still be exactly ONE default profile
      final defaultProfileAfter = await db.getDefaultProfile();
      final profilesAfter = await db.getAllProfiles();

      expect(profilesAfter.length, 1,
          reason: 'Must not create a duplicate Default Profile');
      expect(defaultProfileAfter!.id, defaultProfileIdBefore,
          reason:
              'Must reuse the existing Default Profile, not create a new one');

      // The imported record must be under the existing Default Profile
      final defaultRecords =
          await db.getAllRecords(profileId: defaultProfileAfter.id);
      expect(defaultRecords.any((r) => r!.title == 'Lunch'), isTrue,
          reason:
              'Record from backup must be mapped to existing Default Profile');
    });

    testlib.test(
        'restoring a multi-profile backup reuses existing Default Profile',
        () async {
      final db = ServiceConfig.database;

      final defaultProfileBefore = await db.getDefaultProfile();
      final defaultProfileIdBefore = defaultProfileBefore!.id!;

      // Craft a backup with a Default Profile + one extra profile
      final backupJson = jsonEncode({
        'profiles': [
          {'id': 1, 'name': 'Default Profile', 'is_default': 1},
          {'id': 2, 'name': 'Work', 'is_default': 0},
        ],
        'wallets': [],
        'categories': [
          {'name': 'Food', 'icon': 1, 'color': '255:0:0:0', 'category_type': 0},
          {
            'name': 'Transport',
            'icon': 2,
            'color': '255:0:0:255',
            'category_type': 0
          }
        ],
        'records': [
          {
            'id': 1,
            'title': 'Lunch',
            'value': -15.0,
            'datetime': 1000000,
            'timezone': 'UTC',
            'category_name': 'Food',
            'category_type': 0,
            'profile_id': 1,
          },
          {
            'id': 2,
            'title': 'Taxi',
            'value': -25.0,
            'datetime': 2000000,
            'timezone': 'UTC',
            'category_name': 'Transport',
            'category_type': 0,
            'profile_id': 2,
          }
        ],
        'recurrent_record_patterns': [],
        'record_tag_associations': [],
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'package_name': 'com.test',
        'version': '1.0.0',
        'database_version': '23',
      });

      final file = File('${testDir.path}/multi_profile_backup.json');
      await file.writeAsString(backupJson);

      expect(await BackupService.importDataFromBackupFile(file), isTrue);

      final profilesAfter = await db.getAllProfiles();
      expect(profilesAfter.length, 2,
          reason: 'Existing Default Profile + new Work profile = 2');

      // Default Profile must be the same one that existed before
      final defaultProfileAfter = await db.getDefaultProfile();
      expect(defaultProfileAfter!.id, defaultProfileIdBefore,
          reason: 'Existing Default Profile must be reused');

      // Work profile must be newly created
      final workProfile = profilesAfter.firstWhere((p) => p.name == 'Work');
      expect(workProfile.isDefault, isFalse);

      // Records must be correctly assigned
      final defaultRecords =
          await db.getAllRecords(profileId: defaultProfileAfter.id);
      final workRecords = await db.getAllRecords(profileId: workProfile.id);

      expect(defaultRecords.any((r) => r!.title == 'Lunch'), isTrue);
      expect(workRecords.any((r) => r!.title == 'Taxi'), isTrue);

      // No cross-contamination
      expect(defaultRecords.any((r) => r!.title == 'Taxi'), isFalse);
      expect(workRecords.any((r) => r!.title == 'Lunch'), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // Profile ID remapping — backup IDs must not persist verbatim
  // ---------------------------------------------------------------------------
  testlib.group('Profile ID remapping', () {
    testlib
        .test('imported profiles receive new database IDs, not the backup IDs',
            () async {
      final db = ServiceConfig.database;

      // Backup with profile backup_id = 777 (a large, obviously-non-real id)
      final backupJson = jsonEncode({
        'profiles': [
          {'id': 777, 'name': 'Exotic Profile', 'is_default': 0}
        ],
        'wallets': [],
        'categories': [],
        'records': [],
        'recurrent_record_patterns': [],
        'record_tag_associations': [],
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'package_name': 'com.test',
        'version': '1.0.0',
        'database_version': '23',
      });

      final file = File('${testDir.path}/remap_backup.json');
      await file.writeAsString(backupJson);

      await BackupService.importDataFromBackupFile(file);

      final profiles = await db.getAllProfiles();
      final exotic = profiles.firstWhere((p) => p.name == 'Exotic Profile');

      // The new id must NOT be 777 — the DB auto-assigns a fresh sequential id
      expect(exotic.id, isNot(777),
          reason:
              'Profile IDs from the backup file must be remapped to new DB-assigned IDs');
    });
  });
}
