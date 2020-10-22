import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:i18n_extension/i18n_widget.dart';
import 'package:piggybank/shell.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() => runApp(App());

class App extends StatelessWidget {
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
      // the list of locales that this app has been localized for,
      // i.e., the supported languages
      // by default, only the American English locale would be supported
      supportedLocales: [
        const Locale.fromSubtags(languageCode: 'en', countryCode: 'US'),
        const Locale.fromSubtags(languageCode: 'it', countryCode: 'IT'),
//        const Locale.fromSubtags(languageCode: 'es', countryCode: 'ES'),
//        const Locale.fromSubtags(languageCode: 'fr', countryCode: 'FR'),
//        const Locale.fromSubtags(languageCode: 'de', countryCode: 'DE'),
        // TODO add other locales
        // TODO as of now, the current system locale is used. We should give the user the ability to change language in the settings
      ],
      title: 'Welcome to PiggyBank', // DO NOT LOCALIZE THIS, YOU CAN'T.
      home: I18n(
          // I18n translates strings to the current system locale
          child: Shell()),

      //theme: ThemeData(          // Add the 3 lines from here...
      // primaryColor: Colors.white,
      // ),
    );
  }
}
