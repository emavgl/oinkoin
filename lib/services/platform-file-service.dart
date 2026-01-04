import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

/// Platform-aware file sharing/saving service
/// On mobile: Uses share_plus
/// On desktop: Uses file_selector for "Save As" dialog
class PlatformFileService {

  /// Check if we're running on a desktop platform
  static bool get isDesktop {
    if (kIsWeb) return false;
    return Platform.isLinux || Platform.isWindows || Platform.isMacOS;
  }

  /// Share or save a file depending on platform
  /// On mobile: Opens share sheet
  /// On desktop: Opens "Save As" dialog
  static Future<bool> shareOrSaveFile({
    required String filePath,
    String? suggestedName,
    String? mimeType,
  }) async {
    final file = File(filePath);

    if (!await file.exists()) {
      return false;
    }

    if (isDesktop) {
      // Desktop: Use "Save As" dialog
      return await _saveFileAs(file, suggestedName);
    } else {
      // Mobile: Use share sheet
      return await _shareFile(file);
    }
  }

  /// Save file using "Save As" dialog (desktop only)
  static Future<bool> _saveFileAs(File sourceFile, String? suggestedName) async {
    try {
      final fileName = suggestedName ?? sourceFile.path.split('/').last;

      // Determine file extension and type group
      final extension = fileName.split('.').last.toLowerCase();
      final XTypeGroup typeGroup = _getTypeGroup(extension);

      // Show save file dialog
      final FileSaveLocation? result = await getSaveLocation(
        suggestedName: fileName,
        acceptedTypeGroups: [typeGroup],
      );

      if (result == null) {
        // User cancelled
        return false;
      }

      // Read source file and write to selected location
      final bytes = await sourceFile.readAsBytes();
      final targetFile = File(result.path);
      await targetFile.writeAsBytes(bytes);

      return true;
    } catch (e) {
      print('Error saving file: $e');
      return false;
    }
  }

  /// Share file using share sheet (mobile only)
  static Future<bool> _shareFile(File file) async {
    try {
      final result = await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)]),
      );

      return result.status == ShareResultStatus.success ||
             result.status == ShareResultStatus.unavailable; // unavailable means it worked on some platforms
    } catch (e) {
      print('Error sharing file: $e');
      return false;
    }
  }

  /// Get XTypeGroup based on file extension
  static XTypeGroup _getTypeGroup(String extension) {
    switch (extension) {
      case 'json':
        return const XTypeGroup(
          label: 'JSON files',
          extensions: ['json'],
          mimeTypes: ['application/json'],
        );
      case 'csv':
        return const XTypeGroup(
          label: 'CSV files',
          extensions: ['csv'],
          mimeTypes: ['text/csv'],
        );
      case 'db':
        return const XTypeGroup(
          label: 'Database files',
          extensions: ['db'],
          mimeTypes: ['application/x-sqlite3'],
        );
      default:
        return const XTypeGroup(
          label: 'All files',
          extensions: ['*'],
        );
    }
  }
}

