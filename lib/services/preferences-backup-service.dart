import 'dart:convert';

import 'package:piggybank/models/category-icons.dart';
import 'package:piggybank/services/logger.dart';
import 'package:piggybank/settings/constants/preferences-keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Handles the portable subset of SharedPreferences used by backup files.
///
/// Preferences are intentionally restored one at a time. A removed key,
/// changed type, invalid enum/index, malformed serialized value, or failing
/// setter can never prevent the remaining settings from being restored.
class PreferencesBackupService {
  static final _logger = Logger.withContext('PreferencesBackupService');

  static const _savedCsvMappingsKey = 'csv_import_saved_mappings';

  static final Set<String> _portableKeys = {
    // Appearance and localization
    PreferencesKeys.themeColor,
    PreferencesKeys.themeMode,
    PreferencesKeys.languageLocale,
    PreferencesKeys.firstDayOfWeek,
    PreferencesKeys.dateFormat,
    PreferencesKeys.colorizeAmounts,
    PreferencesKeys.enableNavigationBarAnimations,
    PreferencesKeys.privacyMode,

    // Number and currency formatting
    PreferencesKeys.decimalSeparator,
    PreferencesKeys.groupSeparator,
    PreferencesKeys.numberDecimalDigits,
    PreferencesKeys.overwriteDotValueWithComma,
    PreferencesKeys.overwriteCommaValueWithDot,
    PreferencesKeys.amountInputAutoDecimalShift,
    PreferencesKeys.currencySymbolPosition,
    PreferencesKeys.currencySymbolSpacing,
    PreferencesKeys.showCurrencySymbol,
    PreferencesKeys.defaultCurrency,
    PreferencesKeys.currencyConversionRates,
    PreferencesKeys.userCurrencies,

    // Homepage and records
    PreferencesKeys.homepageTimeInterval,
    PreferencesKeys.homepageRecordsMonthStartDay,
    PreferencesKeys.homepageOverviewWidgetTimeInterval,
    PreferencesKeys.homepageRecordNotesVisible,
    PreferencesKeys.enableRecordNameSuggestions,
    PreferencesKeys.visualiseTagsInMainPage,
    PreferencesKeys.showWalletInRecordList,
    PreferencesKeys.showFutureRecords,
    PreferencesKeys.showCategoriesAtBottom,
    PreferencesKeys.restoreAmountOnDelete,

    // Categories, wallets, and budgets
    PreferencesKeys.categoryListSortOption,
    // Kept because this legacy key is still written by the category tab.
    'defaultCategorySortOption',
    PreferencesKeys.walletListSortOption,
    PreferencesKeys.profileListSortOption,
    PreferencesKeys.walletsEnabled,
    PreferencesKeys.budgetsEnabled,
    PreferencesKeys.walletBalanceMode,
    PreferencesKeys.showWalletBarOnHomepage,
    PreferencesKeys.transferIconCodePoint,
    PreferencesKeys.transferIconEmoji,
    PreferencesKeys.transferIconColor,

    // Statistics
    PreferencesKeys.statisticsPieChartUseCategoryColors,
    PreferencesKeys.statisticsPieChartNumberOfCategoriesToDisplay,

    // In-app keyboard
    PreferencesKeys.amountInputKeyboardType,
    PreferencesKeys.inAppKeyboardScale,
    PreferencesKeys.inAppKeyboardBackgroundColorIndex,
    PreferencesKeys.inAppKeyboardButtonColorIndex,
    PreferencesKeys.inAppKeyboardTextColorIndex,

    // Portable saved data that lives in SharedPreferences
    PreferencesKeys.reverseMonthlyImages,
    _savedCsvMappingsKey,
  };

