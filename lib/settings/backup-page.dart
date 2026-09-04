import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' show join;
import 'package:path_provider/path_provider.dart';
import 'package:piggybank/i18n.dart';
import 'package:piggybank/services/backup-directory-service.dart';
import 'package:piggybank/services/backup-service.dart';
import 'package:piggybank/settings/backup-retention-period.dart';
import 'package:piggybank/settings/preferences-utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../helpers/alert-dialog-builder.dart';
import '../services/database/sqlite-database.dart';
import '../services/platform-file-service.dart';
import '../services/service-config.dart';
import 'clickable-customization-item.dart';
import 'components/setting-separator.dart';
import 'constants/preferences-keys.dart';
import 'style.dart';
import 'dropdown-customization-item.dart';
import 'settings-item.dart';
import 'switch-customization-item.dart';

class BackupPage extends StatefulWidget {
  @override
  BackupPageState createState() => BackupPageState();
}

class BackupPageState extends State<BackupPage> {
  // Stored so rebuilds (e.g. toggling a switch) don't refetch preferences
  // and rebuild the page from scratch, which would collapse sections.
  late final Future<void> _preferencesFuture;

  @override
  void initState() {
    super.initState();
    _preferencesFuture = initializePreferences();
  }

  static String getKeyFromObject<T>(Map<String, T> originalMap, T? searchValue,
      {String? defaultKey}) {
    final invertedMap = originalMap.map((key, value) => MapEntry(value, key));
    if (invertedMap.containsKey(searchValue)) {
      return invertedMap[searchValue]!;
    }
    if (defaultKey != null) {
      return defaultKey;
    }
    return invertedMap.values.first;
  }

  Future<void> initializePreferences() async {
    prefs = await SharedPreferences.getInstance();
    defaultDirectory = await BackupService.getDefaultBackupDirectory();
    fetchAllThePreferences();
    String? l = await BackupService.getStringDateLatestBackup();
    if (l != null) {
      lastBackupDataStr = l;
    }
  }

  createAndShareBackupFile() async {
    String? filename = enableVersionAndDateInBackupName
        ? null
        : await BackupService.getDefaultFileName();
    File backupFile =
        await BackupService.createJsonBackupFile(backupFileName: filename);

    // Use platform-aware service (share on mobile, save-as on desktop)
    final success = await PlatformFileService.shareOrSaveFile(
      filePath: backupFile.path,
      suggestedName: filename ?? backupFile.path.split('/').last,
    );

    if (!success) {
      log('Failed to share/save backup file');
    }
  }

