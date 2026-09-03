import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:piggybank/main.dart';
import 'package:piggybank/i18n.dart';
import 'package:piggybank/premium/splash-screen.dart';
import 'package:piggybank/premium/util-widgets.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/services/locale-service.dart';
import 'package:piggybank/wallets/customize-transfer-icon-page.dart';
import 'package:piggybank/settings/components/setting-separator.dart';
import 'package:piggybank/settings/constants/preferences-keys.dart';
import 'package:piggybank/settings/constants/preferences-options.dart';
import 'package:piggybank/settings/monthly-banner-page.dart';
import 'package:piggybank/settings/preferences-utils.dart';
import 'package:piggybank/settings/style.dart';
import 'package:piggybank/settings/switch-customization-item.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/records-utility-functions.dart';
import 'dropdown-customization-item.dart';

class _CustomizationOption {
  final String section;
  final String title;
  final String subtitle;
  final Widget Function() builder;

  _CustomizationOption({
    required this.section,
    required this.title,
    required this.subtitle,
    required this.builder,
  });
}

class CustomizationPage extends StatefulWidget {
  @override
  CustomizationPageState createState() => CustomizationPageState();
}

class CustomizationPageState extends State<CustomizationPage> {
  late SharedPreferences prefs;
  late Future<void> _preferencesFuture;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ValueNotifier<String> _searchQueryNotifier = ValueNotifier('');

  @override
  void initState() {
    super.initState();
    _preferencesFuture = initializePreferences();
  }

