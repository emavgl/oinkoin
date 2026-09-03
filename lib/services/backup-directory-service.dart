import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:piggybank/i18n.dart';
import 'package:piggybank/services/logger.dart';

/// Outcome of a backup directory pick.
enum BackupDirectoryPickOutcome {
  /// A writable folder was chosen.
  success,

  /// The user dismissed the picker.
  cancelled,

  /// A folder was chosen, but the app cannot write into it.
  notWritable,
}

/// Result of a backup directory pick.
class BackupDirectoryPick {
  final BackupDirectoryPickOutcome outcome;

  /// Raw filesystem path of the chosen folder, when available. Used for
  /// display only on Android, where writes go through the Storage Access
  /// Framework instead.
  final String? path;

  /// Content URI of the chosen Android folder. The platform channel persists
  /// the associated grant so the app keeps access across reboots.
  final String? uri;

  const BackupDirectoryPick(this.outcome, this.path, this.uri);
}

/// A document inside the SAF-managed backup folder.
class BackupFolderEntry {
  final String name;

  /// Last-modified timestamp in milliseconds since epoch, when the provider
  /// reports one.
  final int? lastModifiedMs;

  const BackupFolderEntry(this.name, this.lastModifiedMs);
}

/// Lets the user choose the folder where backup files are stored and provides
/// Storage Access Framework access to it.
///
/// On Android the folder is picked with the system picker
/// (ACTION_OPEN_DOCUMENT_TREE) through the platform channel implemented in
/// MainActivity. Scoped storage forbids writing into such a folder through
/// raw file paths, so backup files are written, listed, and deleted through
/// the same channel using the persisted tree URI.
/// On desktop platforms the file_picker package opens a native dialog and
/// regular file access is used.
class BackupDirectoryService {
  static final _logger = Logger.withClass(BackupDirectoryService);

  static const MethodChannel _channel =
      MethodChannel('oinkoin/backup_directory');

  /// Custom backup folders need direct filesystem access that iOS does not
  /// grant to third-party apps, so the option is not offered there.
  static bool get isSupported => !Platform.isIOS;

  /// Opens the platform directory picker and verifies that the app can
  /// actually write into the chosen folder.
  static Future<BackupDirectoryPick> pickDirectory() async {
    String? path;
    String? uri;
    try {
      if (Platform.isAndroid) {
        final result =
            await _channel.invokeMethod<dynamic>('pickBackupDirectory');
        if (result is Map) {
          path = result['path'] as String?;
          uri = result['uri'] as String?;
        }
      } else {
        path = await FilePicker.getDirectoryPath(
            dialogTitle: "Select the destination folder".i18n);
      }
    } catch (e, st) {
      // A missing channel (e.g. outdated native side) or a picker failure
      // is treated like a cancelled pick: nothing is stored.
      _logger.handle(e, st, 'Failed to pick the backup directory');
      return const BackupDirectoryPick(
          BackupDirectoryPickOutcome.cancelled, null, null);
    }

    if (Platform.isAndroid) {
      if (uri == null) {
        return const BackupDirectoryPick(
            BackupDirectoryPickOutcome.cancelled, null, null);
      }
      if (path == null) {
        // The provider is not backed by the local filesystem (e.g. a cloud
        // provider), so no display path exists.
        return BackupDirectoryPick(
            BackupDirectoryPickOutcome.notWritable, null, uri);
      }
      if (!await probeBackupFolder(uri)) {
        _logger.warning('Picked backup directory is not writable');
        return BackupDirectoryPick(
            BackupDirectoryPickOutcome.notWritable, path, uri);
      }
      return BackupDirectoryPick(
          BackupDirectoryPickOutcome.success, path, uri);
    }

    if (path == null) {
      return const BackupDirectoryPick(
          BackupDirectoryPickOutcome.cancelled, null, null);
    }
    if (!await _isWritable(path)) {
      _logger.warning('Picked backup directory is not writable');
      return BackupDirectoryPick(
          BackupDirectoryPickOutcome.notWritable, path, null);
    }
    return BackupDirectoryPick(
        BackupDirectoryPickOutcome.success, path, null);
  }

  /// Verifies through the Storage Access Framework that the app can create
  /// and delete documents in the folder identified by [uri].
  static Future<bool> probeBackupFolder(String uri) async {
    try {
      return await _channel.invokeMethod<bool>(
          'probeWrite', {'uri': uri}) ?? false;
    } catch (e, st) {
      _logger.handle(e, st, 'Backup directory write probe failed');
      return false;
    }
  }

  /// Copies the staged backup file at [stagedFilePath] into the folder
  /// identified by [uri], overwriting an existing document with the same
  /// name. Returns false when the grant was lost or the folder is gone,
  /// so callers can surface an error instead of crashing.
  static Future<bool> writeBackupFile(
    String uri,
    String fileName,
    String stagedFilePath,
  ) async {
    try {
      return await _channel.invokeMethod<bool>('writeFile', {
            'uri': uri,
            'fileName': fileName,
            'sourcePath': stagedFilePath,
          }) ??
          false;
    } catch (e, st) {
      _logger.handle(e, st, 'Failed to write backup file into custom folder');
      return false;
    }
  }

  /// Deletes the document named [fileName] from the folder identified by
  /// [uri]. Returns false when no such document exists or the folder is
  /// no longer accessible.
  static Future<bool> deleteBackupFile(String uri, String fileName) async {
    try {
      return await _channel.invokeMethod<bool>('deleteFile', {
            'uri': uri,
            'fileName': fileName,
          }) ??
          false;
    } catch (e, st) {
      _logger.handle(e, st, 'Failed to delete backup file in custom folder');
      return false;
    }
  }

  /// Lists the documents in the folder identified by [uri]. Returns an
  /// empty list when the grant was revoked or the folder is gone.
  static Future<List<BackupFolderEntry>> listBackupFiles(String uri) async {
    try {
      final result = await _channel
          .invokeMethod<List<dynamic>>('listFiles', {'uri': uri});
      if (result == null) {
        return const [];
      }
      return result
          .whereType<Map>()
          .map((entry) => BackupFolderEntry(
                entry['name'] as String? ?? '',
                entry['lastModifiedMs'] as int?,
              ))
          .where((entry) => entry.name.isNotEmpty)
          .toList();
    } catch (e, st) {
      _logger.handle(e, st, 'Failed to list backup files in custom folder');
      return const [];
    }
  }

  /// Verifies that a backup file can be created in [path] by writing and
  /// deleting a temporary probe file. Used on desktop platforms, where the
  /// picked folder is accessed through regular file paths.
  static Future<bool> _isWritable(String path) async {
    try {
      final directory = Directory(path);
      if (!await directory.exists()) return false;
      final probe = File('${directory.path}/.oinkoin_write_probe');
      await probe.writeAsString('');
      await probe.delete();
      return true;
    } catch (e, st) {
      _logger.handle(e, st, 'Backup directory write probe failed');
      return false;
    }
  }
}
