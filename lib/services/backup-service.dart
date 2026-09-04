import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

import 'package:i18n_extension/default.i18n.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' show join;
import 'package:path_provider/path_provider.dart';
import 'package:piggybank/models/backup.dart';
import 'package:piggybank/models/budget.dart';
import 'package:piggybank/models/wallet.dart';
import 'package:piggybank/models/currency.dart';
import 'package:piggybank/services/database/exceptions.dart';
import 'package:piggybank/services/backup-directory-service.dart';
import 'package:piggybank/services/preferences-backup-service.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:piggybank/settings/backup-retention-period.dart';
import 'package:piggybank/settings/currencies-page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../settings/constants/preferences-keys.dart';
import '../settings/preferences-utils.dart';
import 'database/database-interface.dart';

import 'package:crypto/crypto.dart';

import 'database/sqlite-database.dart';
import 'logger.dart';

/// BackupService contains the methods to create/restore backup file
class BackupService {
  static final _logger = Logger.withClass(BackupService);

  static const String DEFAULT_STORAGE_DIR =
      "/storage/emulated/0/Documents/oinkoin";

  static const String MANDATORY_BACKUP_SUFFIX = "obackup.json";

  static String ERROR_MSG =
      "Unable to create a backup: please, delete manually the old backup".i18n;

  static const Duration AUTOMATIC_BACKUP_THRESHOLD = Duration(hours: 1);

  // not final because it is swapped in the tests
  static DatabaseInterface database = ServiceConfig.database;

  /// Test-only Android override. `Platform.isAndroid` is false on desktop
  /// test hosts, so SAF-gated behavior is exercised by setting this to true
  /// and resetting it afterwards. Null (the default) uses the real platform.
  @visibleForTesting
  static bool? debugOverrideIsAndroid;

  static bool get _isAndroid => debugOverrideIsAndroid ?? Platform.isAndroid;

