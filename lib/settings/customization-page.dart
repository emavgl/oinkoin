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
      int themeColorDropdownValueIndex = prefs.getInt('themeColor') ?? 0;
      setState(() {
        themeColorDropdownValue = themeColorDropDownValues[themeColorDropdownValueIndex];
        themeStyleDropdownValue = themeStyleDropDownValues[themeStyleDropdownValueIndex];
      });
    });
  }

  late SharedPreferences prefs;
  List<String> themeStyleDropDownValues = ["System".i18n, "Light".i18n, "Dark".i18n];
  String themeStyleDropdownValue = "System".i18n;

  List<String> themeColorDropDownValues = ["Default".i18n, "System".i18n, "Monthly Image".i18n];
  String themeColorDropdownValue = "Default".i18n;

  Widget buildThemeStyleDropdownButton() {
    return DropdownButton<String>(
      padding: EdgeInsets.all(15),
      value: themeStyleDropdownValue,
      underline: SizedBox(),
      onChanged: (String? value) {
        setState(() {
          themeStyleDropdownValue = value!;
          prefs.setInt("themeMode", themeStyleDropDownValues.indexOf(value));
        });
      },
      items: themeStyleDropDownValues.map<DropdownMenuItem<String>>((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value),
        );
      }).toList(),
    );
  }

  Widget buildThemeColorDropdownButton() {
    return DropdownButton<String>(
      padding: EdgeInsets.all(15),
      underline: SizedBox(),
      value: themeColorDropdownValue,
      onChanged: (String? value) {
        setState(() {
          themeColorDropdownValue = value!;
          prefs.setInt("themeColor", themeColorDropDownValues.indexOf(value));
        });
      },
      items: themeColorDropDownValues.map<DropdownMenuItem<String>>((String value) {
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
          ListTile(
            trailing: buildThemeColorDropdownButton(),
            title: Text("Colors".i18n),
            subtitle: Text("Select the app theme color - Require App restart".i18n),
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
