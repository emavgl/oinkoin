import 'dart:ui';

import 'package:i18n_extension/i18n_extension.dart';
import 'package:intl/intl.dart';
import 'package:piggybank/i18n.dart';
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
      String startLocalRepr =
          DateFormat.MMMd(myLocale.languageCode).format(earlier);
      String endLocalRepr =
          DateFormat.yMMMd(myLocale.languageCode).format(later);
      return startLocalRepr + " - " + endLocalRepr;
    } else {
      // Different years: show year for both dates
      String startLocalRepr =
          DateFormat.yMMMd(myLocale.languageCode).format(earlier);
      String endLocalRepr =
          DateFormat.yMMMd(myLocale.languageCode).format(later);
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

/// Returns the first day of the week (1=Monday, 7=Sunday) based on locale.
/// Different locales have different week start days:
/// - US, Brazil, China, Japan: Sunday (7)
/// - Arabic regions: Saturday (6)
/// - Most European and other locales: Monday (1)
int getFirstDayOfWeekIndex() {
  try {
    String localeStr = I18n.locale.toString();

    if (localeStr == 'en_US') return DateTime.sunday;
    if (localeStr.startsWith('pt_BR')) return DateTime.sunday;
    if (localeStr.startsWith('zh')) return DateTime.sunday;
    if (localeStr.startsWith('ja')) return DateTime.sunday;
    if (localeStr.startsWith('ar')) return DateTime.saturday;
  } catch (e) {
    // Locale not initialized, use default
  }

  return DateTime.monday; // Default for most locales
}

/// Returns the last day of the week based on the first day.
int _getLastDayOfWeek(int firstDayOfWeek) {
  return firstDayOfWeek == DateTime.monday
      ? DateTime.sunday
      : firstDayOfWeek - 1;
}

/// Calculates the number of days to offset from current day to reach target weekday.
/// Handles week wraparound (e.g., going from Monday to previous Sunday).
int _calculateDaysOffset(int fromWeekday, int toWeekday,
    {bool forward = false}) {
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
  int daysToAdd =
      _calculateDaysOffset(date.weekday, lastDayOfWeek, forward: true);
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
  return from.day == 1 &&
      getEndOfMonth(from.year, from.month).isAtSameMomentAs(to);
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

bool canShift(
  int shift,
  DateTime? customIntervalFrom,
  DateTime? customIntervalTo,
  HomepageTimeInterval hti,
) {
  // Get the current date
  DateTime currentDate = DateTime.now();
  currentDate = DateTime(currentDate.year, currentDate.month, currentDate.day);

  // Check if customIntervalFrom is not null
  if (customIntervalFrom != null) {
    // If it is a full month interval, check the destination month after shifting
    if (isFullMonth(customIntervalFrom, customIntervalTo!)) {
      // Create a new "from" date by shifting the month
      DateTime newFrom = DateTime(
          customIntervalFrom.year, customIntervalFrom.month + shift, 1);
      return !newFrom.isAfter(currentDate);
    }

    // If it is a full year interval, check the destination year after shifting
    if (isFullYear(customIntervalFrom, customIntervalTo)) {
      return customIntervalFrom.year + shift <= currentDate.year;
    }

    // If it is a full week interval, check the destination week after shifting
    if (isFullWeek(customIntervalFrom, customIntervalTo)) {
      DateTime newFrom = customIntervalFrom.add(Duration(days: 7 * shift));
      return !newFrom.isAfter(currentDate);
    }

    // If neither full month nor full year, return false (cannot shift)
    return false;
  }

  // If customIntervalFrom is null, check based on the HomepageTimeInterval setting
  DateTime d = DateTime.now();

  // If it's the current month interval, check if shifting the month results in a valid date range
  if (hti == HomepageTimeInterval.CurrentMonth) {
    DateTime newFrom = DateTime(d.year, d.month + shift, 1);
    return newFrom.isBefore(currentDate);
  }

  // If it's the current year interval, check if shifting the year results in a valid date range
  if (hti == HomepageTimeInterval.CurrentYear) {
    DateTime newFrom = DateTime(d.year + shift, d.month, 1);
    return newFrom.year + shift <= currentDate.year;
  }

  // If it's the current week interval, check if shifting the week results in a valid date range
  if (hti == HomepageTimeInterval.CurrentWeek) {
    DateTime currentWeekStart = getStartOfWeek(d);
    DateTime newFrom = currentWeekStart.add(Duration(days: 7 * shift));
    return !newFrom.isAfter(currentDate);
  }

  // Default: If it doesn't match any of the above conditions, return false
  return false;
}
