import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:i18n_extension/i18n_extension.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:piggybank/helpers/datetime-utility-functions.dart';
import 'package:piggybank/i18n.dart';
import 'package:piggybank/settings/constants/homepage-time-interval.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Initialize date formatting for both locales
    await initializeDateFormatting('en_US', null);
    await initializeDateFormatting('en_GB', null);
  });

  // Tests for locales where week starts on SUNDAY (en_US)
  group('Week utility functions (Sunday-start locale: en_US)', () {
    setUp(() {
      // Set locale to en_US (Sunday-start)
      I18n.define(Locale('en', 'US'));
    });

    group('getStartOfWeek', () {
      test('should return Sunday when given a Sunday', () {
        // Sunday, December 14, 2025
        final sunday = DateTime(2025, 12, 14);
        final startOfWeek = getStartOfWeek(sunday);

        expect(startOfWeek.year, 2025);
        expect(startOfWeek.month, 12);
        expect(startOfWeek.day, 14);
        expect(startOfWeek.weekday, DateTime.sunday);
      });

      test('should return Sunday when given a Monday', () {
        // Monday, December 15, 2025
        final monday = DateTime(2025, 12, 15);
        final startOfWeek = getStartOfWeek(monday);

        expect(startOfWeek.year, 2025);
        expect(startOfWeek.month, 12);
        expect(startOfWeek.day, 14); // Sunday
        expect(startOfWeek.weekday, DateTime.sunday);
      });

      test('should return Sunday when given a Tuesday', () {
        // Tuesday, December 16, 2025
        final tuesday = DateTime(2025, 12, 16);
        final startOfWeek = getStartOfWeek(tuesday);

        expect(startOfWeek.year, 2025);
        expect(startOfWeek.month, 12);
        expect(startOfWeek.day, 14); // Sunday
        expect(startOfWeek.weekday, DateTime.sunday);
      });

      test('should return Sunday when given a Wednesday', () {
        // Wednesday, December 17, 2025
        final wednesday = DateTime(2025, 12, 17);
        final startOfWeek = getStartOfWeek(wednesday);

        expect(startOfWeek.year, 2025);
        expect(startOfWeek.month, 12);
        expect(startOfWeek.day, 14); // Sunday
        expect(startOfWeek.weekday, DateTime.sunday);
      });

      test('should return Sunday when given a Saturday', () {
        // Saturday, December 20, 2025
        final saturday = DateTime(2025, 12, 20);
        final startOfWeek = getStartOfWeek(saturday);

        expect(startOfWeek.year, 2025);
        expect(startOfWeek.month, 12);
        expect(startOfWeek.day, 14); // Sunday
        expect(startOfWeek.weekday, DateTime.sunday);
      });

      test('should handle week crossing month boundary', () {
        // Friday, January 3, 2025
        final friday = DateTime(2025, 1, 3);
        final startOfWeek = getStartOfWeek(friday);

        expect(startOfWeek.year, 2024);
        expect(startOfWeek.month, 12);
        expect(startOfWeek.day, 29); // Sunday in previous month
        expect(startOfWeek.weekday, DateTime.sunday);
      });

      test('should handle week crossing year boundary', () {
        // Thursday, January 2, 2025
        final thursday = DateTime(2025, 1, 2);
        final startOfWeek = getStartOfWeek(thursday);

        expect(startOfWeek.year, 2024);
        expect(startOfWeek.month, 12);
        expect(startOfWeek.day, 29); // Sunday in previous year
        expect(startOfWeek.weekday, DateTime.sunday);
      });
    });

    group('getEndOfWeek', () {
      test('should return Saturday at 23:59 when given a Monday', () {
        // Monday, December 15, 2025
        final monday = DateTime(2025, 12, 15);
        final endOfWeek = getEndOfWeek(monday);

        expect(endOfWeek.year, 2025);
        expect(endOfWeek.month, 12);
        expect(endOfWeek.day, 20); // Saturday
        expect(endOfWeek.weekday, DateTime.saturday);
        expect(endOfWeek.hour, 23);
        expect(endOfWeek.minute, 59);
      });

      test('should return Saturday at 23:59 when given a Wednesday', () {
        // Wednesday, December 17, 2025
        final wednesday = DateTime(2025, 12, 17);
        final endOfWeek = getEndOfWeek(wednesday);

        expect(endOfWeek.year, 2025);
        expect(endOfWeek.month, 12);
        expect(endOfWeek.day, 20); // Saturday
        expect(endOfWeek.weekday, DateTime.saturday);
        expect(endOfWeek.hour, 23);
        expect(endOfWeek.minute, 59);
      });

      test('should return Saturday at 23:59 when given a Sunday', () {
        // Sunday, December 14, 2025
        final sunday = DateTime(2025, 12, 14);
        final endOfWeek = getEndOfWeek(sunday);

        expect(endOfWeek.year, 2025);
        expect(endOfWeek.month, 12);
        expect(endOfWeek.day, 20); // Saturday
        expect(endOfWeek.weekday, DateTime.saturday);
        expect(endOfWeek.hour, 23);
        expect(endOfWeek.minute, 59);
      });

      test('should handle week crossing month boundary', () {
        // Monday, December 29, 2025
        final monday = DateTime(2025, 12, 29);
        final endOfWeek = getEndOfWeek(monday);

        expect(endOfWeek.year, 2026);
        expect(endOfWeek.month, 1);
        expect(endOfWeek.day, 3); // Saturday in next month
        expect(endOfWeek.weekday, DateTime.saturday);
        expect(endOfWeek.hour, 23);
        expect(endOfWeek.minute, 59);
      });

      test('should handle week crossing year boundary', () {
        // Tuesday, December 30, 2025
        final tuesday = DateTime(2025, 12, 30);
        final endOfWeek = getEndOfWeek(tuesday);

        expect(endOfWeek.year, 2026);
        expect(endOfWeek.month, 1);
        expect(endOfWeek.day, 3); // Saturday in next year
        expect(endOfWeek.weekday, DateTime.saturday);
        expect(endOfWeek.hour, 23);
        expect(endOfWeek.minute, 59);
      });
    });

    group('getWeekStr', () {
      test('should return non-empty string for mid-December week', () {
        // Wednesday, December 17, 2025
        final wednesday = DateTime(2025, 12, 17);
        final weekStr = getWeekStr(wednesday);

        // Basic validation - just ensure it returns a valid string
        expect(weekStr, isNotNull);
        expect(weekStr, isNotEmpty);
      });

      test('should return non-empty string for week at start of year', () {
        // Thursday, January 2, 2025 (week spans 2024-2025)
        final thursday = DateTime(2025, 1, 2);
        final weekStr = getWeekStr(thursday);

        expect(weekStr, isNotNull);
        expect(weekStr, isNotEmpty);
      });

      test('should return non-empty string for week at end of year', () {
        // Tuesday, December 30, 2025 (week spans 2025-2026)
        final tuesday = DateTime(2025, 12, 30);
        final weekStr = getWeekStr(tuesday);

        expect(weekStr, isNotNull);
        expect(weekStr, isNotEmpty);
      });

      test('should return same string for all days in the same week', () {
        // All days in the week of December 14-20, 2025 (Sunday to Saturday)
        final sunday = DateTime(2025, 12, 14);
        final monday = DateTime(2025, 12, 15);
        final wednesday = DateTime(2025, 12, 17);
        final saturday = DateTime(2025, 12, 20);

        final sundayStr = getWeekStr(sunday);
        final mondayStr = getWeekStr(monday);
        final wednesdayStr = getWeekStr(wednesday);
        final saturdayStr = getWeekStr(saturday);

        expect(sundayStr, equals(mondayStr));
        expect(sundayStr, equals(wednesdayStr));
        expect(sundayStr, equals(saturdayStr));
      });
    });

    group('Edge cases and validation', () {
      test('start and end of week should be exactly 6 days apart', () {
        final testDate = DateTime(2025, 12, 17);
        final startOfWeek = getStartOfWeek(testDate);
        final endOfWeek = getEndOfWeek(testDate);

        // Calculate days difference (ignoring hours/minutes)
        final startDay =
            DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
        final endDay = DateTime(endOfWeek.year, endOfWeek.month, endOfWeek.day);
        final daysDifference = endDay.difference(startDay).inDays;

        expect(daysDifference, 6);
      });

      test('start of week should always be Sunday', () {
        // Test various dates throughout the year
        final testDates = [
          DateTime(2025, 1, 15), // Wednesday
          DateTime(2025, 3, 7), // Friday
          DateTime(2025, 6, 20), // Friday
          DateTime(2025, 9, 14), // Sunday
          DateTime(2025, 12, 1), // Monday
        ];

        for (var date in testDates) {
          final startOfWeek = getStartOfWeek(date);
          expect(startOfWeek.weekday, DateTime.sunday,
              reason: 'Start of week for $date should be Sunday');
        }
      });

      test('end of week should always be Saturday', () {
        // Test various dates throughout the year
        final testDates = [
          DateTime(2025, 1, 15), // Wednesday
          DateTime(2025, 3, 7), // Friday
          DateTime(2025, 6, 20), // Friday
          DateTime(2025, 9, 14), // Sunday
          DateTime(2025, 12, 1), // Monday
        ];

        for (var date in testDates) {
          final endOfWeek = getEndOfWeek(date);
          expect(endOfWeek.weekday, DateTime.saturday,
              reason: 'End of week for $date should be Saturday');
        }
      });

      test('end of week should always be at 23:59', () {
        final testDate = DateTime(2025, 6, 15, 10, 30); // With specific time
        final endOfWeek = getEndOfWeek(testDate);

        expect(endOfWeek.hour, 23);
        expect(endOfWeek.minute, 59);
      });
    });
  });

  group('canShift for CurrentWeek', () {
    test('should allow shifting backward when there are past weeks', () {
      DateTime now = DateTime.now();
      bool canShiftBack =
          canShift(-1, null, null, HomepageTimeInterval.CurrentWeek);
      expect(canShiftBack, true);
    });

    test('should not allow shifting forward beyond current week', () {
      DateTime now = DateTime.now();
      bool canShiftForward =
          canShift(1, null, null, HomepageTimeInterval.CurrentWeek);
      expect(canShiftForward, false);
    });

    test('should allow shifting forward if we are viewing a past week', () {
      DateTime pastDate = DateTime.now().subtract(Duration(days: 14));
      DateTime startOfPastWeek = getStartOfWeek(pastDate);
      DateTime endOfPastWeek = getEndOfWeek(pastDate);

      bool canShiftForward = canShift(
          1, startOfPastWeek, endOfPastWeek, HomepageTimeInterval.CurrentWeek);
      expect(canShiftForward, true);
    });

    test('should not allow shifting forward from current week', () {
      DateTime now = DateTime.now();
      DateTime startOfCurrentWeek = getStartOfWeek(now);
      DateTime endOfCurrentWeek = getEndOfWeek(now);

      bool canShiftForward = canShift(1, startOfCurrentWeek, endOfCurrentWeek,
          HomepageTimeInterval.CurrentWeek);
      expect(canShiftForward, false);
    });
  });
}
