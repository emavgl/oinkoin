import 'dart:collection';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/number_symbols.dart';
import 'package:intl/number_symbols_data.dart';
import 'package:piggybank/i18n.dart';
import 'package:piggybank/models/currency.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/models/records-per-day.dart';
import 'package:piggybank/models/wallet.dart';
import 'package:piggybank/services/database/database-interface.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/settings/constants/homepage-time-interval.dart';
import 'package:piggybank/settings/constants/overview-time-interval.dart';
import 'package:piggybank/settings/constants/preferences-keys.dart';
import 'package:piggybank/settings/currencies-page.dart';
import 'package:piggybank/settings/preferences-utils.dart';

import 'banner-image-service.dart';
import 'datetime-utility-functions.dart';

/// Placeholder shown instead of monetary amounts when privacy mode is on.
const String obscuredAmountText = '****';

List<RecordsPerDay> groupRecordsByDay(List<Record?> records) {
  /// Groups the records by days using a Map<DateTime, List<Record>>.
  /// It returns a list of RecordsPerDay objects, each containing at least 1 record.
  Map<DateTime, List<Record?>> movementsGroups = {};

  // Iterate over each record and group them by date (year, month, day).
  for (var record in records) {
    if (record != null) {
      DateTime dateKey = DateTime(
          record.dateTime.year, record.dateTime.month, record.dateTime.day);

      if (!movementsGroups.containsKey(dateKey)) {
        movementsGroups[dateKey] = [];
      }
      movementsGroups[dateKey]!.add(record);
    }
  }

  // Convert the map to a queue of RecordsPerDay objects.
  Queue<RecordsPerDay> movementsPerDay = Queue();
  movementsGroups.forEach((date, groupedMovements) {
    if (groupedMovements.isNotEmpty) {
      groupedMovements.sort((a, b) {
        if (a == null || b == null) return 0;
        final timeCmp = b.dateTime.compareTo(a.dateTime);
        if (timeCmp != 0) return timeCmp;
        return (b.id ?? 0).compareTo(a.id ?? 0);
      });
      movementsPerDay.addFirst(RecordsPerDay(date, records: groupedMovements));
    }
  });

  // Convert the queue to a list and sort it in descending order by date.
  var movementsDayList = movementsPerDay.toList();
  movementsDayList.sort((b, a) => a.dateTime!.compareTo(b.dateTime!));

  return movementsDayList;
}

String getGroupingSeparator() {
  return PreferencesUtils.getOrDefault<String>(
      ServiceConfig.sharedPreferences!, PreferencesKeys.groupSeparator)!;
}

String getDecimalSeparator() {
  return PreferencesUtils.getOrDefault<String>(
      ServiceConfig.sharedPreferences!, PreferencesKeys.decimalSeparator)!;
}

bool getOverwriteDotValue() {
  if (getDecimalSeparator() == ".") return false;
  return PreferencesUtils.getOrDefault<bool>(ServiceConfig.sharedPreferences!,
      PreferencesKeys.overwriteDotValueWithComma)!;
}

bool getOverwriteCommaValue() {
  if (getDecimalSeparator() == ",") return false;
  return PreferencesUtils.getOrDefault<bool>(ServiceConfig.sharedPreferences!,
      PreferencesKeys.overwriteCommaValueWithDot)!;
}

int getNumberDecimalDigits() {
  return PreferencesUtils.getOrDefault<int>(
    ServiceConfig.sharedPreferences!,
    PreferencesKeys.numberDecimalDigits,
  )!;
}

/// Resolves the effective decimal-digit count for an amount field.
///
/// Priority: [fieldOverride] (an explicit per-field value) wins first, then
/// the per-currency override configured for [currencyCode] (see
/// [getCurrencyDecimalDigitsOverride]), then the global
/// [getNumberDecimalDigits] preference. Centralizes the fallback so every
/// amount-input call site (formatters, hint text, rounding, display
/// formatting) agrees on the same value.
int resolveDecimalDigits(int? fieldOverride, {String? currencyCode}) {
  if (fieldOverride != null) return fieldOverride;
  final currencyOverride = getCurrencyDecimalDigitsOverride(currencyCode);
  if (currencyOverride != null) return currencyOverride;
  return getNumberDecimalDigits();
}

