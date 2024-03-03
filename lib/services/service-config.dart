import 'dart:ui';

import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'database/database-interface.dart';
import 'database/sqlite-database.dart';

class ServiceConfig {
  /// ServiceConfig is a class that contains all the services
  /// used in different parts of the applications.

  static final DatabaseInterface database = SqliteDatabase.instance;
  static bool isPremium = false; // set in main.dart
  static SharedPreferences? sharedPreferences;

  static String? packageName; // set in main.dart
  static String? version; // set in main.dart
  static Locale? currencyLocale; // set in main.dart
  static NumberFormat? currencyNumberFormat; // set in main.dart
  static NumberFormat? currencyNumberFormatWithoutGrouping; // set in main.dart
}
