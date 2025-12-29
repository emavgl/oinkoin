import 'dart:io';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:i18n_extension/i18n_extension.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:piggybank/services/locale-service.dart';
import 'package:piggybank/services/logger.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/shell.dart';
import 'package:piggybank/style.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;

import 'i18n.dart';

final logger = Logger.withContext("main");

main() async {
  DartPluginRegistrant.ensureInitialized();
  WidgetsFlutterBinding.ensureInitialized();

  logger.info('App initialization started');

  try {
    tz_data.initializeTimeZones();
    ServiceConfig.localTimezone = await FlutterTimezone.getLocalTimezone();
    logger.info('Timezone initialized: ${ServiceConfig.localTimezone}');

    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    ServiceConfig.packageName = packageInfo.packageName;
    ServiceConfig.version = packageInfo.version;
    ServiceConfig.isPremium = packageInfo.packageName.endsWith("pro");
    logger.info('Package: ${ServiceConfig.packageName} v${ServiceConfig.version} (Premium: ${ServiceConfig.isPremium})');

    ServiceConfig.sharedPreferences = await SharedPreferences.getInstance();
    await MyI18n.loadTranslations();
    if (Platform.isAndroid) await FlutterDisplayMode.setHighRefreshRate();

    final languageLocale = LocaleService.resolveLanguageLocale();
    final currencyLocale = LocaleService.resolveCurrencyLocale();
    LocaleService.setCurrencyLocale(currencyLocale);
    logger.info('Locale configured: language=$languageLocale, currency=$currencyLocale');

    final lightTheme = await MaterialThemeInstance.getLightTheme();
    final darkTheme = await MaterialThemeInstance.getDarkTheme();
    final themeMode = await MaterialThemeInstance.getThemeMode();
    logger.info('Theme loaded: $themeMode');

    logger.info('App initialization completed successfully');

    runApp(
      TalkerWrapper(
        talker: globalTalker,
        child: MyApp(
          languageLocale: languageLocale,
          lightTheme: lightTheme,
          darkTheme: darkTheme,
          themeMode: themeMode,
        ),
      ),
    );
  } catch (e, st) {
    logger.handle(e, st, 'Critical error during app initialization');
    rethrow;
  }
}

class MyApp extends StatelessWidget {
  // Declare languageLocale as a final instance variable
  final Locale languageLocale;
  final ThemeData lightTheme;
  final ThemeData darkTheme;
  final ThemeMode themeMode;

  // Constructor to initialize the instance variables
  MyApp({
    required this.languageLocale,
    required this.lightTheme,
    required this.darkTheme,
    required this.themeMode,
  });

  Widget build(BuildContext context) {
    return I18n(
      initialLocale: languageLocale,
      supportedLocales: LocaleService.supportedLocales,
      localizationsDelegates: [
        DefaultMaterialLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        DefaultCupertinoLocalizations.delegate
      ],
      child: AppCore(
          lightTheme: lightTheme, darkTheme: darkTheme, themeMode: themeMode),
    );
  }
}

class AppCore extends StatelessWidget {
  // Declare languageLocale as a final instance variable
  final ThemeData lightTheme;
  final ThemeData darkTheme;
  final ThemeMode themeMode;

  // Constructor to initialize the instance variables
  AppCore({
    required this.lightTheme,
    required this.darkTheme,
    required this.themeMode,
  });

  Widget build(BuildContext context) {
    return MaterialApp(
      locale: I18n.locale,
      localizationsDelegates: I18n.localizationsDelegates,
      supportedLocales: I18n.supportedLocales,
      debugShowCheckedModeBanner: false,
      onNavigationNotification: _defaultOnNavigationNotification,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      title: "Oinkoin",
      home: Shell(),
    );
  }
}

bool _defaultOnNavigationNotification(NavigationNotification _) {
  // https://github.com/flutter/flutter/issues/153672#issuecomment-2583262294
  switch (WidgetsBinding.instance.lifecycleState) {
    case null:
    case AppLifecycleState.detached:
    case AppLifecycleState.inactive:
      // Avoid updating the engine when the app isn't ready.
      return true;
    case AppLifecycleState.resumed:
    case AppLifecycleState.hidden:
    case AppLifecycleState.paused:
      SystemNavigator.setFrameworkHandlesBack(true);

      /// This must be `true` instead of `notification.canHandlePop`, otherwise application closes on back gesture.
      return true;
  }
}