  static final Map<String, bool Function(Object)> _validators = {
    // Booleans
    for (final key in [
      PreferencesKeys.overwriteDotValueWithComma,
      PreferencesKeys.overwriteCommaValueWithDot,
      PreferencesKeys.amountInputAutoDecimalShift,
      PreferencesKeys.colorizeAmounts,
      PreferencesKeys.enableNavigationBarAnimations,
      PreferencesKeys.privacyMode,
      PreferencesKeys.showCurrencySymbol,
      PreferencesKeys.enableRecordNameSuggestions,
      PreferencesKeys.visualiseTagsInMainPage,
      PreferencesKeys.showWalletInRecordList,
      PreferencesKeys.showFutureRecords,
      PreferencesKeys.showCategoriesAtBottom,
      PreferencesKeys.restoreAmountOnDelete,
      PreferencesKeys.walletsEnabled,
      PreferencesKeys.budgetsEnabled,
      PreferencesKeys.showWalletBarOnHomepage,
      PreferencesKeys.statisticsPieChartUseCategoryColors,
      PreferencesKeys.reverseMonthlyImages,
    ])
      key: (value) => value is bool,

    // Integer options
    PreferencesKeys.themeColor: _intIn({0, 1, 2}),
    PreferencesKeys.themeMode: _intIn({0, 1, 2}),
    PreferencesKeys.firstDayOfWeek: _intIn({0, 1, 6, 7}),
    PreferencesKeys.numberDecimalDigits: _intIn({0, 1, 2, 3, 4, 5, 6, 7, 8}),
    PreferencesKeys.currencySymbolPosition: _intIn({0, 1, 2}),
    PreferencesKeys.currencySymbolSpacing: _intIn({0, 1}),
    PreferencesKeys.homepageTimeInterval: _intIn({0, 1, 2, 3}),
    PreferencesKeys.homepageRecordsMonthStartDay: _intInRange(1, 31),
    PreferencesKeys.homepageOverviewWidgetTimeInterval: _intIn({0, 1, 2, 3}),
    PreferencesKeys.homepageRecordNotesVisible: _intIn({0, 1, 2, 3, 1000}),
    PreferencesKeys.amountInputKeyboardType: _intIn({0, 1, 2}),
    PreferencesKeys.categoryListSortOption: _intIn({0, 1, 2, 3}),
    'defaultCategorySortOption': _intIn({0, 1, 2, 3}),
    PreferencesKeys.walletListSortOption: _intIn({0, 1, 2, 3}),
    PreferencesKeys.profileListSortOption: _intIn({0, 1}),
    PreferencesKeys.walletBalanceMode: _intIn({0, 1}),
    PreferencesKeys.statisticsPieChartNumberOfCategoriesToDisplay: _intIn({
      4,
      5,
      6,
      8,
      10,
      999,
    }),
    PreferencesKeys.inAppKeyboardScale: _intIn({0, 1, 2}),
    PreferencesKeys.inAppKeyboardBackgroundColorIndex: _intInRange(0, 8),
    PreferencesKeys.inAppKeyboardButtonColorIndex: _intInRange(0, 4),
    PreferencesKeys.inAppKeyboardTextColorIndex: _intIn({0, 1, 2}),

    // Strings with finite option sets
    PreferencesKeys.languageLocale: (value) =>
        value is String &&
        {
          'system',
          'ar-SA',
          'ca',
          'da',
          'de',
          'en-US',
          'en-GB',
          'es',
          'fr',
          'hr',
          'it',
          'ja',
          'el',
          'or-IN',
          'pl',
          'pt-BR',
          'pt-PT',
          'ru',
          'tr',
          'ta-IN',
          'uk-UA',
          'vec-IT',
          'zh-CN',
          'hy',
        }.contains(value),
    PreferencesKeys.dateFormat: (value) =>
        value is String &&
        {
          'system',
          'dd/MM/yyyy',
          'MM/dd/yyyy',
          'yyyy-MM-dd',
          'd MMM yyyy',
          'MMM d, yyyy',
        }.contains(value),
    PreferencesKeys.decimalSeparator: (value) => value == '.' || value == ',',
    PreferencesKeys.groupSeparator: (value) =>
        value == '' ||
        value == '.' ||
        value == ',' ||
        value == '\u00A0' ||
        value == '_' ||
        value == "'",

    // Free-form but typed strings
    PreferencesKeys.defaultCurrency: (value) => value is String,
    PreferencesKeys.transferIconEmoji: (value) => value is String,
    PreferencesKeys.transferIconColor: _isSerializedColor,
    PreferencesKeys.currencyConversionRates: _isJsonObject,
    PreferencesKeys.userCurrencies: _isJsonObject,
    _savedCsvMappingsKey: _isSavedCsvMappings,

    // A custom icon must still exist in the current shared icon set.
    PreferencesKeys.transferIconCodePoint: (value) =>
        value is int &&
        CategoryIcons.pro_category_icons.any((icon) => icon.codePoint == value),
  };