bool getAmountInputAutoDecimalShift() {
  if (getNumberDecimalDigits() <= 0) return false;
  return PreferencesUtils.getOrDefault<bool>(
    ServiceConfig.sharedPreferences!,
    PreferencesKeys.amountInputAutoDecimalShift,
  )!;
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

/// Builds a [NumberFormat] using the user's locale/separator customizations.
///
/// If [decimalDigits] is provided, it overrides the global
/// [PreferencesKeys.numberDecimalDigits] preference for this format only.
NumberFormat getNumberFormatWithCustomizations(
    {turnOffGrouping = false, locale, int? decimalDigits}) {
  NumberFormat? numberFormat;

  String? userDefinedGroupSeparator = PreferencesUtils.getOrDefault<String?>(
      ServiceConfig.sharedPreferences!, PreferencesKeys.groupSeparator);

  decimalDigits ??= PreferencesUtils.getOrDefault<int>(
      ServiceConfig.sharedPreferences!, PreferencesKeys.numberDecimalDigits)!;

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

void setNumberFormatCache() {
  Locale toSet = ServiceConfig.currencyLocale!;
  ServiceConfig.currencyNumberFormat =
      getNumberFormatWithCustomizations(locale: toSet);
  ServiceConfig.currencyNumberFormatWithoutGrouping =
      getNumberFormatWithCustomizations(locale: toSet, turnOffGrouping: true);
}

String getCurrencyValueString(double? value, {turnOffGrouping = false}) {
  if (value == null) return "";
  NumberFormat? numberFormat;
  if (turnOffGrouping) {
    numberFormat = ServiceConfig.currencyNumberFormatWithoutGrouping;
  } else {
    numberFormat = ServiceConfig.currencyNumberFormat;
  }
  if (numberFormat == null) {
    setNumberFormatCache();
    if (turnOffGrouping) {
      numberFormat = ServiceConfig.currencyNumberFormatWithoutGrouping!;
    } else {
      numberFormat = ServiceConfig.currencyNumberFormat!;
    }
  }
  return numberFormat.format(value);
}

/// Like [tryParseCurrencyString] but preserves a leading minus sign.
/// Use this when the input may legitimately be negative (e.g. wallet balance).
double? tryParseSignedCurrencyString(String toParse) {
  final isNegative = toParse.trimLeft().startsWith('-');
  final result = tryParseCurrencyString(toParse.replaceFirst('-', ''));
  if (result == null) return null;
  return isNegative ? -result : result;
}

double? tryParseCurrencyString(String toParse) {
  try {
    // Apparently numberFormat.parse is very fragile if for some reason
    // the string contains characters which are not the decimal or the
    // group separator, for this reason, it is better to strip those characters
    // in advance.
    toParse = stripUnknownPatternCharacters(toParse);
    NumberFormat? numberFormat = ServiceConfig.currencyNumberFormat;
    if (numberFormat == null) {
      setNumberFormatCache();
      numberFormat = ServiceConfig.currencyNumberFormat!;
    }
    double r = numberFormat.parse(toParse).toDouble();
    return r;
  } catch (e) {
    return null;
  }
}

String stripUnknownPatternCharacters(String toParse) {
  String decimalSeparator = getDecimalSeparator();
  String groupingSeparator = getGroupingSeparator();
  // Use a regular expression to keep only digits,
  // the decimal separator, and the grouping separator
  String pattern = '[0-9' +
      RegExp.escape(decimalSeparator) +
      RegExp.escape(groupingSeparator) +
      ']';
  RegExp regex = RegExp(pattern);
  String result =
      toParse.split('').where((char) => regex.hasMatch(char)).join();
  return result;
}

// -1 for default
ImageProvider getBackgroundImage(int monthIndex) {
  return BannerImageService.getBannerImage(monthIndex);
}

Future<List<Record?>> getAllRecords(DatabaseInterface database,
    {int? profileId}) async {
  return await database.getAllRecords(profileId: profileId);
}

Future<DateTime?> getDateTimeFirstRecord(DatabaseInterface database) async {
  return await database.getDateTimeFirstRecord();
}

Future<List<Record?>> getRecordsByInterval(
    DatabaseInterface database, DateTime? _from, DateTime? _to,
    {int? profileId}) async {
  return await database.getAllRecordsInInterval(_from, _to,
      profileId: profileId);
}

Future<List<Record?>> getRecordsByMonth(
    DatabaseInterface database, int year, int month,
    {int? profileId}) async {
  /// Returns the list of movements of a given month identified by
  /// :year and :month integers.
  DateTime _from = new DateTime(year, month, 1);
  DateTime _to = getEndOfMonth(year, month);
  return await getRecordsByInterval(database, _from, _to, profileId: profileId);
}

Future<List<Record?>> getRecordsByYear(DatabaseInterface database, int year,
    {int? profileId}) async {
  /// Returns the list of movements of a given year identified by
  /// :year integer.
  DateTime _from = new DateTime(year, 1, 1);
  DateTime _to = new DateTime(year, 12, 31, 23, 59);
  return await getRecordsByInterval(database, _from, _to, profileId: profileId);
}

HomepageTimeInterval getHomepageTimeIntervalEnumSetting() {
  var userDefinedHomepageIntervalIndex = PreferencesUtils.getOrDefault<int>(
      ServiceConfig.sharedPreferences!, PreferencesKeys.homepageTimeInterval)!;
  return HomepageTimeInterval.values[userDefinedHomepageIntervalIndex];
}

OverviewTimeInterval getHomepageOverviewWidgetTimeIntervalEnumSetting() {
  var userDefinedHomepageIntervalIndex = PreferencesUtils.getOrDefault<int>(
      ServiceConfig.sharedPreferences!,
      PreferencesKeys.homepageOverviewWidgetTimeInterval)!;
  return OverviewTimeInterval.values[userDefinedHomepageIntervalIndex];
}

int getHomepageRecordsMonthStartDay() {
  return PreferencesUtils.getOrDefault<int>(ServiceConfig.sharedPreferences!,
      PreferencesKeys.homepageRecordsMonthStartDay)!;
}

// 'MMMd' provides the localized month name and day (e.g., "Jan 15")
String getShortDateStr(DateTime date) {
  return DateFormat.MMMd().format(date);
}

String getHeaderFromHomepageTimeInterval(HomepageTimeInterval timeInterval) {
  DateTime _now = DateTime.now();
  switch (timeInterval) {
    case HomepageTimeInterval.CurrentMonth:
      return getMonthStr(_now);
    case HomepageTimeInterval.CurrentYear:
      return getYearStr(_now);
    case HomepageTimeInterval.All:
      return "All records".i18n;
    case HomepageTimeInterval.CurrentWeek:
      return getWeekStr(_now);
  }
}

Future<List<DateTime>> getTimeIntervalFromHomepageTimeInterval(
    DatabaseInterface database, HomepageTimeInterval timeInterval,
    {int monthStartDay = 1}) async {
  DateTime now = DateTime.now();

  if (timeInterval == HomepageTimeInterval.All) {
    DateTime? firstRecord = await database.getDateTimeFirstRecord();
    if (firstRecord == null) {
      // Fallback to current month if no records exist
      return calculateInterval(HomepageTimeInterval.CurrentMonth, now,
          monthStartDay: monthStartDay);
    }
    return [firstRecord, now];
  }

  return calculateInterval(timeInterval, now, monthStartDay: monthStartDay);
}

HomepageTimeInterval mapOverviewTimeIntervalToHomepageTimeInterval(
    OverviewTimeInterval overviewTimeInterval) {
  if (overviewTimeInterval == OverviewTimeInterval.FixAllRecords) {
    return HomepageTimeInterval.All;
  }
  if (overviewTimeInterval == OverviewTimeInterval.FixCurrentYear) {
    return HomepageTimeInterval.CurrentYear;
  }
  if (overviewTimeInterval == OverviewTimeInterval.FixCurrentMonth) {
    return HomepageTimeInterval.CurrentMonth;
  }
  return HomepageTimeInterval.CurrentMonth;
}

Future<List<Record?>> getRecordsByHomepageTimeInterval(
    DatabaseInterface database, HomepageTimeInterval timeInterval,
    {int monthStartDay = 1, int? profileId}) async {
  DateTime _now = DateTime.now();
  switch (timeInterval) {
    case HomepageTimeInterval.CurrentMonth:
      var cycle = calculateMonthCycle(DateTime.now(), monthStartDay);
      return await getRecordsByInterval(database, cycle[0], cycle[1],
          profileId: profileId);
    case HomepageTimeInterval.CurrentYear:
      return await getRecordsByYear(database, _now.year, profileId: profileId);
    case HomepageTimeInterval.All:
      return await getAllRecords(database, profileId: profileId);
    case HomepageTimeInterval.CurrentWeek:
      return await getRecordsByInterval(
          database, getStartOfWeek(_now), getEndOfWeek(_now),
          profileId: profileId);
  }
}

/// Maps wallet IDs to their effective currency codes.
/// Wallets without an assigned currency are treated as having the predefined
/// user currency (if any). Returns null for wallets when no currency is set
/// anywhere, which signals callers to omit currency signs.
Map<int, String?> buildWalletCurrencyMap(List<Wallet> wallets) {
  final defaultCurrency = getDefaultCurrency();
  final effectiveDefault =
      (defaultCurrency != null && defaultCurrency.isNotEmpty)
          ? defaultCurrency
          : null;
  return {
    for (final w in wallets)
      if (w.id != null)
        w.id!: (w.currency != null && w.currency!.isNotEmpty)
            ? w.currency
            : effectiveDefault
  };
}

/// Returns a raw per-currency breakdown of record values (unconverted).
/// Key = ISO currency code (empty string for wallets with no currency).
Map<String, double> buildCurrencyBreakdown(
  Iterable<Record?> records,
  Map<int, String?> walletCurrencyMap, {
  bool isAbsValue = false,
}) {
  final breakdown = <String, double>{};
  for (final r in records.where((r) => r != null).cast<Record>()) {
    final currency =
        (r.walletId != null ? walletCurrencyMap[r.walletId] : null) ?? '';
    final val = isAbsValue ? r.value!.abs() : r.value!;
    breakdown[currency] = (breakdown[currency] ?? 0.0) + val;
  }
  return breakdown;
}

/// Returns [records] excluding transfers between the user's own wallets:
/// they net to zero and shouldn't count toward a balance total, matching
/// [RecordsPerDay.balance]'s own exclusion of transfers from income/expenses.
List<Record?> balanceRelevantRecords(List<Record?> records) =>
    records.where((r) => r != null && !r.isTransfer).toList();

/// Returns true when [records] span more than one currency group,
/// meaning a per-currency breakdown is meaningful.
bool hasMixedCurrencies(
  Iterable<Record?> records,
  Map<int, String?> walletCurrencyMap,
) =>
    buildCurrencyBreakdown(records, walletCurrencyMap).length > 1;

/// Result of a currency-aware records total computation.
class RecordsTotalResult {
  final double total;
  final String? currency; // ISO code, or null if no currency context

  const RecordsTotalResult(this.total, this.currency);
}

/// Computes the total of [records], converting values to the default currency
/// when multiple wallet currencies are involved.
///
/// [walletCurrencyMap]: maps wallet ID → currency ISO code.
/// [isAbsValue]: if true, use the absolute value of each record (for expense/income totals).
RecordsTotalResult computeConvertedTotal(
  Iterable<Record?> records,
  Map<int, String?> walletCurrencyMap, {
  bool isAbsValue = false,
}) {
  final nonNull = records.where((r) => r != null).cast<Record>().toList();
  if (nonNull.isEmpty) {
    return const RecordsTotalResult(0.0, null);
  }

  // Determine unique non-null currencies among the wallets used by these records
  final usedWalletIds = nonNull.map((r) => r.walletId).whereType<int>().toSet();
  final uniqueCurrencies = usedWalletIds
      .map((id) => walletCurrencyMap[id])
      .where((c) => c != null && c.isNotEmpty)
      .cast<String>()
      .toSet();

  final defaultCurrency = getDefaultCurrency();

  if (uniqueCurrencies.isEmpty) {
    final total = nonNull.fold<double>(
        0.0, (sum, r) => sum + (isAbsValue ? r.value!.abs() : r.value!));
    // If a default currency is set, treat no-currency records as being in that currency
    final currency = (defaultCurrency != null && defaultCurrency.isNotEmpty)
        ? defaultCurrency
        : null;
    return RecordsTotalResult(total, currency);
  }

  if (uniqueCurrencies.length == 1) {
    final walletCurrency = uniqueCurrencies.first;
    // If a default currency is set and it differs from the wallet currency, convert
    if (defaultCurrency != null && defaultCurrency != walletCurrency) {
      final entries = nonNull.map((r) => _CurrencyAmount(
            r.walletId != null ? walletCurrencyMap[r.walletId] : null,
            isAbsValue ? r.value!.abs() : r.value!,
          ));
      final total = _convertAmountsToDefaultCurrency(
          entries, defaultCurrency, getConversionRates());
      return RecordsTotalResult(total, defaultCurrency);
    }
    final total = nonNull.fold<double>(
        0.0, (sum, r) => sum + (isAbsValue ? r.value!.abs() : r.value!));
    return RecordsTotalResult(total, walletCurrency);
  }

  if (defaultCurrency == null) {
    // Multiple currencies but no default set — return null currency
    final total = nonNull.fold<double>(
        0.0, (sum, r) => sum + (isAbsValue ? r.value!.abs() : r.value!));
    return RecordsTotalResult(total, null);
  }
  final entries = nonNull.map((r) => _CurrencyAmount(
        r.walletId != null ? walletCurrencyMap[r.walletId] : null,
        isAbsValue ? r.value!.abs() : r.value!,
      ));
  final total = _convertAmountsToDefaultCurrency(
      entries, defaultCurrency, getConversionRates());
  return RecordsTotalResult(total, defaultCurrency);
}

/// Computes the total of [records] expressed in [targetCurrency],
/// converting each record's value from its wallet currency as needed.
/// Falls back to raw sum if no conversion rate is available for a record.
RecordsTotalResult computeTotalInCurrency(
  Iterable<Record?> records,
  Map<int, String?> walletCurrencyMap,
  String targetCurrency, {
  bool isAbsValue = false,
}) {
  final nonNull = records.where((r) => r != null).cast<Record>().toList();
  if (nonNull.isEmpty) return RecordsTotalResult(0.0, targetCurrency);

  final entries = nonNull.map((r) => _CurrencyAmount(
        r.walletId != null ? walletCurrencyMap[r.walletId] : null,
        isAbsValue ? r.value!.abs() : r.value!,
      ));
  final total = _convertAmountsToDefaultCurrency(
      entries, targetCurrency, getConversionRates());
  return RecordsTotalResult(total, targetCurrency);
}

/// Formats [value] with currency symbol, position, and locale-appropriate
/// separators using the customized number format.
///
/// Uses [currencyCode]'s per-currency decimal digits override when
/// configured (see [getCurrencyDecimalDigitsOverride]), otherwise falls back
/// to the global decimal digits setting.
String formatCurrencyAmount(double value, String currencyCode) {
  final decDigits = resolveDecimalDigits(null, currencyCode: currencyCode);
  final numberFormat = _numberFormatForDecimalDigits(decDigits);
  final currencySymbol = getCurrencySymbol(currencyCode);
  final formatted = numberFormat.format(value);
  return insertCurrencySymbol(formatted, currencySymbol);
}

/// Returns a [NumberFormat] for [decDigits], reusing the cached global format
/// when it already uses that many digits, otherwise reading/populating
/// [ServiceConfig.perCurrencyNumberFormatCache].
NumberFormat _numberFormatForDecimalDigits(int decDigits) {
  if (decDigits == getNumberDecimalDigits()) {
    var numberFormat = ServiceConfig.currencyNumberFormat;
    if (numberFormat == null) {
      setNumberFormatCache();
      numberFormat = ServiceConfig.currencyNumberFormat;
    }
    return numberFormat!;
  }
  return ServiceConfig.perCurrencyNumberFormatCache.putIfAbsent(
    decDigits,
    () => getNumberFormatWithCustomizations(decimalDigits: decDigits),
  );
}

/// Gets the currency symbol for a given currency code.
String getCurrencySymbol(String currencyCode) {
  final currencyInfo = CurrencyInfo.byCode(currencyCode);
  if (currencyInfo != null) return currencyInfo.symbol;

  try {
    return NumberFormat.simpleCurrency(name: currencyCode).currencySymbol;
  } catch (_) {
    return currencyCode;
  }
}

int getCurrencySymbolPosition() {
  return PreferencesUtils.getOrDefault<int>(
    ServiceConfig.sharedPreferences!,
    PreferencesKeys.currencySymbolPosition,
  )!;
}

bool getCurrencySymbolSpacing() {
  return PreferencesUtils.getOrDefault<int>(
        ServiceConfig.sharedPreferences!,
        PreferencesKeys.currencySymbolSpacing,
      ) ==
      0;
}

/// Inserts the currency symbol into a formatted number string.
/// The symbol is placed at the beginning or end based on the user's preference.
/// Adds a space between the symbol and the digits for left/right positions.
/// Respects the [PreferencesKeys.showCurrencySymbol] setting.
String insertCurrencySymbol(String formattedValue, String symbol) {
  if (!getShowCurrencySymbol()) return formattedValue;
  if (symbol.isEmpty || formattedValue.isEmpty) return formattedValue;
  if (formattedValue.startsWith(symbol) || formattedValue.endsWith(symbol)) {
    return formattedValue;
  }

  int position = getCurrencySymbolPosition();
  bool useSpace = getCurrencySymbolSpacing();
  String space = useSpace ? ' ' : '';

  if (position == 1) {
    // Left position: symbol before number
    return '$symbol$space$formattedValue';
  } else if (position == 2) {
    // Right position: symbol after number
    return '$formattedValue$space$symbol';
  }
  // Default: use locale default (symbol at start)
  return '$symbol$space$formattedValue';
}

/// Formats a [RecordsTotalResult] for display, adding the currency symbol if known.
String formatRecordsTotalResult(RecordsTotalResult result) {
  if (result.currency != null && result.currency!.isNotEmpty) {
    return formatCurrencyAmount(result.total, result.currency!);
  }
  return getCurrencyValueString(result.total);
}

/// Returns the display label for [wallet] in a record form field.
/// Shows "Name · ISO" when the wallet has a currency, otherwise just "Name".
/// Falls back to [emptyLabel] when [wallet] is null.
String formatWalletDisplay(Wallet? wallet, {String emptyLabel = ''}) {
  if (wallet == null) return emptyLabel;
  if (wallet.currency != null && wallet.currency!.isNotEmpty) {
    return '${wallet.name} · ${wallet.currency!}';
  }
  return wallet.name;
}

/// Formats a wallet's balance with its currency symbol if set.
String formatWalletBalance(Wallet wallet) {
  final balance = wallet.balance ?? 0.0;
  if (wallet.currency == null || wallet.currency!.isEmpty) {
    return getCurrencyValueString(balance);
  }
  return formatCurrencyAmount(balance, wallet.currency!);
}

/// Splits [amount] (denominated in [currency]) into its original and converted
/// (default currency) display strings so callers can color each part
/// independently with [getAmountColor], matching the sign-based coloring used
/// for non-converted amounts.
///
/// Returns null when [currency] is empty, matches the default currency, or no
/// conversion rate is available — i.e. when the `<original> (<converted>)`
/// display does not apply.
({String original, String converted, double convertedValue})?
    splitAmountConversion(double amount, String currency) {
  if (currency.isEmpty) return null;
  final defaultCurrency = getDefaultCurrency();
  if (defaultCurrency == null || currency == defaultCurrency) return null;
  final converted = convertAmount(amount, currency, defaultCurrency);
  if (converted == null) return null;
  return (
    original: formatCurrencyAmount(amount, currency),
    converted: formatCurrencyAmount(converted, defaultCurrency),
    convertedValue: converted,
  );
}

/// Formats an amount with currency-aware display.
///
/// When [currency] differs from the user's default currency,
/// shows: `<original> (<converted>)` — original amount first,
/// converted to default currency in parentheses.
///
/// When [currency] matches the default (or no default is set),
/// shows just the formatted amount with its currency symbol.
String formatAmountWithCurrency(double amount, String currency) {
  if (currency.isEmpty) {
    return getCurrencyValueString(amount);
  }

  final parts = splitAmountConversion(amount, currency);
  if (parts != null) {
    return '${parts.original} (${parts.converted})';
  }

  return formatCurrencyAmount(amount, currency);
}

bool _colorizeEnabled() {
  final prefs = ServiceConfig.sharedPreferences;
  if (prefs == null) return false;
  return PreferencesUtils.getOrDefault<bool>(
      prefs, PreferencesKeys.colorizeAmounts)!;
}

Color _greenShade(Brightness brightness) => brightness == Brightness.dark
    ? Colors.green.shade400
    : Colors.green.shade700;

Color _redShade(Brightness brightness) =>
    brightness == Brightness.dark ? Colors.red.shade400 : Colors.red.shade700;

/// Returns the color used to display [amount], based purely on its sign:
/// green when positive or zero, red when negative. Returns null when amount
/// colorization is disabled.
Color? getAmountColor(double amount, Brightness brightness) {
  if (!_colorizeEnabled()) return null;
  return amount >= 0 ? _greenShade(brightness) : _redShade(brightness);
}

/// Returns the color to use for [record]'s amount.
///
/// A transfer between the user's own wallets nets to zero overall, so it's
/// colored neutrally (returns null) when both its wallets - or no wallet
/// filter at all - are currently visible. When exactly one side is visible
/// ([Record.isSingleSideTransferView], set by a wallet-filtered records
/// list), it's colored by sign like a normal record instead: red when
/// leaving the visible wallet, green when arriving into it - [record.value]
/// is already signed for that perspective by the filter that produced it.
/// Non-transfer records are always colored by sign.
Color? getRecordAmountColor(Record record, Brightness brightness) {
  if (record.isTransfer && !record.isSingleSideTransferView) return null;
  return getAmountColor(record.value ?? 0.0, brightness);
}

/// Returns a Widget displaying [amount] in [currency].
///
/// When [currency] differs from the user's default currency and a conversion
/// exists, shows the converted amount (in the default currency) on the first
/// line and the original amount on a second line in a slightly smaller font.
/// The original line is colored by sign via [getAmountColor] (using
/// [brightness]) when colorization is enabled, otherwise grey.
/// Otherwise returns a single-line [Text].
///
/// When [amount] is an absolute (sign-less) value but the color should reflect
/// the sign of the underlying data, pass that signed value as [colorValue]; it
/// is used only for coloring, never for the displayed text.
///
/// Pass [neutralColor] when the caller has already decided the amount should
/// not be colored by sign at all (e.g. a transfer between the user's own
/// wallets, which [mainStyle] already renders neutrally) - otherwise the
/// second line would still color itself by sign independently, producing a
/// red/green secondary amount underneath a neutral primary one.
Widget buildAmountWithCurrencyWidget(
  double amount,
  String currency, {
  TextStyle? mainStyle,
  Brightness? brightness,
  double? colorValue,
  bool neutralColor = false,
}) {
  if (currency.isEmpty) {
    return Text(getCurrencyValueString(amount),
        style: mainStyle, textAlign: TextAlign.right);
  }

  final defaultCurrency = getDefaultCurrency();
  if (defaultCurrency != null && currency != defaultCurrency) {
    final converted = convertAmount(amount, currency, defaultCurrency);
    if (converted != null) {
      final originalStr = formatCurrencyAmount(amount, currency);
      final convertedStr = formatCurrencyAmount(converted, defaultCurrency);
      final baseFontSize = mainStyle?.fontSize ?? 14.0;
      final primaryStyle =
          (mainStyle ?? const TextStyle()).copyWith(height: 1.1);
      final secondaryColor = !neutralColor && brightness != null
          ? getAmountColor(colorValue ?? amount, brightness)
          : null;
      final secondaryStyle = primaryStyle.copyWith(
        fontSize: (baseFontSize - 2).clamp(10.0, double.infinity),
        color: secondaryColor ?? Colors.grey,
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(convertedStr, style: primaryStyle, textAlign: TextAlign.right),
          Text(originalStr, style: secondaryStyle, textAlign: TextAlign.right),
        ],
      );
    }
  }

  return Text(formatCurrencyAmount(amount, currency),
      style: mainStyle, textAlign: TextAlign.right);
}

/// Sums [currencyAmountPairs] into a single total expressed in [defaultCurrency],
/// applying stored conversion [rates].
double _convertAmountsToDefaultCurrency(
  Iterable<_CurrencyAmount> currencyAmountPairs,
  String defaultCurrency,
  Map<String, double> rates,
) {
  double total = 0.0;
  for (final pair in currencyAmountPairs) {
    final currency = pair.currency;
    final amount = pair.amount;
    if (currency == null || currency.isEmpty || currency == defaultCurrency) {
      total += amount;
    } else {
      final rate = rates['${currency}_$defaultCurrency'];
      total += rate != null ? amount * rate : amount;
    }
  }
  return total;
}

class _CurrencyAmount {
  final String? currency;
  final double amount;
  const _CurrencyAmount(this.currency, this.amount);
}

/// Returns stored currency conversion rates as a Map<String, double>.
/// Keys are in "FROM_TO" format (e.g. "USD_EUR").
Map<String, double> getConversionRates() {
  final prefs = ServiceConfig.sharedPreferences;
  if (prefs == null) return {};
  final raw = prefs.getString(PreferencesKeys.currencyConversionRates);
  if (raw == null || raw.isEmpty) return {};
  try {
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(k, (v as num).toDouble()));
  } catch (_) {
    return {};
  }
}

