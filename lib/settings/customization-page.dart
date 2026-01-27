import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:piggybank/i18n.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/settings/components/setting-separator.dart';
import 'package:piggybank/settings/constants/preferences-keys.dart';
import 'package:piggybank/settings/constants/preferences-options.dart';
import 'package:piggybank/settings/preferences-utils.dart';
import 'package:piggybank/settings/style.dart';
import 'package:piggybank/settings/switch-customization-item.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/records-utility-functions.dart';
import 'dropdown-customization-item.dart';

class CustomizationPage extends StatefulWidget {
  @override
  CustomizationPageState createState() => CustomizationPageState();
}

class CustomizationPageState extends State<CustomizationPage> {
  late SharedPreferences prefs;

  static String getKeyFromObject<T>(Map<String, T> originalMap, T? searchValue,
      {String? defaultKey}) {
    return originalMap.entries
        .firstWhere((entry) => entry.value == searchValue,
            orElse: () => MapEntry(
                defaultKey ?? originalMap.keys.first, searchValue as T))
        .key;
  }

  T getPreferenceValue<T>(String key, T defaultValue) {
    if (T == int) {
      return (prefs.getInt(key) ?? defaultValue) as T;
    } else if (T == String) {
      return (prefs.getString(key) ?? defaultValue) as T;
    } else if (T == bool) {
      return (prefs.getBool(key) ?? defaultValue) as T;
    }
    throw UnsupportedError("Unsupported preference type for key: $key");
  }

  // Init

  Future<void> initializePreferences() async {
    prefs = await SharedPreferences.getInstance();
    await fetchAllThePreferences();
  }

  Future<void> fetchAllThePreferences() async {
    await fetchThemePreferences();
    await fetchLanguagePreferences();
    await fetchWeekSettingsPreferences();
    await fetchDateFormatPreferences();
    await fetchNumberFormattingPreferences();
    await fetchAppLockPreferences();
    await fetchMiscPreferences();
    await fetchStatisticsPreferences();
    await fetchHomepagePreferences();
  }

  // All fetch preferences methods

  Future<void> fetchAppLockPreferences() async {
    var auth = LocalAuthentication();
    try {
      appLockIsAvailable = await auth.isDeviceSupported();
    } catch (e) {
      // Platform doesn't support biometric authentication (e.g., Linux desktop)
      appLockIsAvailable = false;
    }
    enableAppLock = PreferencesUtils.getOrDefault<bool>(
        prefs, PreferencesKeys.enableAppLock)!;
  }

  Future<void> fetchThemePreferences() async {
    // Get theme color
    int themeColorIndex =
        PreferencesUtils.getOrDefault<int>(prefs, PreferencesKeys.themeColor)!;

    themeColorDropdownKey = getKeyFromObject<int>(
        PreferencesOptions.themeColorDropdown, themeColorIndex);

    // Get theme style
    int themeStyleIndex =
        PreferencesUtils.getOrDefault<int>(prefs, PreferencesKeys.themeMode)!;

    themeStyleDropdownKey = getKeyFromObject<int>(
        PreferencesOptions.themeStyleDropdown, themeStyleIndex);
  }

  Future<void> fetchLanguagePreferences() async {
    var userDefinedLanguageLocale = PreferencesUtils.getOrDefault<String?>(
        prefs, PreferencesKeys.languageLocale);

    languageDropdownKey = getKeyFromObject<String>(
        PreferencesOptions.languageDropdown, userDefinedLanguageLocale);
  }

  Future<void> fetchWeekSettingsPreferences() async {
    int firstDayOfWeekValue = PreferencesUtils.getOrDefault<int>(
        prefs, PreferencesKeys.firstDayOfWeek)!;

    firstDayOfWeekDropdownKey = getKeyFromObject<int>(
        PreferencesOptions.firstDayOfWeekDropdown, firstDayOfWeekValue);
  }

