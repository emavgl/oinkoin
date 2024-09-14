import 'package:flutter/material.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/settings/backup-retention-period.dart';
import 'package:piggybank/settings/homepage-time-interval.dart';
import 'package:piggybank/settings/style.dart';
import 'package:piggybank/settings/switch-customization-item.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../helpers/records-utility-functions.dart';
import 'package:piggybank/i18n.dart';

import 'dropdown-customization-item.dart';

class CustomizationPage extends StatefulWidget {
  @override
  CustomizationPageState createState() => CustomizationPageState();
}

class CustomizationPageState extends State<CustomizationPage> {
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
    fetchAllThePreferences();
  }

  fetchAllThePreferences() {
    // Get theme color
    int themeColorDropdownValueIndex = prefs.getInt('themeColor') ?? 0;
    themeColorDropdownKey = getKeyFromObject<int>(
        themeColorDropdownValues, themeColorDropdownValueIndex);

    // Get theme style
    int themeStyleDropdownValueIndex = prefs.getInt('themeMode') ?? 0;
    themeStyleDropdownKey = getKeyFromObject<int>(
        themeStyleDropdownValues, themeStyleDropdownValueIndex);

    // Get languageLocale
    var userDefinedLanguageLocale = prefs.getString("languageLocale");
    languageDropdownKey = getKeyFromObject<String>(
        languageToLocaleTranslation, userDefinedLanguageLocale);

    // Get Number of decimal digits
    decimalDigitsValueDropdownKey =
        (prefs.getInt('numDecimalDigits') ?? 2).toString();

    // Decimal separator
    var usedDefinedDecimalSeparatorValue =
        prefs.getString("decimalSeparator") ?? getLocaleDecimalSeparator();
    decimalSeparatorDropdownKey = getKeyFromObject<String>(
        decimalSeparatorValues, usedDefinedDecimalSeparatorValue);

    // Grouping separator
    var usedDefinedGroupSeparatorValue =
        prefs.getString("groupSeparator") ?? getLocaleGroupingSeparator();
    if (!groupSeparatorsValues.containsValue(usedDefinedGroupSeparatorValue)) {
      // It may happen with unsupported locales (persian)
      groupSeparatorsValues[usedDefinedGroupSeparatorValue] =
          usedDefinedGroupSeparatorValue;
    }
    groupSeparatorDropdownKey = getKeyFromObject<String>(
        groupSeparatorsValues, usedDefinedGroupSeparatorValue);
    allowedGroupSeparatorsValues = Map.from(groupSeparatorsValues);
    allowedGroupSeparatorsValues.remove(decimalSeparatorDropdownKey);

    // Overwrite dot
    overwriteDotValueWithComma = prefs.getBool("overwriteDotValueWithComma") ??
        getDecimalSeparator() == ",";

    // Overwrite comma
    overwriteCommaValueWithDot = prefs.getBool("overwriteCommaValueWithDot") ??
        getDecimalSeparator() == ".";

    // Record's name suggestions
    enableRecordNameSuggestions =
        prefs.getBool("enableRecordNameSuggestions") ?? true;

    // Homepage time interval
    var userDefinedHomepageInterval = prefs.getInt("homepageTimeInterval") ??
        HomepageTimeInterval.CurrentMonth.index;
    homepageTimeIntervalValue = getKeyFromObject<int>(
        homepageTimeIntervalValues, userDefinedHomepageInterval);

    // Backup related
    enableAutomaticBackup =
        prefs.getBool("enableAutomaticBackup") ?? false;
    var backupRetentionIntervalIndex = prefs.getInt("backupRetentionIntervalIndex") ??
        BackupRetentionPeriod.ALWAYS.index;
    backupRetentionPeriodValue = getKeyFromObject<int>(
        backupRetentionPeriodsValues, backupRetentionIntervalIndex);
    backupPassword = prefs.getString("backupPassword") ?? "";
    backupFolderPath = prefs.getString("backupFolderPath");
  }

  late SharedPreferences prefs;

  // Style dropdown
  Map<String, int> themeStyleDropdownValues = {
    "System".i18n: 0,
    "Light".i18n: 1,
    "Dark".i18n: 2
  };
  late String themeStyleDropdownKey;

  // Theme color dropdown
  Map<String, int> themeColorDropdownValues = {
    "Default".i18n: 0,
    "System".i18n: 1,
    "Monthly Image".i18n: 2
  };
  late String themeColorDropdownKey;

  // Language dropdown
  Map<String, String> languageToLocaleTranslation = {
    "System".i18n: "system",
    "Deutsch": "de_DE",
    "English (US)": "en_US",
    "English (UK)": "en_GB",
    "Español": "es_ES",
    "Français": "fr_FR",
    "Italiano": "it_IT",
    "Português (Brazil)": "pt_BR",
    "Português (Portugal)": "pr_PT",
    "Pусский язык": "ru_RU",
    "Türkçe": "tr_TR",
    "Veneto": "vec_IT",
    "简化字": "zh_CN",
  };
  late String languageDropdownKey;

  // Decimal digits
  Map<String, int> decimalDigitsValues = {
    "0": 0,
    "1": 1,
    "2": 2,
    "3": 3,
    "4": 4,
  };
  late String decimalDigitsValueDropdownKey;

  // Group separator
  Map<String, String> groupSeparatorsValues = {
    "none".i18n: "",
    "dot".i18n: ".",
    "comma".i18n: ",",
    "space".i18n: "\u00A0",
    "underscore".i18n: "_",
    "apostrophe".i18n: "'",
  };
  late Map<String, String> allowedGroupSeparatorsValues;
  late String groupSeparatorDropdownKey;

  // Time Interval
  Map<String, int> homepageTimeIntervalValues = {
    "Records of the current month".i18n:
        HomepageTimeInterval.CurrentMonth.index,
    "Records of the current year".i18n: HomepageTimeInterval.CurrentYear.index,
    "All records".i18n: HomepageTimeInterval.All.index,
  };
  late String homepageTimeIntervalValue;

  // Decimal separator
  Map<String, String> decimalSeparatorValues = {
    "dot".i18n: ".",
    "comma".i18n: ",",
  };
  late String decimalSeparatorDropdownKey;

  late bool overwriteDotValueWithComma;
  late bool overwriteCommaValueWithDot;
  late bool enableRecordNameSuggestions;

  // Backup related
  Map<String, int> backupRetentionPeriodsValues = {
    "Never delete".i18n: BackupRetentionPeriod.ALWAYS.index,
    "Weekly".i18n: BackupRetentionPeriod.WEEK.index,
    "Monthly".i18n: BackupRetentionPeriod.MONTH.index,
  };
  late bool enableAutomaticBackup;
  late String backupRetentionPeriodValue;
  late String? backupFolderPath;
  late String backupPassword;

  void invalidateNumberPatternCache() {
    ServiceConfig.currencyNumberFormat = null;
    ServiceConfig.currencyNumberFormatWithoutGrouping = null;
  }

  void invalidateOverwritePreferences() async {
    if (ServiceConfig.sharedPreferences!
        .containsKey("overwriteDotValueWithComma")) {
      await ServiceConfig.sharedPreferences?.remove("overwriteDotValueWithComma");
    }
    if (ServiceConfig.sharedPreferences!
        .containsKey("overwriteCommaValueWithDot")) {
      await ServiceConfig.sharedPreferences?.remove("overwriteCommaValueWithDot");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text("Customization".i18n),
        ),
        body: FutureBuilder(
          future: initializePreferences(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              return SingleChildScrollView(
                child: Column(
                  children: <Widget>[
                    DropdownCustomizationItem(
                      title: "Colors".i18n,
                      subtitle: "Select the app theme color".i18n +
                          " - " +
                          "Require App restart".i18n,
                      dropdownValues: themeColorDropdownValues,
                      selectedDropdownKey: themeColorDropdownKey,
                      sharedConfigKey: "themeColor",
                    ),
                    DropdownCustomizationItem(
                      title: "Theme style".i18n,
                      subtitle: "Select the app theme style".i18n +
                          " - " +
                          "Require App restart".i18n,
                      dropdownValues: themeStyleDropdownValues,
                      selectedDropdownKey: themeStyleDropdownKey,
                      sharedConfigKey: "themeMode",
                    ),
                    DropdownCustomizationItem(
                      title: "Language".i18n,
                      subtitle: "Select the app language".i18n +
                          " - " +
                          "Require App restart".i18n,
                      dropdownValues: languageToLocaleTranslation,
                      selectedDropdownKey: languageDropdownKey,
                      sharedConfigKey: "languageLocale",
                    ),
                    DropdownCustomizationItem(
                      title: "Decimal digits".i18n,
                      subtitle: "Select the number of decimal digits".i18n,
                      dropdownValues: decimalDigitsValues,
                      selectedDropdownKey: decimalDigitsValueDropdownKey,
                      sharedConfigKey: "numDecimalDigits",
                      onChanged: () {
                        invalidateNumberPatternCache();
                      },
                    ),
                    DropdownCustomizationItem(
                        title: "Decimal separator".i18n,
                        subtitle: "Select the decimal separator".i18n,
                        dropdownValues: decimalSeparatorValues,
                        selectedDropdownKey: decimalSeparatorDropdownKey,
                        sharedConfigKey: "decimalSeparator",
                        onChanged: () {
                          invalidateNumberPatternCache();
                          invalidateOverwritePreferences();
                          setState(() {
                            fetchAllThePreferences();
                            if (decimalSeparatorDropdownKey ==
                                groupSeparatorDropdownKey) {
                              // Inconsistency, disable group separator
                              prefs.setString("groupSeparator", "");
                            }
                            fetchAllThePreferences();
                          });
                        }),
                    DropdownCustomizationItem(
                      title: "Grouping separator".i18n,
                      subtitle: "Select the grouping separator".i18n,
                      dropdownValues: allowedGroupSeparatorsValues,
                      selectedDropdownKey: groupSeparatorDropdownKey,
                      sharedConfigKey: "groupSeparator",
                      onChanged: () {
                        invalidateNumberPatternCache();
                      },
                    ),
                    Visibility(
                      visible: getDecimalSeparator() == ",",
                      child: SwitchCustomizationItem(
                        title: "Overwrite the key `dot`".i18n,
                        subtitle:
                            "When typing `dot`, it types `comma` instead".i18n,
                        switchValue: overwriteDotValueWithComma,
                        sharedConfigKey: "overwriteDotValueWithComma",
                      ),
                    ),
                    Visibility(
                      visible: getDecimalSeparator() == ".",
                      child: SwitchCustomizationItem(
                        title: "Overwrite the key `comma`".i18n,
                        subtitle:
                        "When typing `comma`, it types `dot` instead".i18n,
                        switchValue: overwriteCommaValueWithDot,
                        sharedConfigKey: "overwriteCommaValueWithDot",
                      ),
                    ),
                    DropdownCustomizationItem(
                      title: "Homepage time interval".i18n,
                      subtitle:
                          "Define the records to show in the app homepage".i18n,
                      dropdownValues: homepageTimeIntervalValues,
                      selectedDropdownKey: homepageTimeIntervalValue,
                      sharedConfigKey: "homepageTimeInterval",
                    ),
                    SwitchCustomizationItem(
                      title: "Enable record's name suggestions".i18n,
                      subtitle:
                          "If enabled, you get suggestions when typing the record's name".i18n,
                      switchValue: enableRecordNameSuggestions,
                      sharedConfigKey: "enableRecordNameSuggestions",
                    ),
                    ListTile(
                      onTap: () {
                        setState(() {
                          prefs.clear();
                          fetchAllThePreferences();
                        });
                      },
                      title: Text("Restore all the default configurations".i18n,
                          style: titleTextStyle),
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