  shareDatabase() async {
    // Show a warning dialog explaining this is not the app backup
    AlertDialogBuilder dbDialog = AlertDialogBuilder("Export Database".i18n)
        .addSubtitle(
            "The database export is not the app backup. Use 'Export Backup' to create a backup of your data. The database file is intended for advanced users who want to access the raw data or use it with other apps.".i18n)
        .addTrueButtonName("OK".i18n)
        .addFalseButtonName("Cancel".i18n);
    bool? proceed = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return dbDialog.build(context);
      },
    );

    if (proceed != true) {
      return;
    }

    String databasePath;
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      // For desktop platforms, use application documents directory
      // This ensures we write to a writable location, not inside AppImage mount
      final appDocDir = await getApplicationDocumentsDirectory();
      databasePath = join(appDocDir.path, 'oinkoin');
      // Create directory if it doesn't exist
      final dir = Directory(databasePath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
    } else {
      // For mobile platforms, use the default sqflite path
      databasePath = await getDatabasesPath();
    }

    String _path = join(databasePath, 'movements.db');
    File databaseFile = File.fromUri(Uri.file(_path));

    // Use platform-aware service (share on mobile, save-as on desktop)
    final success = await PlatformFileService.shareOrSaveFile(
      filePath: databaseFile.path,
      suggestedName: 'oinkoin_database.db',
    );

    if (!success) {
      log('Failed to share/save database file');
    }
  }

  storeDatabaseFile(BuildContext context) async {
    try {
      final snapshot = await SqliteDatabase.createDatabaseSnapshot();
      if (snapshot == null) {
        throw StateError('Could not create a database snapshot');
      }
      final stored = await BackupService.storeDatabaseSnapshot(snapshot);
      if (!stored) {
        throw StateError('Could not store the database file');
      }
      final location = await BackupService.getDatabaseCopyLocation();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'File stored in ${location.path}/${BackupService.DATABASE_SNAPSHOT_FILE}'),
      ));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Could not save the database file".i18n),
      ));
    }
  }

  storeBackupFile(BuildContext context) async {
    String? filename = enableVersionAndDateInBackupName
        ? null
        : await BackupService.getDefaultFileName();
    try {
      File backupFile = await BackupService.createJsonBackupFile(
          backupFileName: filename,
          directoryPath: backupFolderPath,
          encryptionPassword: enableEncryptedBackup ? backupPassword : null);
      log("${backupFile.path} successfully created");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('File stored in ${backupFile.path}'),
      ));
      String? l = await BackupService.getStringDateLatestBackup();
      if (l != null) {
        setState(() {
          lastBackupDataStr = l;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(BackupService.ERROR_MSG),
      ));
    }
  }

  late SharedPreferences prefs;
  late String defaultDirectory;

  // Backup related
  final Map<String, int> backupRetentionPeriodsValues = {
    "Never delete".i18n: BackupRetentionPeriod.ALWAYS.index,
    "Weekly".i18n: BackupRetentionPeriod.WEEK.index,
    "Monthly".i18n: BackupRetentionPeriod.MONTH.index,
  };
  late bool enableAutomaticBackup;
  late bool enableVersionAndDateInBackupName;
  late bool enableEncryptedBackup;
  late bool includeDatabaseCopy;
  late String backupRetentionPeriodValue;
  late String backupFolderPath;
  bool hasCustomBackupFolder = false;
  late String databaseCopyFolderPath;
  bool hasCustomDatabaseCopyFolder = false;
  late String backupPassword;
  String lastBackupDataStr = "-";

  fetchAllThePreferences() {
    enableVersionAndDateInBackupName = PreferencesUtils.getOrDefault<bool>(
        prefs, PreferencesKeys.enableVersionAndDateInBackupName)!;
    enableAutomaticBackup = PreferencesUtils.getOrDefault<bool>(
        prefs, PreferencesKeys.enableAutomaticBackup)!;
    enableEncryptedBackup = PreferencesUtils.getOrDefault<bool>(
        prefs, PreferencesKeys.enableEncryptedBackup)!;
    includeDatabaseCopy = PreferencesUtils.getOrDefault<bool>(
        prefs, PreferencesKeys.backupIncludeDatabase)!;
    int backupRetentionIntervalIndex = PreferencesUtils.getOrDefault<int>(
        prefs, PreferencesKeys.backupRetentionIntervalIndex)!;
    backupRetentionPeriodValue = getKeyFromObject<int>(
        backupRetentionPeriodsValues, backupRetentionIntervalIndex);
    backupPassword = PreferencesUtils.getOrDefault<String>(
        prefs, PreferencesKeys.backupPassword)!;
    String customBackupFolderPath = PreferencesUtils.getOrDefault<String>(
        prefs, PreferencesKeys.backupFolderPath)!;
    hasCustomBackupFolder = customBackupFolderPath.isNotEmpty;
    backupFolderPath =
        hasCustomBackupFolder ? customBackupFolderPath : defaultDirectory;
    String customCopyFolderPath = PreferencesUtils.getOrDefault<String>(
        prefs, PreferencesKeys.databaseCopyFolderPath)!;
    hasCustomDatabaseCopyFolder = customCopyFolderPath.isNotEmpty;
    databaseCopyFolderPath = hasCustomDatabaseCopyFolder
        ? customCopyFolderPath
        : backupFolderPath;
  }

  resetEnableEncryptedBackup() {
    prefs.remove(PreferencesKeys.enableEncryptedBackup);
    prefs.remove(PreferencesKeys.backupPassword);
    setState(() {
      enableEncryptedBackup = false;
      backupPassword = "";
    });
  }

  setPasswordInPreferences(String password) {
    prefs.setString(
        PreferencesKeys.backupPassword, BackupService.hashPassword(password));
  }

  changeBackupFolder() async {
    BackupDirectoryPick pick = await BackupDirectoryService.pickDirectory();
    if (!mounted) return;
    if (pick.outcome == BackupDirectoryPickOutcome.success &&
        pick.path != null) {
      await prefs.setString(PreferencesKeys.backupFolderPath, pick.path!);
      if (pick.uri != null) {
        await prefs.setString(PreferencesKeys.backupFolderUri, pick.uri!);
      } else {
        await prefs.remove(PreferencesKeys.backupFolderUri);
      }
      setState(() {
        fetchAllThePreferences();
      });
    } else if (pick.outcome == BackupDirectoryPickOutcome.notWritable) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            "The selected folder is not writable. Please choose another one."
                .i18n),
      ));
    }
  }

  resetBackupFolder() {
    prefs.remove(PreferencesKeys.backupFolderPath);
    prefs.remove(PreferencesKeys.backupFolderUri);
    setState(() {
      fetchAllThePreferences();
    });
  }

  changeDatabaseCopyFolder() async {
    BackupDirectoryPick pick = await BackupDirectoryService.pickDirectory();
    if (!mounted) return;
    if (pick.outcome == BackupDirectoryPickOutcome.success &&
        pick.path != null) {
      await prefs.setString(
          PreferencesKeys.databaseCopyFolderPath, pick.path!);
      if (pick.uri != null) {
        await prefs.setString(PreferencesKeys.databaseCopyFolderUri, pick.uri!);
      } else {
        await prefs.remove(PreferencesKeys.databaseCopyFolderUri);
      }
      setState(() {
        fetchAllThePreferences();
      });
    } else if (pick.outcome == BackupDirectoryPickOutcome.notWritable) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            "The selected folder is not writable. Please choose another one."
                .i18n),
      ));
    }
  }

  resetDatabaseCopyFolder() {
    prefs.remove(PreferencesKeys.databaseCopyFolderPath);
    prefs.remove(PreferencesKeys.databaseCopyFolderUri);
    setState(() {
      fetchAllThePreferences();
    });
  }

  final _textController = TextEditingController();
  bool _isOkButtonEnabled = false;

  /// Small explanatory line under a section header.
  Widget _buildExplainer(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Text(
        text,
        style: subtitleTextStyle,
      ),
    );
  }

  Future<String?> showPasswordInputDialog(BuildContext context) async {
    return await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: Text("Enter an encryption password".i18n),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Once set, you can't see the password".i18n,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  SizedBox(height: 20),
                  TextField(
                    controller: _textController,
                    obscureText: false,
                    enableSuggestions: false,
                    autocorrect: false,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Enter your password here'.i18n,
                    ),
                    onChanged: (value) {
                      // Update the state of the OK button based on input text
                      setState(() {
                        _isOkButtonEnabled =
                            _textController.text.trim().isNotEmpty;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('Cancel'),
                ),
                TextButton(
                  onPressed: _isOkButtonEnabled
                      ? () {
                          Navigator.pop(context, _textController.text.trim());
                        }
                      : null, // Disable if text is empty
                  child: Text('OK'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text("Backup".i18n),
        ),
        body: FutureBuilder(
          future: _preferencesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SettingSeparator(title: "Backup".i18n),
                    _buildExplainer(
                        "Complete snapshots of your data, encrypted and restorable anytime."
                            .i18n),
                    SettingsItem(
                        icon: Icon(Icons.backup, color: Colors.white),
                        iconBackgroundColor: Colors.orange.shade600,
                        title: 'Export Backup'.i18n,
                        subtitle: "Share the backup file".i18n,
                        onPressed: () async =>
                            await createAndShareBackupFile()),
                    SettingsItem(
                        icon: Icon(Icons.save_alt, color: Colors.white),
                        iconBackgroundColor: Colors.lightBlue.shade600,
                        title: 'Store the Backup on disk'.i18n,
                        onPressed: () async => await storeBackupFile(context)),
                    Visibility(
                      visible: BackupDirectoryService.isSupported,
                      child: Column(
                        children: [
                          ClickableCustomizationItem(
                              title: "Destination folder".i18n,
                              subtitle: backupFolderPath,
                              enabled: true,
                              onTap: () async => await changeBackupFolder()),
                          if (hasCustomBackupFolder)
                            ClickableCustomizationItem(
                                title: "Reset to the default folder".i18n,
                                subtitle: defaultDirectory,
                                enabled: true,
                                onTap: resetBackupFolder),
                        ],
                      ),
                    ),
                    SwitchCustomizationItem(
                      title: "Backup encryption".i18n,
                      subtitle:
                          "Enable if you want to have encrypted backups".i18n,
                      switchValue: enableEncryptedBackup,
                      sharedConfigKey: PreferencesKeys.enableEncryptedBackup,
                      onChanged: (value) async {
                        if (value) {
                          String? password =
                              await showPasswordInputDialog(context);
                          if (password != null) {
                            setPasswordInPreferences(password);
                          } else {
                            resetEnableEncryptedBackup();
                          }
                          _textController.clear();
                        }
                      },
                    ),
                    SwitchCustomizationItem(
                      title: "Include version and date in the name".i18n,
                      subtitle: "File will have a unique name".i18n,
                      switchValue: enableVersionAndDateInBackupName,
                      sharedConfigKey:
                          PreferencesKeys.enableVersionAndDateInBackupName,
                      onChanged: (value) => {
                        setState(() {
                          fetchAllThePreferences();
                        })
                      },
                    ),
                    SwitchCustomizationItem(
                      title: "Enable automatic backup".i18n,
                      enabled: ServiceConfig.isPremium,
                      subtitle: !ServiceConfig.isPremium
                          ? "Available on Oinkoin Pro".i18n
                          : "Enable to automatically backup at every access"
                              .i18n,
                      switchValue: enableAutomaticBackup,
                      sharedConfigKey: PreferencesKeys.enableAutomaticBackup,
                      onChanged: (value) {
                        if (!value) {
                          prefs.remove(
                              PreferencesKeys.backupRetentionIntervalIndex);
                        }
                        setState(() {
                          fetchAllThePreferences();
                        });
                      },
                    ),
                    Visibility(
                      visible: enableAutomaticBackup,
                      child: Column(
                        children: [
                          Visibility(
                            visible: enableVersionAndDateInBackupName,
                            child: DropdownCustomizationItem(
                              title: "Automatic backup retention".i18n,
                              subtitle:
                                  "How long do you want to keep backups".i18n,
                              dropdownValues: backupRetentionPeriodsValues,
                              selectedDropdownKey: backupRetentionPeriodValue,
                              sharedConfigKey: "backupRetentionIntervalIndex",
                            ),
                          ),
                        ],
                      ),
                    ),
                    ExpansionTile(
                      initiallyExpanded: false,
                      maintainState: true,
                      tilePadding:
                          const EdgeInsets.symmetric(horizontal: 16.0),
                      childrenPadding: EdgeInsets.zero,
                      title: Text(
                        "Database".i18n,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Theme.of(context).colorScheme.secondary,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      subtitle: Text(
                        "Raw database file for advanced use. Not a backup, and it cannot be encrypted."
                            .i18n,
                        style: subtitleTextStyle,
                      ),
                      children: [
                        SettingsItem(
                            icon: Icon(Icons.dataset, color: Colors.white),
                            iconBackgroundColor: Colors.blueGrey.shade600,
                            title: 'Export Database'.i18n,
                            subtitle: "Share the database file".i18n,
                            onPressed: () async => await shareDatabase()),
                        SettingsItem(
                            icon: Icon(Icons.storage, color: Colors.white),
                            iconBackgroundColor: Colors.brown.shade600,
                            title: 'Store the database on disk'.i18n,
                            onPressed: () async =>
                                await storeDatabaseFile(context)),
                        Visibility(
                          visible: BackupDirectoryService.isSupported,
                          child: Column(
                            children: [
                              ClickableCustomizationItem(
                                  title: "Storage folder".i18n,
                                  subtitle: databaseCopyFolderPath,
                                  enabled: true,
                                  onTap: () async =>
                                      await changeDatabaseCopyFolder()),
                              if (hasCustomDatabaseCopyFolder)
                                ClickableCustomizationItem(
                                    title: "Follow the backup destination".i18n,
                                    subtitle: backupFolderPath,
                                    enabled: true,
                                    onTap: resetDatabaseCopyFolder),
                            ],
                          ),
                        ),
                    SwitchCustomizationItem(
                      title: "Save database automatically".i18n,
                      enabled: ServiceConfig.isPremium,
                      subtitle: !ServiceConfig.isPremium
                          ? "Available on Oinkoin Pro".i18n
                          : "Automatically keep a fresh copy in the storage folder"
                              .i18n,
                      switchValue: includeDatabaseCopy,
                      sharedConfigKey:
                          PreferencesKeys.backupIncludeDatabase,
                      onChanged: (value) => {
                        setState(() {
                          fetchAllThePreferences();
                        })
                      },
                    ),
                      ],
                    ),
                    Center(
                        child: Text("Last backup: ".i18n + lastBackupDataStr))
                  ],
                ),
              );
            } else {
              // Return a placeholder or loading indicator while waiting for initialization.
              return Center(
                child: CircularProgressIndicator(),
              ); // Replace with your desired loading widget.
            }
          },
        ));
  }
}