  /// Exports only recognized, portable, JSON-safe preferences that are
  /// currently present. Missing preferences are omitted so defaults remain
  /// active after restore.
  static Map<String, dynamic> exportPreferences(SharedPreferences prefs) {
    final result = <String, dynamic>{};
    var present = 0;
    var exported = 0;
    var skippedInvalid = 0;
    var skippedErrors = 0;

    _logger.info(
      'Starting portable preference export (${_portableKeys.length} recognized keys)',
    );
    for (final key in _portableKeys) {
      if (!prefs.containsKey(key)) continue;
      present++;
      try {
        final value = prefs.get(key);
        if (value == null) {
          skippedInvalid++;
          _logger.warning(
            'Skipping preference during export: $key has a null value',
          );
        } else if (_isValid(key, value)) {
          result[key] = value;
          exported++;
          _logger.debug('Exported preference: $key');
        } else {
          skippedInvalid++;
          _logger.warning(
            'Skipping preference during export: $key has an invalid type or value',
          );
        }
      } catch (error, stackTrace) {
        skippedErrors++;
        _logger.handle(
          error,
          stackTrace,
          'Skipping preference during export: $key',
        );
      }
    }
    _logger.info(
      'Portable preference export completed: $exported exported, ${present - exported} skipped, $skippedInvalid invalid, $skippedErrors errors',
    );
    return result;
  }

  /// Restores preferences independently, skipping every unknown or invalid
  /// entry without aborting the rest of the backup import.
  static Future<void> restorePreferences(
    SharedPreferences prefs,
    Map<String, dynamic> preferences,
  ) async {
    var restored = 0;
    var skippedUnknown = 0;
    var skippedInvalid = 0;
    var skippedErrors = 0;

    _logger.info(
      'Starting portable preference restore (${preferences.length} entries)',
    );
    for (final entry in preferences.entries) {
      final key = entry.key;
      final value = entry.value;
      if (!_portableKeys.contains(key)) {
        skippedUnknown++;
        _logger.warning('Skipping unknown preference from backup: $key');
        continue;
      }
      try {
        if (!_isValid(key, value)) {
          skippedInvalid++;
          _logger.warning(
            'Skipping invalid preference from backup: $key has an invalid type or value',
          );
          continue;
        }
        await _setPreference(prefs, key, value);
        restored++;
        _logger.debug('Restored preference: $key');
      } catch (error, stackTrace) {
        skippedErrors++;
        _logger.handle(
          error,
          stackTrace,
          'Skipping preference during restore: $key',
        );
      }
    }
    _logger.info(
      'Portable preference restore completed: $restored restored, $skippedUnknown unknown, $skippedInvalid invalid, $skippedErrors errors',
    );
  }

  static bool _isValid(String key, Object value) {
    final validator = _validators[key];
    return validator != null && validator(value);
  }

  static Future<void> _setPreference(
    SharedPreferences prefs,
    String key,
    Object value,
  ) async {
    final bool applied;
    if (value is bool) {
      applied = await prefs.setBool(key, value);
    } else if (value is int) {
      applied = await prefs.setInt(key, value);
    } else if (value is double) {
      applied = await prefs.setDouble(key, value);
    } else if (value is String) {
      applied = await prefs.setString(key, value);
    } else if (value is List && value.every((item) => item is String)) {
      applied = await prefs.setStringList(key, value.cast<String>());
    } else {
      throw const FormatException('Unsupported SharedPreferences value type');
    }
    if (!applied) {
      throw StateError('SharedPreferences rejected the value');
    }
  }

  static bool Function(Object) _intIn(Set<int> allowed) =>
      (value) => value is int && allowed.contains(value);

  static bool Function(Object) _intInRange(int min, int max) =>
      (value) => value is int && value >= min && value <= max;

  static bool _isJsonObject(Object value) {
    if (value is! String || value.isEmpty) return false;
    try {
      return jsonDecode(value) is Map<String, dynamic>;
    } catch (_) {
      return false;
    }
  }

  static bool _isSerializedColor(Object value) {
    if (value is! String) return false;
    final parts = value.split(':').map(int.tryParse).toList();
    return parts.length == 4 &&
        parts.every(
          (component) =>
              component != null && component >= 0 && component <= 255,
        );
  }

  static bool _isSavedCsvMappings(Object value) {
    if (!_isJsonObject(value)) return false;
    final decoded = jsonDecode(value as String) as Map<String, dynamic>;
    return decoded.values.every((mapping) => mapping is String);
  }
}
