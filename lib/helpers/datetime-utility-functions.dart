import 'dart:ui';

import 'package:i18n_extension/i18n_widget.dart';
import 'package:intl/intl.dart';

String getDateRangeStr(DateTime start, DateTime end) {
  /// Returns a string representing the range from :start to :end
  Locale myLocale = I18n.locale;
  DateTime lastDayOfTheMonth = (start.month < 12) ? new DateTime(start.year, start.month + 1, 0) : new DateTime(start.year + 1, 1, 0);
  lastDayOfTheMonth = lastDayOfTheMonth.add(Duration(hours: 23, minutes: 59));
  if (lastDayOfTheMonth.isAtSameMomentAs(end)) {
    // Visualizing an entire month
    String localeRepr = DateFormat.yMMMM(myLocale.languageCode).format(lastDayOfTheMonth);
    return localeRepr[0].toUpperCase() + localeRepr.substring(1); // capitalize
  } else {
    String startLocalRepr = DateFormat.yMMMd(myLocale.languageCode).format(start);
    String endLocalRepr = DateFormat.yMMMd(myLocale.languageCode).format(start);
    return startLocalRepr.split(",")[0] + " - " + endLocalRepr;
  }
}