import 'package:flutter/material.dart';
import 'package:piggybank/helpers/alert-dialog-builder.dart';
import 'package:piggybank/i18n.dart';
import 'package:piggybank/premium/splash-screen.dart';
import 'package:piggybank/premium/util-widgets.dart';
import 'package:piggybank/recurrent_record_patterns/patterns-page-view.dart';
import 'package:piggybank/services/database/database-interface.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/settings/backup-page.dart';
import 'package:piggybank/settings/backup-restore-dialogs.dart';
import 'package:piggybank/settings/customization-page.dart';
import 'package:piggybank/settings/settings-item.dart';
import 'package:piggybank/tags/tags-page-view.dart';
import 'package:url_launcher/url_launcher.dart';

import 'feedback-page.dart';

// look here for how to store settings
//https://flutter.dev/docs/cookbook/persistence/key-value
//https://pub.dev/packages/shared_preferences

class TabSettings extends StatelessWidget {
  static const double kSettingsItemsExtent = 75.0;
  static const double kSettingsItemsIconPadding = 8.0;
  static const double kSettingsItemsIconElevation = 2.0;
  final DatabaseInterface database = ServiceConfig.database;

  deleteAllData(BuildContext context) async {
    AlertDialogBuilder premiumDialog =
        AlertDialogBuilder("Critical action".i18n)
            .addSubtitle("Do you really want to delete all the data?".i18n)
            .addTrueButtonName("Yes".i18n)
            .addFalseButtonName("No".i18n);
    var ok = await showDialog(
        context: context,
        builder: (BuildContext context) {
          return premiumDialog.build(context);
        });
    if (ok) {
      await database.deleteDatabase();
      AlertDialogBuilder resultDialog =
          AlertDialogBuilder("Data is deleted".i18n)
              .addSubtitle("All the data has been deleted".i18n)
              .addTrueButtonName("OK");
      await showDialog(
          context: context,
          builder: (BuildContext context) {
            return resultDialog.build(context);
          });
    }
  }

  goToPremiumSplashScreen(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PremiumSplashScreen()),
    );
  }

  goToRecurrentRecordPage(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PatternsPageView()),
    );
  }

  goToTagsPage(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => TagsPageView()),
    );
  }

  goToCustomizationPage(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CustomizationPage()),
    );
  }

  goToBackupPage(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => BackupPage()),
    );
  }

  goToFeedbackPage(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => FeedbackPage()),
    );
  }

  _launchURL(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
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
        children: <Widget>[
          SettingsItem(
              icon: Icon(
                Icons.wallpaper,
                color: Colors.white,
              ),
              iconBackgroundColor: Colors.blue.shade600,
              title: 'Customization'.i18n,
              subtitle: "Visual settings and more".i18n,
              onPressed: () async => await goToCustomizationPage(context)),
          Divider(),
          SettingsItem(
              icon: Icon(
                Icons.repeat,
                color: Colors.white,
              ),
              iconBackgroundColor: Colors.pink.shade600,
              title: 'Recurrent Records'.i18n,
              subtitle: "View or delete recurrent records".i18n,
              onPressed: () async => await goToRecurrentRecordPage(context)),
          SettingsItem(
              icon: Icon(
                Icons.tag,
                color: Colors.white,
              ),
              iconBackgroundColor: Colors.amber.shade600,
              title: 'Tags'.i18n,
              subtitle: "Manage your existing tags".i18n,
              onPressed: () async => await goToTagsPage(context)),
          Divider(),
          SettingsItem(
              icon: Icon(
                Icons.backup,
                color: Colors.white,
              ),
              iconBackgroundColor: Colors.orange.shade600,
              title: 'Backup'.i18n,
              subtitle: "Create backup and change settings".i18n,
              onPressed: () async => await goToBackupPage(context)),
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
                onPressed: ServiceConfig.isPremium
                    ? () async =>
                        await BackupRestoreDialog.importFromBackupFile(context)
                    : () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => PremiumSplashScreen()),
                        );
                      },
              ),
              !ServiceConfig.isPremium
                  ? Container(
                      margin: EdgeInsets.fromLTRB(8, 8, 0, 0),
                      child: getProLabel(labelFontSize: 10.0),
                    )
                  : Container()
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
          Divider(),
          SettingsItem(
            icon: Icon(
              Icons.info_outline,
              color: Colors.white,
            ),
            iconBackgroundColor: Colors.tealAccent.shade700,
            title: 'Info'.i18n,
            subtitle: 'Privacy policy and credits'.i18n,
            onPressed: () async => await _launchURL(
                "https://github.com/emavgl/oinkoin/blob/master/privacy-policy.md"),
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
            },
          ),
        ],
      ),
    ));
  }
}
