import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:piggybank/components/settings-item.dart';
import 'package:piggybank/helpers/alert-dialog-builder.dart';
import 'package:piggybank/models/backup.dart';
import 'package:piggybank/services/database/database-interface.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:share/share.dart';
import './i18n/settings-page.i18n.dart';
import 'dart:convert';
import 'dart:io';

// look here for how to store settings
//https://flutter.dev/docs/cookbook/persistence/key-value
//https://pub.dev/packages/shared_preferences

class SettingsPage extends StatelessWidget {
  static const double kSettingsItemsExtent = 75.0;
  static const double kSettingsItemsIconPadding = 8.0;
  static const double kSettingsItemsIconElevation = 2.0;
  final DatabaseInterface database = ServiceConfig.database;

  export() async {
    var records = await database.getAllRecords();
    var categories = await database.getAllCategories();
    var backup = Backup(categories, records);
    var backupJsonStr = jsonEncode(backup.toMap());
    final path = await getApplicationDocumentsDirectory();
    var backupJsonOnDisk = File(path.path + "/backup.json");
    await backupJsonOnDisk.writeAsString(backupJsonStr);
    Share.shareFile(backupJsonOnDisk);
  }

  deleteAllData() async {
    await database.deleteDatabase();
  }

  premiumFeatureMessage(BuildContext context) async {
    AlertDialogBuilder premiumDialog = AlertDialogBuilder("Premium required")
        .addSubtitle("This feature is accessible in the premium version of the app.")
        .addTrueButtonName("OK");
    await showDialog(context: context, builder: (BuildContext context) {
      return premiumDialog.build(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        child: Scaffold(
      appBar: AppBar(
        title: Text('Settings'.i18n),
      ),
      body: ListView(
        itemExtent: kSettingsItemsExtent,
        children: <Widget>[
          SettingsItem(
            icon: Icon(
              Icons.euro_symbol,
              color: Colors.white,
            ),
            iconBackgroundColor: Colors.blue,
            title: 'Currency'.i18n,
            subtitle: 'Select the currency for your expenses'.i18n,
            onPressed: () {},
          ),
          SettingsItem(
            icon: Icon(
              Icons.save,
              color: Colors.white,
            ),
            iconBackgroundColor: Colors.orange.shade600,
            title: 'Export'.i18n,
            subtitle: 'Make a backup of the data of the app'.i18n,
            onPressed: () async => await export(),
          ),
          SettingsItem(
            icon: Icon(
              Icons.backup,
              color: Colors.white,
            ),
            iconBackgroundColor: Colors.teal,
            title: 'Import'.i18n,
            subtitle: '(Premium) Import a backup of the data of the app'.i18n,
            onPressed: () async => await premiumFeatureMessage(context),
          ),
          SettingsItem(
            icon: Icon(
              Icons.delete_outline,
              color: Colors.white,
            ),
            iconBackgroundColor: Colors.teal,
            title: 'Delete'.i18n,
            subtitle: 'Delete all the data'.i18n,
            onPressed: () async => await deleteAllData(),
          ),
          SettingsItem(
            icon: Icon(
              Icons.feedback,
              color: Colors.white,
            ),
            iconBackgroundColor: Colors.amber.shade600,
            title: 'Feedback'.i18n,
            subtitle: 'Any suggestion? Tell us!'.i18n,
            onPressed: () {},
          ),
          SettingsItem(
            icon: Icon(
              Icons.info_outline,
              color: Colors.white,
            ),
            iconBackgroundColor: Colors.tealAccent.shade700,
            title: 'Info'.i18n,
            subtitle: 'Privacy policy and credits'.i18n,
            onPressed: () {},
          ),
        ],
      ),
    ));
  }
}