  Future<void> fetchDateFormatPreferences() async {
    String dateFormatValue = PreferencesUtils.getOrDefault<String>(
        prefs, PreferencesKeys.dateFormat)!;

    dateFormatDropdownKey = getKeyFromObject<String>(
        PreferencesOptions.dateFormatDropdown, dateFormatValue);
  }

  Future<void> fetchNumberFormattingPreferences() async {
    // Get Number of decimal digits
    decimalDigitsValueDropdownKey = PreferencesUtils.getOrDefault<int>(
            prefs, PreferencesKeys.numberDecimalDigits)
        .toString();

    // Decimal separator
    var usedDefinedDecimalSeparatorValue =
        PreferencesUtils.getOrDefault<String>(
            prefs, PreferencesKeys.decimalSeparator);

    decimalSeparatorDropdownKey = getKeyFromObject<String>(
        PreferencesOptions.decimalSeparators, usedDefinedDecimalSeparatorValue);

    // Grouping separator
    String usedDefinedGroupSeparatorValue =
        PreferencesUtils.getOrDefault<String>(
            prefs, PreferencesKeys.groupSeparator)!;

    if (!PreferencesOptions.groupSeparators
        .containsValue(usedDefinedGroupSeparatorValue)) {
      // Handle unsupported locales (e.g., Persian)
      PreferencesOptions.groupSeparators[usedDefinedGroupSeparatorValue] =
          usedDefinedGroupSeparatorValue;
    }

    groupSeparatorDropdownKey = getKeyFromObject<String>(
        PreferencesOptions.groupSeparators, usedDefinedGroupSeparatorValue);

    allowedGroupSeparatorsValues = Map.from(PreferencesOptions.groupSeparators);
    allowedGroupSeparatorsValues.remove(decimalSeparatorDropdownKey);

    // Overwrite dot
    overwriteDotValueWithComma = PreferencesUtils.getOrDefault<bool>(
        prefs, PreferencesKeys.overwriteDotValueWithComma)!;

    // Overwrite comma
    overwriteCommaValueWithDot = PreferencesUtils.getOrDefault<bool>(
        prefs, PreferencesKeys.overwriteCommaValueWithDot)!;
  }

  Future<void> fetchHomepagePreferences() async {
    // Homepage time interval
    var userDefinedHomepageIntervalEnumIndex =
        PreferencesUtils.getOrDefault<int>(
            prefs, PreferencesKeys.homepageTimeInterval)!;

    homepageTimeIntervalValue = getKeyFromObject<int>(
        PreferencesOptions.homepageTimeInterval,
        userDefinedHomepageIntervalEnumIndex);

    var homepageRecordsMonthStartDayIndex = PreferencesUtils.getOrDefault<int>(
        prefs, PreferencesKeys.homepageRecordsMonthStartDay)!;

    homepageRecordsMonthStartDay = getKeyFromObject<int>(
        PreferencesOptions.monthDaysMap,
        homepageRecordsMonthStartDayIndex);

    // Homepage overview widget
    var userDefinedHomepageOverviewIntervalEnumIndex =
        PreferencesUtils.getOrDefault<int>(
            prefs, PreferencesKeys.homepageOverviewWidgetTimeInterval)!;

    homepageOverviewWidgetTimeInterval = getKeyFromObject<int>(
        PreferencesOptions.homepageOverviewWidgetTimeInterval,
        userDefinedHomepageOverviewIntervalEnumIndex);

    // Note visible
    var noteVisibleIndex = PreferencesUtils.getOrDefault<int>(
        prefs, PreferencesKeys.homepageRecordNotesVisible)!;

    homepageRecordNotesVisible = getKeyFromObject<int>(
        PreferencesOptions.showNotesOnHomepage, noteVisibleIndex);
  }

  Future<void> fetchMiscPreferences() async {
    // Record's name suggestions
    enableRecordNameSuggestions = PreferencesUtils.getOrDefault<bool>(
        prefs, PreferencesKeys.enableRecordNameSuggestions)!;

    // Amount input keyboard type
    var amountInputKeyboardTypeIndex = PreferencesUtils.getOrDefault<int>(
        prefs, PreferencesKeys.amountInputKeyboardType)!;

    amountInputKeyboardTypeDropdownKey = getKeyFromObject<int>(
        PreferencesOptions.amountInputKeyboardType,
        amountInputKeyboardTypeIndex);
  }

