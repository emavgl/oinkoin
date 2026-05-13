import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/services/backup-service.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timezone/data/latest_all.dart' as tz;

import '../helpers/test_database.dart';

const int _dt1 = 1745000000000;
const int _dt2 = 1745100000000;
const int _dt3 = 1745200000000;

Map<String, dynamic> _backup({
  required List<Map<String, dynamic>> records,
  required List<Map<String, dynamic>> associations,
  List<Map<String, dynamic>> wallets = const [],
}) {
  return {
    'records': records,
    'categories': [
      {'name': 'Groceries', 'icon': 1, 'color': '255:0:0:0', 'category_type': 0},
      {'name': 'Travel', 'icon': 2, 'color': '255:0:0:0', 'category_type': 0},
    ],
    'record_tag_associations': associations,
    'recurrent_record_patterns': [],
    'wallets': wallets,
    'profiles': [],
    'created_at': 1745000000000,
    'package_name': 'com.example.oinkoin',
    'version': '1.5.0',
    'database_version': '17',
  };
}

Map<String, dynamic> _record({
  required int id,
  required String? title,
  required double value,
  required int datetime,
  String category = 'Groceries',
  int? walletId,
}) =>
    {
      'id': id,
      'title': title,
      'value': value,
      'datetime': datetime,
      'timezone': 'UTC',
      'category_name': category,
      'category_type': 0,
      'description': null,
      'recurrence_id': null,
      if (walletId != null) 'wallet_id': walletId,
    };

