import 'dart:collection';
import "package:collection/collection.dart";
import 'package:flutter/cupertino.dart';
import 'package:i18n_extension/i18n_widget.dart';
import 'package:intl/intl.dart';
import 'package:intl/number_symbols_data.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/models/records-per-day.dart';
import 'package:intl/src/intl_helpers.dart' as helpers;

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

String getLocaleDecimalSeparator() {
  String myLocale = I18n.locale.toString();
  String? existingLocale = helpers.verifiedLocale(myLocale, localeExists, null);
  if (existingLocale == null) {
    return ".";
  }
  return numberFormatSymbols[existingLocale]?.DECIMAL_SEP;
}

bool getOverwriteDotValue() {
  return ServiceConfig.sharedPreferences?.getBool("overwriteDotValueWithComma") ?? getLocaleDecimalSeparator() == ",";
}

String getCurrencyValueString(double? value, { turnOffGrouping = false }) {
  if (value == null) return "";
  NumberFormat numberFormat;
  bool useGroupSeparator = ServiceConfig.sharedPreferences?.getBool("useGroupSeparator") ?? true;
  int decimalDigits = ServiceConfig.sharedPreferences?.getInt("numDecimalDigits") ?? 2;
  try {
    Locale myLocale = I18n.locale;
    numberFormat = new NumberFormat.currency(
        locale: myLocale.toString(), symbol: "", decimalDigits: decimalDigits);
  } on Exception catch (_) {
    numberFormat = new NumberFormat.currency(
        locale: "en_US", symbol: "", decimalDigits: decimalDigits);
  }
  bool mustRemoveGrouping = !useGroupSeparator || turnOffGrouping;
  if (mustRemoveGrouping) {
    numberFormat.turnOffGrouping();
  }
  String result = numberFormat.format(value);
  bool userDefinedGroupingSeparator = ServiceConfig.sharedPreferences!.containsKey("groupSeparator");
  if (!mustRemoveGrouping && userDefinedGroupingSeparator) {
    String localeGroupingSeparator = getLocaleGroupingSeparator()!;
    String groupingSeparatorByTheUser = getUserDefinedGroupingSeparator()!;
    result = result.replaceAll(localeGroupingSeparator, groupingSeparatorByTheUser);
  }
  return result;
}

double? tryParseCurrencyString(String toParse) {
  try {
    Locale myLocale = I18n.locale;
    Intl.defaultLocale = myLocale.toString();
    // Clean up from user defined grouping separator if they ever
    // end up here
    var userDefinedGroupingSeparator = getUserDefinedGroupingSeparator();
    if (userDefinedGroupingSeparator != null) {
      toParse = toParse.replaceAll(userDefinedGroupingSeparator, "");
    }
    num f = NumberFormat().parse(toParse);
    return f.toDouble();
  } catch (e) {
    return null;
  }
}

AssetImage getBackgroundImage() {
  if (!ServiceConfig.isPremium) {
    return AssetImage('assets/background.jpg');
  } else {
    try {
      var now = DateTime.now();
      String month = now.month.toString();
      return AssetImage('assets/bkg_' + month + '.jpg');
    } on Exception catch (_) {
      return AssetImage('assets/background.jpg');
    }
  }
}
