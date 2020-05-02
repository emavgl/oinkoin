import 'package:flutter/material.dart';
import 'package:piggybank/components/settings-item.dart';
import '../i18n/settings-page.i18n.dart';

class SettingsPage extends StatelessWidget {
  static const double kSettingsItemsExtent = 75.0;
  static const double kSettingsItemsIconPadding = 8.0;
  static const double kSettingsItemsIconElevation = 2.0;

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
              Icons.color_lens,
              color: Colors.white,
            ),
            iconBackgroundColor: Colors.green,
            title: 'Theme'.i18n,
            subtitle: 'Select the theme of the app'.i18n,
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
            onPressed: () {},
          ),
          SettingsItem(
            icon: Icon(
              Icons.backup,
              color: Colors.white,
            ),
            iconBackgroundColor: Colors.teal,
            title: 'Import'.i18n,
            subtitle: 'Import a backup of the data of the app'.i18n,
            onPressed: () {},
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
              Icons.cake,
              color: Colors.white,
            ),
            iconBackgroundColor: Colors.tealAccent.shade700,
            title: 'Thanks'.i18n,
            subtitle: 'Pay us a coffee'.i18n,
            onPressed: () {},
          ),
        ],
      ),
    ));
  }
}