  /// Gets the platform-appropriate default backup directory
  /// Android: /storage/emulated/0/Documents/oinkoin
  /// Linux/Desktop: ~/Documents/oinkoin
  static Future<String> getDefaultBackupDirectory() async {
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      // Desktop: use Documents directory
      final documentsDir = await getApplicationDocumentsDirectory();
      return '${documentsDir.parent.path}/Documents/oinkoin';
    } else {
      // Android/iOS: use the original path
      return DEFAULT_STORAGE_DIR;
    }
  }

  /// Gets the directory backups are currently stored in: the custom folder
  /// chosen by the user in the backup settings, or the platform default when
  /// none has been set.
  static Future<String> getBackupDirectory() async {
    var prefs = await SharedPreferences.getInstance();
    String customBackupFolderPath = PreferencesUtils.getOrDefault<String>(
      prefs,
      PreferencesKeys.backupFolderPath,
    )!;
    if (customBackupFolderPath.isNotEmpty) {
      return customBackupFolderPath;
    }
    return await getDefaultBackupDirectory();
  }

  /// Returns the SAF URI of the user-picked Android backup folder when
  /// [directoryPath] refers to it. Scoped storage blocks direct file writes
  /// into such a folder, so every operation targeting it must go through the
  /// Storage Access Framework instead. Returns null for every other
  /// destination.
  static Future<String?> _getSafFolderUri(String? directoryPath) async {
    if (!_isAndroid || directoryPath == null) {
      return null;
    }
    var prefs = await SharedPreferences.getInstance();
    String customBackupFolderPath = PreferencesUtils.getOrDefault<String>(
      prefs,
      PreferencesKeys.backupFolderPath,
    )!;
    String backupFolderUri = PreferencesUtils.getOrDefault<String>(
      prefs,
      PreferencesKeys.backupFolderUri,
    )!;
    if (customBackupFolderPath.isEmpty ||
        backupFolderUri.isEmpty ||
        directoryPath != customBackupFolderPath) {
      return null;
    }
    return backupFolderUri;
  }

  /// Returns the SAF URI of the active custom Android backup folder, or null
  /// when backups are stored in a plain filesystem directory.
  static Future<String?> _getActiveSafFolderUri() async {
    if (!_isAndroid) {
      return null;
    }
    var prefs = await SharedPreferences.getInstance();
    String customBackupFolderPath = PreferencesUtils.getOrDefault<String>(
      prefs,
      PreferencesKeys.backupFolderPath,
    )!;
    return await _getSafFolderUri(customBackupFolderPath);
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
      ":",
      "-",
    ); // Replace colon to avoid issues in file naming

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

      // Android custom folders are only writable through the Storage Access
      // Framework: scoped storage blocks direct file writes outside the
      // app-specific directories even when a persistable URI grant exists.
      final safFolderUri = await _getSafFolderUri(directoryPath);

      // Ensure the directory exists (raw file writes only)
      if (safFolderUri == null) {
        await path.create(recursive: true);
      }

      final packageInfo = await PackageInfo.fromPlatform();
      final appName = packageInfo.packageName; // The package name
      final version = packageInfo.version; // The app version
      final databaseVersion = SqliteDatabase.version.toString();

      _logger.debug('Fetching data for backup...');
      // Create the backup (no profileId filter — backup all profiles)
      var records = await database.getAllRecords();
      var categories = await database.getAllCategories();
      var recurrentRecordPatterns = await database.getRecurrentRecordPatterns();
      var recordTagAssociations = await database.getAllRecordTagAssociations();
      var wallets = await database.getAllWallets();
      var profiles = await database.getAllProfiles();
      // Older test doubles and database implementations may not expose the
      // optional budget collection yet; keep those backups readable while
      // production databases include budgets normally.
      var budgets = <Budget>[];
      try {
        budgets = await database.getBudgets();
      } catch (e) {
        // Keep backups compatible with older implementations and test doubles
        // that do not yet provide budget storage.
        _logger.warning('Skipping budgets during backup: $e');
      }
      var prefs = await SharedPreferences.getInstance();
      var userCurrencies = prefs.getString(PreferencesKeys.userCurrencies);
      var preferences = PreferencesBackupService.exportPreferences(prefs);

      _logger.info(
        'Backup data: ${records.length} records, ${categories.length} categories, ${recurrentRecordPatterns.length} recurrent patterns, ${recordTagAssociations.length} tags, ${wallets.length} wallets, ${profiles.length} profiles, ${budgets.length} budgets',
      );

      var backup = Backup(
        appName,
        version,
        databaseVersion,
        categories,
        records,
        recurrentRecordPatterns,
        recordTagAssociations,
        wallets: wallets,
        profiles: profiles,
        budgets: budgets,
        userCurrencies: userCurrencies,
        preferences: preferences,
      );
      var backupJsonStr = jsonEncode(backup.toMap());

      // Encrypt the backup JSON string if an encryption password is provided
      if (encryptionPassword != null && encryptionPassword.isNotEmpty) {
        _logger.info('Encrypting backup...');
        backupJsonStr = encryptData(backupJsonStr, encryptionPassword);
      }

      // Write on disk. SAF destinations receive the backup through the
      // platform channel, which copies a staged file into the picked folder.
      if (safFolderUri != null) {
        final tempDir = await getTemporaryDirectory();
        final stagedFile = File("${tempDir.path}/$backupFileName");
        await stagedFile.writeAsString(backupJsonStr, flush: true);
        try {
          final written = await BackupDirectoryService.writeBackupFile(
              safFolderUri, backupFileName, stagedFile.path);
          if (!written) {
            throw StateError(
                'Could not write $backupFileName into the custom backup folder');
          }
        } finally {
          if (await stagedFile.exists()) {
            await stagedFile.delete();
          }
        }
        var safBackupFile = File("${path.path}/$backupFileName");
        _logger.info(
          'Backup created successfully: ${safBackupFile.path} (${backupJsonStr.length} bytes)',
        );
        return safBackupFile;
      }

      var backupJsonOnDisk = File("${path.path}/$backupFileName");
      var result = await backupJsonOnDisk.writeAsString(backupJsonStr);

      _logger.info(
        'Backup created successfully: ${backupJsonOnDisk.path} (${backupJsonStr.length} bytes)',
      );
      return result;
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
        prefs,
        PreferencesKeys.enableAutomaticBackup,
      )!;

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
          "Last backup was ${now.difference(latestBackupDate).inHours}h ago, automatic backup needed",
        );
      } else {
        _logger.debug(
          "Last backup was ${now.difference(latestBackupDate).inMinutes}m ago, no backup needed yet",
        );
      }

      return shouldBackup;
    } catch (e, st) {
      _logger.handle(e, st, 'Error checking if automatic backup is needed');
      return false;
    }
  }

  /// File name of the database snapshot stored next to automatic backups.
  /// Fixed name on purpose: it is overwritten in place and never touched
  /// by retention cleanup, which only removes `*_obackup.json` files.
  static const String DATABASE_SNAPSHOT_FILE = 'oinkoin_database.db';

  static bool _copyRunning = false;
  static bool _copyDirty = false;

  /// Schedules a database copy after a database write (see
  /// `SqliteDatabase.onDatabaseChanged`). Copies run one at a time; a
  /// write landing mid-copy marks it dirty so one more copy follows.
  /// Failures only log and never propagate to the write path.
  static void scheduleDatabaseCopy() {
    unawaited(_runDatabaseCopy());
  }

  static Future<void> _runDatabaseCopy() async {
    if (_copyRunning) {
      _copyDirty = true;
      return;
    }
    do {
      _copyDirty = false;
      _copyRunning = true;
      try {
        var prefs = await SharedPreferences.getInstance();
        bool includeDatabaseCopy = PreferencesUtils.getOrDefault<bool>(
          prefs,
          PreferencesKeys.backupIncludeDatabase,
        )!;
        if (!includeDatabaseCopy) return;
        final snapshot = await SqliteDatabase.createDatabaseSnapshot();
        if (snapshot != null) {
          await storeDatabaseSnapshot(snapshot);
        }
      } catch (e, st) {
        _logger.handle(e, st, 'Failed to store scheduled database copy');
      } finally {
        _copyRunning = false;
      }
    } while (_copyDirty);
  }

  /// Where database copies go: the dedicated copy folder when set,
  /// otherwise the backup destination. Returns the display path and, on
  /// Android custom folders, the SAF URI to write through.
  static Future<({String path, String? uri})>
      getDatabaseCopyLocation() async {
    var prefs = await SharedPreferences.getInstance();
    String copyFolderPath = PreferencesUtils.getOrDefault<String>(
      prefs,
      PreferencesKeys.databaseCopyFolderPath,
    )!;
    if (copyFolderPath.isNotEmpty) {
      String copyFolderUri = PreferencesUtils.getOrDefault<String>(
        prefs,
        PreferencesKeys.databaseCopyFolderUri,
      )!;
      return (
        path: copyFolderPath,
        uri: copyFolderUri.isEmpty ? null : copyFolderUri
      );
    }
    final backupDir = await getBackupDirectory();
    return (path: backupDir, uri: await _getSafFolderUri(backupDir));
  }

  /// Stores an already-created database [snapshot] into the database copy
  /// location (dedicated folder or backup destination), through SAF on
  /// Android custom folders and by plain copy elsewhere.
  static Future<bool> storeDatabaseSnapshot(File snapshot) async {
    final location = await getDatabaseCopyLocation();
    return storeDatabaseCopy(snapshot, location.path, location.uri);
  }

  /// Stores an already-created database [snapshot] into [backupDir],
  /// through SAF on Android custom folders and by plain copy elsewhere.
  /// Always deletes the snapshot afterwards. Returns false on failure.
  static Future<bool> storeDatabaseCopy(
    File snapshot,
    String backupDir, [
    String? safFolderUri,
  ]) async {
    try {
      if (safFolderUri != null) {
        final written = await BackupDirectoryService.writeBackupFile(
            safFolderUri, DATABASE_SNAPSHOT_FILE, snapshot.path);
        if (!written) {
          throw StateError(
              'Could not write $DATABASE_SNAPSHOT_FILE into the backup folder');
        }
      } else {
        await snapshot.copy(join(backupDir, DATABASE_SNAPSHOT_FILE));
      }
      _logger.info('Database copy stored in $backupDir');
      return true;
    } catch (e, st) {
      _logger.handle(e, st, 'Failed to store database copy');
      return false;
    } finally {
      if (await snapshot.exists()) {
        await snapshot.delete();
      }
    }
  }

  static Future<bool> createAutomaticBackup() async {
    var prefs = await SharedPreferences.getInstance();

    // Retrieve preferences using PreferencesUtils
    bool enableAutomaticBackup = PreferencesUtils.getOrDefault<bool>(
      prefs,
      PreferencesKeys.enableAutomaticBackup,
    )!;
    bool includeDatabaseCopy = PreferencesUtils.getOrDefault<bool>(
      prefs,
      PreferencesKeys.backupIncludeDatabase,
    )!;
    if (!enableAutomaticBackup && !includeDatabaseCopy) {
      log("No automatic backup set");
      return false;
    }

    bool enableEncryptedBackup = PreferencesUtils.getOrDefault<bool>(
      prefs,
      PreferencesKeys.enableEncryptedBackup,
    )!;
    String? backupPassword = PreferencesUtils.getOrDefault<String?>(
      prefs,
      PreferencesKeys.backupPassword,
    );
    bool enableVersionAndDateInBackupName = PreferencesUtils.getOrDefault<bool>(
      prefs,
      PreferencesKeys.enableVersionAndDateInBackupName,
    )!;

    String? filename = !enableVersionAndDateInBackupName
        ? await getDefaultFileName()
        : null;

    try {
      if (enableAutomaticBackup) {
        _logger.info('Creating automatic backup...');
        final backupDir = await getBackupDirectory();
        File backupFile = await BackupService.createJsonBackupFile(
          backupFileName: filename,
          directoryPath: backupDir,
          encryptionPassword: enableEncryptedBackup ? backupPassword : null,
        );
        _logger.info("Automatic backup created: ${backupFile.path}");
      }
      if (includeDatabaseCopy) {
        // Best effort: a failed database copy must not fail the backup.
        final snapshot = await SqliteDatabase.createDatabaseSnapshot();
        if (snapshot != null) {
          await storeDatabaseSnapshot(snapshot);
        }
      }
      return true;
    } catch (e, st) {
      _logger.handle(e, st, 'Failed to create automatic backup');
      return false;
    }
  }

  /// Date of the existing database copy, or null when there is none or
  /// its timestamp is unknown (e.g. a provider not reporting one).
  static Future<DateTime?> getDateLatestDatabaseCopy() async {
    try {
      final location = await getDatabaseCopyLocation();
      if (location.uri != null) {
        final files =
            await BackupDirectoryService.listBackupFiles(location.uri!);
        for (final file in files) {
          if (file.name == DATABASE_SNAPSHOT_FILE &&
              file.lastModifiedMs != null &&
              file.lastModifiedMs! > 0) {
            return DateTime.fromMillisecondsSinceEpoch(file.lastModifiedMs!);
          }
        }
        return null;
      }
      final copy = File(join(location.path, DATABASE_SNAPSHOT_FILE));
      if (!await copy.exists()) return null;
      return (await copy.stat()).modified;
    } catch (e, st) {
      _logger.handle(e, st, 'Failed to read database copy date');
      return null;
    }
  }

  /// Whether an automatic database copy should be stored: enabled and the
  /// existing copy missing or older than the backup threshold.
  static Future<bool> shouldCreateAutomaticDatabaseCopy() async {
    try {
      var prefs = await SharedPreferences.getInstance();
      bool includeDatabaseCopy = PreferencesUtils.getOrDefault<bool>(
        prefs,
        PreferencesKeys.backupIncludeDatabase,
      )!;
      if (!includeDatabaseCopy) return false;

      final latestCopyDate = await getDateLatestDatabaseCopy();
      if (latestCopyDate == null) {
        _logger.info("No database copy found, automatic copy needed");
        return true;
      }
      return DateTime.now().difference(latestCopyDate) >
          AUTOMATIC_BACKUP_THRESHOLD;
    } catch (e, st) {
      _logger.handle(e, st, 'Error checking if automatic copy is needed');
      return false;
    }
  }

  /// Removes old automatic backups based on the retention policy.
  static Future<bool> removeOldAutomaticBackups() async {
    var prefs = await SharedPreferences.getInstance();

    // Retrieve preferences using PreferencesUtils
    bool enableEncryptedBackup = PreferencesUtils.getOrDefault<bool>(
      prefs,
      PreferencesKeys.enableEncryptedBackup,
    )!;
    int? backupRetentionIntervalIndex = PreferencesUtils.getOrDefault<int?>(
      prefs,
      PreferencesKeys.backupRetentionIntervalIndex,
    );

    if (enableEncryptedBackup && backupRetentionIntervalIndex != null) {
      var period = BackupRetentionPeriod.values[backupRetentionIntervalIndex];
      if (period != BackupRetentionPeriod.ALWAYS) {
        final safFolderUri = await _getActiveSafFolderUri();
        if (safFolderUri != null) {
          return await _removeOldSafBackups(safFolderUri, period);
        }
        final backupDir = await getBackupDirectory();
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
  static Future<bool> importDataFromBackupFile(
    File inputFile, {
    String? encryptionPassword,
  }) async {
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
        'Importing: ${backup.records.length} records, ${backup.categories.length} categories, ${backup.wallets.length} wallets, ${backup.budgets.length} budgets',
      );

      // Restore portable preferences independently. A malformed, obsolete, or
      // failing setting is skipped by the preference service and cannot abort
      // the database restore. Very old backups stored user currencies in a
      // top-level field, so expose that field to the same tolerant path when
      // the newer preferences map does not contain it.
      if (backup.preferences.isNotEmpty || backup.userCurrencies != null) {
        SharedPreferences? restorePrefs;
        try {
          restorePrefs = await SharedPreferences.getInstance();
        } catch (error, stackTrace) {
          // Preferences are optional for legacy/database-only imports. A
          // missing platform implementation must not prevent the actual data
          // from being restored.
          _logger.handle(
            error,
            stackTrace,
            'Skipping preferences because they are unavailable',
          );
        }
        if (restorePrefs != null) {
          final preferencesToRestore = <String, dynamic>{
            ...backup.preferences,
            if (!backup.preferences.containsKey(
                  PreferencesKeys.userCurrencies,
                ) &&
                backup.userCurrencies != null)
              PreferencesKeys.userCurrencies: backup.userCurrencies,
          };
          await PreferencesBackupService.restorePreferences(
            restorePrefs,
            preferencesToRestore,
          );
          ServiceConfig.initBudgetsEnabled();

          // Load custom currencies into CurrencyInfo before wallets are
          // restored. The payload may come from an old backup and can be
          // malformed; this must never make an otherwise usable backup fail.
          _loadRestoredCustomCurrencies(
            restorePrefs.getString(PreferencesKeys.userCurrencies),
          );
        }
      }

      // Insert profiles and build backup_id → new_db_id mapping
      final profileIdMap =
          <int, int>{}; // backup profile id → new db profile id
      int? fallbackProfileId;
      // Profiles freshly created by addProfile() during this import (as
      // opposed to an existing Default Profile that was reused). addProfile
      // auto-creates a placeholder "Default Wallet" for each of these as a
      // side effect - real backup wallet data for these profiles must
      // overwrite that placeholder rather than be discarded by the wallet
      // dedup logic below, which otherwise can't tell it apart from a
      // genuine pre-existing wallet worth preserving as-is.
      final newlyCreatedProfileIds = <int>{};

      if (backup.profiles.isNotEmpty) {
        // Check if a default profile already exists in the database
        final existingDefaultProfile = await database.getDefaultProfile();
        final int? existingDefaultProfileId = existingDefaultProfile?.id;

        for (var backupProfile in backup.profiles) {
          final backupId = backupProfile.id;

          if (backupProfile.isDefault && existingDefaultProfileId != null) {
            // Reuse the existing Default Profile instead of creating a duplicate
            if (backupId != null) {
              profileIdMap[backupId] = existingDefaultProfileId;
            }
            fallbackProfileId = existingDefaultProfileId;
          } else {
            backupProfile.id = null;
            final newId = await database.addProfile(backupProfile);
            if (backupId != null) {
              profileIdMap[backupId] = newId;
            }
            if (backupProfile.isDefault) fallbackProfileId = newId;
            newlyCreatedProfileIds.add(newId);
          }
        }
      } else {
        // Old backup with no profiles: assign everything to the existing Default Profile
        final defaultProfile = await database.getDefaultProfile();
        fallbackProfileId = defaultProfile?.id;
      }

      // Insert wallets and build backup_id → new_db_id mapping
      final walletIdMap = <int, int>{}; // backup wallet id → new db wallet id

      // Check if a default wallet already exists in the database
      final existingDefaultWallet = await database.getDefaultWallet();
      final int? existingDefaultWalletId = existingDefaultWallet?.id;

      // Get all existing wallets grouped by profile for name-based merging
      final existingWalletsByProfile = <int?, List<Wallet>>{};
      for (var profileId in profileIdMap.values.toSet()) {
        final wallets = await database.getAllWallets(profileId: profileId);
        existingWalletsByProfile[profileId] = wallets;
      }

      for (var backupWallet in backup.wallets) {
        final backupId = backupWallet.id;
        // Remap profile_id
        if (backupWallet.profileId != null &&
            profileIdMap.containsKey(backupWallet.profileId)) {
          backupWallet.profileId = profileIdMap[backupWallet.profileId];
        } else {
          backupWallet.profileId = fallbackProfileId;
        }

        int? mappedWalletId;
        bool overwritePlaceholder = false;

        if (backupWallet.isDefault &&
            backupWallet.profileId != null &&
            newlyCreatedProfileIds.contains(backupWallet.profileId)) {
          // This wallet's profile was freshly created above, so any default
          // wallet already on file for it is the addProfile() placeholder,
          // not genuine pre-existing device data - overwrite it with the
          // backup's real values instead of discarding them.
          final placeholder = (existingWalletsByProfile[backupWallet.profileId] ?? [])
              .where((w) => w.isDefault);
          if (placeholder.isNotEmpty) {
            mappedWalletId = placeholder.first.id;
            overwritePlaceholder = true;
          }
        }

        // Check if this is a default wallet and reuse existing default
        if (mappedWalletId == null &&
            backupWallet.isDefault &&
            existingDefaultWalletId != null) {
          mappedWalletId = existingDefaultWalletId;
        } else if (mappedWalletId == null) {
          // Check if a wallet with the same name exists in the same profile
          final existingInProfile =
              existingWalletsByProfile[backupWallet.profileId] ?? [];
          final match = existingInProfile.where(
            (w) => w.name.toLowerCase() == backupWallet.name.toLowerCase(),
          );
          if (match.isNotEmpty) {
            mappedWalletId = match.first.id;
          }
        }

        if (overwritePlaceholder && mappedWalletId != null) {
          await database.updateWallet(mappedWalletId, backupWallet);
          if (backupId != null) {
            walletIdMap[backupId] = mappedWalletId;
          }
        } else if (mappedWalletId != null) {
          // Reuse existing wallet
          if (backupId != null) {
            walletIdMap[backupId] = mappedWalletId;
          }
        } else {
          // Insert without the old id so the DB auto-assigns a new one
          backupWallet.id = null;
          final newId = await database.addWallet(backupWallet);
          if (backupId != null) {
            walletIdMap[backupId] = newId;
          }
          // Add to existing list for subsequent duplicates in same profile
          final newWallet = await database.getWalletById(newId);
          if (newWallet != null) {
            existingWalletsByProfile
                .putIfAbsent(backupWallet.profileId, () => [])
                .add(newWallet);
          }
        }
      }

      // Records with no wallet mapping (old backups, missing wallet data, etc.)
      // fall back to the Default Wallet, which always exists.
      final defaultWallet = await database.getDefaultWallet();
      final fallbackWalletId = defaultWallet?.id;

      // Add categories
      for (var backupCategory in backup.categories) {
        try {
          await database.addCategory(backupCategory);
        } on ElementAlreadyExists {
          print("${backupCategory!.name} already exists.");
        }
      }

      // Build a map of record ID -> tags from the backup's tag associations
      final recordIdToTags = <int, Set<String>>{};
      for (var assoc in backup.recordTagAssociations) {
        recordIdToTags
            .putIfAbsent(assoc.recordId, () => <String>{})
            .add(assoc.tagName);
      }

      // Populate record.tags and remap wallet_id + profile_id
      for (var record in backup.records) {
        if (record == null) continue;
        if (record.id != null && recordIdToTags.containsKey(record.id)) {
          record.tags = recordIdToTags[record.id]!;
        }
        // Remap profile_id from backup id to new db id
        if (record.profileId != null &&
            profileIdMap.containsKey(record.profileId)) {
          record.profileId = profileIdMap[record.profileId];
        } else {
          record.profileId = fallbackProfileId;
        }
        // Remap wallet_id from backup id to new db id
        if (record.walletId != null &&
            walletIdMap.containsKey(record.walletId)) {
          record.walletId = walletIdMap[record.walletId];
        } else if (fallbackWalletId != null) {
          record.walletId = fallbackWalletId;
        }
        // Remap transfer_wallet_id from backup id to new db id
        if (record.transferWalletId != null &&
            walletIdMap.containsKey(record.transferWalletId)) {
          record.transferWalletId = walletIdMap[record.transferWalletId];
        } else if (record.transferWalletId != null &&
            !walletIdMap.containsKey(record.transferWalletId)) {
          // Destination wallet not found in backup mapping — clear the transfer
          record.transferWalletId = null;
        }
      }

      // Add records in batch — Phase 2 will correctly map tags to new IDs
      await database.addRecordsInBatch(backup.records);

      // Add recurrent patterns (remap profile_id)
      for (var backupRecurrentPatterns in backup.recurrentRecordsPattern) {
        // Remap profile_id
        if (backupRecurrentPatterns.profileId != null &&
            profileIdMap.containsKey(backupRecurrentPatterns.profileId)) {
          backupRecurrentPatterns.profileId =
              profileIdMap[backupRecurrentPatterns.profileId];
        } else {
          backupRecurrentPatterns.profileId = fallbackProfileId;
        }
        // Remap wallet_id — fall back to default wallet when the backup
        // wallet is missing (mirrors the record remapping logic above).
        if (backupRecurrentPatterns.walletId != null &&
            walletIdMap.containsKey(backupRecurrentPatterns.walletId)) {
          backupRecurrentPatterns.walletId =
              walletIdMap[backupRecurrentPatterns.walletId];
        } else if (fallbackWalletId != null) {
          backupRecurrentPatterns.walletId = fallbackWalletId;
        }
        String? recurrentPatternId = backupRecurrentPatterns.id;
        if (await database.getRecurrentRecordPattern(recurrentPatternId) ==
            null) {
          await database.addRecurrentRecordPattern(backupRecurrentPatterns);
        } else {
          print(
            "Recurrent pattern with id $recurrentPatternId already exists.",
          );
        }
      }

      // Add budgets after profiles have been remapped. Budget filters use
      // category names, so no category ID remapping is necessary.
      for (final backupBudget in backup.budgets) {
        if (backupBudget.profileId != null &&
            profileIdMap.containsKey(backupBudget.profileId)) {
          backupBudget.profileId = profileIdMap[backupBudget.profileId];
        } else {
          backupBudget.profileId = fallbackProfileId;
        }
        // Wallet filters are not valid while the Wallets feature is disabled.
        // Clear them on import so they cannot become active unexpectedly if
        // the feature is later enabled.
        if (!ServiceConfig.walletsEnabled) {
          backupBudget.walletIds = [];
        } else {
          // Budget wallet filters reference wallet IDs from the backup. Remap
          // them to the IDs assigned during wallet restore, just like records.
          backupBudget.walletIds = backupBudget.walletIds
              .map((walletId) => walletIdMap[walletId])
              .whereType<int>()
              .toList();
        }
        backupBudget.id = null;
        await database.addBudget(backupBudget);
      }

      _logger.info('Backup imported successfully');
      return true;
    } catch (e, st) {
      _logger.handle(e, st, 'Failed to import backup');
      return false;
    }
  }

  static void _loadRestoredCustomCurrencies(String? rawCurrencies) {
    if (rawCurrencies == null || rawCurrencies.isEmpty) {
      _logger.debug('No restored custom currency configuration to load');
      return;
    }
    try {
      final decoded = jsonDecode(rawCurrencies);
      if (decoded is! Map<String, dynamic>) {
        _logger.warning(
          'Skipping restored custom currencies: expected a JSON object',
        );
        return;
      }
      final config = UserCurrencyConfig.fromJson(decoded);
      var loaded = 0;
      for (final currency in config.currencies) {
        if (currency.isCustom) {
          CurrencyInfo.addCustomCurrency(
            CurrencyInfo(
              isoCode: currency.isoCode,
              name: currency.customName!,
              customSymbol: currency.customSymbol,
            ),
          );
          loaded++;
        }
      }
      _logger.info('Loaded $loaded custom currencies from backup');
    } catch (error, stackTrace) {
      _logger.handle(
        error,
        stackTrace,
        'Skipping malformed user currencies from backup',
      );
    }
  }

  /// Encrypts the given data using the provided password.
  static String encryptData(String data, String password) {
    final key = encrypt.Key.fromUtf8(
      password.padRight(32, '*').substring(0, 32),
    ); // Ensure the key length is 32 bytes
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

  /// Removes old backups stored in a SAF-managed custom folder. Documents
  /// whose modified date is unknown are kept: deleting them based on a
  /// missing timestamp would risk removing fresh backups.
  static Future<bool> _removeOldSafBackups(
    String safFolderUri,
    BackupRetentionPeriod retentionPeriod,
  ) async {
    if (retentionPeriod == BackupRetentionPeriod.ALWAYS) {
      return true;
    }

    final now = DateTime.now();
    final duration = retentionPeriod == BackupRetentionPeriod.WEEK
        ? Duration(days: 7)
        : Duration(days: 30);

    final files = await BackupDirectoryService.listBackupFiles(safFolderUri);
    for (final file in files) {
      if (!file.name.endsWith(MANDATORY_BACKUP_SUFFIX)) {
        continue;
      }
      final modifiedMs = file.lastModifiedMs;
      if (modifiedMs == null || modifiedMs <= 0) {
        continue;
      }
      final modified = DateTime.fromMillisecondsSinceEpoch(modifiedMs);
      if (now.difference(modified) > duration) {
        try {
          _logger.debug("Deleting old backup: ${file.name}");
          await BackupDirectoryService.deleteBackupFile(
              safFolderUri, file.name);
        } catch (e, st) {
          _logger.handle(e, st, 'Failed to delete old backup: ${file.name}');
        }
      }
    }
    return true;
  }

  /// Decrypts the given data using the provided password.
  static String decryptData(String data, String password) {
    final key = encrypt.Key.fromUtf8(
      password.padRight(32, '*').substring(0, 32),
    ); // Ensure the key length is 32 bytes
    final encrypted = encrypt.Encrypted.fromBase64(data);

    // Extract IV and encrypted data
    final iv = encrypt.IV(
      Uint8List.fromList(encrypted.bytes.sublist(0, 16)),
    ); // First 16 bytes are the IV
    final encryptedData = encrypt.Encrypted(
      Uint8List.fromList(encrypted.bytes.sublist(16)),
    ); // Remaining bytes are the encrypted data

    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    return encrypter.decrypt(encryptedData, iv: iv);
  }

  /// Removes old backup files based on the specified retention period.
  /// [retentionPeriod] - the retention period to determine which files to delete.
  /// [directory] - the directory where the backup files are stored.
  static Future<bool> removeOldBackups(
    BackupRetentionPeriod retentionPeriod,
    Directory directory,
  ) async {
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

  /// Formatted date of the latest database copy, or null when there is none.
  static Future<String?> getStringDateLatestDatabaseCopy() async {
    var dateLatestCopy = await getDateLatestDatabaseCopy();
    if (dateLatestCopy == null) {
      return null;
    }
    final DateFormat formatter = DateFormat('yyyy-MM-dd HH:mm:ss');
    return formatter.format(dateLatestCopy);
  }

  /// Returns the date of the latest backup file in the backup directory.
  /// Looks for files that end with MANDATORY_BACKUP_SUFFIX
  /// and returns the modified date of the latest backup as DateTime.
  /// Returns null if no backup file is found.
  static Future<DateTime?> getDateLatestBackup() async {
    final safFolderUri = await _getActiveSafFolderUri();
    if (safFolderUri != null) {
      DateTime? latestModifiedDate;
      final files =
          await BackupDirectoryService.listBackupFiles(safFolderUri);
      for (final file in files) {
        if (!file.name.endsWith(MANDATORY_BACKUP_SUFFIX)) {
          continue;
        }
        final modifiedMs = file.lastModifiedMs;
        if (modifiedMs == null || modifiedMs <= 0) {
          continue;
        }
        final modified = DateTime.fromMillisecondsSinceEpoch(modifiedMs);
        if (latestModifiedDate == null || modified.isAfter(latestModifiedDate)) {
          latestModifiedDate = modified;
        }
      }
      return latestModifiedDate;
    }

    final backupDirPath = await getBackupDirectory();
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