/// Returns whether the currency symbol should be shown next to amounts.
bool getShowCurrencySymbol() {
  final prefs = ServiceConfig.sharedPreferences;
  if (prefs == null) return false;
  return PreferencesUtils.getOrDefault<bool>(
      prefs, PreferencesKeys.showCurrencySymbol)!;
}

/// Returns the default currency ISO code from preferences, or null if not set.
String? getDefaultCurrency() {
  final prefs = ServiceConfig.sharedPreferences;
  if (prefs == null) return null;
  final val = prefs.getString(PreferencesKeys.defaultCurrency);
  return (val == null || val.isEmpty) ? null : val;
}

/// Converts [amount] from [fromCurrency] to [toCurrency] using stored rates.
/// Returns null if no conversion rate is available.
double? convertAmount(double amount, String fromCurrency, String toCurrency) {
  if (fromCurrency == toCurrency) return amount;
  final rates = getConversionRates();
  // Direct rate: FROM_TO
  final directRate = rates['${fromCurrency}_$toCurrency'];
  if (directRate != null) return amount * directRate;
  // Inverse rate: TO_FROM
  final inverseRate = rates['${toCurrency}_$fromCurrency'];
  if (inverseRate != null && inverseRate != 0) return amount / inverseRate;
  // Via default currency
  final defaultCurrency = getDefaultCurrency();
  if (defaultCurrency != null &&
      defaultCurrency != fromCurrency &&
      defaultCurrency != toCurrency) {
    final toDefault = rates['${fromCurrency}_$defaultCurrency'];
    final fromDefault = rates['${toCurrency}_$defaultCurrency'];
    if (toDefault != null && fromDefault != null && fromDefault != 0) {
      return amount * toDefault / fromDefault;
    }
  }
  return null;
}

