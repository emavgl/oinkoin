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

  /// Whether the privacy feature is armed: the eye button is shown and
  /// tapping amounts hides them. The switch in settings controls this;
  /// it never hides anything by itself.
  static final ValueNotifier<bool> privacyModeEnabledNotifier =
      ValueNotifier(false);

  static bool get privacyModeEnabled =>
      sharedPreferences?.getBool(PreferencesKeys.privacyMode) ?? false;

  static void setPrivacyModeEnabled(bool value) {
    sharedPreferences?.setBool(PreferencesKeys.privacyMode, value);
    privacyModeEnabledNotifier.value = value;
    if (!value) {
      // Disarming reveals everything and clears the hidden state.
      setPrivacyModeHidden(false);
    }
  }

  /// Whether amounts are currently hidden. Only meaningful while the
  /// feature is armed; hide requests made while disarmed are ignored so
  /// re-arming always starts from visible amounts.
  static final ValueNotifier<bool> privacyModeHiddenNotifier =
      ValueNotifier(false);

  static bool get privacyModeHidden =>
      sharedPreferences?.getBool(PreferencesKeys.privacyModeHidden) ?? false;

  static void setPrivacyModeHidden(bool value) {
    if (value && !privacyModeEnabled) return;
    sharedPreferences?.setBool(PreferencesKeys.privacyModeHidden, value);
    privacyModeHiddenNotifier.value = value;
  }

  static bool get privacyModeOnStart =>
      sharedPreferences?.getBool(PreferencesKeys.privacyModeOnStart) ?? false;

  static void setPrivacyModeOnStart(bool value) {
    sharedPreferences?.setBool(PreferencesKeys.privacyModeOnStart, value);
  }

  /// Syncs both privacy notifiers with the persisted preferences. When
  /// "start with privacy mode on" is enabled, amounts start hidden (the
  /// persisted hidden state is aligned). A disarmed feature always starts
  /// visible. Call once during startup, after [sharedPreferences] has been
  /// loaded.
  static void initPrivacyMode() {
    final enabled = privacyModeEnabled;
    privacyModeEnabledNotifier.value = enabled;
    final hidden = enabled && (privacyModeOnStart || privacyModeHidden);
    sharedPreferences?.setBool(PreferencesKeys.privacyModeHidden, hidden);
    privacyModeHiddenNotifier.value = hidden;
  }
}
