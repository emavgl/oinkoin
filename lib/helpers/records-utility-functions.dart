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
      movementsPerDay
          .addFirst(new RecordsPerDay(groupedDay, records: groupedMovements));
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
  String existingCurrencyLocale = ServiceConfig.currencyLocale.toString();
  NumberFormat currencyLocaleNumberFormat = new NumberFormat.currency(locale: existingCurrencyLocale);
  return currencyLocaleNumberFormat.symbols.GROUP_SEP;
}

String getLocaleDecimalSeparator() {
  String existingCurrencyLocale = ServiceConfig.currencyLocale.toString();
  NumberFormat currencyLocaleNumberFormat = new NumberFormat.currency(locale: existingCurrencyLocale);
  return currencyLocaleNumberFormat.symbols.DECIMAL_SEP;
}

String? getUserDefinedGroupingSeparator() {
  return ServiceConfig.sharedPreferences!.getString("groupSeparator");
}

String getGroupingSeparator() {
  String s = ServiceConfig.sharedPreferences!.getString("groupSeparator") ??
      getLocaleGroupingSeparator();
  return s;
}

String getDecimalSeparator() {
  String s = ServiceConfig.sharedPreferences!.getString("decimalSeparator") ??
      getLocaleDecimalSeparator();
  return s;
}

bool getOverwriteDotValue() {
  if (getDecimalSeparator() == ".") return false;
  return ServiceConfig.sharedPreferences
          ?.getBool("overwriteDotValueWithComma") ??
      getDecimalSeparator() == ",";
}

Locale getCurrencyLocale() {
  return ServiceConfig.currencyLocale!;
}

bool usesWesternArabicNumerals(Locale locale) {
  NumberFormat numberFormat = new NumberFormat.currency(
      locale: locale.toString(), symbol: "", decimalDigits: 2);

  numberFormat.turnOffGrouping();

  return numberFormat.format(1234).contains("1234");
}

NumberFormat getNumberFormatWithCustomizations(
    {turnOffGrouping = false, locale}) {
  NumberFormat? numberFormat;

  String? userDefinedGroupSeparator =
  ServiceConfig.sharedPreferences?.getString("groupSeparator");
  int decimalDigits =
      ServiceConfig.sharedPreferences?.getInt("numDecimalDigits") ?? 2;

  try {

    if (locale == null) {
      locale = getCurrencyLocale();
    }

    NumberFormat referenceNumberFormat = new NumberFormat.currency(
        locale: locale.toString(), symbol: "", decimalDigits: decimalDigits);

    numberFormatSymbols['custom_locale'] = new NumberSymbols(
        NAME: "c",
        DECIMAL_SEP: getDecimalSeparator(),
        GROUP_SEP: getGroupingSeparator(),
        PERCENT: referenceNumberFormat.symbols.PERCENT,
        ZERO_DIGIT: referenceNumberFormat.symbols.ZERO_DIGIT,
        PLUS_SIGN: referenceNumberFormat.symbols.PLUS_SIGN,
        MINUS_SIGN: referenceNumberFormat.symbols.MINUS_SIGN,
        EXP_SYMBOL: referenceNumberFormat.symbols.EXP_SYMBOL,
        PERMILL: referenceNumberFormat.symbols.PERMILL,
        INFINITY: referenceNumberFormat.symbols.INFINITY,
        NAN: referenceNumberFormat.symbols.NAN,
        DECIMAL_PATTERN: referenceNumberFormat.symbols.DECIMAL_PATTERN,
        SCIENTIFIC_PATTERN: referenceNumberFormat.symbols.SCIENTIFIC_PATTERN,
        PERCENT_PATTERN: referenceNumberFormat.symbols.PERCENT_PATTERN,
        CURRENCY_PATTERN: referenceNumberFormat.symbols.CURRENCY_PATTERN,
        DEF_CURRENCY_CODE: referenceNumberFormat.symbols.DEF_CURRENCY_CODE);

    numberFormat = new NumberFormat.currency(
        locale: "custom_locale", symbol: "", decimalDigits: decimalDigits);

    // Copy over some properties
    numberFormat.maximumIntegerDigits =
        referenceNumberFormat.maximumIntegerDigits;
    numberFormat.minimumIntegerDigits =
        referenceNumberFormat.minimumIntegerDigits;

    numberFormat.minimumExponentDigits =
        referenceNumberFormat.minimumExponentDigits;

    numberFormat.maximumFractionDigits =
        referenceNumberFormat.maximumFractionDigits;
    numberFormat.minimumFractionDigits =
        referenceNumberFormat.minimumFractionDigits;

    numberFormat.maximumSignificantDigits =
        referenceNumberFormat.maximumSignificantDigits;
    numberFormat.minimumSignificantDigits =
        referenceNumberFormat.minimumSignificantDigits;
  } on Exception catch (_) {
    numberFormat = new NumberFormat.currency(
        locale: "en_US", symbol: "", decimalDigits: decimalDigits);
  }

  bool mustRemoveGrouping = (userDefinedGroupSeparator != null &&
      userDefinedGroupSeparator.isEmpty) ||
      turnOffGrouping;

  if (mustRemoveGrouping) {
    numberFormat.turnOffGrouping();
  }

  return numberFormat;
}

String getCurrencyValueString(double? value, {turnOffGrouping = false}) {
  if (value == null) return "";
  NumberFormat numberFormat;
  if (turnOffGrouping) {
    numberFormat = ServiceConfig.currencyNumberFormatWithoutGrouping!;
  } else {
    numberFormat = ServiceConfig.currencyNumberFormat!;
  }
  return numberFormat.format(value);
}

double? tryParseCurrencyString(String toParse) {
  try {
    NumberFormat numberFormat = ServiceConfig.currencyNumberFormat!;
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