/// Returns a human-readable rate string like "1 USD = 0.92 EUR".
/// Returns null if no conversion rate is available.
String? getConversionRateString(String fromCurrency, String toCurrency) {
  if (fromCurrency == toCurrency) return null;
  final rates = getConversionRates();
  final directRate = rates['${fromCurrency}_$toCurrency'];
  if (directRate != null)
    return '1 $fromCurrency = ${directRate.toStringAsFixed(4)} $toCurrency';
  final inverseRate = rates['${toCurrency}_$fromCurrency'];
  if (inverseRate != null && inverseRate != 0) {
    return '1 $fromCurrency = ${(1 / inverseRate).toStringAsFixed(4)} $toCurrency';
  }
  final defaultCurrency = getDefaultCurrency();
  if (defaultCurrency != null &&
      defaultCurrency != fromCurrency &&
      defaultCurrency != toCurrency) {
    final toDefault = rates['${fromCurrency}_$defaultCurrency'];
    final fromDefault = rates['${toCurrency}_$defaultCurrency'];
    if (toDefault != null && fromDefault != null && fromDefault != 0) {
      final crossRate = toDefault / fromDefault;
      return '1 $fromCurrency = ${crossRate.toStringAsFixed(4)} $toCurrency';
    }
  }
  return null;
}

