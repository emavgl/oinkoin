import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/record.dart';
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
    'version': '1.17.0',
    'database_version': '34',
  };
}

Map<String, dynamic> _record({
  required Object id,
  required String? title,
  required double value,
  required int datetime,
  String category = 'Test category',
  String? description,
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
};

Record _buildRecord(String title) => Record(
      -10.0,
      title,
      Category('Test category', categoryType: CategoryType.expense),
      DateTime.fromMillisecondsSinceEpoch(_sameDatetime, isUtc: true),
    );

void main() {
  late Directory testDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tz.initializeTimeZones();
    ServiceConfig.localTimezone = 'UTC';

    testDir = Directory('test/temp_restore_uuid_ids').absolute;

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

  Future<File> writeBackup(String name, Map<String, dynamic> content) async {
    final file = File('${testDir.path}/$name');
    await file.writeAsString(jsonEncode(content));
    return file;
  }

  test('uuid backups keep record identity: two identical records with '
      'different ids are both restored, each with its own tags', () async {
    final file = await writeBackup(
      'identical.json',
      _backup(
        records: [
          _record(
            id: '11111111-1111-4111-8111-111111111111',
            title: 'Test record',
            value: -10.0,
            datetime: _sameDatetime,
          ),
          _record(
            id: '22222222-2222-4222-8222-222222222222',
            title: 'Test record',
            value: -10.0,
            datetime: _sameDatetime,
          ),
        ],
        associations: [
          {
            'record_id': '11111111-1111-4111-8111-111111111111',
            'tag_name': 'receipt_a',
          },
          {
            'record_id': '22222222-2222-4222-8222-222222222222',
            'tag_name': 'receipt_b',
          },
        ],
      ),
    );

    expect(await BackupService.importDataFromBackupFile(file), isTrue);

    final all = await ServiceConfig.database.getAllRecords();
    expect(all.length, 2);
    expect(
      all.fold<double>(0, (sum, record) => sum + (record?.value ?? 0)),
      -20.0,
      reason: 'the balance must account for both expenses',
    );

    // Ids are preserved as they are in the backup.
    expect(
      all.map((record) => record!.id).toSet(),
      {
        '11111111-1111-4111-8111-111111111111',
        '22222222-2222-4222-8222-222222222222',
      },
    );

    // ...and each record keeps its own tag.
    final byId = {for (final record in all) record!.id!: record};
    expect(
      byId['11111111-1111-4111-8111-111111111111']!.tags,
      {'receipt_a'},
    );
    expect(
      byId['22222222-2222-4222-8222-222222222222']!.tags,
      {'receipt_b'},
    );
  });

  test('restoring the same uuid backup twice adds no records', () async {
    final file = await writeBackup(
      'twice.json',
      _backup(
        records: [
          _record(
            id: 'aaaaaaaa-1111-4111-8111-111111111111',
            title: 'Test record',
            value: -10.0,
            datetime: _sameDatetime,
          ),
          _record(
            id: 'bbbbbbbb-2222-4222-8222-222222222222',
            title: 'Test record',
            value: -10.0,
            datetime: _sameDatetime,
          ),
        ],
        associations: [],
      ),
    );

    expect(await BackupService.importDataFromBackupFile(file), isTrue);
    expect(await BackupService.importDataFromBackupFile(file), isTrue);

    expect((await ServiceConfig.database.getAllRecords()).length, 2);
  });

  test('restoring a uuid backup over newer data skips exactly the records '
      'whose ids already exist', () async {
    final file = await writeBackup(
      'merge.json',
      _backup(
        records: [
          _record(
            id: 'cccccccc-1111-4111-8111-111111111111',
            title: 'Already here',
            value: -10.0,
            datetime: _sameDatetime,
          ),
          _record(
            id: 'dddddddd-2222-4222-8222-222222222222',
            title: 'From the backup',
            value: -10.0,
            datetime: _sameDatetime,
          ),
        ],
        associations: [],
      ),
    );

    // First restore: both records land in the database.
    expect(await BackupService.importDataFromBackupFile(file), isTrue);
    expect((await ServiceConfig.database.getAllRecords()).length, 2);

    // A record created afterwards in the database is not in the backup and
    // must survive the next restore; the backup's records are already stored.
    await ServiceConfig.database.addRecord(
      _buildRecord('Created after the backup'),
    );

    expect(await BackupService.importDataFromBackupFile(file), isTrue);

    final all = await ServiceConfig.database.getAllRecords();
    expect(all.length, 3);
    expect(
      all.map((record) => record!.title).toSet(),
      {'Already here', 'From the backup', 'Created after the backup'},
    );
  });

  test('legacy integer id backups still import and do not duplicate on a '
      'second import', () async {
    final file = await writeBackup(
      'legacy.json',
      _backup(
        records: [
          _record(id: 10, title: 'Legacy', value: -10.0, datetime: _sameDatetime),
          _record(
            id: 20,
            title: 'Legacy twin',
            value: -10.0,
            datetime: _sameDatetime,
          ),
        ],
        associations: [
          {'record_id': 10, 'tag_name': 'legacy_tag'},
        ],
      ),
    );

    expect(await BackupService.importDataFromBackupFile(file), isTrue);

    var all = await ServiceConfig.database.getAllRecords();
    expect(all.length, 2);
    expect(all.every((record) => (record!.id ?? '').isNotEmpty), isTrue);
    expect(
      all.every((record) => int.tryParse(record!.id!) == null),
      isTrue,
      reason: 'legacy integer ids must be replaced by uuids',
    );

    // The tag from the legacy association is attached to the right record.
    final tagged =
        all.where((record) => record!.tags.contains('legacy_tag')).toList();
    expect(tagged.length, 1);
    expect(tagged.first!.title, 'Legacy');

    // Re-importing the same legacy backup adds nothing (content based check).
    expect(await BackupService.importDataFromBackupFile(file), isTrue);
    all = await ServiceConfig.database.getAllRecords();
    expect(all.length, 2);
  });

  test('a restore keeps the stored version of a record whose id already exists',
      () async {
    const id = 'eeeeeeee-1111-4111-8111-111111111111';
    await ServiceConfig.database.addRecord(Record(
      -99.0,
      'Local version',
      Category('Test category', categoryType: CategoryType.expense),
      DateTime.fromMillisecondsSinceEpoch(_sameDatetime, isUtc: true),
      id: id,
    ));

    // The backup carries the same id with different content: identity wins, so
    // the version already stored is kept.
    final file = await writeBackup(
      'conflict.json',
      _backup(
        records: [
          _record(
            id: id,
            title: 'Backup version',
            value: -10.0,
            datetime: _sameDatetime,
          ),
        ],
        associations: [],
      ),
    );

    expect(await BackupService.importDataFromBackupFile(file), isTrue);

    final all = await ServiceConfig.database.getAllRecords();
    expect(all, hasLength(1));
    expect(all.single!.id, id);
    expect(all.single!.title, 'Local version');
    expect(all.single!.value, -99.0);
  });

  test('a backup that repeats the same id stores the record once', () async {
    const id = 'ffffffff-1111-4111-8111-111111111111';
    final record = _record(
      id: id,
      title: 'Test record',
      value: -10.0,
      datetime: _sameDatetime,
    );
    final file = await writeBackup(
      'repeated-id.json',
      _backup(records: [record, Map<String, dynamic>.from(record)],
          associations: []),
    );

    expect(await BackupService.importDataFromBackupFile(file), isTrue);
    expect((await ServiceConfig.database.getAllRecords()).length, 1);
  });
}
