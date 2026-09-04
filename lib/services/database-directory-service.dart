import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:piggybank/i18n.dart';
import 'package:piggybank/services/logger.dart';

/// Lets the user choose the folder holding the database file.
///
/// SQLite needs a real filesystem path, which scoped storage does not grant
/// outside app-private directories — so unlike backups (SAF tree URIs),
/// a custom database folder is only offered on desktop platforms, where
/// the app has regular file access.
class DatabaseDirectoryService {
  static final _logger = Logger.withClass(DatabaseDirectoryService);

  /// Custom database folders need direct filesystem access that mobile
  /// platforms do not grant to SQLite, so the option is desktop-only.
  static bool get isSupported =>
      Platform.isLinux || Platform.isWindows || Platform.isMacOS;

  /// Opens the native directory picker and verifies that a database file
  /// can be created in the chosen folder. Returns the path, or null when
  /// the user cancels or the folder is not writable.
  static Future<String?> pickDirectory() async {
    String? path;
    try {
      path = await FilePicker.getDirectoryPath(
          dialogTitle: "Select the database folder".i18n);
    } catch (e, st) {
      _logger.handle(e, st, 'Failed to pick the database directory');
      return null;
    }
    if (path == null) return null;
    if (!await _isWritable(path)) {
      _logger.warning('Picked database directory is not writable');
      return null;
    }
    return path;
  }

  /// Verifies that a database file can be created in [path] by writing and
  /// deleting a temporary probe file.
  static Future<bool> _isWritable(String path) async {
    try {
      final directory = Directory(path);
      if (!await directory.exists()) return false;
      final probe = File('${directory.path}/.oinkoin_write_probe');
      await probe.writeAsString('');
      await probe.delete();
      return true;
    } catch (e, st) {
      _logger.handle(e, st, 'Database directory write probe failed');
      return false;
    }
  }
}
