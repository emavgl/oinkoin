import 'dart:collection';
import "package:collection/collection.dart";
import 'package:flutter/cupertino.dart';
import 'package:i18n_extension/i18n_widget.dart';
import 'package:intl/intl.dart';
import 'package:intl/number_symbols_data.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/models/records-per-day.dart';
import 'package:intl/src/intl_helpers.dart' as helpers;
import 'package:intl/number_symbols.dart';
import '../services/service-config.dart';


List<RecordsPerDay> groupRecordsByDay(List<Record?> records) {
  /// Groups the record in days using the object MovementsPerDay.
  /// It returns a list of MovementsPerDay object, containing at least 1 movement.
  var movementsGroups = groupBy(records, (dynamic records) => records.date);
  Queue<RecordsPerDay> movementsPerDay = Queue();
  movementsGroups.forEach((k, groupedMovements) {
    if (groupedMovements.isNotEmpty) {
      DateTime? groupedDay = groupedMovements[0]!.dateTime;
      movementsPerDay.addFirst(new RecordsPerDay(groupedDay, records: groupedMovements));
    }
  });
  var movementsDayList = movementsPerDay.toList();
  movementsDayList.sort((b, a) => a.dateTime!.compareTo(b.dateTime!));
  return movementsDayList;
}

bool localeExists(String? localeName) {
  if (localeName == null) return false;
  return numberFormatSymbols.containsKey(localeName);
}

String getLocaleGroupingSeparator() {
  String myLocale = I18n.locale.toString();
  String? existingLocale = helpers.verifiedLocale(myLocale, localeExists, null);
  if (existingLocale == null) {
    return ",";
  }
  return numberFormatSymbols[existingLocale]?.GROUP_SEP;
}

String? getUserDefinedGroupingSeparator() {
  return ServiceConfig.sharedPreferences!.getString("groupSeparator");
}

String getGroupingSeparator() {
  return ServiceConfig.sharedPreferences!.getString("groupSeparator") ?? getLocaleGroupingSeparator();
}

String getDecimalSeparator() {
  return ServiceConfig.sharedPreferences!.getString("decimalSeparator") ?? getLocaleDecimalSeparator();
}

String getLocaleDecimalSeparator() {
  String myLocale = I18n.locale.toString();
  String? existingLocale = helpers.verifiedLocale(myLocale, localeExists, null);
  if (existingLocale == null) {
    return ".";
  }
  return numberFormatSymbols[existingLocale]?.DECIMAL_SEP;
}

bool getOverwriteDotValue() {
  if (getDecimalSeparator() == ".") return false;
  return ServiceConfig.sharedPreferences?.getBool("overwriteDotValueWithComma") ?? getDecimalSeparator() == ",";
}

Locale getCurrencyLocale() {
  return ServiceConfig.currencyLocale!;
}

String fixNumberFormatPattern(Locale locale, String pattern) {

  var decimalSeparator = getDecimalSeparator();
  var groupingSeparator = getGroupingSeparator();

  NumberFormat numberFormat = new NumberFormat.currency(
      locale: locale.toString(), symbol: "", decimalDigits: 2);

  return pattern
      .replaceAll(numberFormat.symbols.GROUP_SEP, groupingSeparator)
      .replaceAll(numberFormat.symbols.DECIMAL_SEP, decimalSeparator);
}

bool usesWesternArabicNumerals(Locale locale) {
  NumberFormat numberFormat = new NumberFormat.currency(
      locale: locale.toString(), symbol: "", decimalDigits: 2);

  numberFormat.turnOffGrouping();

  return numberFormat.format(1234).contains("1234");
}

NumberFormat getNumberFormatWithCustomizations({ turnOffGrouping = false, locale }) {
  NumberFormat? numberFormat = ServiceConfig.currencyNumberFormat;

  if (numberFormat == null) {
    String? userDefinedGroupSeparator = ServiceConfig.sharedPreferences?.getString("groupSeparator");
    int decimalDigits = ServiceConfig.sharedPreferences?.getInt("numDecimalDigits") ?? 2;

    try {

      if (locale == null) {
        locale = getCurrencyLocale();
      }

      numberFormat = new NumberFormat.currency(
          locale: locale.toString(), symbol: "", decimalDigits: decimalDigits);

      numberFormatSymbols['custom_locale'] = new NumberSymbols(
          NAME: "custom_locale",
          DECIMAL_SEP: getDecimalSeparator(),
          GROUP_SEP: getGroupingSeparator(),
          PERCENT: numberFormat.symbols.PERCENT,
          ZERO_DIGIT: numberFormat.symbols.ZERO_DIGIT,
          PLUS_SIGN: numberFormat.symbols.PLUS_SIGN,
          MINUS_SIGN: numberFormat.symbols.MINUS_SIGN,
          EXP_SYMBOL: numberFormat.symbols.EXP_SYMBOL,
          PERMILL: numberFormat.symbols.PERMILL,
          INFINITY: numberFormat.symbols.INFINITY,
          NAN: numberFormat.symbols.NAN,
          DECIMAL_PATTERN: fixNumberFormatPattern(locale, numberFormat.symbols.DECIMAL_PATTERN),
          SCIENTIFIC_PATTERN: fixNumberFormatPattern(locale, numberFormat.symbols.SCIENTIFIC_PATTERN),
          PERCENT_PATTERN: fixNumberFormatPattern(locale, numberFormat.symbols.PERCENT_PATTERN),
          CURRENCY_PATTERN: fixNumberFormatPattern(locale, numberFormat.symbols.CURRENCY_PATTERN),
          DEF_CURRENCY_CODE: numberFormat.symbols.DEF_CURRENCY_CODE
      );

      numberFormat = new NumberFormat.currency(
          locale: "custom_locale", symbol: "", decimalDigits: decimalDigits);

    } on Exception catch (_) {
      numberFormat = new NumberFormat.currency(
          locale: "en_US", symbol: "", decimalDigits: decimalDigits);
    }

    bool mustRemoveGrouping = (userDefinedGroupSeparator != null && userDefinedGroupSeparator.isEmpty) || turnOffGrouping;
    if (mustRemoveGrouping) {
      numberFormat.turnOffGrouping();
    }

    ServiceConfig.currencyNumberFormat = numberFormat;
  }

  return numberFormat;
}

String getCurrencyValueString(double? value, { turnOffGrouping = false, locale}) {
  if (value == null) return "";
  NumberFormat numberFormat = getNumberFormatWithCustomizations(turnOffGrouping: turnOffGrouping, locale: locale);
  return numberFormat.format(value);
}

double? tryParseCurrencyString(String toParse) {
  try {
    NumberFormat numberFormat = getNumberFormatWithCustomizations();
    double r = numberFormat.parse(toParse).toDouble();
    return r;
  } catch (e) {
    return null;
  }
}

AssetImage getBackgroundImage() {
  if (!ServiceConfig.isPremium) {
    return AssetImage('assets/images/background.jpg');
  } else {
    try {
      var now = DateTime.now();
      String month = now.month.toString();
      return AssetImage('assets/images/bkg_' + month + '.jpg');
    } on Exception catch (_) {
      return AssetImage('assets/images/background.jpg');
    }
  }
}