  Future<void> fetchStatisticsPreferences() async {
    statisticsPieChartUseCategoryColors = PreferencesUtils.getOrDefault<bool>(
        prefs, PreferencesKeys.statisticsPieChartUseCategoryColors)!;

    var numberOfCategoriesToDisplayIndex = PreferencesUtils.getOrDefault<int>(
        prefs, PreferencesKeys.statisticsPieChartNumberOfCategoriesToDisplay)!;

    statisticsPieChartNumberOfCategoriesToDisplay = getKeyFromObject<int>(
        PreferencesOptions.numberOfCategoriesForPieChart,
        numberOfCategoriesToDisplayIndex);
  }

  // Style dropdown
  late String themeStyleDropdownKey;

  // Theme color
  late String themeColorDropdownKey;

  // Language
  late String languageDropdownKey;

  // Week settings
  late String firstDayOfWeekDropdownKey;
  late String dateFormatDropdownKey;

  // Homepage
  late String homepageTimeIntervalValue;
  late String homepageOverviewWidgetTimeInterval;
  late String homepageRecordNotesVisible;
  late String homepageRecordsMonthStartDay;

  // Number formatting
  late String decimalDigitsValueDropdownKey;
  late String decimalSeparatorDropdownKey;
  late bool overwriteDotValueWithComma;
  late bool overwriteCommaValueWithDot;
  late bool enableRecordNameSuggestions;
  late String amountInputKeyboardTypeDropdownKey;
  late Map<String, String> allowedGroupSeparatorsValues;
  late String groupSeparatorDropdownKey;

  // Locks
  late bool appLockIsAvailable;
  late bool enableAppLock;

  // Statistics
  late bool statisticsPieChartUseCategoryColors;
  late String statisticsPieChartNumberOfCategoriesToDisplay;

  static void invalidateNumberPatternCache() {
    ServiceConfig.currencyNumberFormat = null;
    ServiceConfig.currencyNumberFormatWithoutGrouping = null;
  }

