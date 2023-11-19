
import 'package:flutter/material.dart';
import 'package:i18n_extension/i18n_widget.dart';
import 'package:intl/number_symbols_data.dart';
import 'package:shared_preferences/shared_preferences.dart';
import './i18n/settings-page.i18n.dart';
import 'package:intl/src/intl_helpers.dart' as helpers;


class CustomizationPage extends StatefulWidget {

  @override
  CustomizationPageState createState() => CustomizationPageState();
}

class CustomizationPageState extends State<CustomizationPage> {

  static bool localeExists(String? localeName) {
    if (localeName == null) return false;
    return numberFormatSymbols.containsKey(localeName);
  }

  String? getLocaleGroupingSeparator() {
    String myLocale = I18n.locale.toString();
    String? existingLocale = helpers.verifiedLocale(myLocale, localeExists, null);
    if (existingLocale == null) {
      return null;
    }
    return numberFormatSymbols[existingLocale]?.GROUP_SEP;
  }

  String? getLocaleDecimalSeparator() {
    String myLocale = I18n.locale.toString();
    String? existingLocale = helpers.verifiedLocale(myLocale, localeExists, null);
    if (existingLocale == null) {
      return null;
    }
    return numberFormatSymbols[existingLocale]?.DECIMAL_SEP;
  }


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
        decimalDigitsValue = prefs.getInt('numDecimalDigits') ?? 2;
        useGroupSeparator = prefs.getBool("useGroupSeparator") ?? true;
        groupSeparatorValue = prefs.getString("groupSeparator") ?? getLocaleGroupingSeparator()!;
        groupSeparatorsValues.remove(getLocaleDecimalSeparator()!);
      });
    });
  }

  late SharedPreferences prefs;
  List<String> themeStyleDropDownValues = ["System".i18n, "Light".i18n, "Dark".i18n];
  String themeStyleDropdownValue = "System".i18n;

  List<String> themeColorDropDownValues = ["Default".i18n, "System".i18n, "Monthly Image".i18n];
  String themeColorDropdownValue = "Default".i18n;

  List<int> decimalDigitsValues = [0, 1, 2, 3, 4];
  int decimalDigitsValue = 2;

  bool useGroupSeparator = true;
  Map<String, String> groupSeparatorSymbols = {
    ".": "dot".i18n,
    ",": "comma".i18n,
    "\u00A0": "space".i18n,
    "_": "underscore",
    "'": "apostrophe".i18n
  };
  List<String> groupSeparatorsValues = [".", ",", "\u00A0", "_", "'"];
  String groupSeparatorValue = ".";

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

  Widget buildDecimalDigitsDropdownButton() {
    return DropdownButton<int>(
      padding: EdgeInsets.all(15),
      underline: SizedBox(),
      value: decimalDigitsValue,
      onChanged: (int? value) {
        setState(() {
          decimalDigitsValue = value!;
          prefs.setInt("numDecimalDigits", value);
        });
      },
      items: decimalDigitsValues.map<DropdownMenuItem<int>>((int value) {
        return DropdownMenuItem<int>(
          value: value,
          child: Text(value.toString()),
        );
      }).toList(),
    );
  }

  Widget buildGroupingSeparatorDropdownButton() {
    return DropdownButton<String>(
      padding: EdgeInsets.all(15),
      underline: SizedBox(),
      value: groupSeparatorValue,
      onChanged: (String? value) {
        setState(() {
          groupSeparatorValue = value!;
          prefs.setString("groupSeparator", value);
          print("Selected Group Separator:" + groupSeparatorSymbols[value].toString());
        });
      },
      items: groupSeparatorsValues.map<DropdownMenuItem<String>>((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(groupSeparatorSymbols[value].toString()),
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
            subtitle: Text("Select the app theme color".i18n + " - " +  "Require App restart".i18n),
          ),
          ListTile(
            trailing: buildThemeStyleDropdownButton(),
            title: Text("Theme style".i18n),
            subtitle: Text("Select the app theme style".i18n + " - " +  "Require App restart".i18n),
          ),
          ListTile(
            trailing: buildDecimalDigitsDropdownButton(),
            title: Text("Decimal digits".i18n),
            subtitle: Text("Select the number of decimal digits".i18n),
          ),
          ListTile(
            trailing: Switch(
              // This bool value toggles the switch.
              value: useGroupSeparator,
              onChanged: (bool value) {
                setState(() {
                  prefs.setBool("useGroupSeparator", value);
                  useGroupSeparator = value;
                });
              },
            ),
            title: Text("Use `Grouping separator`".i18n),
            subtitle: Text("For example, 1000 -> 1,000".i18n),
          ),
          ListTile(
            trailing: buildGroupingSeparatorDropdownButton(),
            title: Text("Grouping separator".i18n),
            subtitle: Text("Overwrite grouping separator".i18n),
          ),
        ],
      ),
    );
  }
}
