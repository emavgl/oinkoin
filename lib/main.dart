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

main() async {
  WidgetsFlutterBinding.ensureInitialized();
  PackageInfo packageInfo = await PackageInfo.fromPlatform();
  ServiceConfig.packageName = packageInfo.packageName;
  ServiceConfig.version = packageInfo.version;
  ServiceConfig.isPremium = packageInfo.packageName.endsWith("pro");
  ServiceConfig.sharedPreferences = await SharedPreferences.getInstance();
  await FlutterDisplayMode.setHighRefreshRate();
  runApp(
    App(
      lightTheme: await MaterialThemeInstance.getLightTheme(),
      darkTheme: await MaterialThemeInstance.getDarkTheme(),
      themeMode: await MaterialThemeInstance.getThemeMode()
    ),
  );
}

class App extends StatelessWidget {
  
  final ThemeData lightTheme;
  final ThemeData darkTheme;
  final ThemeMode themeMode;

  const App({Key? key, required this.lightTheme, required this.darkTheme, required this.themeMode}) : super(key: key);

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

        // If there is no match, returns the first user choice
        // even if not supported. The user will see still the english
        // translations, but will be used for the currency format

        Locale defaultLocale = locales![0];

        for (Locale locale in locales) {
          // match by language code, but returns full locale
          Locale deviceLanguageLocale = Locale.fromSubtags(languageCode: locale.languageCode);
          if (supportedLocales.contains(deviceLanguageLocale)) {
            return locale;
          }
        }

        return defaultLocale;
      },
      supportedLocales: [
        const Locale.fromSubtags(languageCode: 'en'),
        const Locale.fromSubtags(languageCode: 'it'),
        const Locale.fromSubtags(languageCode: 'de'),
      ],
      title: "Oinkoin", // DO NOT LOCALIZE THIS, YOU CAN'T.
      home: I18n(
          // I18n translates strings to the current system locale
          child: Shell()),
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeMode,
    );
  }
}
