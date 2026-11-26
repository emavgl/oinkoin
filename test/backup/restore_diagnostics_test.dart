import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/services/backup-service.dart';
import 'package:piggybank/services/logger.dart';
import 'package:piggybank/settings/backup-restore-dialogs.dart';

/// Diagnostic logging of the restore path.
///
/// The restore of issue #470 fails on some devices without any visible
/// feedback, and the Logs page shows nothing because the restore flow did not
/// log its picker step. These tests pin the added diagnostics (they must stay
/// in place) and simultaneously pin the current behaviour: a failing picker is
/// still only retried, never replaced by a different flow or a new dialog.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The test host has no registered file picker plugin, so the platform
  // instance is scripted directly instead of the method channel.
  _FakeFilePicker? picker;

  List<String> logMessages() =>
      globalTalker.history.map((entry) => entry.message ?? '').toList();

  bool logged(String fragment) =>
      logMessages().any((message) => message.contains(fragment));

  const MethodChannel packageInfoChannel = MethodChannel(
    'dev.fluttercommunity.plus/package_info',
  );

  setUp(() {
    globalTalker.cleanHistory();
    picker = _FakeFilePicker();
    FilePickerPlatform.instance = picker!;
    // PackageInfo.fromPlatform() never completes when the channel is unmocked.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(packageInfoChannel, (call) async {
          if (call.method == 'getAll') {
            return <String, dynamic>{
              'appName': 'TestApp',
              'packageName': 'com.test.app',
              'version': '1.0.0',
              'buildNumber': '1',
            };
          }
          return null;
        });
  });

  tearDown(() {
    globalTalker.cleanHistory();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(packageInfoChannel, null);
  });

  group('BackupService.isEncrypted diagnostics', () {
    test('valid JSON is not encrypted and is not reported as an error', () async {
      final file = File(
        '${Directory.systemTemp.path}/oinkoin_valid_${DateTime.now().microsecondsSinceEpoch}.json',
      );
      await file.writeAsString('{"records": []}');
      addTearDown(() => file.existsSync() ? file.delete() : null);

      expect(await BackupService.isEncrypted(file), isFalse);
      expect(logged('Could not read'), isFalse);
    });

    test('non-JSON content is reported as encrypted', () async {
      final file = File(
        '${Directory.systemTemp.path}/oinkoin_encrypted_${DateTime.now().microsecondsSinceEpoch}.json',
      );
      await file.writeAsString('not json at all');
      addTearDown(() => file.existsSync() ? file.delete() : null);

      expect(await BackupService.isEncrypted(file), isTrue);
      expect(logged('is not valid JSON'), isTrue);
    });

    test(
      'an unreadable file keeps reporting encrypted but is logged',
      () async {
        final file = File('/nonexistent/oinkoin/oinkoin_obackup.json');

        // Behaviour is unchanged: the password path is still offered.
        expect(await BackupService.isEncrypted(file), isTrue);
        expect(logged('Could not read'), isTrue);
      },
    );
  });

  group('restore flow diagnostics', () {
    testWidgets('a failing picker is logged and stays a silent retry', (
      tester,
    ) async {
      // The filtered picker fails, the unfiltered retry is cancelled.
      picker!.onPick = (bool filtered) async {
        if (filtered) {
          throw PlatformException(
            code: 'unknown_path',
            message: 'Failed to retrieve path.',
          );
        }
        return <PlatformFile>[];
      };

      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (BuildContext builderContext) {
              context = builderContext;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      await BackupRestoreDialog.importFromBackupFile(context);
      await tester.pump();

      // The unfiltered retry happened, in that order.
      expect(picker!.attempts, <bool>[true, false]);
      // The failure of the filtered picker is no longer swallowed.
      expect(logged('Filtered file picker failed'), isTrue);
      expect(logged('unknown_path'), isTrue);
      // The cancelled retry is distinguishable from a path-less document.
      expect(logged('No usable backup file picked'), isTrue);
      // No new UI, no new flow: nothing is shown on failure.
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('the attempt is logged with device and app details', (
      tester,
    ) async {
      picker!.onPick = (bool filtered) async => <PlatformFile>[];

      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (BuildContext builderContext) {
              context = builderContext;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      await BackupRestoreDialog.importFromBackupFile(context);
      await tester.pump();

      expect(logged('Restore from backup file started'), isTrue);
      expect(logged('platform='), isTrue);
      // The lifecycle observer is detached again when the flow ends.
      expect(logged('Restore flow ended after'), isTrue);
      expect(find.byType(AlertDialog), findsNothing);
    });
  });
}

/// Scriptable stand-in for the platform file picker.
class _FakeFilePicker extends FilePickerPlatform {
  /// Whether each call was made with an extension filter, in call order.
  final List<bool> attempts = [];

  Future<List<PlatformFile>> Function(bool filtered) onPick = (
    bool filtered,
  ) async => <PlatformFile>[];

  @override
  Future<List<PlatformFile>> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) {
    final filtered = allowedExtensions != null && allowedExtensions.isNotEmpty;
    attempts.add(filtered);
    return onPick(filtered);
  }
}
