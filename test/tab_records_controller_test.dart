import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:piggybank/helpers/datetime-utility-functions.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/records/controllers/tab_records_controller.dart';
import 'package:piggybank/services/database/database-interface.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/settings/constants/homepage-time-interval.dart';
import 'package:piggybank/settings/constants/preferences-keys.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timezone/data/latest_all.dart' as tz;

import 'helpers/test_database.dart';

void main() {
  late TabRecordsController controller;
  late SharedPreferences sharedPreferences;
  late DatabaseInterface database;

  final testCategory = Category(
    "Test Category",
    iconCodePoint: 1,
    categoryType: CategoryType.expense,
    color: Colors.blue,
  );

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('en_US', null);
    
    // Initialize FFI for sqflite
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    
    // Initialize timezone data
    tz.initializeTimeZones();
    ServiceConfig.localTimezone = "Europe/Vienna";
  });

  setUp(() async {
    // Initialize shared preferences with defaults
    SharedPreferences.setMockInitialValues({
      PreferencesKeys.homepageTimeInterval: HomepageTimeInterval.CurrentMonth.index,
    });
    sharedPreferences = await SharedPreferences.getInstance();
    ServiceConfig.sharedPreferences = sharedPreferences;

    // Create a new isolated in-memory database for each test
    await TestDatabaseHelper.setupTestDatabase();
    database = ServiceConfig.database;
    
    // Add test category
    await database.addCategory(testCategory);

    controller = TabRecordsController(onStateChanged: () {});
  });

  group('shiftMonthWeekYear', () {
    test('should shift month forward by 1 with custom interval set to a full month', () async {
      // Setup: Custom interval is January 2025
      controller.customIntervalFrom = DateTime(2025, 1, 1);
      controller.customIntervalTo = getEndOfMonth(2025, 1);

      // Act: Shift forward by 1 month
      await controller.shiftMonthWeekYear(1);

      // Assert: Should now be February 2025
      expect(controller.customIntervalFrom, DateTime(2025, 2, 1));
      expect(controller.customIntervalTo!.year, 2025);
      expect(controller.customIntervalTo!.month, 2);
      expect(controller.customIntervalTo!.day, 28); // February has 28 days in 2025
    });

    test('should shift month backward by 1 with custom interval set to a full month', () async {
      // Setup: Custom interval is March 2025
      controller.customIntervalFrom = DateTime(2025, 3, 1);
      controller.customIntervalTo = getEndOfMonth(2025, 3);

      // Act: Shift backward by 1 month
      await controller.shiftMonthWeekYear(-1);

      // Assert: Should now be February 2025
      expect(controller.customIntervalFrom, DateTime(2025, 2, 1));
      expect(controller.customIntervalTo!.year, 2025);
      expect(controller.customIntervalTo!.month, 2);
      expect(controller.customIntervalTo!.day, 28);
    });

    test('should shift year forward by 1 with custom interval set to a full year', () async {
      // Setup: Custom interval is full year 2024
      controller.customIntervalFrom = DateTime(2024, 1, 1);
      controller.customIntervalTo = DateTime(2024, 12, 31, 23, 59);

      // Act: Shift forward by 1 year
      await controller.shiftMonthWeekYear(1);

      // Assert: Should now be 2025
      expect(controller.customIntervalFrom, DateTime(2025, 1, 1));
      expect(controller.customIntervalTo, DateTime(2025, 12, 31, 23, 59));
    });

    test('should shift year backward by 1 with custom interval set to a full year', () async {
      // Setup: Custom interval is full year 2025
      controller.customIntervalFrom = DateTime(2025, 1, 1);
      controller.customIntervalTo = DateTime(2025, 12, 31, 23, 59);

      // Act: Shift backward by 1 year
      await controller.shiftMonthWeekYear(-1);

      // Assert: Should now be 2024
      expect(controller.customIntervalFrom, DateTime(2024, 1, 1));
      expect(controller.customIntervalTo, DateTime(2024, 12, 31, 23, 59));
    });

    test('should shift week forward by 1 when HomepageTimeInterval is CurrentWeek', () async {
      // Setup: No custom interval, use CurrentWeek setting
      controller.customIntervalFrom = null;
      controller.customIntervalTo = null;
      
      await sharedPreferences.setInt(
        PreferencesKeys.homepageTimeInterval,
        HomepageTimeInterval.CurrentWeek.index,
      );

      // Get the current week's start
      DateTime now = DateTime.now();
      DateTime currentWeekStart = getStartOfWeek(now);
      
      // Act: Shift forward by 1 week
      await controller.shiftMonthWeekYear(1);

      // Assert: Should be next week
      DateTime expectedStart = currentWeekStart.add(Duration(days: 7));
      DateTime expectedEnd = expectedStart.add(Duration(days: 6));
      
      expect(controller.customIntervalFrom!.year, expectedStart.year);
      expect(controller.customIntervalFrom!.month, expectedStart.month);
      expect(controller.customIntervalFrom!.day, expectedStart.day);
      expect(controller.customIntervalTo!.year, expectedEnd.year);
      expect(controller.customIntervalTo!.month, expectedEnd.month);
      expect(controller.customIntervalTo!.day, expectedEnd.day);
    });

    test('should shift week backward by 1 when HomepageTimeInterval is CurrentWeek', () async {
      // Setup: No custom interval, use CurrentWeek setting
      controller.customIntervalFrom = null;
      controller.customIntervalTo = null;
      
      await sharedPreferences.setInt(
        PreferencesKeys.homepageTimeInterval,
        HomepageTimeInterval.CurrentWeek.index,
      );

      // Get the current week's start
      DateTime now = DateTime.now();
      DateTime currentWeekStart = getStartOfWeek(now);
      
      // Act: Shift backward by 1 week
      await controller.shiftMonthWeekYear(-1);

      // Assert: Should be previous week
      DateTime expectedStart = currentWeekStart.subtract(Duration(days: 7));
      DateTime expectedEnd = expectedStart.add(Duration(days: 6));
      
      expect(controller.customIntervalFrom!.year, expectedStart.year);
      expect(controller.customIntervalFrom!.month, expectedStart.month);
      expect(controller.customIntervalFrom!.day, expectedStart.day);
      expect(controller.customIntervalTo!.year, expectedEnd.year);
      expect(controller.customIntervalTo!.month, expectedEnd.month);
      expect(controller.customIntervalTo!.day, expectedEnd.day);
    });

    test('should shift month forward when HomepageTimeInterval is CurrentMonth', () async {
      // Setup: No custom interval, use CurrentMonth setting
      controller.customIntervalFrom = null;
      controller.customIntervalTo = null;
      
      await sharedPreferences.setInt(
        PreferencesKeys.homepageTimeInterval,
        HomepageTimeInterval.CurrentMonth.index,
      );

      DateTime now = DateTime.now();
      
      // Act: Shift forward by 1 month
      await controller.shiftMonthWeekYear(1);

      // Assert: Should be next month
      DateTime expectedDate = DateTime(now.year, now.month + 1, 1);
      expect(controller.customIntervalFrom, expectedDate);
      expect(controller.customIntervalTo, getEndOfMonth(expectedDate.year, expectedDate.month));
    });

    test('should shift year forward when HomepageTimeInterval is CurrentYear', () async {
      // Setup: No custom interval, use CurrentYear setting
      controller.customIntervalFrom = null;
      controller.customIntervalTo = null;
      
      await sharedPreferences.setInt(
        PreferencesKeys.homepageTimeInterval,
        HomepageTimeInterval.CurrentYear.index,
      );

      DateTime now = DateTime.now();
      
      // Act: Shift forward by 1 year
      await controller.shiftMonthWeekYear(1);

      // Assert: Should be next year
      expect(controller.customIntervalFrom, DateTime(now.year + 1, 1, 1));
      expect(controller.customIntervalTo, DateTime(now.year + 1, 12, 31, 23, 59));
    });

    test('should update backgroundImageIndex to the new month', () async {
      // Setup: Custom interval is January
      controller.customIntervalFrom = DateTime(2025, 1, 1);
      controller.customIntervalTo = getEndOfMonth(2025, 1);

      // Act: Shift to February
      await controller.shiftMonthWeekYear(1);

      // Assert: backgroundImageIndex should be February (2)
      expect(controller.backgroundImageIndex, 2);
    });

    test('should update header string when shifting', () async {
      // Setup: Custom interval is January 2025
      controller.customIntervalFrom = DateTime(2025, 1, 1);
      controller.customIntervalTo = getEndOfMonth(2025, 1);

      // Act: Shift to February
      await controller.shiftMonthWeekYear(1);

      // Assert: Header should be updated (format depends on locale)
      expect(controller.header, isNotEmpty);
      expect(controller.header.toLowerCase(), contains('february'));
    });

    test('should handle shifting across year boundary', () async {
      // Setup: December 2024
      controller.customIntervalFrom = DateTime(2024, 12, 1);
      controller.customIntervalTo = getEndOfMonth(2024, 12);

      // Act: Shift forward to January 2025
      await controller.shiftMonthWeekYear(1);

      // Assert: Should be January 2025
      expect(controller.customIntervalFrom, DateTime(2025, 1, 1));
      expect(controller.customIntervalTo!.year, 2025);
      expect(controller.customIntervalTo!.month, 1);
    });

    test('should handle shifting backward across year boundary', () async {
      // Setup: January 2025
      controller.customIntervalFrom = DateTime(2025, 1, 1);
      controller.customIntervalTo = getEndOfMonth(2025, 1);

      // Act: Shift backward to December 2024
      await controller.shiftMonthWeekYear(-1);

      // Assert: Should be December 2024
      expect(controller.customIntervalFrom, DateTime(2024, 12, 1));
      expect(controller.customIntervalTo!.year, 2024);
      expect(controller.customIntervalTo!.month, 12);
    });
  });
}
