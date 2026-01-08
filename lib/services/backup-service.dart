import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

import 'package:i18n_extension/default.i18n.dart';
import 'package:intl/intl.dart';
import 'package:file_selector/file_selector.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:piggybank/models/backup.dart';
import 'package:piggybank/services/database/exceptions.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:piggybank/settings/backup-retention-period.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../settings/constants/preferences-keys.dart';
import '../settings/preferences-utils.dart';
import 'database/database-interface.dart';
import 'package:crypto/crypto.dart';

import 'database/sqlite-database.dart';
import 'logger.dart';

/// BackupService contains the methods to create/restore backup file
class BackupService {
  static final _logger = Logger.withContext('BackupService');

  static String DEFAULT_STORAGE_DIR = Platform.isAndroid
      ? '/storage/emulated/0/Documents/oinkoin'
      : '${Platform.environment["HOME"]}/.oinkoin';

  static const String MANDATORY_BACKUP_SUFFIX = "obackup.json";

  static String ERROR_MSG =
      "Unable to create a backup: please, delete manually the old backup".i18n;

  static const Duration AUTOMATIC_BACKUP_THRESHOLD = Duration(hours: 1);

  // not final because it is swapped in the tests
  static DatabaseInterface database = ServiceConfig.database;

  /// Gets the platform-appropriate default backup directory
  /// Android: /storage/emulated/0/Documents/oinkoin
  /// Linux/macOS: ~/.oinkoin
  /// Windows: AppData/Local/oinkoin
  static Future<String> getDefaultBackupDirectory() async {
    if (Platform.isIOS || Platform.isMacOS) {
      // macOS or iOS
      final documentsDir = await getApplicationDocumentsDirectory();
      return '${documentsDir.parent.path}/Documents/oinkoin';
    } else if (Platform.isAndroid)
      return DEFAULT_STORAGE_DIR;
    else
      return (await getApplicationDocumentsDirectory()).path;
  }

  /// Generates a backup file name containing the app package name, version, and current time.
  static Future<String> generateBackupFileName() async {
    // Get app information
    final packageInfo = await PackageInfo.fromPlatform();
    final appName = packageInfo.packageName.split(".").last; // The package name
    final version = packageInfo.version; // The app version

    // Get current date and time
    final now = DateTime.now();
    final dateStr = now.toIso8601String().split(".")[0]; // Strip milliseconds
    final formattedDate = dateStr.replaceAll(
        ":", "-"); // Replace colon to avoid issues in file naming

    // Construct the file name
    return "${appName}_${version}_${formattedDate}_${MANDATORY_BACKUP_SUFFIX}";
  }

