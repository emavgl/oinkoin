import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:i18n_extension/i18n_widget.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/shell.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:piggybank/style.dart';

main() async {
  WidgetsFlutterBinding.ensureInitialized();
  PackageInfo packageInfo = await PackageInfo.fromPlatform();
  ServiceConfig.isPremium = packageInfo.packageName.endsWith("pro");
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
        for (Locale locale in locales!) {
          // if device language is supported by the app,
          // just return it to set it as current app language
          if (supportedLocales.contains(locale)) {
            return locale;
          }
        }
        // if device language is not supported by the app, returns english
        return Locale('en', 'US');
      },
      locale: Locale('en', 'US'),
      supportedLocales: [
        const Locale.fromSubtags(languageCode: 'en', countryCode: 'US'),
        const Locale.fromSubtags(languageCode: 'it', countryCode: 'IT'),
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
