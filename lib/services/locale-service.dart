import 'dart:ui';

import 'package:i18n_extension/i18n_extension.dart';
import 'package:piggybank/helpers/records-utility-functions.dart'; // for getDecimalSeparator, getNumberFormatWithCustomizations
import 'package:piggybank/i18n.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/settings/constants/preferences-keys.dart';
import 'package:piggybank/settings/preferences-utils.dart';

import '../settings/constants/preferences-defaults-values.dart';

class LocaleService {
  static final Locale DEFAULT_LOCALE =
      const Locale.fromSubtags(languageCode: 'en', countryCode: "US");
  static final Locale VENETIAN_LOCALE =
      const Locale.fromSubtags(languageCode: 'vec', countryCode: "IT");
  static final Locale ITALIAN_LOCALE =
      const Locale.fromSubtags(languageCode: 'it');

  static final List<Locale> supportedLocales = [
    DEFAULT_LOCALE,
    const Locale.fromSubtags(languageCode: 'en', countryCode: "GB"),
    ITALIAN_LOCALE,
    const Locale.fromSubtags(languageCode: 'de'),
    const Locale.fromSubtags(languageCode: 'fr'),
    const Locale.fromSubtags(languageCode: 'es'),
    const Locale.fromSubtags(languageCode: 'ar'),
    const Locale.fromSubtags(languageCode: 'ru'),
    const Locale.fromSubtags(languageCode: 'tr'),
    const Locale.fromSubtags(languageCode: 'uk', countryCode: "UA"),
    VENETIAN_LOCALE,
    const Locale.fromSubtags(languageCode: 'zh', countryCode: "CN"),
    const Locale.fromSubtags(languageCode: 'pt', countryCode: "BR"),
    const Locale.fromSubtags(languageCode: 'pt', countryCode: "PT"),
  ];

  /// Returns the list of locales the user has configured on their device,
  /// ordered by preference.
  static List<Locale> getUserPreferredLocales() {
    return PlatformDispatcher.instance.locales;
  }

  static Locale resolveCurrencyLocale() {
    Locale? localeFromUserPreferences = getLocaleFromUserPreferences();
    if (localeFromUserPreferences != null) {
      return localeFromUserPreferences;
    }
    return getUserPreferredLocales().first;
  }

  // Language locale
  static Locale resolveLanguageLocale() {
    Locale? localeFromUserPreferences = getLocaleFromUserPreferences();
    if (localeFromUserPreferences != null) {
      return localeFromUserPreferences;
    }

    // no match from user-preferences, use device locales
    Locale? localeFromDeviceSettings = getLocaleFromDeviceSettings();
    if (localeFromDeviceSettings != null) {
      return localeFromDeviceSettings;
    }

    // still no match, return default
    return DEFAULT_LOCALE;
  }

  static Locale? getLocaleFromUserPreferences() {
    Locale? localeFromUserPreferences = null;

    // Get language locale from preferences
    final userSpecifiedLocaleStr = PreferencesUtils.getOrDefault<String>(
      ServiceConfig.sharedPreferences!,
      PreferencesKeys.languageLocale,
    );

    final defaultLanguageLocale =
        PreferencesDefaultValues.defaultValues[PreferencesKeys.languageLocale];
    if (userSpecifiedLocaleStr != null &&
        userSpecifiedLocaleStr != defaultLanguageLocale) {
      // User has chosen something different via the settings
      localeFromUserPreferences = userSpecifiedLocaleStr.asLocale;

      // Is there something venetian? Use sketchy workaround
      // to replace Italian translations with venetian one
      // set Italian, then.
      if (localeFromUserPreferences == VENETIAN_LOCALE) {
        MyI18n.replaceTranslations(
            ITALIAN_LOCALE.toLanguageTag(), VENETIAN_LOCALE.toLanguageTag());
        localeFromUserPreferences = ITALIAN_LOCALE;
      }

      // validate that it a supported language
      if (!supportedLocales.contains(localeFromUserPreferences)) {
        // try with the language-code only
        localeFromUserPreferences =
            Locale(localeFromUserPreferences.languageCode);
        if (!supportedLocales.contains(localeFromUserPreferences)) {
          // no luck
          localeFromUserPreferences = null;
        }
      }
    }

    return localeFromUserPreferences;
  }

  static Locale? getLocaleFromDeviceSettings() {
    for (final locale in getUserPreferredLocales()) {
      // Exact match
      if (supportedLocales.contains(locale)) {
        return locale;
      }

      // Match by language code
      final matchingLocales = supportedLocales.where(
        (supported) => supported.languageCode == locale.languageCode,
      );

      if (matchingLocales.isNotEmpty) {
        return matchingLocales.first;
      }
    }

    return null;
  }

  static void setCurrencyLocale(Locale toSet) {
    if (!usesWesternArabicNumerals(toSet)) {
      toSet = DEFAULT_LOCALE;
    }

    ServiceConfig.currencyLocale = toSet;
    ServiceConfig.currencyNumberFormat =
        getNumberFormatWithCustomizations(locale: toSet);
    ServiceConfig.currencyNumberFormatWithoutGrouping =
        getNumberFormatWithCustomizations(locale: toSet, turnOffGrouping: true);

    checkForSettingInconsistency(toSet);
  }

  static void checkForSettingInconsistency(Locale toSet) {
    // Custom Group Separator Inconsistency
    bool userDefinedGroupingSeparator = ServiceConfig.sharedPreferences!
        .containsKey(PreferencesKeys.groupSeparator);
    if (userDefinedGroupingSeparator) {
      String groupingSeparatorByTheUser = getGroupingSeparator();
      if (groupingSeparatorByTheUser == getDecimalSeparator()) {
        // It may happen when a custom groupSeparator is set
        // then the app language is changed
        // in this case, reset the user preferences
        ServiceConfig.sharedPreferences?.remove(PreferencesKeys.groupSeparator);
      }
    }

    // Replace dot with comma inconsistency
    bool userDefinedOverwriteDotWithComma = ServiceConfig.sharedPreferences!
        .containsKey(PreferencesKeys.overwriteDotValueWithComma);
    if (userDefinedOverwriteDotWithComma && getDecimalSeparator() != ",") {
      // overwriteDotValueWithComma possible just when decimal separator is ,
      ServiceConfig.sharedPreferences
          ?.remove(PreferencesKeys.overwriteDotValueWithComma);
    }
  }
}
