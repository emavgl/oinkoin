import 'dart:ui';

import 'package:i18n_extension/i18n_extension.dart';
import 'package:intl/intl.dart';
import 'package:piggybank/statistics/statistics-models.dart';

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
