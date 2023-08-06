import 'dart:ffi';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import './i18n/settings-page.i18n.dart';

class CustomizationPage extends StatefulWidget {

  @override
  CustomizationPageState createState() => CustomizationPageState();
}

class CustomizationPageState extends State<CustomizationPage> {

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((value) {
      prefs = value;
      int themeStyleDropdownValueIndex = prefs.getInt('themeMode') ?? 0;
      setState(() {
        switchValue1 = prefs.getBool('dynamicColorScheme') ?? false;
        themeStyleDropdownValue = dropDownValues[themeStyleDropdownValueIndex];
      });
    });
  }

  bool switchValue1 = false;
  late SharedPreferences prefs;
  List<String> dropDownValues = ["System".i18n, "Light".i18n, "Dark".i18n];
  String themeStyleDropdownValue = "System".i18n;

  Widget buildThemeStyleDropdownButton() {
    return DropdownButton<String>(
      value: themeStyleDropdownValue,
      onChanged: (String? value) {
        setState(() {
          themeStyleDropdownValue = value!;
          prefs.setInt("themeMode", dropDownValues.indexOf(value));
        });
      },
      items: dropDownValues.map<DropdownMenuItem<String>>((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Customization".i18n),
      ),
      body: Column(
        children: <Widget>[
          SwitchListTile(
            value: switchValue1,
            onChanged: (bool? value) async {
              setState(() {
                switchValue1 = value!;
                prefs.setBool("dynamicColorScheme", switchValue1);
              });
            },
            title: Text("Dynamic colors".i18n),
            subtitle: Text("Use a color palette based on the main image - Require App restart".i18n),
          ),
          ListTile(
            trailing: buildThemeStyleDropdownButton(),
            title: Text("Theme style".i18n),
            subtitle: Text("Select the app theme style - Require App restart".i18n),
          ),
        ],
      ),
    );
  }
}
