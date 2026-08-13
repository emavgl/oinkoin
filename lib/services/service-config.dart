import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'database/database-interface.dart';
import 'database/sqlite-database.dart';
import '../settings/constants/preferences-keys.dart';

class ServiceConfig {
  /// ServiceConfig is a class that contains all the services
  /// used in different parts of the applications.

  static final DatabaseInterface database = SqliteDatabase.instance;
  static bool isPremium = false; // set in main.dart
  static final ValueNotifier<bool> premiumNotifier = ValueNotifier(false);
  static SharedPreferences? sharedPreferences;
  static String localTimezone = "Europe/London"; // set in main

  static String? packageName; // set in main.dart
  static String? version; // set in main.dart
  static Locale? currencyLocale; // set in main.dart
  static NumberFormat? currencyNumberFormat; // set in main.dart
  static NumberFormat? currencyNumberFormatWithoutGrouping; // set in main.dart

  /// Cache of per-currency [NumberFormat] instances keyed by decimal digit
  /// count. Populated lazily by [formatCurrencyAmount], cleared whenever the
  /// global format is invalidated.
  static final Map<int, NumberFormat> perCurrencyNumberFormatCache = {};

  /// Notifies consumers (e.g. the shell bottom navigation) when the
  /// "Use wallets" preference changes, so wallet UI can appear/disappear
  /// without an app restart.
  static final ValueNotifier<bool> walletsEnabledNotifier = ValueNotifier(true);

  static bool get walletsEnabled =>
      sharedPreferences?.getBool(PreferencesKeys.walletsEnabled) ?? true;

  static bool get showWalletBarOnHomepage =>
      sharedPreferences?.getBool(PreferencesKeys.showWalletBarOnHomepage) ??
      true;

  static void setWalletsEnabled(bool value) {
    sharedPreferences?.setBool(PreferencesKeys.walletsEnabled, value);
    walletsEnabledNotifier.value = value;
  }

  /// Syncs [walletsEnabledNotifier] with the persisted "Use wallets"
  /// preference. Call once during startup, after [sharedPreferences] has been
  /// loaded, so the Wallets tab respects the saved state instead of the
  /// hard-coded default (`true`).
  static void initWalletsEnabled() {
    walletsEnabledNotifier.value = walletsEnabled;
  }

  static void togglePremium() {
    isPremium = !isPremium;
    premiumNotifier.value = isPremium;
  }
}
