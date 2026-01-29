import 'dart:ui';

import 'package:i18n_extension/i18n_extension.dart';
import 'package:intl/intl.dart';
import 'package:piggybank/helpers/records-utility-functions.dart';
import 'package:piggybank/i18n.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/settings/constants/preferences-keys.dart';
import 'package:piggybank/settings/preferences-utils.dart';
import 'package:piggybank/statistics/statistics-models.dart';
import 'package:timezone/timezone.dart' as tz;

import '../settings/constants/homepage-time-interval.dart';

DateTime addDuration(DateTime start, Duration duration) {
  // Convert to UTC
  DateTime utcDateTime = new DateTime.utc(start.year, start.month, start.day,
      start.hour, start.minute, start.second);

  // Add Duration
  DateTime endTime = utcDateTime.add(duration);

  // Convert back
  return new DateTime(endTime.year, endTime.month, endTime.day, endTime.hour,
      endTime.minute, endTime.second);
}

DateTime getEndOfMonth(int year, int month) {
  DateTime lastDayOfMonths = (month < 12)
      ? new DateTime(year, month + 1, 0)
      : new DateTime(year + 1, 1, 0);
  return addDuration(lastDayOfMonths, Duration(hours: 23, minutes: 59));
}

String getDateRangeStr(DateTime start, DateTime end) {
  /// Returns a string representing the range from earliest to latest date
  Locale myLocale = I18n.locale;

  // Ensure earlier date goes to left, latest to right
  DateTime earlier = start.isBefore(end) ? start : end;
  DateTime later = start.isBefore(end) ? end : start;

  DateTime lastDayOfTheMonth = getEndOfMonth(earlier.year, earlier.month);
  if (earlier.day == 1 && lastDayOfTheMonth.isAtSameMomentAs(later)) {
    // Visualizing an entire month (starts on 1st and ends on last day)
    String localeRepr =
        DateFormat.yMMMM(myLocale.languageCode).format(lastDayOfTheMonth);
    return localeRepr[0].toUpperCase() + localeRepr.substring(1); // capitalize
  } else {
    if (earlier.year == later.year) {
      // Same year: show year only once at the end
      String startLocalRepr = DateFormat.MMMd(myLocale.languageCode).format(earlier);
      String endLocalRepr = DateFormat.yMMMd(myLocale.languageCode).format(later);
      return startLocalRepr + " - " + endLocalRepr;
    } else {
      // Different years: show year for both dates
      String startLocalRepr = DateFormat.yMMMd(myLocale.languageCode).format(earlier);
      String endLocalRepr = DateFormat.yMMMd(myLocale.languageCode).format(later);
      return startLocalRepr + " - " + endLocalRepr;
    }
  }
}

String getMonthStr(DateTime dateTime) {
  /// Returns the header string identifying the current visualised month.
  Locale myLocale = I18n.locale;
  String localeRepr = DateFormat.yMMMM(myLocale.languageCode).format(dateTime);
  return localeRepr[0].toUpperCase() + localeRepr.substring(1); // capitalize
}

String getYearStr(DateTime dateTime) {
  return "${"Year".i18n} ${dateTime.year}";
}

String getWeekStr(DateTime dateTime) {
  DateTime startOfWeek = getStartOfWeek(dateTime);
  DateTime endOfWeek = getEndOfWeek(dateTime);
  return getDateRangeStr(startOfWeek, endOfWeek);
}

