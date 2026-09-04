import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:piggybank/services/backup-service.dart';
import 'package:piggybank/settings/backup-retention-period.dart';
import 'package:piggybank/settings/constants/preferences-keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

import './backup_service_test.mocks.dart';

/// Android SAF branches of [BackupService] behind a custom backup folder.
///
/// `Platform.isAndroid` is false on the desktop test host, so these tests
/// force the Android behavior through [BackupService.debugOverrideIsAndroid]
/// and fake the `oinkoin/backup_directory` platform channel, including
/// grant-loss failures.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const String safPath = '/storage/emulated/0/Backups';
  const String safUri = 'content://com.android.externalstorage/tree/Backups';

  late MockDatabaseInterface mockDatabase;
  late Directory testDir;
  final Map<String, Object> prefStore = {};
  Future<dynamic> Function(MethodCall)? safHandler;
  final List<MethodCall> safCalls = [];
  String? stagedContent;

  Future<void> mockChannels() async {
    const MethodChannel packageInfo =
        MethodChannel('dev.fluttercommunity.plus/package_info');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(packageInfo, (MethodCall call) async {
      if (call.method == 'getAll') {
        return <String, dynamic>{
          'appName': 'ABC',
          'packageName': 'A.B.C',
          'version': '1.0.0',
          'buildNumber': '67',
        };
      }
      return null;
    });

    const MethodChannel pathProvider =
        MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProvider, (MethodCall call) async {
      return testDir.path;
    });

    const MethodChannel prefs =
        MethodChannel('plugins.flutter.io/shared_preferences');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(prefs, (MethodCall call) async {
      switch (call.method) {
        case 'getAll':
          return Map<String, Object>.from(prefStore);
        case 'setString':
        case 'setBool':
        case 'setInt':
        case 'setDouble':
        case 'setStringList':
          final args = call.arguments as Map;
          prefStore[args['key'] as String] = args['value'] as Object;
          return true;
        case 'remove':
          prefStore.remove((call.arguments as Map)['key'] as String);
          return true;
        case 'clear':
          prefStore.clear();
          return true;
        default:
          return null;
      }
    });

    const MethodChannel saf = MethodChannel('oinkoin/backup_directory');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(saf, (MethodCall call) async {
      safCalls.add(call);
      if (safHandler != null) {
        return safHandler!(call);
      }
      return null;
    });
  }

  setUpAll(() async {
    testDir = Directory('test/temp_saf_backup');
    mockDatabase = MockDatabaseInterface();
    when(mockDatabase.getAllRecords()).thenAnswer((_) async => []);
    when(mockDatabase.getAllCategories()).thenAnswer((_) async => []);
    when(mockDatabase.getRecurrentRecordPatterns())
        .thenAnswer((_) async => []);
    when(mockDatabase.getAllRecordTagAssociations())
        .thenAnswer((_) async => []);
    when(mockDatabase.getAllWallets()).thenAnswer((_) async => []);
    when(mockDatabase.getAllProfiles()).thenAnswer((_) async => []);
    when(mockDatabase.getBudgets()).thenAnswer((_) async => []);
    when(mockDatabase.getDefaultWallet()).thenAnswer((_) async => null);
    when(mockDatabase.getDefaultProfile()).thenAnswer((_) async => null);
    BackupService.database = mockDatabase;
    BackupService.debugOverrideIsAndroid = true;
    await mockChannels();
  });

  tearDownAll(() async {
    BackupService.debugOverrideIsAndroid = null;
    if (await testDir.exists()) {
      await testDir.delete(recursive: true);
    }
  });

  setUp(() async {
    safCalls.clear();
    stagedContent = null;
    safHandler = null;
    if (await testDir.exists()) {
      await testDir.delete(recursive: true);
    }
    await testDir.create(recursive: true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  });

  Future<void> useCustomSafFolder() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(PreferencesKeys.backupFolderPath, safPath);
    await prefs.setString(PreferencesKeys.backupFolderUri, safUri);
  }

  test('routes the backup through SAF and removes the staged file',
      () async {
    await useCustomSafFolder();
    String? stagedPath;
    safHandler = (call) async {
      if (call.method == 'writeFile') {
        final args = call.arguments as Map;
        stagedPath = args['sourcePath'] as String;
        stagedContent = await File(stagedPath!).readAsString();
        return true;
      }
      return null;
    };

    final file = await BackupService.createJsonBackupFile(
      backupFileName: 'oinkoin_obackup.json',
      directoryPath: safPath,
    );

    expect(file.path, '$safPath/oinkoin_obackup.json');
    expect(safCalls, hasLength(1));
    expect(safCalls.single.method, 'writeFile');
    expect(safCalls.single.arguments['uri'], safUri);
    expect(safCalls.single.arguments['fileName'], 'oinkoin_obackup.json');
    expect(stagedContent, isNotNull);
    expect(stagedContent, isNotEmpty);
    // The staged temp copy must not leak into the temp directory.
    expect(stagedPath, isNotNull);
    expect(File(stagedPath!).existsSync(), isFalse);
  });

  test('surfaces a lost grant as an error instead of a silent file',
      () async {
    await useCustomSafFolder();
    safHandler = (_) async => false;

    expect(
      () => BackupService.createJsonBackupFile(
        backupFileName: 'oinkoin_obackup.json',
        directoryPath: safPath,
      ),
      throwsStateError,
    );
  });

  test('finds the latest backup through the SAF listing', () async {
    await useCustomSafFolder();
    final now = DateTime.now();
    safHandler = (_) async => [
          {
            'name': 'old_obackup.json',
            'lastModifiedMs':
                now.subtract(const Duration(hours: 5)).millisecondsSinceEpoch,
          },
          {
            'name': 'new_obackup.json',
            'lastModifiedMs':
                now.subtract(const Duration(minutes: 10)).millisecondsSinceEpoch,
          },
          {'name': 'notes.txt', 'lastModifiedMs': now.millisecondsSinceEpoch},
          {'name': 'unknown_obackup.json', 'lastModifiedMs': null},
        ];

    final latest = await BackupService.getDateLatestBackup();

    expect(latest, isNotNull);
    expect(
      now.difference(latest!).inMinutes,
      inInclusiveRange(9, 11),
    );
  });

  test('latest-backup detection degrades to null when the grant is lost',
      () async {
    await useCustomSafFolder();
    safHandler = (_) async {
      throw PlatformException(code: 'backup_directory_error');
    };

    expect(await BackupService.getDateLatestBackup(), isNull);
  });

  test('retention cleanup deletes only expired SAF backups', () async {
    await useCustomSafFolder();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(PreferencesKeys.enableEncryptedBackup, true);
    await prefs.setInt(
      PreferencesKeys.backupRetentionIntervalIndex,
      BackupRetentionPeriod.WEEK.index,
    );
    final now = DateTime.now();
    safHandler = (call) async {
      if (call.method == 'listFiles') {
        return [
          {
            'name': 'expired_obackup.json',
            'lastModifiedMs':
                now.subtract(const Duration(days: 8)).millisecondsSinceEpoch,
          },
          {
            'name': 'fresh_obackup.json',
            'lastModifiedMs':
                now.subtract(const Duration(days: 1)).millisecondsSinceEpoch,
          },
          {
            'name': 'expired_notes.txt',
            'lastModifiedMs':
                now.subtract(const Duration(days: 9)).millisecondsSinceEpoch,
          },
          {'name': 'dateless_obackup.json', 'lastModifiedMs': null},
        ];
      }
      return true;
    };

    expect(await BackupService.removeOldAutomaticBackups(), isTrue);

    final deletes =
        safCalls.where((call) => call.method == 'deleteFile').toList();
    expect(deletes, hasLength(1));
    expect(deletes.single.arguments['fileName'], 'expired_obackup.json');
  });

  test('writes a plain file when no custom folder is set', () async {
    safHandler = (_) async {
      fail('must not reach SAF without a custom folder');
    };

    final file = await BackupService.createJsonBackupFile(
      backupFileName: 'plain_obackup.json',
      directoryPath: testDir.path,
    );

    expect(await file.exists(), isTrue);
    expect(await file.readAsString(), isNotEmpty);
  });

  group('storeDatabaseCopy', () {
    Future<File> makeSnapshot() async {
      final snapshot =
          File('${testDir.path}/snapshot_${DateTime.now().microsecondsSinceEpoch}.db');
      await snapshot.writeAsString('snapshot-bytes');
      return snapshot;
    }

    test('routes through SAF and cleans up the snapshot', () async {
      safHandler = (_) async => true;
      final snapshot = await makeSnapshot();

      expect(
        await BackupService.storeDatabaseCopy(snapshot, safPath, safUri),
        isTrue,
      );

      final writes =
          safCalls.where((call) => call.method == 'writeFile').toList();
      expect(writes, hasLength(1));
      expect(writes.single.arguments['uri'], safUri);
      expect(writes.single.arguments['fileName'], 'oinkoin_database.db');
      expect(writes.single.arguments['sourcePath'], snapshot.path);
      expect(await snapshot.exists(), isFalse);
    });

    test('copies directly for plain directories', () async {
      final target = Directory('${testDir.path}/plain_backups');
      await target.create();
      final snapshot = await makeSnapshot();

      expect(await BackupService.storeDatabaseCopy(snapshot, target.path),
          isTrue);
      expect(
        await File('${target.path}/oinkoin_database.db').readAsString(),
        'snapshot-bytes',
      );
      expect(await snapshot.exists(), isFalse);
    });

    test('reports failure but still cleans up', () async {
      safHandler = (_) async => false;
      final snapshot = await makeSnapshot();

      expect(
        await BackupService.storeDatabaseCopy(snapshot, safPath, safUri),
        isFalse,
      );
      expect(await snapshot.exists(), isFalse);
    });
  });
}
