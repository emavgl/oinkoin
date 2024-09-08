import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:i18n_extension/i18n_extension.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/shell.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:piggybank/style.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/records-utility-functions.dart';
import 'i18n.dart';

main() async {
  DartPluginRegistrant.ensureInitialized();
  WidgetsFlutterBinding.ensureInitialized();
  PackageInfo packageInfo = await PackageInfo.fromPlatform();
  ServiceConfig.packageName = packageInfo.packageName;
  ServiceConfig.version = packageInfo.version;
  ServiceConfig.isPremium = packageInfo.packageName.endsWith("pro");
  ServiceConfig.sharedPreferences = await SharedPreferences.getInstance();
  await MyI18n.loadTranslations();
  await FlutterDisplayMode.setHighRefreshRate();
  runApp(
    OinkoinApp(
        lightTheme: await MaterialThemeInstance.getLightTheme(),
        darkTheme: await MaterialThemeInstance.getDarkTheme(),
        themeMode: await MaterialThemeInstance.getThemeMode()),
  );
}

class OinkoinApp extends StatefulWidget {
  final ThemeData lightTheme;
  final ThemeData darkTheme;
  final ThemeMode themeMode;

  OinkoinApp(
      {Key? key,
      required this.lightTheme,
      required this.darkTheme,
      required this.themeMode})
      : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return OinkoinAppState();
  }
}

class OinkoinAppState extends State<OinkoinApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        debugShowCheckedModeBanner: false,
        // these are the app-specific localization delegates that collectively
        // define the localized resources for this application's Localizations widget
        localizationsDelegates: [
          DefaultMaterialLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations
              .delegate, // defines the default text direction, either left-to-right or right-to-left, for the widgets library
          GlobalCupertinoLocalizations.delegate, // for IoS
          DefaultCupertinoLocalizations.delegate
        ],
        localeListResolutionCallback: (locales, supportedLocales) {
          print('device locales=$locales supported locales=$supportedLocales');

          // Returns the first user choice
          // even if not supported. The user will still the english
          // translations, but it will be used for the currency format

          Locale deviceLocale = locales![0];
          Locale attemptedLocale = deviceLocale; // Get device locale

          // Check if user specified a locale
          var userSpecifiedLocale =
              ServiceConfig.sharedPreferences?.getString("languageLocale");
          if (userSpecifiedLocale != null && userSpecifiedLocale != "system") {
            var split = userSpecifiedLocale.split("_");
            if (split.length == 2) {
              attemptedLocale = Locale.fromSubtags(
                  languageCode: split[0], countryCode: split[1]);
            } else if (split.length == 1) {
              attemptedLocale = Locale.fromSubtags(languageCode: split[0]);
            }
          }

          // Is there a currency locale for this? Probably it is a strange
          // localization, for example, venetian. Take this workaround:
          // replace the device locale translations with the attempted one
          // (venetian).
          if (attemptedLocale.toString() == "vec_IT") {
            String localeToReplace = attemptedLocale.toString();
            String supportedDeviceLocale =
                getEffectiveLocaleGivenTheDeviceLocale(
                    supportedLocales, deviceLocale.toString());
            MyI18n.replaceTranslations(supportedDeviceLocale, localeToReplace);
            attemptedLocale = deviceLocale;
          }

          setCurrencyLocale(attemptedLocale);

          return attemptedLocale;
        },
        supportedLocales: [
          const Locale.fromSubtags(languageCode: 'en', countryCode: "US"),
          const Locale.fromSubtags(languageCode: 'en', countryCode: "GB"),
          const Locale.fromSubtags(languageCode: 'it'),
          const Locale.fromSubtags(languageCode: 'de'),
          const Locale.fromSubtags(languageCode: 'fr'),
          const Locale.fromSubtags(languageCode: 'es'),
          const Locale.fromSubtags(languageCode: 'ar'),
          const Locale.fromSubtags(languageCode: 'ru'),
          const Locale.fromSubtags(languageCode: 'tr'),
          const Locale.fromSubtags(languageCode: 'vec', countryCode: "IT"),
          const Locale.fromSubtags(languageCode: 'zh', countryCode: "CN"),
          const Locale.fromSubtags(languageCode: 'pt', countryCode: "BR"),
          const Locale.fromSubtags(languageCode: 'pt', countryCode: "PT")
        ],
        theme: widget.lightTheme,
        darkTheme: widget.darkTheme,
        themeMode: widget.themeMode,
        title: "Oinkoin", // DO NOT LOCALIZE THIS, YOU CAN'T.
        home: I18n(
          child: Shell(),
        ));
  }

  String getEffectiveLocaleGivenTheDeviceLocale(
      Iterable<Locale> supportedLocales, String deviceLocale) {
    var split = deviceLocale.split("_");
    if (split.length == 2) {
      Locale l =
          Locale.fromSubtags(languageCode: split[0], countryCode: split[1]);
      if (supportedLocales.contains(l)) {
        return l.toString();
      }
      l = Locale.fromSubtags(languageCode: split[0]);
      if (supportedLocales.contains(l)) {
        return l.toString();
      }
    } else if (split.length == 1) {
      Locale l = Locale.fromSubtags(languageCode: split[0]);
      if (supportedLocales.contains(l)) {
        return l.toString();
      }
    }
    return "en";
  }

  void setCurrencyLocale(Locale toSet) {
    if (!usesWesternArabicNumerals(toSet)) {
      toSet = Locale.fromSubtags(languageCode: 'en', countryCode: "US");
    }
    ServiceConfig.currencyLocale = toSet;
    ServiceConfig.currencyNumberFormat =
        getNumberFormatWithCustomizations(locale: toSet);
    ServiceConfig.currencyNumberFormatWithoutGrouping =
        getNumberFormatWithCustomizations(locale: toSet, turnOffGrouping: true);
    checkForSettingInconsistency(toSet);
  }

  void checkForSettingInconsistency(Locale toSet) {
    // Custom Group Separator Inconsistency
    bool userDefinedGroupingSeparator =
        ServiceConfig.sharedPreferences!.containsKey("groupSeparator");
    if (userDefinedGroupingSeparator) {
      String groupingSeparatorByTheUser = getGroupingSeparator();
      if (groupingSeparatorByTheUser == getDecimalSeparator()) {
        // It may happen when a custom groupSeparator is set
        // then the app language is changed
        // in this case, reset the user preferences
        ServiceConfig.sharedPreferences?.remove("groupSeparator");
      }
    }

    // Replace dot with comma inconsistency
    bool userDefinedOverwriteDotWithComma = ServiceConfig.sharedPreferences!
        .containsKey("overwriteDotValueWithComma");
    if (userDefinedOverwriteDotWithComma && getDecimalSeparator() != ",") {
      // overwriteDotValueWithComma possible just when decimal separator is ,
      ServiceConfig.sharedPreferences?.remove("overwriteDotValueWithComma");
    }
  }
}
