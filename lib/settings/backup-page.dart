import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:piggybank/settings/backup-retention-period.dart';
import 'package:piggybank/settings/settings-item.dart';
import 'package:piggybank/settings/switch-customization-item.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:piggybank/i18n.dart';

import '../services/backup-service.dart';
import '../services/service-config.dart';
import 'clickable-customization-item.dart';
import 'dropdown-customization-item.dart';

class BackupPage extends StatefulWidget {
  @override
  BackupPageState createState() => BackupPageState();
}

class BackupPageState extends State<BackupPage> {
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
    defaultDirectory = BackupService.DEFAULT_STORAGE_DIR;
    fetchAllThePreferences();
    String? l = await BackupService.getDateLatestBackup();
    if (l != null) {
      lastBackupDataStr = l;
    }
  }

  createAndShareBackupFile() async {
    String? filename = await BackupService.getDefaultFileName();
    if (enableVersionAndDateInBackupName) {
      filename = null;
    }
    File backupFile = await BackupService.createJsonBackupFile(
        backupFileName: filename
    );
    Share.shareXFiles([XFile(backupFile.path)]);
  }

  storeBackupFile() async {
    String? filename = await BackupService.getDefaultFileName();
    if (enableVersionAndDateInBackupName) {
      filename = null;
    }
    File backupFile = await BackupService.createJsonBackupFile(
      backupFileName: filename,
      directoryPath: backupFolderPath,
      encryptionPassword: enableEncryptedBackup ? backupPassword : null
    );
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('File stored in ' + backupFile.path),
      )
    );
    String? l = await BackupService.getDateLatestBackup();
    if (l != null) {
      lastBackupDataStr = l;
    }
  }

  late SharedPreferences prefs;
  late String defaultDirectory;

  // Backup related
  Map<String, int> backupRetentionPeriodsValues = {
    "Never delete".i18n: BackupRetentionPeriod.ALWAYS.index,
    "Weekly".i18n: BackupRetentionPeriod.WEEK.index,
    "Monthly".i18n: BackupRetentionPeriod.MONTH.index,
  };
  late bool enableAutomaticBackup;
  late bool enableVersionAndDateInBackupName;
  late bool enableEncryptedBackup;
  late String backupRetentionPeriodValue;
  late String backupFolderPath;
  late String backupPassword;
  String lastBackupDataStr = "-";

  fetchAllThePreferences() {
    enableVersionAndDateInBackupName =
        prefs.getBool("enableVersionAndDateInBackupName") ?? true;
    enableAutomaticBackup =
        prefs.getBool("enableAutomaticBackup") ?? false;
    enableEncryptedBackup =
        prefs.getBool("enableEncryptedBackup") ?? false;
    var backupRetentionIntervalIndex = prefs.getInt("backupRetentionIntervalIndex") ??
        BackupRetentionPeriod.ALWAYS.index;
    backupRetentionPeriodValue = getKeyFromObject<int>(
        backupRetentionPeriodsValues, backupRetentionIntervalIndex);
    backupPassword = prefs.getString("backupPassword") ?? "";
    backupFolderPath = defaultDirectory;
  }

  resetEnableEncryptedBackup() {
    prefs.remove("enableEncryptedBackup");
    prefs.remove("backupPassword");
    setState(() {
      enableEncryptedBackup = false;
      backupPassword = "";
    });
  }

  setPasswordInPreferences(String password) {
    prefs.setString('backupPassword', BackupService.hashPassword(password));
  }

  final _textController = TextEditingController();
  bool _isOkButtonEnabled = false;
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
                      hintText: 'Enter your password here',
                    ),
                    onChanged: (value) {
                      // Update the state of the OK button based on input text
                      setState(() {
                        _isOkButtonEnabled = _textController.text.trim().isNotEmpty;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close the dialog
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
          future: initializePreferences(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              return SingleChildScrollView(
                child: Column(
                  children: <Widget>[
                    SettingsItem(
                        icon: Icon(
                          Icons.backup,
                          color: Colors.white,
                        ),
                        iconBackgroundColor: Colors.orange.shade600,
                        title: 'Export Backup'.i18n,
                        subtitle: "Share the backup file".i18n,
                        onPressed: () async => await createAndShareBackupFile()),
                    SettingsItem(
                        icon: Icon(
                          Icons.save_alt,
                          color: Colors.white,
                        ),
                        iconBackgroundColor: Colors.lightBlue.shade600,
                        title: 'Store the Backup on disk'.i18n,
                        onPressed: () async => await storeBackupFile()),
                    ClickableCustomizationItem(
                        title: "Destination folder".i18n,
                        subtitle: backupFolderPath,
                        enabled: false
                    ),
                    SwitchCustomizationItem(
                      title: "Backup encryption".i18n,
                      subtitle: "Enable if you want to have encrypted backups".i18n,
                      switchValue: enableEncryptedBackup,
                      sharedConfigKey: "enableEncryptedBackup",
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
                      subtitle: "File will have an unique name".i18n,
                      switchValue: enableVersionAndDateInBackupName,
                      sharedConfigKey: "enableVersionAndDateInBackupName",
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
                          : "Enable to automatic backup at every access".i18n,
                      switchValue: enableAutomaticBackup,
                      sharedConfigKey: "enableAutomaticBackup",
                      onChanged: (value) {
                        if (value == false) {
                          prefs.remove("backupRetentionIntervalIndex");
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
                              subtitle: "How long do you want to keep backups".i18n,
                              dropdownValues: backupRetentionPeriodsValues,
                              selectedDropdownKey: backupRetentionPeriodValue,
                              sharedConfigKey: "backupRetentionIntervalIndex",
                            ),
                          ),
                        ],
                      ),
                    ),
                    Center(
                      child: Text("Last backup: ".i18n + lastBackupDataStr)
                    )
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
