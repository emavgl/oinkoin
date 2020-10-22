import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:piggybank/premium/splash-screen.dart';
import 'package:piggybank/premium/util-widgets.dart';
import 'package:piggybank/recurrent_record_patterns/patterns-page-view.dart';
import 'package:piggybank/services/backup-service.dart';
import 'package:piggybank/settings/settings-item.dart';
import 'package:piggybank/helpers/alert-dialog-builder.dart';
import 'package:piggybank/services/database/database-interface.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:share/share.dart';
import './i18n/settings-page.i18n.dart';
import 'dart:io';

import 'currency-page.dart';
import 'package:url_launcher/url_launcher.dart';

import 'feedback-page.dart';

// look here for how to store settings
//https://flutter.dev/docs/cookbook/persistence/key-value
//https://pub.dev/packages/shared_preferences

class SettingsPage extends StatelessWidget {
  static const double kSettingsItemsExtent = 75.0;
  static const double kSettingsItemsIconPadding = 8.0;
  static const double kSettingsItemsIconElevation = 2.0;
  final DatabaseInterface database = ServiceConfig.database;

  createAndShareBackupFile() async {
    File backupFile = await BackupService.createJsonBackupFile();
    Share.shareFiles([backupFile.path]);
  }

  importFromBackupFile(BuildContext context) async {
    File file = await FilePicker.getFile(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (file != null) {
      bool successful = await BackupService.importDataFromBackupFile(file);
      if (successful) {
        AlertDialogBuilder resultDialog = AlertDialogBuilder("Restore successful".i18n)
            .addSubtitle("The data from the backup file are now restored.".i18n)
            .addTrueButtonName("OK");
        await showDialog(context: context, builder: (BuildContext context) {
          return resultDialog.build(context);
        });
      } else {
        AlertDialogBuilder resultDialog = AlertDialogBuilder("Restore unsuccessful".i18n)
            .addSubtitle("Make sure you have the latest version of the app. If so, the backup file may be corrupted.".i18n)
            .addTrueButtonName("OK");
        await showDialog(context: context, builder: (BuildContext context) {
          return resultDialog.build(context);
        });
      }
    }
  }

  deleteAllData(BuildContext context) async {
    AlertDialogBuilder premiumDialog = AlertDialogBuilder("Critical action".i18n)
        .addSubtitle("Do you really want to delete all the data?".i18n)
        .addTrueButtonName("Yes".i18n).addFalseButtonName("No".i18n);
    var ok = await showDialog(context: context, builder: (BuildContext context) {
      return premiumDialog.build(context);
    });
    if (ok) {
      await database.deleteDatabase();
    }
  }

  goToPremiumSplashScreen(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PremiumSplashScren()),
    );
  }

  goToRecurrentRecordPage(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PatternsPageView()),
    );
  }

  goToFeedbackPage(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => FeedbackPage()),
    );
  }

  _launchURL(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    }
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
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => CurrencyPage()),
              );
            },
          ),
          SettingsItem(
              icon: Icon(
                Icons.repeat,
                color: Colors.white,
              ),
              iconBackgroundColor: Colors.pink.shade600,
              title: 'Recurrent Records'.i18n,
              subtitle: "View or delete recurrent records".i18n,
              onPressed: () async => await goToRecurrentRecordPage(context)
          ),
          SettingsItem(
            icon: Icon(
              Icons.backup,
              color: Colors.white,
            ),
            iconBackgroundColor: Colors.orange.shade600,
            title: 'Backup'.i18n,
            subtitle: "Make a backup of all the data".i18n,
            onPressed: () async => await createAndShareBackupFile()
          ),
          Stack(
            children: [
              SettingsItem(
                icon: Icon(
                  Icons.restore_page,
                  color: Colors.white,
                ),
                iconBackgroundColor: Colors.teal,
                title: 'Restore Backup'.i18n,
                subtitle: "Restore data from a backup file".i18n,
                onPressed: ServiceConfig.isPremium ? () async => await importFromBackupFile(context) : () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => PremiumSplashScren()),
                  );
                },
              ),
              !ServiceConfig.isPremium ? Container(
                margin: EdgeInsets.fromLTRB(8, 8, 0, 0),
                child:  getProLabel(labelFontSize: 10.0),
              ) : Container()
            ],
          ),
          SettingsItem(
            icon: Icon(
              Icons.delete_outline,
              color: Colors.white,
            ),
            iconBackgroundColor: Colors.teal,
            title: 'Delete'.i18n,
            subtitle: 'Delete all the data'.i18n,
            onPressed: () async => await deleteAllData(context),
          ),
          SettingsItem(
            icon: Icon(
              Icons.info_outline,
              color: Colors.white,
            ),
            iconBackgroundColor: Colors.tealAccent.shade700,
            title: 'Info'.i18n,
            subtitle: 'Privacy policy and credits'.i18n,
            onPressed: () async => await _launchURL("https://github.com/emavgl/piggybank-privacy-policy/blob/master/privacy-policy.md"),
          ),
          SettingsItem(
            icon: Icon(
              Icons.mail_outline,
              color: Colors.white,
            ),
            iconBackgroundColor: Colors.red.shade700,
            title: 'Feedback'.i18n,
            subtitle: "Send us a feedback".i18n,
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => FeedbackPage()),
              );
            },          ),
        ],
      ),
    ));
  }

}
