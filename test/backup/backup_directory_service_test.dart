import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/services/backup-directory-service.dart';

/// Android Storage Access Framework behavior of [BackupDirectoryService].
///
/// `Platform.isAndroid` is false on the desktop test host, so the
/// Android branches are exercised through the [BackupDirectoryService]
/// test overrides. The platform channel itself is faked with scriptable
/// responses, including grant-loss failures.
void main() {
  const MethodChannel channel = MethodChannel('oinkoin/backup_directory');

  TestWidgetsFlutterBinding.ensureInitialized();

  Future<dynamic> Function(MethodCall)? handler;
  final List<MethodCall> calls = [];

  setUp(() {
    calls.clear();
    handler = null;
    BackupDirectoryService.debugOverrideIsAndroid = true;
    BackupDirectoryService.debugOverrideIsIOS = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      calls.add(call);
      if (handler != null) {
        return handler!(call);
      }
      return null;
    });
  });

  tearDown(() {
    BackupDirectoryService.debugOverrideIsAndroid = null;
    BackupDirectoryService.debugOverrideIsIOS = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('probeBackupFolder', () {
    test('returns true when the native probe succeeds', () async {
      handler = (_) async => true;

      expect(
        await BackupDirectoryService.probeBackupFolder('content://tree/x'),
        isTrue,
      );
    });

    test('returns false when the native probe fails', () async {
      handler = (_) async => false;

      expect(
        await BackupDirectoryService.probeBackupFolder('content://tree/x'),
        isFalse,
      );
    });

    test('returns false when the grant was lost', () async {
      handler = (_) async {
        throw PlatformException(code: 'backup_directory_error');
      };

      expect(
        await BackupDirectoryService.probeBackupFolder('content://tree/x'),
        isFalse,
      );
    });
  });

  group('writeBackupFile', () {
    test('forwards uri, file name, and staged path', () async {
      handler = (_) async => true;

      final written = await BackupDirectoryService.writeBackupFile(
        'content://tree/x',
        'oinkoin_obackup.json',
        '/tmp/staged.json',
      );

      expect(written, isTrue);
      expect(calls, hasLength(1));
      expect(calls.single.method, 'writeFile');
      expect(
        calls.single.arguments,
        {
          'uri': 'content://tree/x',
          'fileName': 'oinkoin_obackup.json',
          'sourcePath': '/tmp/staged.json',
        },
      );
    });

    test('returns false when the folder is gone', () async {
      handler = (_) async => false;

      expect(
        await BackupDirectoryService.writeBackupFile(
          'content://tree/gone',
          'oinkoin_obackup.json',
          '/tmp/staged.json',
        ),
        isFalse,
      );
    });

    test('returns false instead of throwing on channel errors', () async {
      handler = (_) async {
        throw PlatformException(code: 'backup_directory_error');
      };

      expect(
        await BackupDirectoryService.writeBackupFile(
          'content://tree/gone',
          'oinkoin_obackup.json',
          '/tmp/staged.json',
        ),
        isFalse,
      );
    });
  });

  group('deleteBackupFile', () {
    test('returns true when the document is deleted', () async {
      handler = (_) async => true;

      expect(
        await BackupDirectoryService.deleteBackupFile(
          'content://tree/x',
          'old_obackup.json',
        ),
        isTrue,
      );
    });

    test('returns false when no such document exists', () async {
      handler = (_) async => false;

      expect(
        await BackupDirectoryService.deleteBackupFile(
          'content://tree/x',
          'missing_obackup.json',
        ),
        isFalse,
      );
    });

    test('returns false instead of throwing on channel errors', () async {
      handler = (_) async {
        throw PlatformException(code: 'backup_directory_error');
      };

      expect(
        await BackupDirectoryService.deleteBackupFile(
          'content://tree/gone',
          'old_obackup.json',
        ),
        isFalse,
      );
    });
  });

  group('listBackupFiles', () {
    test('parses entries and drops empty names', () async {
      handler = (_) async => [
            {'name': 'a_obackup.json', 'lastModifiedMs': 123},
            {'name': 'b_obackup.json', 'lastModifiedMs': null},
            {'name': '', 'lastModifiedMs': 456},
          ];

      final entries =
          await BackupDirectoryService.listBackupFiles('content://tree/x');

      expect(entries.map((e) => e.name), ['a_obackup.json', 'b_obackup.json']);
      expect(entries.first.lastModifiedMs, 123);
      expect(entries.last.lastModifiedMs, isNull);
    });

    test('returns empty when the grant was revoked', () async {
      handler = (_) async {
        throw PlatformException(code: 'backup_directory_error');
      };

      expect(
        await BackupDirectoryService.listBackupFiles('content://tree/gone'),
        isEmpty,
      );
    });
  });

  group('pickDirectory on Android', () {
    test('success when the folder is writable', () async {
      handler = (call) async {
        if (call.method == 'pickBackupDirectory') {
          return {'path': '/storage/emulated/0/Backups', 'uri': 'content://tree/x'};
        }
        return true;
      };

      final pick = await BackupDirectoryService.pickDirectory();

      expect(pick.outcome, BackupDirectoryPickOutcome.success);
      expect(pick.path, '/storage/emulated/0/Backups');
      expect(pick.uri, 'content://tree/x');
    });

    test('cancelled when the picker is dismissed', () async {
      handler = (_) async => null;

      final pick = await BackupDirectoryService.pickDirectory();

      expect(pick.outcome, BackupDirectoryPickOutcome.cancelled);
      expect(pick.path, isNull);
      expect(pick.uri, isNull);
    });

    test('notWritable for cloud providers without a display path', () async {
      handler = (_) async => {'path': null, 'uri': 'content://cloud/tree'};

      final pick = await BackupDirectoryService.pickDirectory();

      expect(pick.outcome, BackupDirectoryPickOutcome.notWritable);
    });

    test('notWritable when the write probe fails', () async {
      handler = (call) async {
        if (call.method == 'pickBackupDirectory') {
          return {'path': '/storage/emulated/0/RO', 'uri': 'content://tree/ro'};
        }
        return false;
      };

      final pick = await BackupDirectoryService.pickDirectory();

      expect(pick.outcome, BackupDirectoryPickOutcome.notWritable);
      expect(pick.path, '/storage/emulated/0/RO');
    });
  });

  group('platform gating', () {
    test('iOS keeps the previous behavior: cancelled, unsupported', () async {
      BackupDirectoryService.debugOverrideIsAndroid = false;
      BackupDirectoryService.debugOverrideIsIOS = true;
      handler = (_) async {
        fail('must not reach the native picker on iOS');
      };

      final pick = await BackupDirectoryService.pickDirectory();

      expect(pick.outcome, BackupDirectoryPickOutcome.cancelled);
      expect(BackupDirectoryService.isSupported, isFalse);
    });

    test('Android and desktop support the option', () {
      expect(BackupDirectoryService.isSupported, isTrue);
    });
  });
}