  static void invalidateOverwritePreferences() async {
    if (ServiceConfig.sharedPreferences!
        .containsKey(PreferencesKeys.overwriteDotValueWithComma)) {
      await ServiceConfig.sharedPreferences
          ?.remove(PreferencesKeys.overwriteDotValueWithComma);
    }
    if (ServiceConfig.sharedPreferences!
        .containsKey(PreferencesKeys.overwriteCommaValueWithDot)) {
      await ServiceConfig.sharedPreferences
          ?.remove(PreferencesKeys.overwriteCommaValueWithDot);
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
                    SettingSeparator(title: "Localization".i18n),
                    DropdownCustomizationItem(
                      title: "Language".i18n,
                      subtitle: "Select the app language".i18n +
                          " - " +
                          "Require App restart".i18n,
                      dropdownValues: PreferencesOptions.languageDropdown,
                      selectedDropdownKey: languageDropdownKey,
                      sharedConfigKey: PreferencesKeys.languageLocale,
                    ),
                    DropdownCustomizationItem(
                      title: "First Day of Week".i18n,
                      subtitle: "Select the first day of the week".i18n,
                      dropdownValues: PreferencesOptions.firstDayOfWeekDropdown,
                      selectedDropdownKey: firstDayOfWeekDropdownKey,
                      sharedConfigKey: PreferencesKeys.firstDayOfWeek,
                    ),
                    DropdownCustomizationItem(
                      title: "Date Format".i18n,
                      subtitle: "Select the date format".i18n,
                      dropdownValues: PreferencesOptions.dateFormatDropdown,
                      selectedDropdownKey: dateFormatDropdownKey,
                      sharedConfigKey: PreferencesKeys.dateFormat,
                      onChanged: () {
                        // Invalidate/refresh date format cache if any
                      },
                    ),
                    SettingSeparator(title: "Appearance".i18n),
                    DropdownCustomizationItem(
                      title: "Colors".i18n,
                      subtitle: "Select the app theme color".i18n +
                          " - " +
                          "Require App restart".i18n,
                      dropdownValues: PreferencesOptions.themeColorDropdown,
                      selectedDropdownKey: themeColorDropdownKey,
                      sharedConfigKey: PreferencesKeys.themeColor,
                    ),
                    DropdownCustomizationItem(
                      title: "Theme style".i18n,
                      subtitle: "Select the app theme style".i18n +
                          " - " +
                          "Require App restart".i18n,
                      dropdownValues: PreferencesOptions.themeStyleDropdown,
                      selectedDropdownKey: themeStyleDropdownKey,
                      sharedConfigKey: PreferencesKeys.themeMode,
                    ),
                    SettingSeparator(title: "Number & Formatting".i18n),
                    DropdownCustomizationItem(
                      title: "Decimal digits".i18n,
                      subtitle: "Select the number of decimal digits".i18n,
                      dropdownValues: PreferencesOptions.decimalDigits,
                      selectedDropdownKey: decimalDigitsValueDropdownKey,
                      sharedConfigKey: PreferencesKeys.numberDecimalDigits,
                      onChanged: () {
                        invalidateNumberPatternCache();
                      },
                    ),
                    DropdownCustomizationItem(
                        title: "Decimal separator".i18n,
                        subtitle: "Select the decimal separator".i18n,
                        dropdownValues: PreferencesOptions.decimalSeparators,
                        selectedDropdownKey: decimalSeparatorDropdownKey,
                        sharedConfigKey: PreferencesKeys.decimalSeparator,
                        onChanged: () {
                          invalidateNumberPatternCache();
                          invalidateOverwritePreferences();
                          fetchNumberFormattingPreferences();
                          setState(() {
                            if (decimalSeparatorDropdownKey ==
                                groupSeparatorDropdownKey) {
                              // Inconsistency, disable group separator
                              prefs.setString(
                                  PreferencesKeys.groupSeparator, "");
                            }
                            fetchNumberFormattingPreferences();
                          });
                        }),
                    DropdownCustomizationItem(
                      title: "Grouping separator".i18n,
                      subtitle: "Select the grouping separator".i18n,
                      dropdownValues: allowedGroupSeparatorsValues,
                      selectedDropdownKey: groupSeparatorDropdownKey,
                      sharedConfigKey: PreferencesKeys.groupSeparator,
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
                        sharedConfigKey:
                            PreferencesKeys.overwriteDotValueWithComma,
                      ),
                    ),
                    Visibility(
                      visible: getDecimalSeparator() == ".",
                      child: SwitchCustomizationItem(
                        title: "Overwrite the key `comma`".i18n,
                        subtitle:
                            "When typing `comma`, it types `dot` instead".i18n,
                        switchValue: overwriteCommaValueWithDot,
                        sharedConfigKey:
                            PreferencesKeys.overwriteCommaValueWithDot,
                      ),
                    ),
                    SettingSeparator(title: "Homepage settings".i18n),
                    DropdownCustomizationItem(
                      title: "Homepage time interval".i18n,
                      subtitle:
                          "Define the records to show in the app homepage".i18n,
                      dropdownValues: PreferencesOptions.homepageTimeInterval,
                      selectedDropdownKey: homepageTimeIntervalValue,
                      sharedConfigKey: PreferencesKeys.homepageTimeInterval,
                    ),
                    DropdownCustomizationItem(
                      title: "Custom starting day of the month".i18n,
                      subtitle:
                      "Define the starting day of the month for records that show in the app homepage".i18n,
                      dropdownValues: PreferencesOptions.monthDaysMap,
                      selectedDropdownKey: homepageRecordsMonthStartDay,
                      sharedConfigKey: PreferencesKeys.homepageRecordsMonthStartDay,
                    ),
                    DropdownCustomizationItem(
                      title:
                          "What should the 'Overview widget' summarize?".i18n,
                      subtitle: "Define what to summarize".i18n,
                      dropdownValues:
                          PreferencesOptions.homepageOverviewWidgetTimeInterval,
                      selectedDropdownKey: homepageOverviewWidgetTimeInterval,
                      sharedConfigKey:
                          PreferencesKeys.homepageOverviewWidgetTimeInterval,
                    ),
                    DropdownCustomizationItem(
                      title: "Show records' notes on the homepage".i18n,
                      subtitle: "Number of rows to display".i18n,
                      dropdownValues: PreferencesOptions.showNotesOnHomepage,
                      selectedDropdownKey: homepageRecordNotesVisible,
                      sharedConfigKey:
                          PreferencesKeys.homepageRecordNotesVisible,
                    ),
                    SwitchCustomizationItem(
                      title: "Visualise tags in the main page".i18n,
                      subtitle: "Show or hide tags in the record list".i18n,
                      switchValue: PreferencesUtils.getOrDefault<bool>(
                          prefs, PreferencesKeys.visualiseTagsInMainPage)!,
                      sharedConfigKey: PreferencesKeys.visualiseTagsInMainPage,
                    ),
                    SwitchCustomizationItem(
                      title: "Show future recurrent records".i18n,
                      subtitle:
                      "Generate and display upcoming recurrent records (they will be included in statistics)"
                          .i18n,
                      switchValue: PreferencesUtils.getOrDefault<bool>(
                          prefs, PreferencesKeys.showFutureRecords)!,
                      sharedConfigKey: PreferencesKeys.showFutureRecords,
                    ),
                    SettingSeparator(title: "Statistics".i18n),
                    DropdownCustomizationItem(
                      title: "Number of categories/tags in Pie Chart".i18n,
                      subtitle: "How many categories/tags to be displayed".i18n,
                      dropdownValues:
                          PreferencesOptions.numberOfCategoriesForPieChart,
                      selectedDropdownKey:
                          statisticsPieChartNumberOfCategoriesToDisplay,
                      sharedConfigKey: PreferencesKeys
                          .statisticsPieChartNumberOfCategoriesToDisplay,
                    ),
                    SwitchCustomizationItem(
                      title: "Use Category Colors in Pie Chart".i18n,
                      subtitle:
                          "Show categories with their own colors instead of the default palette"
                              .i18n,
                      switchValue: statisticsPieChartUseCategoryColors,
                      sharedConfigKey:
                          PreferencesKeys.statisticsPieChartUseCategoryColors,
                    ),
                    SettingSeparator(title: "Additional Settings".i18n),
                    DropdownCustomizationItem(
                      title: "Amount input keyboard type".i18n,
                      subtitle:
                          "Select the keyboard layout for amount input".i18n,
                      dropdownValues:
                          PreferencesOptions.amountInputKeyboardType,
                      selectedDropdownKey: amountInputKeyboardTypeDropdownKey,
                      sharedConfigKey:
                          PreferencesKeys.amountInputKeyboardType,
                    ),
                    SwitchCustomizationItem(
                      title: "Enable record's name suggestions".i18n,
                      subtitle:
                          "If enabled, you get suggestions when typing the record's name"
                              .i18n,
                      switchValue: enableRecordNameSuggestions,
                      sharedConfigKey:
                          PreferencesKeys.enableRecordNameSuggestions,
                    ),
                    Visibility(
                      visible: appLockIsAvailable,
                      child: SwitchCustomizationItem(
                        title: "Protect access to the app".i18n,
                        subtitle:
                            "App protected by PIN or biometric check".i18n,
                        switchValue: enableAppLock,
                        sharedConfigKey: PreferencesKeys.enableAppLock,
                        proLabel: !ServiceConfig.isPremium,
                        enabled: ServiceConfig.isPremium,
                      ),
                    ),
                    const Divider(thickness: 1.5),
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
