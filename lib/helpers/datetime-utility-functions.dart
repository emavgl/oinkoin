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
  /// Returns a string representing the range from :start to :end
  Locale myLocale = I18n.locale;
  DateTime lastDayOfTheMonth = getEndOfMonth(start.year, start.month);
  if (lastDayOfTheMonth.isAtSameMomentAs(end)) {
    // Visualizing an entire month
    String localeRepr =
        DateFormat.yMMMM(myLocale.languageCode).format(lastDayOfTheMonth);
    return localeRepr[0].toUpperCase() + localeRepr.substring(1); // capitalize
  } else {
    String startLocalRepr =
        DateFormat.yMMMd(myLocale.languageCode).format(start);
    String endLocalRepr = DateFormat.yMMMd(myLocale.languageCode).format(end);
    if (start.year == end.year) {
      return startLocalRepr.split(",")[0] + " - " + endLocalRepr;
    }
    return startLocalRepr + " - " + endLocalRepr;
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

tz.TZDateTime createTzDateTime(DateTime utcDateTime, String timeZoneName) {
  tz.Location location;
  try {
    // Use the stored timezone name
    location = tz.getLocation(timeZoneName);
  } catch (e) {
    // Fallback if the stored name is invalid or the timezone database isn't loaded
    print(
        'Warning: Could not find timezone $timeZoneName. Falling back to local.');
    location = tz.local;
  }
  return tz.TZDateTime.from(utcDateTime, location);
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

  // Default: If it doesn't match any of the above conditions, return false
  return false;
}
