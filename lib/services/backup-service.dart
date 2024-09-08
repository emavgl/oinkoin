import 'dart:convert';
import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:piggybank/models/backup.dart';
import 'package:piggybank/services/database/exceptions.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:encrypt/encrypt.dart' as encrypt; // Import the encrypt package

import 'database/database-interface.dart';

/// BackupService contains the methods to create/restore backup file
class BackupService {

  // not final because it is swapped in the tests
  static DatabaseInterface database = ServiceConfig.database;

  /// Generates a backup file name containing the app package name, version, and current time.
  static Future<String> generateBackupFileName() async {
    // Get app information
    final packageInfo = await PackageInfo.fromPlatform();
    final appName = packageInfo.packageName;  // The package name
    final version = packageInfo.version;      // The app version

    // Get current date and time
    final now = DateTime.now();
    final formattedDate = now.toIso8601String().replaceAll(":", "-"); // Replace colon to avoid issues in file naming

    // Construct the file name
    return "${appName}_${version}_${formattedDate}_backup.json";
  }

  /// Creates a JSON backup file.
  /// [backupFileName] - optional, if not specified uses the generated backup file name.
  /// [directoryPath] - optional, if not specified it uses the application's documents directory.
  /// [encryptionPassword] - optional, if provided, encrypts the backup JSON string with the password.
  static Future<File> createJsonBackupFile({
    String? backupFileName,
    String? directoryPath,
    String? encryptionPassword,
  }) async {
    // Generate backup file name if not provided
    backupFileName ??= await generateBackupFileName();

    // Use the provided directory path or default to the application's documents directory
    final path = directoryPath != null
        ? Directory(directoryPath)
        : await getApplicationDocumentsDirectory();

    // Ensure the directory exists
    await path.create(recursive: true);

    // Create the backup
    var records = await database.getAllRecords();
    var categories = await database.getAllCategories();
    var recurrentRecordPatterns = await database.getRecurrentRecordPatterns();
    var backup = Backup(categories, records, recurrentRecordPatterns);
    var backupJsonStr = jsonEncode(backup.toMap());

    // Encrypt the backup JSON string if an encryption password is provided
    if (encryptionPassword != null && encryptionPassword.isNotEmpty) {
      final key = encrypt.Key.fromUtf8(encryptionPassword.padRight(32, '*').substring(0, 32)); // Ensure the key length is 32 bytes
      final iv = encrypt.IV.fromLength(16); // AES uses a 16 bytes IV
      final encrypter = encrypt.Encrypter(encrypt.AES(key));
      final encrypted = encrypter.encrypt(backupJsonStr, iv: iv);
      backupJsonStr = encrypted.base64; // Save the encrypted data as Base64
    }

    // Write on disk
    var backupJsonOnDisk = File("${path.path}/$backupFileName");
    return await backupJsonOnDisk.writeAsString(backupJsonStr);
  }

  /// Imports data from a backup file. If an encryption password is provided,
  /// it attempts to decrypt the file content before importing.
  ///
  /// [inputFile] - the backup file to import.
  /// [encryptionPassword] - optional, if provided, attempts to decrypt the backup file content.
  static Future<bool> importDataFromBackupFile(File inputFile, {String? encryptionPassword}) async {
    try {
      String fileContent = await inputFile.readAsString();

      // Decrypt the file content if an encryption password is provided
      if (encryptionPassword != null && encryptionPassword.isNotEmpty) {
        final key = encrypt.Key.fromUtf8(encryptionPassword.padRight(32, '*').substring(0, 32)); // Ensure the key length is 32 bytes
        final iv = encrypt.IV.fromLength(16); // AES uses a 16 bytes IV
        final encrypter = encrypt.Encrypter(encrypt.AES(key));

        try {
          final decrypted = encrypter.decrypt64(fileContent, iv: iv);
          fileContent = decrypted;
        } catch (e) {
          print('Decryption failed: $e');
          return false; // Return false if decryption fails
        }
      }

      var jsonMap = jsonDecode(fileContent);
      Backup backup = Backup.fromMap(jsonMap);

      // Add categories
      for (var backupCategory in backup.categories) {
        try {
          await database.addCategory(backupCategory);
        } on ElementAlreadyExists {
          print("${backupCategory!.name} already exists.");
        }
      }

      // Add records
      for (var backupRecord in backup.records) {
        if (await database.getMatchingRecord(backupRecord) == null) {
          // we need to strip the ID, since there could be another record
          // with the same ID, we want to ensure no collisions happen
          backupRecord?.id = null;
          await database.addRecord(backupRecord);
        } else {
          print(
              "${backupRecord!.category!.name} of value ${backupRecord.value} already exists.");
        }
      }

      // Add recurrent patterns
      for (var backupRecurrentPatterns in backup.recurrentRecordsPattern) {
        String? recurrentPatternId = backupRecurrentPatterns.id;
        if (await database.getRecurrentRecordPattern(recurrentPatternId) ==
            null) {
          await database.addRecurrentRecordPattern(backupRecurrentPatterns);
        } else {
          print(
              "Recurrent pattern with id $recurrentPatternId already exists.");
        }
      }

      return true;
    } catch (err) {
      return false;
    }
  }
}
