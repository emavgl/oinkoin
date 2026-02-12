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

  group('calculateMonthCycle Tests', () {
    test('Standard month cycle (Start Day 1)', () {
      final ref = DateTime(2024, 6, 15);
      final result = calculateMonthCycle(ref, 1);

      expect(result[0], DateTime(2024, 6, 1));
      expect(result[1].day, 30);
      expect(result[1].month, 6);
    });

    test('Custom cycle mid-month (Start Day 15, Ref after 15th)', () {
      final ref = DateTime(2024, 6, 20); // Today is the 20th
      final result = calculateMonthCycle(ref, 15);

      // Cycle should be June 15 to July 14
      expect(result[0], DateTime(2024, 6, 15));
      expect(result[1].month, 7);
      expect(result[1].day, 14);
    });

    test('Custom cycle mid-month (Start Day 15, Ref before 15th)', () {
      final ref = DateTime(2024, 6, 10); // Today is the 10th
      final result = calculateMonthCycle(ref, 15);

      // Cycle should have started in the previous month: May 15 to June 14
      expect(result[0], DateTime(2024, 5, 15));
      expect(result[1].month, 6);
      expect(result[1].day, 14);
    });

    test('Leap Year Clamping (Start Day 31 in February)', () {
      final ref = DateTime(2024, 2, 10); // 2024 is a leap year
      final result = calculateMonthCycle(ref, 31);

      // February has 29 days in 2024. 31 should clamp to 29.
      // Logic: ref day (10) < startDay (31), so it looks at January.
      // Start: Jan 31. End: Feb 28 (Feb 29 - 1 sec).
      expect(result[0], DateTime(2024, 1, 31));
      expect(result[1].month, 2);
      expect(result[1].day, 28); // The day before the next cycle starts (Feb 29)
    });

    test('January rollover to previous year December', () {
      // January 5th, 2024. Cycle starts on the 10th.
      // We expect the cycle to be Dec 10, 2023 - Jan 9, 2024.
      final ref = DateTime(2024, 1, 5);
      final result = calculateMonthCycle(ref, 10);

      expect(result[0].year, 2023);
      expect(result[0].month, 12);
      expect(result[0].day, 10);

      expect(result[1].year, 2024);
      expect(result[1].month, 1);
      expect(result[1].day, 9);
    });

    test('December rollover to next year January', () {
      // December 20th, 2023. Cycle starts on the 15th.
      // We expect the cycle to be Dec 15, 2023 - Jan 14, 2024.
      final ref = DateTime(2023, 12, 20);
      final result = calculateMonthCycle(ref, 15);

      expect(result[0].year, 2023);
      expect(result[0].month, 12);

      expect(result[1].year, 2024);
      expect(result[1].month, 1);
      expect(result[1].day, 14);
    });
  });

  group('calculateInterval Tests', () {
    test('Year interval calculation', () {
      final ref = DateTime(2024, 5, 20);
      final result = calculateInterval(HomepageTimeInterval.CurrentYear, ref);
      expect(result[0], DateTime(2024, 1, 1));
      expect(result[1], DateTime(2024, 12, 31, 23, 59, 59));
    });

    test('All interval fallback', () {
      final ref = DateTime(2024, 5, 20);
      final result = calculateInterval(HomepageTimeInterval.All, ref);

      // Should return the reference date as a fallback
      expect(result[0], ref);
      expect(result[1], ref);
    });

    test('Month interval calculation', () {
      final ref = DateTime(2024, 5, 20);
      // [monthStartDay] is default to 1
      final result = calculateInterval(HomepageTimeInterval.CurrentMonth, ref);
      expect(result[0], DateTime(2024, 5, 1));
      expect(result[1], DateTime(2024, 5, 31, 23, 59, 59));
    });

    test('CurrentWeek: Sunday Start', () {
      // We simulate/force the logic for a Sunday (7) start
      final ref = DateTime(2024, 6, 12); // Wednesday
      final result = calculateInterval(HomepageTimeInterval.CurrentWeek, ref);

      // Start: 2024-06-09 (Sunday)
      // End:   2024-06-15 (Saturday)
      expect(result[0], DateTime(2024, 6, 9));
      expect(result[1], DateTime(2024, 6, 15, 23, 59, 59));
    });

    test('CurrentWeek: Year Rollover with Sunday Start', () {
      // January 1, 2026 is a Thursday
      final ref = DateTime(2026, 1, 1);
      final result = calculateInterval(HomepageTimeInterval.CurrentWeek, ref);

      // If Sunday is the start:
      // Dec 28, 2025 was Sunday.
      // Jan 3, 2026 is Saturday.
      expect(result[0], DateTime(2025, 12, 28));
      expect(result[1], DateTime(2026, 1, 3, 23, 59, 59));
    });

    test('CurrentWeek: Leap Year inclusive week', () {
      // February 29, 2024 (Leap Day)
      final ref = DateTime(2024, 2, 29);
      final result = calculateInterval(HomepageTimeInterval.CurrentWeek, ref);

      // Sunday Start: Feb 25
      // Saturday End: March 2
      expect(result[0], DateTime(2024, 2, 25));
      expect(result[1], DateTime(2024, 3, 2, 23, 59, 59));
    });
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
        final startDay = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
        final endDay = DateTime(endOfWeek.year, endOfWeek.month, endOfWeek.day);
        final daysDifference = endDay.difference(startDay).inDays;
        
        expect(daysDifference, 6);
      });

      test('start of week should always be Sunday', () {
        // Test various dates throughout the year
        final testDates = [
          DateTime(2025, 1, 15),  // Wednesday
          DateTime(2025, 3, 7),   // Friday
          DateTime(2025, 6, 20),  // Friday
          DateTime(2025, 9, 14),  // Sunday
          DateTime(2025, 12, 1),  // Monday
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
          DateTime(2025, 1, 15),  // Wednesday
          DateTime(2025, 3, 7),   // Friday
          DateTime(2025, 6, 20),  // Friday
          DateTime(2025, 9, 14),  // Sunday
          DateTime(2025, 12, 1),  // Monday
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
      bool canShiftBack = canShift(-1, null, null, HomepageTimeInterval.CurrentWeek);
      expect(canShiftBack, true);
    });

    test('should not allow shifting forward beyond current week', () {
      DateTime now = DateTime.now();
      bool canShiftForward = canShift(1, null, null, HomepageTimeInterval.CurrentWeek);
      expect(canShiftForward, false);
    });

    test('should allow shifting forward if we are viewing a past week', () {
      DateTime pastDate = DateTime.now().subtract(Duration(days: 14));
      DateTime startOfPastWeek = getStartOfWeek(pastDate);
      DateTime endOfPastWeek = getEndOfWeek(pastDate);
      
      bool canShiftForward = canShift(1, startOfPastWeek, endOfPastWeek, HomepageTimeInterval.CurrentWeek);
      expect(canShiftForward, true);
    });

    test('should not allow shifting forward from current week', () {
      DateTime now = DateTime.now();
      DateTime startOfCurrentWeek = getStartOfWeek(now);
      DateTime endOfCurrentWeek = getEndOfWeek(now);
      
      bool canShiftForward = canShift(1, startOfCurrentWeek, endOfCurrentWeek, HomepageTimeInterval.CurrentWeek);
      expect(canShiftForward, false);
    });
  });
}