  /// Generates a backup file name containing the app package name, version, and current time.
  static Future<String> getDefaultFileName() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final appName = packageInfo.packageName.split(".").last; // The package name
    return "${appName}_${MANDATORY_BACKUP_SUFFIX}";
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
    try {
      _logger.info('Starting backup creation...');

      // Generate backup file name if not provided
      backupFileName ??= await generateBackupFileName();
      _logger.debug('Backup filename: $backupFileName');

      // Use the provided directory path or default to the application's documents directory
      final path = directoryPath != null
          ? Directory(directoryPath)
          : await getApplicationDocumentsDirectory();

      _logger.debug('Backup directory: ${path.path}');

      // Ensure the directory exists
      await path.create(recursive: true);

      final packageInfo = await PackageInfo.fromPlatform();
      final appName = packageInfo.packageName; // The package name
      final version = packageInfo.version; // The app version
      final databaseVersion = SqliteDatabase.version.toString();

      _logger.debug('Fetching data for backup...');
      // Create the backup
      var records = await database.getAllRecords();
      var categories = await database.getAllCategories();
      var recurrentRecordPatterns = await database.getRecurrentRecordPatterns();
      var recordTagAssociations = await database.getAllRecordTagAssociations();

      _logger.info(
          'Backup data: ${records.length} records, ${categories.length} categories, ${recurrentRecordPatterns.length} recurrent patterns, ${recordTagAssociations.length} tags');

      var backup = Backup(appName, version, databaseVersion, categories,
          records, recurrentRecordPatterns, recordTagAssociations);
      var backupJsonStr = jsonEncode(backup.toMap());

      // Encrypt the backup JSON string if an encryption password is provided
      if (encryptionPassword != null && encryptionPassword.isNotEmpty) {
        _logger.info('Encrypting backup...');
        backupJsonStr = encryptData(backupJsonStr, encryptionPassword);
      }

      // Write on disk
      if (!Platform.isAndroid && !Platform.isIOS) {
        final FileSaveLocation? result = await getSaveLocation(
          suggestedName: backupFileName,
          initialDirectory: path.path,
        );
        if (result == null) throw Exception("Canceled by user");

        final Uint8List fileData =
            Uint8List.fromList(utf8.encode(backupJsonStr));
        final XFile textFile = XFile.fromData(
          fileData,
          name: backupFileName,
        );
        await textFile.saveTo(result.path);
        return File(textFile.path);
      } else {
        var backupJsonOnDisk = File("${path.path}/$backupFileName");
        var result = await backupJsonOnDisk.writeAsString(backupJsonStr);

        _logger.info(
            'Backup created successfully: ${backupJsonOnDisk.path} (${backupJsonStr.length} bytes)');
        return result;
      }
    } catch (e, st) {
      _logger.handle(e, st, 'Failed to create backup');
      rethrow;
    }
  }

  /// Determines if an automatic backup should be created.
  /// Returns true if the latest backup was created more than 1 hour ago, false otherwise.
  static Future<bool> shouldCreateAutomaticBackup() async {
    try {
      var prefs = await SharedPreferences.getInstance();

      // Use PreferencesUtils for enableAutomaticBackup
      bool enableAutomaticBackup = PreferencesUtils.getOrDefault<bool>(
          prefs, PreferencesKeys.enableAutomaticBackup)!;

      if (!enableAutomaticBackup) {
        _logger.debug("Automatic backup disabled in settings");
        return false;
      }

      final latestBackupDate = await getDateLatestBackup();

      // If no backups exist, return true to create a backup
      if (latestBackupDate == null) {
        _logger.info("No previous backup found, automatic backup needed");
        return true;
      }

      // Check if the time since the latest backup exceeds the threshold
      final now = DateTime.now();
      final shouldBackup =
          now.difference(latestBackupDate) > AUTOMATIC_BACKUP_THRESHOLD;

      if (shouldBackup) {
        _logger.info(
            "Last backup was ${now.difference(latestBackupDate).inHours}h ago, automatic backup needed");
      } else {
        _logger.debug(
            "Last backup was ${now.difference(latestBackupDate).inMinutes}m ago, no backup needed yet");
      }

      return shouldBackup;
    } catch (e, st) {
      _logger.handle(e, st, 'Error checking if automatic backup is needed');
      return false;
    }
  }

  /// Creates an automatic backup, given the settings in the preferences.
  static Future<bool> createAutomaticBackup() async {
    var prefs = await SharedPreferences.getInstance();

    // Retrieve preferences using PreferencesUtils
    bool enableAutomaticBackup = PreferencesUtils.getOrDefault<bool>(
        prefs, PreferencesKeys.enableAutomaticBackup)!;
    if (!enableAutomaticBackup) {
      log("No automatic backup set");
      return false;
    }

    bool enableEncryptedBackup = PreferencesUtils.getOrDefault<bool>(
        prefs, PreferencesKeys.enableEncryptedBackup)!;
    String? backupPassword = PreferencesUtils.getOrDefault<String?>(
        prefs, PreferencesKeys.backupPassword);
    bool enableVersionAndDateInBackupName = PreferencesUtils.getOrDefault<bool>(
        prefs, PreferencesKeys.enableVersionAndDateInBackupName)!;

    String? filename =
        !enableVersionAndDateInBackupName ? await getDefaultFileName() : null;

    try {
      _logger.info('Creating automatic backup...');
      final backupDir = await getDefaultBackupDirectory();
      File backupFile = await BackupService.createJsonBackupFile(
          backupFileName: filename,
          directoryPath: backupDir,
          encryptionPassword: enableEncryptedBackup ? backupPassword : null);
      _logger.info("Automatic backup created: ${backupFile.path}");
      return true;
    } catch (e, st) {
      _logger.handle(e, st, 'Failed to create automatic backup');
      return false;
    }
  }

  /// Removes old automatic backups based on the retention policy.
  static Future<bool> removeOldAutomaticBackups() async {
    var prefs = await SharedPreferences.getInstance();

    // Retrieve preferences using PreferencesUtils
    bool enableEncryptedBackup = PreferencesUtils.getOrDefault<bool>(
        prefs, PreferencesKeys.enableEncryptedBackup)!;
    int? backupRetentionIntervalIndex = PreferencesUtils.getOrDefault<int?>(
        prefs, PreferencesKeys.backupRetentionIntervalIndex);

    if (enableEncryptedBackup && backupRetentionIntervalIndex != null) {
      var period = BackupRetentionPeriod.values[backupRetentionIntervalIndex];
      if (period != BackupRetentionPeriod.ALWAYS) {
        final backupDir = await getDefaultBackupDirectory();
        return await removeOldBackups(period, Directory(backupDir));
      }
    }
    return false;
  }

  /// Imports data from a backup file. If an encryption password is provided,
  /// it attempts to decrypt the file content before importing.
  ///
  /// [inputFile] - the backup file to import.
  /// [encryptionPassword] - optional, if provided, attempts to decrypt the backup file content.
  static Future<bool> importDataFromBackupFile(File inputFile,
      {String? encryptionPassword}) async {
    try {
      _logger.info('Starting backup import from: ${inputFile.path}');
      String fileContent = await inputFile.readAsString();

      // Decrypt the file content if an encryption password is provided
      if (encryptionPassword != null && encryptionPassword.isNotEmpty) {
        _logger.info('Decrypting backup...');
        fileContent = decryptData(fileContent, encryptionPassword);
      }

      var jsonMap = jsonDecode(fileContent);
      Backup backup = Backup.fromMap(jsonMap);
      _logger.info(
          'Importing: ${backup.records.length} records, ${backup.categories.length} categories');

      // Add categories
      for (var backupCategory in backup.categories) {
        try {
          await database.addCategory(backupCategory);
        } on ElementAlreadyExists {
          print("${backupCategory!.name} already exists.");
        }
      }

      // Add records in batch (slightly faster)
      await database.addRecordsInBatch(backup.records);

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

      // Add record tag associations
      await database
          .addRecordTagAssociationsInBatch(backup.recordTagAssociations);

      _logger.info('Backup imported successfully');
      return true;
    } catch (e, st) {
      _logger.handle(e, st, 'Failed to import backup');
      return false;
    }
  }

  /// Encrypts the given data using the provided password.
  static String encryptData(String data, String password) {
    final key = encrypt.Key.fromUtf8(password
        .padRight(32, '*')
        .substring(0, 32)); // Ensure the key length is 32 bytes
    final iv = encrypt.IV.fromLength(16); // AES uses a 16 bytes IV
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    final encrypted = encrypter.encrypt(data, iv: iv);

    // Combine IV and encrypted data
    final combined = Uint8List.fromList(iv.bytes + encrypted.bytes);
    return encrypt.Encrypted(combined)
        .base64; // Save the combined data as Base64
  }

  static String hashPassword(String password) {
    // Compute the SHA-256 hash of the password
    var bytes = utf8.encode(password); // Convert password to bytes
    var digest = sha256.convert(bytes); // Perform SHA-256 hash

    // Convert the digest to a string and take the first 32 characters
    return digest.toString().substring(0, 32);
  }

  static Future<bool> isEncrypted(File inputFile) async {
    try {
      // Read the content of the file as a string
      String content = await inputFile.readAsString();

      // Try to parse the content as JSON
      jsonDecode(content);

      // If no exception is thrown, the file is valid JSON, so it is not encrypted
      return false;
    } catch (e) {
      // If there's an error (e.g., the content is not valid JSON), assume the file is encrypted
      return true;
    }
  }

  /// Decrypts the given data using the provided password.
  static String decryptData(String data, String password) {
    final key = encrypt.Key.fromUtf8(password
        .padRight(32, '*')
        .substring(0, 32)); // Ensure the key length is 32 bytes
    final encrypted = encrypt.Encrypted.fromBase64(data);

    // Extract IV and encrypted data
    final iv = encrypt.IV(Uint8List.fromList(
        encrypted.bytes.sublist(0, 16))); // First 16 bytes are the IV
    final encryptedData = encrypt.Encrypted(Uint8List.fromList(
        encrypted.bytes.sublist(16))); // Remaining bytes are the encrypted data

    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    return encrypter.decrypt(encryptedData, iv: iv);
  }

  /// Removes old backup files based on the specified retention period.
  /// [retentionPeriod] - the retention period to determine which files to delete.
  /// [directory] - the directory where the backup files are stored.
  static Future<bool> removeOldBackups(
      BackupRetentionPeriod retentionPeriod, Directory directory) async {
    if (retentionPeriod == BackupRetentionPeriod.ALWAYS) {
      return true;
    }

    final now = DateTime.now();
    final duration = retentionPeriod == BackupRetentionPeriod.WEEK
        ? Duration(days: 7)
        : Duration(days: 30);

    final files = directory.listSync().whereType<File>().where((file) {
      if (!file.path.endsWith(MANDATORY_BACKUP_SUFFIX)) {
        return false;
      }
      ;
      final fileStat = file.statSync();
      final modifiedDate = fileStat.modified;
      return now.difference(modifiedDate) > duration;
    });

    for (final file in files) {
      try {
        _logger.debug("Deleting old backup: ${file.path}");
        await file.delete();
      } catch (e, st) {
        _logger.handle(e, st, 'Failed to delete old backup: ${file.path}');
      }
    }
    return true;
  }

  /// Returns the date of the latest backup file in the DEFAULT_STORAGE_DIR.
  /// Looks for files that end with MANDATORY_BACKUP_SUFFIX
  /// and returns the modified date of the latest backup as String.
  /// Returns null if no backup file is found.
  static Future<String?> getStringDateLatestBackup() async {
    var dateLatestBackup = await getDateLatestBackup();
    if (dateLatestBackup == null) {
      return null;
    }
    final DateFormat formatter = DateFormat('yyyy-MM-dd HH:mm:ss');
    return formatter.format(dateLatestBackup);
  }

  /// Returns the date of the latest backup file in the default backup directory.
  /// Looks for files that end with MANDATORY_BACKUP_SUFFIX
  /// and returns the modified date of the latest backup as DateTime.
  /// Returns null if no backup file is found.
  static Future<DateTime?> getDateLatestBackup() async {
    final backupDirPath = await getDefaultBackupDirectory();
    final backupDir = Directory(backupDirPath);

    // Check if the directory exists, return null if it doesn't exist
    if (!await backupDir.exists()) {
      return null;
    }

    // Get all files in the directory that end with "_oinkoin_backup"
    final backupFiles = backupDir.listSync().whereType<File>().where((file) {
      return file.path.endsWith(MANDATORY_BACKUP_SUFFIX);
    });

    // If no backup files found, return null
    if (backupFiles.isEmpty) {
      return null;
    }

    // Find the latest backup file based on the modified date
    DateTime? latestModifiedDate;

    for (final file in backupFiles) {
      final fileStat = file.statSync();
      if (latestModifiedDate == null ||
          fileStat.modified.isAfter(latestModifiedDate)) {
        latestModifiedDate = fileStat.modified;
      }
    }

    return latestModifiedDate;
  }
}
