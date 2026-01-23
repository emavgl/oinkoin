import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'first_day_of_week_localizations.dart';

class DatePickerUtils {
  /// Wraps the date picker with appropriate locale settings based on the
  /// provided [firstDayOfWeek] preference (0=Default, 1=Monday, 7=Sunday, etc).
  /// This ensures the calendar displays with the correct week start day
  /// while preserving the existing language/locale.
  static Widget buildDatePickerWithFirstDayOfWeek(
      BuildContext context, Widget? child, int firstDayOfWeek) {
    if (firstDayOfWeek == 0) {
      // System default, do nothing (or return child as is)
      return child ?? Container();
    }

    // Use custom delegate wrapper to override firstDayOfWeekIndex
    // while keeping the original locale's strings
    return Localizations.override(
      context: context,
      delegates: [
        FirstDayOfWeekLocalizationsDelegate(
          GlobalMaterialLocalizations.delegate,
          firstDayOfWeek,
        ),
      ],
      child: child ?? Container(),
    );
  }
}
