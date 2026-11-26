import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:future_progress_dialog/future_progress_dialog.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:piggybank/i18n.dart';

import '../helpers/alert-dialog-builder.dart';
import '../services/backup-service.dart';
import '../services/logger.dart';

/// Logs the app lifecycle transitions observed during a restore attempt.
///
/// The picker leaves the app (the system chooser is another activity), so the
/// log shows whether the app came back and how many times. When the app is
/// resumed but no picker result line follows, the activity result was lost
/// between the picker and the plugin: that is the signature of the reports in
/// which "the picker opens, the file is selected, and nothing happens".
class _RestoreLifecycleLogger with WidgetsBindingObserver {
  _RestoreLifecycleLogger(this._stopwatch);

  final Stopwatch _stopwatch;

  void attach() => WidgetsBinding.instance.addObserver(this);

  void detach() => WidgetsBinding.instance.removeObserver(this);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    BackupRestoreDialog._logger.debug(
      'App lifecycle during restore: $state '
      '(${_stopwatch.elapsedMilliseconds} ms after the flow started)',
    );
  }
}

class BackupRestoreDialog {
  static final _logger = Logger.withClass(BackupRestoreDialog);

  static Future<String?> showRestoreBackupDialog(BuildContext context) {
    TextEditingController passwordController = TextEditingController();
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Enter decryption password'.i18n),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "It appears the file has been encrypted. Enter the password:"
                    .i18n,
              ),
              SizedBox(height: 10),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password'.i18n,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog without action
              },
              child: Text("Cancel".i18n),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(
                  context,
                ).pop(passwordController.text); // Return password if provided
              },
              child: Text("Load".i18n),
            ),
          ],
        );
      },
    );
  }

  /// Describes the device and the app version. Recorded with every restore
  /// attempt so a report can be matched to a specific build and Android
  /// version without asking the user for details.
  static Future<String> _describeRuntime() async {
    final buffer = StringBuffer(
      'platform=${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
    );
    try {
      // Bounded so a misbehaving platform channel can never delay the restore.
      final packageInfo = await PackageInfo.fromPlatform().timeout(
        const Duration(seconds: 2),
      );
      buffer.write(', app=${packageInfo.version}+${packageInfo.buildNumber}');
    } catch (error) {
      buffer.write(', app version unavailable ($error)');
    }
    return buffer.toString();
  }

  /// Summarizes what the platform picker handed back. The local path is null
  /// for documents opened through a `content://` URI (Android Storage Access
  /// Framework), which the restore flow cannot read; the URI, the concrete
  /// type and whether the content can actually be read make that case visible
  /// in the log.
  static Future<String> _describePickedFile(PlatformFile picked) async {
    int? lengthBytes;
    String size;
    try {
      lengthBytes = await picked.length();
      size = '$lengthBytes bytes';
    } catch (error) {
      size = 'size unavailable ($error)';
    }
    // The content is read through the platform file object, so a document that
    // is listed but cannot be opened is distinguishable from a readable one.
    // Backups are small and are read again by the import shortly after, but a
    // huge file is skipped so this cannot become a memory problem.
    String readable;
    if (lengthBytes != null && lengthBytes > 32 * 1024 * 1024) {
      readable = 'content not probed (${lengthBytes} bytes)';
    } else {
      try {
        final bytes = await picked.readAsBytes();
        readable = 'content readable (${bytes.length} bytes)';
      } catch (error) {
        readable = 'content unreadable ($error)';
      }
    }
    return 'name=${picked.name}, path=${picked.path ?? "<null>"}, '
        'uri=${picked.uri}, type=${picked.runtimeType}, length=$size, '
        '$readable';
  }

  /// Describes a local file without reading it, so an unreadable or truncated
  /// backup file is visible in the log.
  static String _describeLocalFile(File file) {
    try {
      final exists = file.existsSync();
      final size = exists ? file.lengthSync() : -1;
      return 'path=${file.path}, exists=$exists, size=$size bytes';
    } catch (error) {
      return 'path=${file.path}, inaccessible ($error)';
    }
  }

  static Future<void> importFromBackupFile(BuildContext context) async {
    final stopwatch = Stopwatch()..start();
    final lifecycleLogger = _RestoreLifecycleLogger(stopwatch)..attach();
    try {
      await _restoreFromBackupFile(context, stopwatch);
    } finally {
      // Detaching observes nothing and never alters the outcome of the flow.
      lifecycleLogger.detach();
      _logger.debug(
        'Restore flow ended after ${stopwatch.elapsedMilliseconds} ms',
      );
    }
  }

  static Future<void> _restoreFromBackupFile(
    BuildContext context,
    Stopwatch stopwatch,
  ) async {
    _logger.info(
      'Restore from backup file started (${await _describeRuntime()})',
    );
    try {
      await FilePicker.clearTemporaryFiles();
      _logger.debug('FilePicker temporary cache cleared');
    } catch (e) {
      _logger.debug('FilePicker.clearTemporaryFiles() failed: $e');
    }
    List<PlatformFile> result;
    try {
      _logger.debug('Opening the file picker filtered to .json files');
      result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      _logger.debug(
        'Filtered file picker returned ${result.length} file(s) after '
        '${stopwatch.elapsedMilliseconds} ms',
      );
    } catch (e, st) {
      // strange issue on android-9 due to filter. The failure is logged before
      // retrying: it is the only trace of what the filtered picker did.
      _logger.error(
        'Filtered file picker failed, retrying unfiltered: $e\n$st',
      );
      result = await FilePicker.pickFiles();
      _logger.debug(
        'Unfiltered file picker returned ${result.length} file(s) after '
        '${stopwatch.elapsedMilliseconds} ms',
      );
    }
    for (final picked in result) {
      _logger.debug('Picked file: ${await _describePickedFile(picked)}');
    }
    if (result.isNotEmpty && result.single.path != null) {
      File file = File(result.single.path!);
      _logger.info('Backup file selected: ${_describeLocalFile(file)}');
      String? password;
      final isEncrypted = await BackupService.isEncrypted(file);
      _logger.info('Backup file ${file.path} appears encrypted: $isEncrypted');
      if (isEncrypted) {
        password = await showRestoreBackupDialog(context);
        if (password != null && password.isNotEmpty) {
          password = BackupService.hashPassword(password);
          _logger.debug('Decryption password provided');
        } else {
          _logger.warning('Restore aborted: no decryption password provided');
          await showBackupRestoreDialog(
            context,
            "Restore unsuccessful".i18n,
            "Can't decrypt without a password".i18n,
          );
          return;
        }
      }
      bool successful = await showDialog(
        context: context,
        builder: (context) => FutureProgressDialog(
          BackupService.importDataFromBackupFile(
            file,
            encryptionPassword: password,
          ),
        ),
      );
      _logger.info(
        'Restore finished: the import reported $successful '
        '(type: ${successful.runtimeType}) after '
        '${stopwatch.elapsedMilliseconds} ms',
      );
      if (successful) {
        await showBackupRestoreDialog(
          context,
          "Restore successful".i18n,
          "The data from the backup file are now restored.".i18n,
        );
      } else {
        await showBackupRestoreDialog(
          context,
          "Restore unsuccessful".i18n,
          "Make sure you have the latest version of the app. If so, the backup file may be corrupted."
              .i18n,
        );
      }
    } else {
      // Either the picker was dismissed or it returned a document without a
      // local path. Both cases used to be indistinguishable in the log.
      _logger.warning(
        'No usable backup file picked (${result.length} result(s)); '
        'the restore was not attempted',
      );
    }
  }

  static Future<void> showBackupRestoreDialog(
    BuildContext context,
    String title,
    String subtitle,
  ) async {
    AlertDialogBuilder resultDialog = AlertDialogBuilder(title)
        .addSubtitle(subtitle)
        .addTrueButtonName("OK".i18n);
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return resultDialog.build(context);
      },
    );
  }
}
