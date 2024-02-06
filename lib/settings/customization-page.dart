
import 'package:flutter/material.dart';
import 'package:intl/number_symbols_data.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../helpers/records-utility-functions.dart';
import 'package:piggybank/i18n.dart';

class CustomizationPage extends StatefulWidget {

  @override
  CustomizationPageState createState() => CustomizationPageState();
}

class CustomizationPageState extends State<CustomizationPage> {

  static bool localeExists(String? localeName) {
    if (localeName == null) return false;
    return numberFormatSymbols.containsKey(localeName);
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
        groupSeparatorValue = prefs.getString("groupSeparator") ?? getLocaleGroupingSeparator();
        if (!symbolsTranslations.containsKey(groupSeparatorValue)) {
          // this happen when there are languages with different group separator
          // like persian
          symbolsTranslations[groupSeparatorValue] = groupSeparatorValue;
        }
        groupSeparatorsValues.remove(getLocaleDecimalSeparator());
        overwriteDotValueWithComma = prefs.getBool("overwriteDotValueWithComma") ?? getLocaleDecimalSeparator() == ",";
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
  Map<String, String> symbolsTranslations = {
    ".": "dot".i18n,
    ",": "comma".i18n,
    "\u00A0": "space".i18n,
    "_": "underscore".i18n,
    "'": "apostrophe".i18n
  };
  List<String> groupSeparatorsValues = [".", ",", "\u00A0", "_", "'"];
  String groupSeparatorValue = ".";

  bool overwriteDotValueWithComma = true;

  Widget buildThemeStyleDropdownButton() {
    return DropdownButton<String>(
      padding: EdgeInsets.all(0),
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
      padding: EdgeInsets.all(0),
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
      padding: EdgeInsets.all(0),
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
      padding: EdgeInsets.all(0),
      underline: SizedBox(),
      value: groupSeparatorValue,
      onChanged: (String? value) {
        setState(() {
          groupSeparatorValue = value!;
          prefs.setString("groupSeparator", value);
          print("Selected Group Separator:" + symbolsTranslations[value]!);
        });
      },
      items: groupSeparatorsValues.map<DropdownMenuItem<String>>((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(symbolsTranslations[value]!),
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
      body: SingleChildScrollView(
        child: Column(
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
            Visibility(
              visible: getLocaleDecimalSeparator() == ",",
              child: ListTile(
                trailing: Switch(
                  // This bool value toggles the switch.
                  value: overwriteDotValueWithComma,
                  onChanged: (bool value) {
                    setState(() {
                      prefs.setBool("overwriteDotValueWithComma", value);
                      overwriteDotValueWithComma = value;
                    });
                  },
                ),
                title: Text("Overwrite the `dot`".i18n),
                subtitle: Text("Overwrite `dot` with `comma`".i18n),
              ),
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
            Visibility(
              visible: useGroupSeparator,
              child: ListTile(
                trailing: buildGroupingSeparatorDropdownButton(),
                title: Text("Grouping separator".i18n),
                subtitle: Text("Overwrite grouping separator".i18n),
              ),
            )
          ],
        ),
      )
    );
  }
}