  Widget _buildSearchField(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: _searchQueryNotifier,
      builder: (context, query, _) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            onChanged: (value) => _searchQueryNotifier.value = value,
            decoration: InputDecoration(
              hintText: "Search".i18n,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _searchQueryNotifier.value = '';
                      },
                    ),
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchQueryNotifier.dispose();
    super.dispose();
  }

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
    await fetchCurrencyPreferences();
    await fetchWalletPreferences();
    ServiceConfig.initBudgetsEnabled();
  }

  Future<void> fetchAppLockPreferences() async {
    var auth = LocalAuthentication();
    try {
      appLockIsAvailable = await auth.isDeviceSupported();
    } catch (e) {
      appLockIsAvailable = false;
    }
    enableAppLock = PreferencesUtils.getOrDefault<bool>(
        prefs, PreferencesKeys.enableAppLock)!;
  }

  Future<void> fetchThemePreferences() async {
    int themeColorIndex =
        PreferencesUtils.getOrDefault<int>(prefs, PreferencesKeys.themeColor)!;
    themeColorDropdownKey = getKeyFromObject<int>(
        PreferencesOptions.themeColorDropdown, themeColorIndex);

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
    decimalDigitsValueDropdownKey = PreferencesUtils.getOrDefault<int>(
            prefs, PreferencesKeys.numberDecimalDigits)
        .toString();

    var usedDefinedDecimalSeparatorValue =
        PreferencesUtils.getOrDefault<String>(
            prefs, PreferencesKeys.decimalSeparator);
    decimalSeparatorDropdownKey = getKeyFromObject<String>(
        PreferencesOptions.decimalSeparators, usedDefinedDecimalSeparatorValue);

    String usedDefinedGroupSeparatorValue =
        PreferencesUtils.getOrDefault<String>(
            prefs, PreferencesKeys.groupSeparator)!;
    if (!PreferencesOptions.groupSeparators
        .containsValue(usedDefinedGroupSeparatorValue)) {
      PreferencesOptions.groupSeparators[usedDefinedGroupSeparatorValue] =
          usedDefinedGroupSeparatorValue;
    }
    groupSeparatorDropdownKey = getKeyFromObject<String>(
        PreferencesOptions.groupSeparators, usedDefinedGroupSeparatorValue);

    amountInputAutoDecimalShift = PreferencesUtils.getOrDefault<bool>(
      ServiceConfig.sharedPreferences!,
      PreferencesKeys.amountInputAutoDecimalShift,
    )!;

    allowedGroupSeparatorsValues = Map.from(PreferencesOptions.groupSeparators);
    allowedGroupSeparatorsValues.remove(decimalSeparatorDropdownKey);

    overwriteDotValueWithComma = PreferencesUtils.getOrDefault<bool>(
        prefs, PreferencesKeys.overwriteDotValueWithComma)!;
    overwriteCommaValueWithDot = PreferencesUtils.getOrDefault<bool>(
        prefs, PreferencesKeys.overwriteCommaValueWithDot)!;

    int currencySymbolPositionValue = PreferencesUtils.getOrDefault<int>(
        prefs, PreferencesKeys.currencySymbolPosition)!;
    currencySymbolPositionDropdownKey = getKeyFromObject<int>(
        PreferencesOptions.currencySymbolPosition, currencySymbolPositionValue);

    int currencySymbolSpacingValue = PreferencesUtils.getOrDefault<int>(
        prefs, PreferencesKeys.currencySymbolSpacing)!;
    currencySymbolSpacingDropdownKey = getKeyFromObject<int>(
        PreferencesOptions.currencySymbolSpacing, currencySymbolSpacingValue);
  }

  Future<void> fetchCurrencyPreferences() async {
    showCurrencySymbol = PreferencesUtils.getOrDefault<bool>(
        prefs, PreferencesKeys.showCurrencySymbol)!;
  }

  Future<void> fetchWalletPreferences() async {
    int walletBalanceModeValue = PreferencesUtils.getOrDefault<int>(
        prefs, PreferencesKeys.walletBalanceMode)!;
    walletBalanceModeDropdownKey = getKeyFromObject<int>(
        PreferencesOptions.walletBalanceMode, walletBalanceModeValue);
  }

  Future<void> fetchHomepagePreferences() async {
    var userDefinedHomepageIntervalEnumIndex =
        PreferencesUtils.getOrDefault<int>(
            prefs, PreferencesKeys.homepageTimeInterval)!;
    homepageTimeIntervalValue = getKeyFromObject<int>(
        PreferencesOptions.homepageTimeInterval,
        userDefinedHomepageIntervalEnumIndex);

    var homepageRecordsMonthStartDayIndex = PreferencesUtils.getOrDefault<int>(
        prefs, PreferencesKeys.homepageRecordsMonthStartDay)!;
    homepageRecordsMonthStartDay = getKeyFromObject<int>(
        PreferencesOptions.monthDaysMap, homepageRecordsMonthStartDayIndex);

    var userDefinedHomepageOverviewIntervalEnumIndex =
        PreferencesUtils.getOrDefault<int>(
            prefs, PreferencesKeys.homepageOverviewWidgetTimeInterval)!;
    homepageOverviewWidgetTimeInterval = getKeyFromObject<int>(
        PreferencesOptions.homepageOverviewWidgetTimeInterval,
        userDefinedHomepageOverviewIntervalEnumIndex);

    var noteVisibleIndex = PreferencesUtils.getOrDefault<int>(
        prefs, PreferencesKeys.homepageRecordNotesVisible)!;
    homepageRecordNotesVisible = getKeyFromObject<int>(
        PreferencesOptions.showNotesOnHomepage, noteVisibleIndex);
  }

  Future<void> fetchMiscPreferences() async {
    enableRecordNameSuggestions = PreferencesUtils.getOrDefault<bool>(
        prefs, PreferencesKeys.enableRecordNameSuggestions)!;
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

  late String themeStyleDropdownKey;
  late String themeColorDropdownKey;
  late String languageDropdownKey;
  late String firstDayOfWeekDropdownKey;
  late String dateFormatDropdownKey;
  late String homepageTimeIntervalValue;
  late String homepageOverviewWidgetTimeInterval;
  late String homepageRecordNotesVisible;
  late String homepageRecordsMonthStartDay;
  late String decimalDigitsValueDropdownKey;
  late String decimalSeparatorDropdownKey;
  late bool overwriteDotValueWithComma;
  late bool overwriteCommaValueWithDot;
  late bool enableRecordNameSuggestions;
  late String amountInputKeyboardTypeDropdownKey;
  late Map<String, String> allowedGroupSeparatorsValues;
  late String groupSeparatorDropdownKey;
  late bool amountInputAutoDecimalShift;
  late String currencySymbolPositionDropdownKey;
  late String currencySymbolSpacingDropdownKey;
  late bool showCurrencySymbol;
  late bool appLockIsAvailable;
  late bool enableAppLock;
  late bool statisticsPieChartUseCategoryColors;
  late String statisticsPieChartNumberOfCategoriesToDisplay;
  late String walletBalanceModeDropdownKey;

  static void invalidateNumberPatternCache() {
    ServiceConfig.currencyNumberFormat = null;
    ServiceConfig.currencyNumberFormatWithoutGrouping = null;
    ServiceConfig.perCurrencyNumberFormatCache.clear();
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

  bool _matchesOption(_CustomizationOption option, String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return true;

    return option.title.i18n.toLowerCase().contains(normalizedQuery) ||
        option.subtitle.i18n.toLowerCase().contains(normalizedQuery);
  }

  Widget _buildOptionWidget(_CustomizationOption option) {
    // Keep each setting's state attached to its option while search results
    // appear and disappear.
    return KeyedSubtree(
      key: ValueKey(option.title),
      child: option.builder(),
    );
  }

  List<_CustomizationOption> _buildOptions(BuildContext context) {
    return [
      _CustomizationOption(
        section: "Localization",
        title: "Language",
        subtitle: "Select the app language",
        builder: () => DropdownCustomizationItem(
          title: "Language".i18n,
          subtitle: "Select the app language".i18n,
          dropdownValues: PreferencesOptions.languageDropdown,
          selectedDropdownKey: languageDropdownKey,
          sharedConfigKey: PreferencesKeys.languageLocale,
          onChanged: () {
            MyApp.reloadLocale();
            LocaleService.reloadCurrencyLocale();
          },
        ),
      ),
      _CustomizationOption(
        section: "Localization",
        title: "First Day of Week",
        subtitle: "Select the first day of the week",
        builder: () => DropdownCustomizationItem(
          title: "First Day of Week".i18n,
          subtitle: "Select the first day of the week".i18n,
          dropdownValues: PreferencesOptions.firstDayOfWeekDropdown,
          selectedDropdownKey: firstDayOfWeekDropdownKey,
          sharedConfigKey: PreferencesKeys.firstDayOfWeek,
        ),
      ),
      _CustomizationOption(
        section: "Localization",
        title: "Date Format",
        subtitle: "Select the date format",
        builder: () => DropdownCustomizationItem(
          title: "Date Format".i18n,
          subtitle: "Select the date format".i18n,
          dropdownValues: PreferencesOptions.dateFormatDropdown,
          selectedDropdownKey: dateFormatDropdownKey,
          sharedConfigKey: PreferencesKeys.dateFormat,
          onChanged: () {},
        ),
      ),
      _CustomizationOption(
        section: "Appearance",
        title: "Colors",
        subtitle: "Select the app theme color",
        builder: () => DropdownCustomizationItem(
          title: "Colors".i18n,
          subtitle: "Select the app theme color".i18n,
          dropdownValues: PreferencesOptions.themeColorDropdown,
          selectedDropdownKey: themeColorDropdownKey,
          sharedConfigKey: PreferencesKeys.themeColor,
          onChanged: () => MyApp.reloadTheme(),
        ),
      ),
      _CustomizationOption(
        section: "Appearance",
        title: "Theme style",
        subtitle: "Select the app theme style",
        builder: () => DropdownCustomizationItem(
          title: "Theme style".i18n,
          subtitle: "Select the app theme style".i18n,
          dropdownValues: PreferencesOptions.themeStyleDropdown,
          selectedDropdownKey: themeStyleDropdownKey,
          sharedConfigKey: PreferencesKeys.themeMode,
          onChanged: () => MyApp.reloadTheme(),
        ),
      ),
      _CustomizationOption(
        section: "Appearance",
        title: "Colorize income and expenses",
        subtitle: "Show income in green and expenses in red",
        builder: () => SwitchCustomizationItem(
          title: "Colorize income and expenses".i18n,
          subtitle: "Show income in green and expenses in red".i18n,
          switchValue: PreferencesUtils.getOrDefault<bool>(
              prefs, PreferencesKeys.colorizeAmounts)!,
          sharedConfigKey: PreferencesKeys.colorizeAmounts,
        ),
      ),
      _CustomizationOption(
        section: "Appearance",
        title: "Show homepage image",
        subtitle: "Show the image on the homepage appbar",
        builder: () => SwitchCustomizationItem(
          title: "Show homepage image".i18n,
          subtitle: "Show the image on the homepage appbar".i18n,
          switchValue: PreferencesUtils.getOrDefault<bool>(
              prefs, PreferencesKeys.showHomepageImage)!,
          sharedConfigKey: PreferencesKeys.showHomepageImage,
          onChanged: (value) => ServiceConfig.setShowHomepageImage(value),
        ),
      ),
      _CustomizationOption(
        section: "Appearance",
        title: "Animate navigation bar",
        subtitle: "Play animations when selecting navigation tabs",
        builder: () => SwitchCustomizationItem(
          title: "Animate navigation bar".i18n,
          subtitle: "Play animations when selecting navigation tabs".i18n,
          switchValue: ServiceConfig.navigationBarAnimationsEnabled,
          sharedConfigKey: PreferencesKeys.enableNavigationBarAnimations,
          onChanged: (value) =>
              ServiceConfig.setNavigationBarAnimationsEnabled(value),
        ),
      ),
      _CustomizationOption(
        section: "Appearance",
        title: "Monthly banner",
        subtitle: "Choose a custom image for each month",
        builder: () => ValueListenableBuilder<bool>(
          valueListenable: ServiceConfig.showHomepageImageNotifier,
          builder: (context, showHomepageImage, _) => Stack(
            children: [
              ListTile(
                enabled: showHomepageImage,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ServiceConfig.isPremium
                          ? const MonthlyBannerPage()
                          : PremiumSplashScreen(),
                    ),
                  );
                },
                title: Text("Monthly banner".i18n, style: titleTextStyle),
                subtitle: Text("Choose a custom image for each month".i18n,
                    style: subtitleTextStyle),
                trailing: const Icon(Icons.chevron_right),
              ),
              !ServiceConfig.isPremium
                  ? Positioned(
                      right: 12,
                      top: 8,
                      child: getProLabel(labelFontSize: 10.0),
                    )
                  : const SizedBox.shrink(),
            ],
          ),
        ),
      ),
      _CustomizationOption(
        section: "Privacy".i18n,
        title: "Privacy mode",
        subtitle: "Show the eye button and enable tap-to-hide amounts",
        builder: () => ValueListenableBuilder<bool>(
          valueListenable: ServiceConfig.privacyModeEnabledNotifier,
          builder: (context, armed, _) => SwitchCustomizationItem(
            // Recreate with the fresh value so it never disagrees.
            key: ValueKey('privacyModeEnabled-$armed'),
            title: "Privacy mode".i18n,
            subtitle: "Show the eye button and enable tap-to-hide amounts".i18n,
            switchValue: armed,
            sharedConfigKey: PreferencesKeys.privacyMode,
            onChanged: (value) => ServiceConfig.setPrivacyModeEnabled(value),
          ),
        ),
      ),
      _CustomizationOption(
        section: "Privacy".i18n,
        title: "Start with privacy mode on",
        subtitle: "When on, the app always starts hidden",
        builder: () => SwitchCustomizationItem(
          title: "Start with privacy mode on".i18n,
          subtitle: "When on, the app always starts hidden".i18n,
          switchValue: ServiceConfig.privacyModeOnStart,
          sharedConfigKey: PreferencesKeys.privacyModeOnStart,
          // Only affects future launches; the current session is untouched.
          onChanged: (value) => ServiceConfig.setPrivacyModeOnStart(value),
        ),
      ),
      _CustomizationOption(
        section: "Number & Formatting",
        title: "Decimal digits",
        subtitle: "Select the number of decimal digits",
        builder: () => DropdownCustomizationItem(
          title: "Decimal digits".i18n,
          subtitle: "Select the number of decimal digits".i18n,
          dropdownValues: PreferencesOptions.decimalDigits,
          selectedDropdownKey: decimalDigitsValueDropdownKey,
          sharedConfigKey: PreferencesKeys.numberDecimalDigits,
          onChanged: invalidateNumberPatternCache,
        ),
      ),
      _CustomizationOption(
        section: "Number & Formatting",
        title: "Decimal separator",
        subtitle: "Select the decimal separator",
        builder: () => DropdownCustomizationItem(
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
              if (decimalSeparatorDropdownKey == groupSeparatorDropdownKey) {
                prefs.setString(PreferencesKeys.groupSeparator, "");
              }
              fetchNumberFormattingPreferences();
            });
          },
        ),
      ),
      _CustomizationOption(
        section: "Number & Formatting",
        title: "Grouping separator",
        subtitle: "Select the grouping separator",
        builder: () => DropdownCustomizationItem(
          title: "Grouping separator".i18n,
          subtitle: "Select the grouping separator".i18n,
          dropdownValues: allowedGroupSeparatorsValues,
          selectedDropdownKey: groupSeparatorDropdownKey,
          sharedConfigKey: PreferencesKeys.groupSeparator,
          onChanged: invalidateNumberPatternCache,
        ),
      ),
      _CustomizationOption(
        section: "Number & Formatting",
        title: "Overwrite the key `dot`",
        subtitle: "When typing `dot`, it types `comma` instead",
        builder: () => Visibility(
          visible: getDecimalSeparator() == ",",
          child: SwitchCustomizationItem(
            title: "Overwrite the key `dot`".i18n,
            subtitle: "When typing `dot`, it types `comma` instead".i18n,
            switchValue: overwriteDotValueWithComma,
            sharedConfigKey: PreferencesKeys.overwriteDotValueWithComma,
          ),
        ),
      ),
      _CustomizationOption(
        section: "Number & Formatting",
        title: "Overwrite the key `comma`",
        subtitle: "When typing `comma`, it types `dot` instead",
        builder: () => Visibility(
          visible: getDecimalSeparator() == ".",
          child: SwitchCustomizationItem(
            title: "Overwrite the key `comma`".i18n,
            subtitle: "When typing `comma`, it types `dot` instead".i18n,
            switchValue: overwriteCommaValueWithDot,
            sharedConfigKey: PreferencesKeys.overwriteCommaValueWithDot,
          ),
        ),
      ),
      _CustomizationOption(
        section: "Number & Formatting",
        title: "Auto decimal input",
        subtitle: "Typing 5 becomes %s5",
        builder: () => SwitchCustomizationItem(
          title: "Auto decimal input".i18n,
          subtitle: "Typing 5 becomes %s5".i18n.fill([
            (() {
              final dd = getNumberDecimalDigits();
              if (dd <= 0) return "";
              final sep = getDecimalSeparator();
              return ("0$sep").padRight(dd + 1, '0');
            }())
          ]),
          switchValue: amountInputAutoDecimalShift,
          sharedConfigKey: PreferencesKeys.amountInputAutoDecimalShift,
        ),
      ),
      _CustomizationOption(
        section: "Number & Formatting",
        title: "Currency symbol position",
        subtitle: "Select the position of the currency symbol",
        builder: () => DropdownCustomizationItem(
          title: "Currency symbol position".i18n,
          subtitle: "Select the position of the currency symbol".i18n,
          dropdownValues: PreferencesOptions.currencySymbolPosition,
          selectedDropdownKey: currencySymbolPositionDropdownKey,
          sharedConfigKey: PreferencesKeys.currencySymbolPosition,
          onChanged: invalidateNumberPatternCache,
        ),
      ),
      _CustomizationOption(
        section: "Number & Formatting",
        title: "Currency symbol spacing",
        subtitle: "Add space between symbol and amount",
        builder: () => DropdownCustomizationItem(
          title: "Currency symbol spacing".i18n,
          subtitle: "Add space between symbol and amount".i18n,
          dropdownValues: PreferencesOptions.currencySymbolSpacing,
          selectedDropdownKey: currencySymbolSpacingDropdownKey,
          sharedConfigKey: PreferencesKeys.currencySymbolSpacing,
          onChanged: invalidateNumberPatternCache,
        ),
      ),
      _CustomizationOption(
        section: "Number & Formatting",
        title: "Show currency symbol",
        subtitle: "Display the currency symbol next to amounts",
        builder: () => SwitchCustomizationItem(
          title: "Show currency symbol".i18n,
          subtitle: "Display the currency symbol next to amounts".i18n,
          switchValue: showCurrencySymbol,
          sharedConfigKey: PreferencesKeys.showCurrencySymbol,
        ),
      ),
      _CustomizationOption(
        section: "Homepage settings",
        title: "Homepage time interval",
        subtitle: "Define the records to show in the app homepage",
        builder: () => DropdownCustomizationItem(
          title: "Homepage time interval".i18n,
          subtitle: "Define the records to show in the app homepage".i18n,
          dropdownValues: PreferencesOptions.homepageTimeInterval,
          selectedDropdownKey: homepageTimeIntervalValue,
          sharedConfigKey: PreferencesKeys.homepageTimeInterval,
        ),
      ),
      _CustomizationOption(
        section: "Homepage settings",
        title: "Custom starting day of the month",
        subtitle:
            "Define the starting day of the month for records that show in the app homepage",
        builder: () => DropdownCustomizationItem(
          title: "Custom starting day of the month".i18n,
          subtitle:
              "Define the starting day of the month for records that show in the app homepage"
                  .i18n,
          dropdownValues: PreferencesOptions.monthDaysMap,
          selectedDropdownKey: homepageRecordsMonthStartDay,
          sharedConfigKey: PreferencesKeys.homepageRecordsMonthStartDay,
        ),
      ),
      _CustomizationOption(
        section: "Homepage settings",
        title: "What should the 'Overview widget' summarize?",
        subtitle: "Define what to summarize",
        builder: () => DropdownCustomizationItem(
          title: "What should the 'Overview widget' summarize?".i18n,
          subtitle: "Define what to summarize".i18n,
          dropdownValues: PreferencesOptions.homepageOverviewWidgetTimeInterval,
          selectedDropdownKey: homepageOverviewWidgetTimeInterval,
          sharedConfigKey: PreferencesKeys.homepageOverviewWidgetTimeInterval,
        ),
      ),
      _CustomizationOption(
        section: "Homepage settings",
        title: "Show records' notes on the homepage",
        subtitle: "Number of rows to display",
        builder: () => DropdownCustomizationItem(
          title: "Show records' notes on the homepage".i18n,
          subtitle: "Number of rows to display".i18n,
          dropdownValues: PreferencesOptions.showNotesOnHomepage,
          selectedDropdownKey: homepageRecordNotesVisible,
          sharedConfigKey: PreferencesKeys.homepageRecordNotesVisible,
        ),
      ),
      _CustomizationOption(
        section: "Homepage settings",
        title: "Visualise tags in the main page",
        subtitle: "Show or hide tags in the record list",
        builder: () => SwitchCustomizationItem(
          title: "Visualise tags in the main page".i18n,
          subtitle: "Show or hide tags in the record list".i18n,
          switchValue: PreferencesUtils.getOrDefault<bool>(
              prefs, PreferencesKeys.visualiseTagsInMainPage)!,
          sharedConfigKey: PreferencesKeys.visualiseTagsInMainPage,
        ),
      ),
      _CustomizationOption(
        section: "Homepage settings",
        title: "Show future recurrent records",
        subtitle:
            "Generate and display upcoming recurrent records (they will be included in statistics)",
        builder: () => SwitchCustomizationItem(
          title: "Show future recurrent records".i18n,
          subtitle:
              "Generate and display upcoming recurrent records (they will be included in statistics)"
                  .i18n,
          switchValue: PreferencesUtils.getOrDefault<bool>(
              prefs, PreferencesKeys.showFutureRecords)!,
          sharedConfigKey: PreferencesKeys.showFutureRecords,
        ),
      ),
      _CustomizationOption(
        section: "Homepage settings",
        title: "Categories at the bottom",
        subtitle: "Show expense and income categories at the bottom of the screen",
        builder: () => SwitchCustomizationItem(
          title: "Categories at the bottom".i18n,
          subtitle: "Show expense and income categories at the bottom of the screen".i18n,
          switchValue: PreferencesUtils.getOrDefault<bool>(
              prefs, PreferencesKeys.showCategoriesAtBottom)!,
          sharedConfigKey: PreferencesKeys.showCategoriesAtBottom,
        ),
      ),
      _CustomizationOption(
        section: "Budgets",
        title: "Enable Budgets",
        subtitle: "Show budgets in the navigation bar",
        builder: () => SwitchCustomizationItem(
          title: "Enable Budgets".i18n,
          subtitle: "Show budgets in the navigation bar".i18n,
          switchValue: ServiceConfig.budgetsEnabled,
          onChanged: (value) => ServiceConfig.setBudgetsEnabled(value),
          sharedConfigKey: PreferencesKeys.budgetsEnabled,
        ),
      ),
      _CustomizationOption(
        section: "Wallets",
        title: "Use wallets",
        subtitle: "Show wallets and their balances across the app",
        builder: () => SwitchCustomizationItem(
          title: "Use wallets".i18n,
          subtitle: "Show wallets and their balances across the app".i18n,
          switchValue: ServiceConfig.walletsEnabled,
          onChanged: (value) => ServiceConfig.setWalletsEnabled(value),
          sharedConfigKey: PreferencesKeys.walletsEnabled,
        ),
      ),
      _CustomizationOption(
        section: "Wallets",
        title: "Wallet balance",
        subtitle: "Select how wallet balances are calculated",
        builder: () => ValueListenableBuilder<bool>(
          valueListenable: ServiceConfig.walletsEnabledNotifier,
          builder: (context, walletsEnabled, _) =>
              DropdownCustomizationItem<int>(
            title: "Wallet balance".i18n,
            subtitle: "Select how wallet balances are calculated".i18n,
            dropdownValues: PreferencesOptions.walletBalanceMode,
            selectedDropdownKey: walletBalanceModeDropdownKey,
            sharedConfigKey: PreferencesKeys.walletBalanceMode,
            enabled: walletsEnabled,
          ),
        ),
      ),
      _CustomizationOption(
        section: "Wallets",
        title: "Show wallet bar on the homepage",
        subtitle: "Display the wallet summary bar below the homepage banner",
        builder: () => ValueListenableBuilder<bool>(
          valueListenable: ServiceConfig.walletsEnabledNotifier,
          builder: (context, walletsEnabled, _) => SwitchCustomizationItem(
            title: "Show wallet bar on the homepage".i18n,
            subtitle:
                "Display the wallet summary bar below the homepage banner".i18n,
            switchValue: PreferencesUtils.getOrDefault<bool>(
                prefs, PreferencesKeys.showWalletBarOnHomepage)!,
            sharedConfigKey: PreferencesKeys.showWalletBarOnHomepage,
            enabled: walletsEnabled,
          ),
        ),
      ),
      _CustomizationOption(
        section: "Wallets",
        title: "Visualise wallet name in the main page",
        subtitle: "Show or hide wallet name in the record list",
        builder: () => ValueListenableBuilder<bool>(
          valueListenable: ServiceConfig.walletsEnabledNotifier,
          builder: (context, walletsEnabled, _) => SwitchCustomizationItem(
            title: "Visualise wallet name in the main page".i18n,
            subtitle: "Show or hide wallet name in the record list".i18n,
            switchValue: PreferencesUtils.getOrDefault<bool>(
                prefs, PreferencesKeys.showWalletInRecordList)!,
            sharedConfigKey: PreferencesKeys.showWalletInRecordList,
            enabled: walletsEnabled,
          ),
        ),
      ),
      _CustomizationOption(
        section: "Wallets",
        title: "Restore wallet amount on record deletion",
        subtitle:
            "When deleting a record, add back its amount to the wallet balance",
        builder: () => ValueListenableBuilder<bool>(
          valueListenable: ServiceConfig.walletsEnabledNotifier,
          builder: (context, walletsEnabled, _) => SwitchCustomizationItem(
            title: "Restore wallet amount on record deletion".i18n,
            subtitle:
                "When deleting a record, add back its amount to the wallet balance"
                    .i18n,
            switchValue: PreferencesUtils.getOrDefault<bool>(
                prefs, PreferencesKeys.restoreAmountOnDelete)!,
            sharedConfigKey: PreferencesKeys.restoreAmountOnDelete,
            enabled: walletsEnabled,
          ),
        ),
      ),
      _CustomizationOption(
        section: "Wallets",
        title: "Customize Transfer Icon",
        subtitle: "Change the icon, emoji and color used for transfers",
        builder: () => ValueListenableBuilder<bool>(
          valueListenable: ServiceConfig.walletsEnabledNotifier,
          builder: (context, walletsEnabled, _) => ListTile(
            enabled: walletsEnabled,
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CustomizeTransferIconPage(),
                ),
              );
            },
            title: Text("Customize Transfer Icon".i18n, style: titleTextStyle),
            subtitle: Text(
                "Change the icon, emoji and color used for transfers".i18n,
                style: subtitleTextStyle),
            trailing: const Icon(Icons.chevron_right),
          ),
        ),
      ),
      _CustomizationOption(
        section: "Statistics",
        title: "Number of categories/tags in Pie Chart",
        subtitle: "How many categories/tags to be displayed",
        builder: () => DropdownCustomizationItem(
          title: "Number of categories/tags in Pie Chart".i18n,
          subtitle: "How many categories/tags to be displayed".i18n,
          dropdownValues: PreferencesOptions.numberOfCategoriesForPieChart,
          selectedDropdownKey: statisticsPieChartNumberOfCategoriesToDisplay,
          sharedConfigKey:
              PreferencesKeys.statisticsPieChartNumberOfCategoriesToDisplay,
        ),
      ),
      _CustomizationOption(
        section: "Statistics",
        title: "Use Category Colors in Pie Chart",
        subtitle:
            "Show categories with their own colors instead of the default palette",
        builder: () => SwitchCustomizationItem(
          title: "Use Category Colors in Pie Chart".i18n,
          subtitle:
              "Show categories with their own colors instead of the default palette"
                  .i18n,
          switchValue: statisticsPieChartUseCategoryColors,
          sharedConfigKey: PreferencesKeys.statisticsPieChartUseCategoryColors,
        ),
      ),
      _CustomizationOption(
        section: "Additional Settings",
        title: "Amount input keyboard type",
        subtitle: "Select the keyboard layout for amount input",
        builder: () => DropdownCustomizationItem(
          title: "Amount input keyboard type".i18n,
          subtitle: "Select the keyboard layout for amount input".i18n,
          dropdownValues: PreferencesOptions.amountInputKeyboardType,
          selectedDropdownKey: amountInputKeyboardTypeDropdownKey,
          sharedConfigKey: PreferencesKeys.amountInputKeyboardType,
        ),
      ),
      _CustomizationOption(
        section: "Additional Settings",
        title: "Enable record's name suggestions",
        subtitle:
            "If enabled, you get suggestions when typing the record's name",
        builder: () => SwitchCustomizationItem(
          title: "Enable record's name suggestions".i18n,
          subtitle:
              "If enabled, you get suggestions when typing the record's name"
                  .i18n,
          switchValue: enableRecordNameSuggestions,
          sharedConfigKey: PreferencesKeys.enableRecordNameSuggestions,
        ),
      ),
      _CustomizationOption(
        section: "Additional Settings",
        title: "Protect access to the app",
        subtitle: "App protected by PIN or biometric check",
        builder: () => Visibility(
          visible: appLockIsAvailable,
          child: SwitchCustomizationItem(
            title: "Protect access to the app".i18n,
            subtitle: "App protected by PIN or biometric check".i18n,
            switchValue: enableAppLock,
            sharedConfigKey: PreferencesKeys.enableAppLock,
            proLabel: !ServiceConfig.isPremium,
            enabled: ServiceConfig.isPremium,
          ),
        ),
      ),
      _CustomizationOption(
        section: "Additional Settings",
        title: "Restore all the default configurations",
        subtitle: "",
        builder: () => ListTile(
          onTap: () {
            setState(() {
              prefs.clear();
              fetchAllThePreferences();
            });
          },
          title: Text("Restore all the default configurations".i18n,
              style: titleTextStyle),
        ),
      ),
    ];
  }

  List<Widget> _buildStaticSettings(List<_CustomizationOption> options) {
    final children = <Widget>[];
    String? currentSection;

    for (final option in options) {
      if (option.section != currentSection) {
        currentSection = option.section;
        children.add(SettingSeparator(title: option.section.i18n));
      }
      if (option.title == "Restore all the default configurations") {
        children.add(const Divider(thickness: 1.5));
      }
      children.add(_buildOptionWidget(option));
    }

    return children;
  }

  Widget _buildContent(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: _searchQueryNotifier,
      builder: (context, query, _) {
        final options = _buildOptions(context);
        final children = <Widget>[_buildSearchField(context)];

        if (query.trim().isEmpty) {
          children.addAll(_buildStaticSettings(options));
        } else {
          final filteredOptions =
              options.where((option) => _matchesOption(option, query)).toList();

          if (filteredOptions.isEmpty) {
            children.add(
              Padding(
                padding: const EdgeInsets.all(32),
                child: Center(child: Text("No entries to show.".i18n)),
              ),
            );
          } else {
            children.addAll(
              filteredOptions.map(_buildOptionWidget),
            );
          }
        }

        return ListView(children: children);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Customization".i18n),
      ),
      body: FutureBuilder(
        future: _preferencesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          return _buildContent(context);
        },
      ),
    );
  }
}