/// Returns the first day of the week (1=Monday, 7=Sunday) based on user preference or locale.
/// User preference options:
/// - 0: System default (use locale)
/// - 1: Monday
/// - 6: Saturday
/// - 7: Sunday
/// Different locales have different week start days:
/// - US, Brazil, China, Japan: Sunday (7)
/// - Arabic regions: Saturday (6)  
/// - Most European and other locales: Monday (1)
int getFirstDayOfWeekIndex() {
  try {
    // Check if user has set a preference
    if (ServiceConfig.sharedPreferences != null) {
      int? userPreference = PreferencesUtils.getOrDefault<int>(
          ServiceConfig.sharedPreferences!, PreferencesKeys.firstDayOfWeek);

      if (userPreference != null && userPreference != 0) {
        // User has explicitly set a preference (not "System")
        return userPreference;
      }
    }

    // Fall back to locale-based logic
    String localeStr = I18n.locale.toString();
    
    if (localeStr == 'en_US') return DateTime.sunday;
    if (localeStr.startsWith('pt_BR')) return DateTime.sunday;
    if (localeStr.startsWith('zh')) return DateTime.sunday;
    if (localeStr.startsWith('ja')) return DateTime.sunday;
    if (localeStr.startsWith('ar')) return DateTime.saturday;
  } catch (e) {
    // Locale not initialized or error, use default
  }
  
  return DateTime.monday; // Default for most locales
}

/// Returns the last day of the week based on the first day.
int _getLastDayOfWeek(int firstDayOfWeek) {
  return firstDayOfWeek == DateTime.monday ? DateTime.sunday : firstDayOfWeek - 1;
}

/// Calculates the number of days to offset from current day to reach target weekday.
/// Handles week wraparound (e.g., going from Monday to previous Sunday).
int _calculateDaysOffset(int fromWeekday, int toWeekday, {bool forward = false}) {
  if (forward) {
    return toWeekday >= fromWeekday 
        ? toWeekday - fromWeekday
        : (7 - fromWeekday) + toWeekday;
  } else {
    return fromWeekday >= toWeekday
        ? fromWeekday - toWeekday
        : fromWeekday + (7 - toWeekday);
  }
}

DateTime getStartOfWeek(DateTime date) {
  int firstDayOfWeek = getFirstDayOfWeekIndex();
  int daysToSubtract = _calculateDaysOffset(date.weekday, firstDayOfWeek);
  return DateTime(date.year, date.month, date.day - daysToSubtract);
}

DateTime getEndOfWeek(DateTime date) {
  int firstDayOfWeek = getFirstDayOfWeekIndex();
  int lastDayOfWeek = _getLastDayOfWeek(firstDayOfWeek);
  int daysToAdd = _calculateDaysOffset(date.weekday, lastDayOfWeek, forward: true);
  return DateTime(date.year, date.month, date.day + daysToAdd, 23, 59);
}


String getDateStr(DateTime? dateTime, {AggregationMethod? aggregationMethod}) {
  Locale myLocale = I18n.locale;
  if (aggregationMethod != null) {
    if (aggregationMethod == AggregationMethod.MONTH) {
      return DateFormat.yM(myLocale.toString()).format(dateTime!);
    }
    if (aggregationMethod == AggregationMethod.YEAR) {
      return DateFormat.y(myLocale.toString()).format(dateTime!);
    }
  }

  // Check for user preference
  if (ServiceConfig.sharedPreferences != null) {
    String? dateFormatPref = PreferencesUtils.getOrDefault<String>(
        ServiceConfig.sharedPreferences!, PreferencesKeys.dateFormat);

    if (dateFormatPref != null && dateFormatPref != "system" && dateFormatPref.isNotEmpty) {
      return DateFormat(dateFormatPref, myLocale.toString()).format(dateTime!);
    }
  }

  return DateFormat.yMd(myLocale.toString()).format(dateTime!);
}

String extractMonthString(DateTime dateTime) {
  Locale myLocale = I18n.locale;
  return DateFormat.MMMM(myLocale.languageCode).format(dateTime);
}

String extractYearString(DateTime dateTime) {
  Locale myLocale = I18n.locale;
  return new DateFormat.y(myLocale.languageCode).format(dateTime);
}

String extractWeekdayString(DateTime dateTime) {
  Locale myLocale = I18n.locale;
  return DateFormat.EEEE(myLocale.languageCode).format(dateTime);
}

