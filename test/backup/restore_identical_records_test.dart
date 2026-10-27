import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/services/backup-service.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timezone/data/latest_all.dart' as tz;

import '../helpers/test_database.dart';

/// 2026-10-23 20:00 UTC: the two identical expenses of issue #452 share the
/// very same datetime, down to the second.
const int _sameDatetime = 1792785600000;

Map<String, dynamic> _backup({
  required List<Map<String, dynamic>> records,
  required List<Map<String, dynamic>> associations,
}) {
  return {
    'records': records,
    'categories': [
      {
        'name': 'Test category',
        'icon': 1,
        'color': '255:0:0:0',
        'category_type': 0,
      },
    ],
    'record_tag_associations': associations,
    'recurrent_record_patterns': [],
    'wallets': [],
    'profiles': [],
    'created_at': 1792785600000,
    'package_name': 'com.example.oinkoin',
    'version': '1.16.0',
    'database_version': '33',
  };
}

Map<String, dynamic> _record({
  required int id,
  required String? title,
  required double value,
  required int datetime,
  String category = 'Test category',
  String? description,
  int? walletId,
}) => {
  'id': id,
  'title': title,
  'value': value,
  'datetime': datetime,
  'timezone': 'UTC',
  'category_name': category,
  'category_type': 0,
  'description': description,
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

    testDir = Directory('test/temp_restore_identical_records');

    const MethodChannel pkgChannel = MethodChannel(
      'dev.fluttercommunity.plus/package_info',
    );
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
          return null;
        });

    const MethodChannel prefsChannel = MethodChannel(
      'plugins.flutter.io/shared_preferences',
    );
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

  // Issue #452: two identical expenses (same amount, title, category and
  // datetime) were stored in the backup file but only one was restored, so the
  // restored balance was wrong. Identical records inside the same backup are
  // distinct user data and must all be restored.
  test('restore keeps two identical records that share the same datetime, and '
      'the restored balance accounts for both of them', () async {
    final file = File('${testDir.path}/identical.json');
    await file.writeAsString(
      jsonEncode(
        _backup(
          records: [
            _record(
              id: 1,
              title: 'Test record',
              value: -10.0,
              datetime: _sameDatetime,
            ),
            _record(
              id: 2,
              title: 'Test record',
              value: -10.0,
              datetime: _sameDatetime,
            ),
          ],
          associations: [],
        ),
      ),
    );

    expect(await BackupService.importDataFromBackupFile(file), isTrue);

    final db = ServiceConfig.database;
    final all = await db.getAllRecords();
    expect(all.length, 2, reason: 'both identical records must be restored');
    expect(
      all.fold<double>(0, (sum, record) => sum + (record?.value ?? 0)),
      -20.0,
      reason: 'the restored balance must account for both expenses',
    );
  });

  // Identical records that only differ by their tags must keep their own tags:
  // tags are attached to the ID returned by each record insert instead of being
  // looked up by record fields, which finds the first identical twin.
  test('identical restored records keep their own tags', () async {
    final file = File('${testDir.path}/identical_tags.json');
    await file.writeAsString(
      jsonEncode(
        _backup(
          records: [
            _record(
              id: 10,
              title: 'Test record',
              value: -10.0,
              datetime: _sameDatetime,
            ),
            _record(
              id: 11,
              title: 'Test record',
              value: -10.0,
              datetime: _sameDatetime,
            ),
          ],
          associations: [
            {'record_id': 10, 'tag_name': 'receipt_a'},
            {'record_id': 11, 'tag_name': 'receipt_b'},
          ],
        ),
      ),
    );

    expect(await BackupService.importDataFromBackupFile(file), isTrue);

    final db = ServiceConfig.database;
    final all = await db.getAllRecords();
    expect(all.length, 2);

    final taggedA = all.where((r) => r!.tags.contains('receipt_a')).toList();
    final taggedB = all.where((r) => r!.tags.contains('receipt_b')).toList();
    expect(taggedA.length, 1, reason: 'one record keeps receipt_a');
    expect(taggedB.length, 1, reason: 'one record keeps receipt_b');
    expect(
      taggedA.first!.id,
      isNot(equals(taggedB.first!.id)),
      reason: 'each tag must stay on its own record',
    );
  });

  // Restoring the same backup twice must not duplicate the records that the
  // first restore already stored: duplicate matching is one-to-one, so the
  // second import finds a stored record for each record of the backup.
  test(
    'restoring the same backup twice does not duplicate its records',
    () async {
      final file = File('${testDir.path}/twice.json');
      await file.writeAsString(
        jsonEncode(
          _backup(
            records: [
              _record(
                id: 1,
                title: 'Test record',
                value: -10.0,
                datetime: _sameDatetime,
              ),
              _record(
                id: 2,
                title: 'Test record',
                value: -10.0,
                datetime: _sameDatetime,
              ),
            ],
            associations: [],
          ),
        ),
      );

      expect(await BackupService.importDataFromBackupFile(file), isTrue);
      expect(await BackupService.importDataFromBackupFile(file), isTrue);

      final all = await ServiceConfig.database.getAllRecords();
      expect(
        all.length,
        2,
        reason: 're-importing a stored backup must not add the records again',
      );
    },
  );
}
