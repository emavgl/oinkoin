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
  static final ValueNotifier<bool> budgetsEnabledNotifier = ValueNotifier(true);

  static bool get walletsEnabled =>
      sharedPreferences?.getBool(PreferencesKeys.walletsEnabled) ?? true;

  static bool get budgetsEnabled =>
      sharedPreferences?.getBool(PreferencesKeys.budgetsEnabled) ?? true;

  static bool get showWalletBarOnHomepage =>
      sharedPreferences?.getBool(PreferencesKeys.showWalletBarOnHomepage) ??
      true;

  static Future<void> setWalletsEnabled(bool value) async {
    final prefs = sharedPreferences;
    if (prefs != null) {
      await prefs.setBool(PreferencesKeys.walletsEnabled, value);
    }
    walletsEnabledNotifier.value = value;
    if (!value) {
      await _clearBudgetWalletFilters();
    }
  }

  static Future<void> _clearBudgetWalletFilters() async {
    final budgets = await database.getBudgets();
    for (final budget in budgets) {
      if (budget.id == null || budget.walletIds.isEmpty) continue;
      budget.walletIds = [];
      await database.updateBudget(budget);
    }
  }

  static void setBudgetsEnabled(bool value) {
    sharedPreferences?.setBool(PreferencesKeys.budgetsEnabled, value);
    budgetsEnabledNotifier.value = value;
  }

  /// Syncs [walletsEnabledNotifier] with the persisted "Use wallets"
  /// preference. Call once during startup, after [sharedPreferences] has been
  /// loaded, so the Wallets tab respects the saved state instead of the
  /// hard-coded default (`true`).
  static void initWalletsEnabled() {
    walletsEnabledNotifier.value = walletsEnabled;
  }

  static void initBudgetsEnabled() {
    budgetsEnabledNotifier.value = budgetsEnabled;
  }

  static void togglePremium() {
    setPremium(!isPremium);
  }

  /// Updates the premium state and notifies [premiumNotifier] listeners.
  /// Used by the purchase service (license sync) and the debug toggle.
  static void setPremium(bool value) {
    if (isPremium == value && premiumNotifier.value == value) return;
    isPremium = value;
    premiumNotifier.value = value;
  }

  /// Notifies consumers (e.g. the customization page) when the
  /// "Show homepage image" preference changes, so the monthly banner entry
  /// can be enabled/disabled without rebuilding the whole page.
  static final ValueNotifier<bool> showHomepageImageNotifier = ValueNotifier(
    true,
  );

  static bool get showHomepageImage =>
      sharedPreferences?.getBool(PreferencesKeys.showHomepageImage) ?? true;

  static final ValueNotifier<bool> navigationBarAnimationsEnabledNotifier =
      ValueNotifier(true);

  static bool get navigationBarAnimationsEnabled =>
      sharedPreferences
          ?.getBool(PreferencesKeys.enableNavigationBarAnimations) ??
      true;

  static void setNavigationBarAnimationsEnabled(bool value) {
    sharedPreferences?.setBool(
      PreferencesKeys.enableNavigationBarAnimations,
      value,
    );
    navigationBarAnimationsEnabledNotifier.value = value;
  }

  static void initNavigationBarAnimationsEnabled() {
    navigationBarAnimationsEnabledNotifier.value =
        navigationBarAnimationsEnabled;
  }

  static void setShowHomepageImage(bool value) {
    sharedPreferences?.setBool(PreferencesKeys.showHomepageImage, value);
    showHomepageImageNotifier.value = value;
  }

  /// Syncs [showHomepageImageNotifier] with the persisted "Show homepage
  /// image" preference. Call once during startup, after [sharedPreferences]
  /// has been loaded.
  static void initShowHomepageImage() {
    showHomepageImageNotifier.value = showHomepageImage;
  }

  /// Notifies consumers (e.g. the homepage summary card) when privacy mode
  /// changes, so amounts are hidden or revealed instantly without an app
  /// restart.
  static final ValueNotifier<bool> privacyModeNotifier = ValueNotifier(false);

  static bool get privacyMode =>
      sharedPreferences?.getBool(PreferencesKeys.privacyMode) ?? false;

  static void setPrivacyMode(bool value) {
    sharedPreferences?.setBool(PreferencesKeys.privacyMode, value);
    privacyModeNotifier.value = value;
  }

  /// Syncs [privacyModeNotifier] with the persisted preference. Call once
  /// during startup, after [sharedPreferences] has been loaded.
  static void initPrivacyMode() {
    privacyModeNotifier.value = privacyMode;
  }
}
