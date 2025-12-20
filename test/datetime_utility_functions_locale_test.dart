import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:i18n_extension/i18n_extension.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:piggybank/helpers/datetime-utility-functions.dart';
import 'package:piggybank/settings/constants/homepage-time-interval.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('en_US', null);
    await initializeDateFormatting('en_GB', null);
    await initializeDateFormatting('it', null);
  });

  // ===== Tests for SUNDAY-start locales (en_US) =====
  group('Week utility functions (Sunday-start locale: en_US)', () {
    setUp(() {
      I18n.define(Locale('en', 'US'));
    });

    group('getStartOfWeek', () {
      test('should return Sunday when given a Sunday', () {
        final sunday = DateTime(2025, 12, 14); // Sunday
        final startOfWeek = getStartOfWeek(sunday);
        
        expect(startOfWeek.day, 14);
        expect(startOfWeek.weekday, DateTime.sunday);
      });

      test('should return Sunday when given a Monday', () {
        final monday = DateTime(2025, 12, 15); // Monday
        final startOfWeek = getStartOfWeek(monday);
        
        expect(startOfWeek.day, 14); // Previous Sunday
        expect(startOfWeek.weekday, DateTime.sunday);
      });

      test('should return Sunday when given a Saturday', () {
        final saturday = DateTime(2025, 12, 20); // Saturday
        final startOfWeek = getStartOfWeek(saturday);
        
        expect(startOfWeek.day, 14); // Sunday
        expect(startOfWeek.weekday, DateTime.sunday);
      });

      test('should handle week crossing month boundary', () {
        final friday = DateTime(2025, 1, 3); // Friday
        final startOfWeek = getStartOfWeek(friday);
        
        expect(startOfWeek.year, 2024);
        expect(startOfWeek.month, 12);
        expect(startOfWeek.day, 29); // Sunday in previous month
        expect(startOfWeek.weekday, DateTime.sunday);
      });
    });

    group('getEndOfWeek', () {
      test('should return Saturday when given a Sunday', () {
        final sunday = DateTime(2025, 12, 14); // Sunday
        final endOfWeek = getEndOfWeek(sunday);
        
        expect(endOfWeek.day, 20); // Saturday
        expect(endOfWeek.weekday, DateTime.saturday);
        expect(endOfWeek.hour, 23);
        expect(endOfWeek.minute, 59);
      });

      test('should return Saturday when given a Monday', () {
        final monday = DateTime(2025, 12, 15); // Monday
        final endOfWeek = getEndOfWeek(monday);
        
        expect(endOfWeek.day, 20); // Saturday
        expect(endOfWeek.weekday, DateTime.saturday);
      });

      test('should handle week crossing month boundary', () {
        final monday = DateTime(2025, 12, 29); // Monday
        final endOfWeek = getEndOfWeek(monday);
        
        expect(endOfWeek.year, 2026);
        expect(endOfWeek.month, 1);
        expect(endOfWeek.day, 3); // Saturday in next month
        expect(endOfWeek.weekday, DateTime.saturday);
      });
    });

    group('isFullWeek', () {
      test('should return true for Sunday-Saturday week', () {
        final sunday = DateTime(2025, 12, 14);
        final saturday = DateTime(2025, 12, 20, 23, 59);
        
        expect(isFullWeek(sunday, saturday), true);
      });

      test('should return false for Monday-Sunday week', () {
        final monday = DateTime(2025, 12, 15);
        final sunday = DateTime(2025, 12, 21, 23, 59);
        
        expect(isFullWeek(monday, sunday), false);
      });
    });

    test('week should be 7 days (Sunday to Saturday)', () {
      final testDate = DateTime(2025, 12, 17);
      final startOfWeek = getStartOfWeek(testDate);
      final endOfWeek = getEndOfWeek(testDate);
      
      final startDay = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
      final endDay = DateTime(endOfWeek.year, endOfWeek.month, endOfWeek.day);
      
      expect(endDay.difference(startDay).inDays, 6);
      expect(startOfWeek.weekday, DateTime.sunday);
      expect(endOfWeek.weekday, DateTime.saturday);
    });
  });

  // ===== Tests for MONDAY-start locales (en_GB, it, de, fr, etc.) =====
  group('Week utility functions (Monday-start locale: en_GB)', () {
    setUp(() {
      I18n.define(Locale('en', 'GB'));
    });

    group('getStartOfWeek', () {
      test('should return Monday when given a Monday', () {
        final monday = DateTime(2025, 12, 15); // Monday
        final startOfWeek = getStartOfWeek(monday);
        
        expect(startOfWeek.day, 15);
        expect(startOfWeek.weekday, DateTime.monday);
      });

      test('should return Monday when given a Tuesday', () {
        final tuesday = DateTime(2025, 12, 16); // Tuesday
        final startOfWeek = getStartOfWeek(tuesday);
        
        expect(startOfWeek.day, 15); // Monday
        expect(startOfWeek.weekday, DateTime.monday);
      });

      test('should return Monday when given a Sunday', () {
        final sunday = DateTime(2025, 12, 21); // Sunday
        final startOfWeek = getStartOfWeek(sunday);
        
        expect(startOfWeek.day, 15); // Monday
        expect(startOfWeek.weekday, DateTime.monday);
      });

      test('should handle week crossing month boundary', () {
        final friday = DateTime(2025, 1, 3); // Friday
        final startOfWeek = getStartOfWeek(friday);
        
        expect(startOfWeek.year, 2024);
        expect(startOfWeek.month, 12);
        expect(startOfWeek.day, 30); // Monday in previous month
        expect(startOfWeek.weekday, DateTime.monday);
      });

      test('should handle week crossing year boundary', () {
        final thursday = DateTime(2025, 1, 2); // Thursday
        final startOfWeek = getStartOfWeek(thursday);
        
        expect(startOfWeek.year, 2024);
        expect(startOfWeek.month, 12);
        expect(startOfWeek.day, 30); // Monday in previous year
        expect(startOfWeek.weekday, DateTime.monday);
      });
    });

    group('getEndOfWeek', () {
      test('should return Sunday when given a Monday', () {
        final monday = DateTime(2025, 12, 15); // Monday
        final endOfWeek = getEndOfWeek(monday);
        
        expect(endOfWeek.day, 21); // Sunday
        expect(endOfWeek.weekday, DateTime.sunday);
        expect(endOfWeek.hour, 23);
        expect(endOfWeek.minute, 59);
      });

      test('should return Sunday when given a Wednesday', () {
        final wednesday = DateTime(2025, 12, 17); // Wednesday
        final endOfWeek = getEndOfWeek(wednesday);
        
        expect(endOfWeek.day, 21); // Sunday
        expect(endOfWeek.weekday, DateTime.sunday);
      });

      test('should return Sunday when given a Sunday', () {
        final sunday = DateTime(2025, 12, 21); // Sunday
        final endOfWeek = getEndOfWeek(sunday);
        
        expect(endOfWeek.day, 21); // Same Sunday
        expect(endOfWeek.weekday, DateTime.sunday);
      });

      test('should handle week crossing month boundary', () {
        final monday = DateTime(2025, 12, 29); // Monday
        final endOfWeek = getEndOfWeek(monday);
        
        expect(endOfWeek.year, 2026);
        expect(endOfWeek.month, 1);
        expect(endOfWeek.day, 4); // Sunday in next month
        expect(endOfWeek.weekday, DateTime.sunday);
      });

      test('should handle week crossing year boundary', () {
        final tuesday = DateTime(2025, 12, 30); // Tuesday
        final endOfWeek = getEndOfWeek(tuesday);
        
        expect(endOfWeek.year, 2026);
        expect(endOfWeek.month, 1);
        expect(endOfWeek.day, 4); // Sunday in next year
        expect(endOfWeek.weekday, DateTime.sunday);
      });
    });

    group('isFullWeek', () {
      test('should return true for Monday-Sunday week', () {
        final monday = DateTime(2025, 12, 15);
        final sunday = DateTime(2025, 12, 21, 23, 59);
        
        expect(isFullWeek(monday, sunday), true);
      });

      test('should return false for Sunday-Saturday week', () {
        final sunday = DateTime(2025, 12, 14);
        final saturday = DateTime(2025, 12, 20, 23, 59);
        
        expect(isFullWeek(sunday, saturday), false);
      });

      test('should return false for partial week', () {
        final tuesday = DateTime(2025, 12, 16);
        final friday = DateTime(2025, 12, 19, 23, 59);
        
        expect(isFullWeek(tuesday, friday), false);
      });
    });

    test('week should be 7 days (Monday to Sunday)', () {
      final testDate = DateTime(2025, 12, 17);
      final startOfWeek = getStartOfWeek(testDate);
      final endOfWeek = getEndOfWeek(testDate);
      
      final startDay = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
      final endDay = DateTime(endOfWeek.year, endOfWeek.month, endOfWeek.day);
      
      expect(endDay.difference(startDay).inDays, 6);
      expect(startOfWeek.weekday, DateTime.monday);
      expect(endOfWeek.weekday, DateTime.sunday);
    });

    test('getWeekStr should return same string for all days in same week', () {
      final monday = DateTime(2025, 12, 15);
      final wednesday = DateTime(2025, 12, 17);
      final friday = DateTime(2025, 12, 19);
      final sunday = DateTime(2025, 12, 21);
      
      final mondayStr = getWeekStr(monday);
      final wednesdayStr = getWeekStr(wednesday);
      final fridayStr = getWeekStr(friday);
      final sundayStr = getWeekStr(sunday);
      
      expect(mondayStr, equals(wednesdayStr));
      expect(mondayStr, equals(fridayStr));
      expect(mondayStr, equals(sundayStr));
    });
  });

  // ===== Tests for Italian locale (also Monday-start) =====
  group('Week utility functions (Monday-start locale: Italian)', () {
    setUp(() {
      I18n.define(Locale('it'));
    });

    test('should use Monday as start of week', () {
      final wednesday = DateTime(2025, 12, 17);
      final startOfWeek = getStartOfWeek(wednesday);
      
      expect(startOfWeek.day, 15);
      expect(startOfWeek.weekday, DateTime.monday);
    });

    test('should use Sunday as end of week', () {
      final wednesday = DateTime(2025, 12, 17);
      final endOfWeek = getEndOfWeek(wednesday);
      
      expect(endOfWeek.day, 21);
      expect(endOfWeek.weekday, DateTime.sunday);
    });
  });

  // ===== Tests for canShift function =====
  group('canShift for CurrentWeek (locale-aware)', () {
    test('should work correctly for Monday-start weeks', () {
      I18n.define(Locale('en', 'GB'));
      
      bool canShiftBack = canShift(-1, null, null, HomepageTimeInterval.CurrentWeek);
      expect(canShiftBack, true);
      
      bool canShiftForward = canShift(1, null, null, HomepageTimeInterval.CurrentWeek);
      expect(canShiftForward, false);
    });

    test('should work correctly for Sunday-start weeks', () {
      I18n.define(Locale('en', 'US'));
      
      bool canShiftBack = canShift(-1, null, null, HomepageTimeInterval.CurrentWeek);
      expect(canShiftBack, true);
      
      bool canShiftForward = canShift(1, null, null, HomepageTimeInterval.CurrentWeek);
      expect(canShiftForward, false);
    });

    test('should correctly validate custom week intervals (Monday-start)', () {
      I18n.define(Locale('en', 'GB'));
      
      // Full week: Monday to Sunday
      DateTime monday = DateTime(2025, 12, 15);
      DateTime sunday = DateTime(2025, 12, 21, 23, 59);
      
      bool canShiftBack = canShift(-1, monday, sunday, HomepageTimeInterval.CurrentWeek);
      expect(canShiftBack, true);
    });

    test('should correctly validate custom week intervals (Sunday-start)', () {
      I18n.define(Locale('en', 'US'));
      
      // Full week: Sunday to Saturday
      DateTime sunday = DateTime(2025, 12, 14);
      DateTime saturday = DateTime(2025, 12, 20, 23, 59);
      
      bool canShiftBack = canShift(-1, sunday, saturday, HomepageTimeInterval.CurrentWeek);
      expect(canShiftBack, true);
    });
  });
}
