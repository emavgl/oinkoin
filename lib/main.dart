import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:i18n_extension/i18n_widget.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/shell.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:piggybank/style.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/records-utility-functions.dart';
import 'i18n.dart';

main() async {
  WidgetsFlutterBinding.ensureInitialized();
  PackageInfo packageInfo = await PackageInfo.fromPlatform();
  ServiceConfig.packageName = packageInfo.packageName;
  ServiceConfig.version = packageInfo.version;
  ServiceConfig.isPremium = packageInfo.packageName.endsWith("pro");
  ServiceConfig.sharedPreferences = await SharedPreferences.getInstance();
  await FlutterDisplayMode.setHighRefreshRate();
  runApp(
    OinkoinApp(
      lightTheme: await MaterialThemeInstance.getLightTheme(),
      darkTheme: await MaterialThemeInstance.getDarkTheme(),
      themeMode: await MaterialThemeInstance.getThemeMode()
    ),
  );
}

class OinkoinApp extends StatefulWidget {

  final ThemeData lightTheme;
  final ThemeData darkTheme;
  final ThemeMode themeMode;

  OinkoinApp({Key? key, required this.lightTheme, required this.darkTheme, required this.themeMode}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return OinkoinAppState();
  }
}

class OinkoinAppState extends State<OinkoinApp> {

  Future<void>? loadAsync;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        debugShowCheckedModeBanner: false,
        // these are the app-specific localization delegates that collectively
        // define the localized resources for this application's Localizations widget
        localizationsDelegates: [
          DefaultMaterialLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,    // defines the default text direction, either left-to-right or right-to-left, for the widgets library
          GlobalCupertinoLocalizations.delegate,  // for IoS
          DefaultCupertinoLocalizations.delegate
        ],
        localeListResolutionCallback: (locales, supportedLocales) {
          print('device locales=$locales supported locales=$supportedLocales');

          // Returns the first user choice
          // even if not supported. The user will still the english
          // translations, but it will be used for the currency format

          Locale attemptedLocale = locales![0];
          setCurrencyLocale(attemptedLocale);

          return attemptedLocale;
        },
        supportedLocales: [
          const Locale.fromSubtags(languageCode: 'en'),
          const Locale.fromSubtags(languageCode: 'it'),
          const Locale.fromSubtags(languageCode: 'de'),
          const Locale.fromSubtags(languageCode: 'fr'),
          const Locale.fromSubtags(languageCode: 'es'),
          const Locale.fromSubtags(languageCode: 'ar'),
          const Locale.fromSubtags(languageCode: 'ru'),
          const Locale.fromSubtags(languageCode: 'zh', countryCode: "CN"),
          const Locale.fromSubtags(languageCode: 'pt', countryCode: "BR"),
          const Locale.fromSubtags(languageCode: 'pt', countryCode: "PT")
        ],
        theme: widget.lightTheme,
        darkTheme: widget.darkTheme,
        themeMode: widget.themeMode,
        title: "Oinkoin", // DO NOT LOCALIZE THIS, YOU CAN'T.
        home: FutureBuilder(
          future: loadAsync,
          builder: (BuildContext context, AsyncSnapshot<void> snapshot) {
            if (snapshot.connectionState == ConnectionState.done)
              return I18n(
                child: Shell(),
              );
            return Container();
          },
        )
    );
  }

  @override
  void initState() {
    super.initState();
    loadAsync = MyI18n.loadTranslations();
  }

  void setCurrencyLocale(Locale toSet) {
    if (!usesWesternArabicNumerals(toSet)) {
      toSet = Locale.fromSubtags(languageCode: 'en', countryCode: "US");
    }
    checkForSettingInconsistency(toSet);
    ServiceConfig.currencyLocale = toSet;
  }

  void checkForSettingInconsistency(Locale toSet) {
    // Custom Group Separator Inconsistency
    bool userDefinedGroupingSeparator = ServiceConfig.sharedPreferences!.containsKey("groupSeparator");
    if (userDefinedGroupingSeparator) {
      String groupingSeparatorByTheUser = getUserDefinedGroupingSeparator()!;
      if (groupingSeparatorByTheUser == getLocaleDecimalSeparator()) {
        // It may happen when a custom groupSeparator is set
        // then the app language is changed
        // in this case, reset the user preferences
        ServiceConfig.sharedPreferences?.remove("groupSeparator");
      }
    }
    
    // Replace dot with comma inconsistency
    bool userDefinedOverwriteDotWithComma =
      ServiceConfig.sharedPreferences!.containsKey("overwriteDotValueWithComma");
    if (userDefinedOverwriteDotWithComma && getLocaleDecimalSeparator() != ",") {
      // overwriteDotValueWithComma possible just when decimal separator is ,
      ServiceConfig.sharedPreferences?.remove("overwriteDotValueWithComma");
    }
  }
}