/// Computes a display string for the combined balance of [wallets].
/// Returns a plain formatted number when all wallets share no currency.
/// Returns a currency-formatted total when all share one currency.
/// For mixed currencies, converts to the default currency using stored rates.
String computeCombinedBalanceString(List<Wallet> wallets) {
  final result = computeCombinedBalanceResult(wallets);
  if (result.currency == null || result.currency!.isEmpty) {
    return getCurrencyValueString(result.total);
  }
  return formatCurrencyAmount(result.total, result.currency!);
}

/// Computes the combined balance of [wallets] as a [RecordsTotalResult].
/// Returns total in the shared currency when all wallets share one currency.
/// For mixed currencies, converts to the default currency.
RecordsTotalResult computeCombinedBalanceResult(List<Wallet> wallets) {
  if (wallets.isEmpty) return const RecordsTotalResult(0.0, null);

  final uniqueCurrencies = wallets
      .map((w) => w.currency)
      .where((c) => c != null && c.isNotEmpty)
      .toSet()
      .cast<String>();

  final defaultCurrency = getDefaultCurrency();

  if (uniqueCurrencies.isEmpty) {
    final total =
        wallets.fold<double>(0.0, (sum, w) => sum + (w.balance ?? 0.0));
    // If a default currency is set, treat no-currency wallets as being in that currency
    final currency = (defaultCurrency != null && defaultCurrency.isNotEmpty)
        ? defaultCurrency
        : null;
    return RecordsTotalResult(total, currency);
  }

  if (uniqueCurrencies.length == 1) {
    final walletCurrency = uniqueCurrencies.first;
    // If a default currency is set and it differs from the wallet currency, convert
    if (defaultCurrency != null && defaultCurrency != walletCurrency) {
      final entries =
          wallets.map((w) => _CurrencyAmount(w.currency, w.balance ?? 0.0));
      final total = _convertAmountsToDefaultCurrency(
          entries, defaultCurrency, getConversionRates());
      return RecordsTotalResult(total, defaultCurrency);
    }
    final total =
        wallets.fold<double>(0.0, (sum, w) => sum + (w.balance ?? 0.0));
    return RecordsTotalResult(total, walletCurrency);
  }

  if (defaultCurrency == null) {
    // Multiple currencies but no default set — return null currency
    final total =
        wallets.fold<double>(0.0, (sum, w) => sum + (w.balance ?? 0.0));
    return RecordsTotalResult(total, null);
  }
  final entries =
      wallets.map((w) => _CurrencyAmount(w.currency, w.balance ?? 0.0));
  final total = _convertAmountsToDefaultCurrency(
      entries, defaultCurrency, getConversionRates());
  return RecordsTotalResult(total, defaultCurrency);
}