bool isFullMonth(DateTime from, DateTime to) {
  // A month is "full" if the duration between from and to is roughly 28-31 days
  // and they start/end on the same relative day.
  final diff = to.difference(from).inDays;
  return diff >= 27 && diff <= 32;
}

bool isFullYear(DateTime from, DateTime to) {
  return from.month == 1 &&
      from.day == 1 &&
      new DateTime(from.year, 12, 31, 23, 59).isAtSameMomentAs(to);
}

bool isFullWeek(DateTime intervalFrom, DateTime intervalTo) {
  int firstDayOfWeek = getFirstDayOfWeekIndex();
  int lastDayOfWeek = _getLastDayOfWeek(firstDayOfWeek);
  
  return intervalTo.difference(intervalFrom).inDays == 6 &&
         intervalFrom.weekday == firstDayOfWeek &&
         intervalTo.weekday == lastDayOfWeek;
}

tz.TZDateTime createTzDateTime(DateTime utcDateTime, String timeZoneName) {
  tz.Location location = getLocation(timeZoneName);
  return tz.TZDateTime.from(utcDateTime, location);
}

tz.Location getLocation(String timeZoneName) {
  try {
    // Use the stored timezone name
    return tz.getLocation(timeZoneName);
  } catch (e) {
    // Fallback if the stored name is invalid or the timezone database isn't loaded
    print(
        'Warning: Could not find timezone $timeZoneName. Falling back to local.');
    return tz.local;
  }
}

/// Calculates the [from, to] range for a month starting on [startDay].
List<DateTime> calculateMonthCycle(DateTime referenceDate, int startDay) {
  int year = referenceDate.year;
  int month = referenceDate.month;

  // Determine if the cycle started in the previous calendar month
  if (referenceDate.day < startDay) {
    month -= 1;
  }

  // Helper for last day (handles the "31st" issue)
  int lastDayOf(int y, int m) => DateTime(y, m + 1, 0).day;

  // Start Date
  int safeStartDay = startDay.clamp(1, lastDayOf(year, month));
  DateTime from = DateTime(year, month, safeStartDay);

  // End Date (Start of next cycle minus 1 second)
  int nextMonth = month + 1;
  int nextYear = year;
  int safeEndDay = startDay.clamp(1, lastDayOf(nextYear, nextMonth));
  DateTime to = DateTime(nextYear, nextMonth, safeEndDay).subtract(const Duration(seconds: 1));

  return [from, to];
}

bool canShift(
    int shift,
    DateTime? customIntervalFrom,
    DateTime? customIntervalTo,
    HomepageTimeInterval hti,
    ) {
  // Moving Backward is always allowed
  if (shift < 0) return true;

  // Setup reference points for Forward shifting
  final DateTime now = DateTime.now();
  final DateTime today = DateTime(now.year, now.month, now.day);

  final DateTime currentFrom = customIntervalFrom ?? now;

  // Logic based on the Interval Type
  switch (hti) {
    case HomepageTimeInterval.CurrentMonth:
      // Calculate what the "Next" cycle's start date would be
      int startDay = getHomepageRecordsMonthStartDay();

      // We look at the month + 1
      DateTime shiftedFrom = DateTime(currentFrom.year, currentFrom.month + shift, startDay);

      // If the next interval starts after today, we can't shift forward
      return !shiftedFrom.isAfter(today);

    case HomepageTimeInterval.CurrentYear:
      // Check if the next year is greater than this year
      int targetYear = currentFrom.year + shift;
      return targetYear <= today.year;

    case HomepageTimeInterval.CurrentWeek:
      // Check if the start of the next week is after today
      DateTime shiftedWeekFrom = currentFrom.add(Duration(days: 7 * shift));
      return !shiftedWeekFrom.isAfter(today);

    case HomepageTimeInterval.All:
      // "All" interval usually doesn't shift
      return false;

    default:
      return false;
  }
}