void main() {
  late Directory testDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tz.initializeTimeZones();
    ServiceConfig.localTimezone = 'UTC';

    testDir = Directory('test/temp_restore_tag_integrity');

    const MethodChannel pkgChannel =
        MethodChannel('dev.fluttercommunity.plus/package_info');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pkgChannel, (call) async {
      if (call.method == 'getAll') {
        return {
          'appName': 'test',
          'packageName': 'com.example.test',
          'version': '1.0.0',
          'buildNumber': '1',
        };
      }
    });

    const MethodChannel prefsChannel =
        MethodChannel('plugins.flutter.io/shared_preferences');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(prefsChannel, (call) async {
      if (call.method == 'getAll') return <String, dynamic>{};
      if (call.method == 'setString') return true;
      return null;
    });
  });

  setUp(() async {
    if (await testDir.exists()) await testDir.delete(recursive: true);
    await testDir.create(recursive: true);
    await TestDatabaseHelper.setupTestDatabase();
    BackupService.database = ServiceConfig.database;
  });

  tearDownAll(() async {
    if (await testDir.exists()) await testDir.delete(recursive: true);
  });

  // ---------------------------------------------------------------------------
  // Test 1 – Title condition bug
  //
  // A tagged record with a non-null title must NOT transfer its tag to an
  // untagged null-title record that shares (datetime, value, category).
  //
  // Root cause (before fix): the dedup query uses
  //   (title IS NULL OR title = 'London Hotel')
  // which matches the null-title record A, causing B's INSERT to be skipped.
  // The tag-lookup then also matches A (same faulty condition) and assigns
  // "london_2026" to A instead of B.
  // ---------------------------------------------------------------------------
  test(
      'titled tagged record does not assign its tag to an untagged null-title '
      'record with the same datetime / value / category', () async {
    // A processed first (null title, no tag), B second (titled, tagged).
    final file = File('${testDir.path}/t1.json');
    await file.writeAsString(jsonEncode(_backup(
      records: [
        _record(id: 100, title: null,           value: -75.0, datetime: _dt1),
        _record(id: 101, title: 'London Hotel', value: -75.0, datetime: _dt1),
      ],
      associations: [
        {'record_id': 101, 'tag_name': 'london_2026'},
      ],
    )));

    expect(await BackupService.importDataFromBackupFile(file), isTrue);

    final db = ServiceConfig.database;
    final all = await db.getAllRecords();
    expect(all.length, 2, reason: 'both records should be persisted');

    final nullTitleRecs = all.where((r) => r?.title == null).toList();
    final titledRecs = all.where((r) => r?.title == 'London Hotel').toList();

    expect(nullTitleRecs.length, 1, reason: 'exactly one null-title record');
    expect(titledRecs.length, 1, reason: 'exactly one titled record');

    expect(nullTitleRecs.first!.tags, isEmpty,
        reason: "null-title record must NOT receive 'london_2026'");
    expect(titledRecs.first!.tags, contains('london_2026'),
        reason: "titled record must keep 'london_2026'");
  });

  // ---------------------------------------------------------------------------
  // Test 2 – Wallet isolation bug
  //
  // An untagged record in wallet A must NOT receive the tag belonging to a
  // tagged record in wallet B when both records share
  // (datetime, value, title=null, category).
  //
  // Root cause (before fix): the dedup query ignores wallet_id, so B's INSERT
  // is skipped when A is already present; the tag-lookup (also wallet-agnostic)
  // then finds A and wrongly assigns the tag to it.
  // ---------------------------------------------------------------------------
  test(
      'untagged record in wallet A does not receive a tag belonging to a tagged '
      'record in wallet B with the same datetime / value / category', () async {
    // Backup includes two explicit wallets so walletIdMap is populated and the
    // two records end up with distinct wallet_ids after restore.
    final file = File('${testDir.path}/t2.json');
    await file.writeAsString(jsonEncode(_backup(
      wallets: [
        {'id': 1, 'name': 'Wallet A', 'is_default': 0, 'sort_order': 0, 'initial_amount': 0.0},
        {'id': 2, 'name': 'Wallet B', 'is_default': 0, 'sort_order': 1, 'initial_amount': 0.0},
      ],
      records: [
        // A: no tags, wallet 1 — inserted first
        _record(id: 200, title: null, value: -50.0, datetime: _dt2, walletId: 1),
        // B: tagged, wallet 2 — same date/value/cat
        _record(id: 201, title: null, value: -50.0, datetime: _dt2, walletId: 2),
      ],
      associations: [
        {'record_id': 201, 'tag_name': 'london_2026'},
      ],
    )));

    expect(await BackupService.importDataFromBackupFile(file), isTrue);

    final db = ServiceConfig.database;
    final all = await db.getAllRecords();
    expect(all.length, 2, reason: 'both wallet records should be persisted');

    // The two records differ only by wallet; verify tags are on the right one.
    final walletRecords = all.map((r) => r!).toList()
      ..sort((a, b) => (a.walletId ?? 0).compareTo(b.walletId ?? 0));

    // Record in Wallet A (lower wallet id after remapping) → no tag
    // Record in Wallet B (higher wallet id after remapping) → london_2026
    // We don't know exact new IDs, so check by tag presence count.
    final untagged = all.where((r) => r!.tags.isEmpty).toList();
    final tagged = all.where((r) => r!.tags.contains('london_2026')).toList();

    expect(untagged.length, 1,
        reason: 'exactly one record should have no tags');
    expect(tagged.length, 1,
        reason: "exactly one record should have 'london_2026'");

    // The untagged and tagged records must live in different wallets
    expect(untagged.first!.walletId, isNot(equals(tagged.first!.walletId)),
        reason: 'the untagged record and the tagged record must be in different wallets');
  });

  // ---------------------------------------------------------------------------
  // Test 3 – Regression: basic restore preserves correct tag assignments
  //
  // After a restore, every record that had no tag association in the backup
  // must have an empty tag set in the database.
  // ---------------------------------------------------------------------------
  test(
      'after restore, records with no tag association in the backup remain '
      'untagged in the database', () async {
    final file = File('${testDir.path}/t3.json');
    await file.writeAsString(jsonEncode(_backup(
      records: [
        _record(id: 1, title: null,    value: -10.0, datetime: _dt1),
        _record(id: 2, title: 'Hotel', value: -200.0, datetime: _dt2),
        _record(id: 3, title: null,    value: -30.0, datetime: _dt3),
        _record(id: 4, title: 'Flight',value: -350.0, datetime: _dt2 + 3600000),
        _record(id: 5, title: null,    value: -5.0,  datetime: _dt1 + 86400000),
      ],
      associations: [
        {'record_id': 2, 'tag_name': 'london_2026'},
        {'record_id': 4, 'tag_name': 'london_2026'},
      ],
    )));

    expect(await BackupService.importDataFromBackupFile(file), isTrue);

    final db = ServiceConfig.database;
    final all = await db.getAllRecords();
    expect(all.length, 5);

    for (final r in all) {
      if (r!.title == 'Hotel' || r.title == 'Flight') {
        expect(r.tags, contains('london_2026'),
            reason: '${r.title} should have london_2026');
      } else {
        expect(r.tags, isEmpty,
            reason: 'record (title=${r.title}) should have no tags');
      }
    }
  });

  // ---------------------------------------------------------------------------
  // Test 4 – User-reported scenario
  //
  // A null-title Groceries record for today must NOT receive "london_2026"
  // when a same-datetime/same-value titled Groceries record carries that tag.
  // This directly mirrors the user's report of today's grocery record
  // being incorrectly labeled.
  // ---------------------------------------------------------------------------
  test(
      "today's untagged null-title Groceries record does not get 'london_2026' "
      'when a same-date titled record carries that tag', () async {
    const int todayDatetime = 1777117941000; // 2026-04-25 13:52 UTC
    final file = File('${testDir.path}/t4.json');
    await file.writeAsString(jsonEncode(_backup(
      records: [
        _record(id: 2940, title: null,                 value: -75.24, datetime: todayDatetime),
        _record(id: 2905, title: 'London Grocery Run', value: -75.24, datetime: todayDatetime),
      ],
      associations: [
        {'record_id': 2905, 'tag_name': 'london_2026'},
      ],
    )));

    expect(await BackupService.importDataFromBackupFile(file), isTrue);

    final db = ServiceConfig.database;
    final all = await db.getAllRecords();
    expect(all.length, 2);

    final todayRecs = all.where((r) => r?.title == null).toList();
    final londonRecs = all.where((r) => r?.title == 'London Grocery Run').toList();

    expect(todayRecs.length, 1, reason: 'today untagged record should be in DB');
    expect(londonRecs.length, 1, reason: 'London Grocery Run record should be in DB');

    expect(todayRecs.first!.tags, isEmpty,
        reason: "today's untagged record must NOT get 'london_2026'");
    expect(londonRecs.first!.tags, contains('london_2026'),
        reason: "London Grocery Run must keep 'london_2026'");
  });
}
