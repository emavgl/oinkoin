import 'package:flutter/material.dart';
import 'package:piggybank/i18n.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/settings/constants/preferences-keys.dart';
import 'package:piggybank/settings/preferences-utils.dart';
import 'package:piggybank/settings/switch-customization-item.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Privacy settings: hides sensitive monetary amounts behind placeholders.
class PrivacyPage extends StatefulWidget {
  const PrivacyPage({super.key});

  @override
  PrivacyPageState createState() => PrivacyPageState();
}

class PrivacyPageState extends State<PrivacyPage> {
  late SharedPreferences prefs;
  late bool privacyMode;

  Future<void> initializePreferences() async {
    prefs = await SharedPreferences.getInstance();
    privacyMode =
        PreferencesUtils.getOrDefault<bool>(prefs, PreferencesKeys.privacyMode)!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Privacy".i18n),
      ),
      body: FutureBuilder(
        future: initializePreferences(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return SingleChildScrollView(
              child: Column(
                children: <Widget>[
                  SwitchCustomizationItem(
                    title: "Privacy mode".i18n,
                    subtitle:
                        "Hide balances and amounts behind placeholders".i18n,
                    switchValue: privacyMode,
                    sharedConfigKey: PreferencesKeys.privacyMode,
                    onChanged: (value) {
                      ServiceConfig.setPrivacyMode(value);
                      setState(() {
                        privacyMode = value;
                      });
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Text(
                      "Tap the amounts in the homepage summary to quickly show or hide them."
                          .i18n,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            );
          } else {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
        },
      ),
    );
  }
}
