import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/helpers/records-utility-functions.dart';
import 'package:piggybank/services/locale-service.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:piggybank/settings/constants/preferences-keys.dart';

void main() {
  group('formatCurrencyAmount tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      ServiceConfig.sharedPreferences = await SharedPreferences.getInstance();
      ServiceConfig.currencyLocale = const Locale('en', 'US');
    });

    test('uses custom decimal separator when set', () async {
      await ServiceConfig.sharedPreferences!
          .setString(PreferencesKeys.decimalSeparator, ',');
      await ServiceConfig.sharedPreferences!
          .setString(PreferencesKeys.groupSeparator, '.');

      setNumberFormatCache();
      final result = formatCurrencyAmount(1234.56, 'USD');

      expect(result, '\$ 1.234,56');
    });

    test('uses custom group separator when set', () async {
      await ServiceConfig.sharedPreferences!
          .setString(PreferencesKeys.decimalSeparator, ',');
      await ServiceConfig.sharedPreferences!
          .setString(PreferencesKeys.groupSeparator, '.');

      setNumberFormatCache();
      final result = formatCurrencyAmount(1234567.89, 'USD');

      expect(result, contains('1.234.567,89'));
    });

    test('includes currency symbol', () async {
      await ServiceConfig.sharedPreferences!
          .setString(PreferencesKeys.decimalSeparator, '.');
      await ServiceConfig.sharedPreferences!
          .setString(PreferencesKeys.groupSeparator, ',');

      setNumberFormatCache();
      final result = formatCurrencyAmount(1234.56, 'USD');

      expect(result, contains('\$'));
    });

    test('formats zero correctly', () async {
      await ServiceConfig.sharedPreferences!
          .setString(PreferencesKeys.decimalSeparator, '.');
      await ServiceConfig.sharedPreferences!
          .setString(PreferencesKeys.groupSeparator, ',');

      setNumberFormatCache();
      final result = formatCurrencyAmount(0, 'EUR');

      expect(result, isNotEmpty);
    });

    test('formats negative amount correctly', () async {
      await ServiceConfig.sharedPreferences!
          .setString(PreferencesKeys.decimalSeparator, '.');
      await ServiceConfig.sharedPreferences!
          .setString(PreferencesKeys.groupSeparator, ',');

      setNumberFormatCache();
      final result = formatCurrencyAmount(-1234.56, 'USD');

      expect(result, contains('-'));
      expect(result, contains('1,234.56'));
    });
  });

  group('getCurrencySymbol tests', () {
    test('returns correct symbol for USD', () {
      final symbol = getCurrencySymbol('USD');
      expect(symbol, '\$');
    });

    test('returns correct symbol for EUR', () {
      final symbol = getCurrencySymbol('EUR');
      expect(symbol, '€');
    });

    test('returns correct symbol for GBP', () {
      final symbol = getCurrencySymbol('GBP');
      expect(symbol, '£');
    });

    test('returns code for unknown currency', () {
      final symbol = getCurrencySymbol('XYZ');
      expect(symbol, 'XYZ');
    });
  });

  group('insertCurrencySymbol tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({
        PreferencesKeys.currencySymbolPosition: 0,
        PreferencesKeys.currencySymbolSpacing: 0,
      });
      ServiceConfig.sharedPreferences = await SharedPreferences.getInstance();
    });

    test('prepends symbol when not present', () {
      final result = insertCurrencySymbol('1,234.56', '\$');
      expect(result, '\$ 1,234.56');
    });

    test('returns original when symbol already present at start', () {
      final result = insertCurrencySymbol('\$1,234.56', '\$');
      expect(result, '\$1,234.56');
    });

    test('returns original when symbol already present at end', () {
      final result = insertCurrencySymbol('1,234.56€', '€');
      expect(result, '1,234.56€');
    });

    test('handles empty formatted value', () {
      final result = insertCurrencySymbol('', '\$');
      expect(result, '');
    });

    test('handles empty symbol', () {
      final result = insertCurrencySymbol('1,234.56', '');
      expect(result, '1,234.56');
    });
  });

  group('currency symbol position and spacing tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({
        PreferencesKeys.currencySymbolPosition: 0,
        PreferencesKeys.currencySymbolSpacing: 0,
      });
      ServiceConfig.sharedPreferences = await SharedPreferences.getInstance();
    });

    test('default position with space adds space before symbol', () async {
      await ServiceConfig.sharedPreferences!
          .setInt(PreferencesKeys.currencySymbolPosition, 0);
      await ServiceConfig.sharedPreferences!
          .setInt(PreferencesKeys.currencySymbolSpacing, 0);

      final result = insertCurrencySymbol('1,234.56', '\$');
      expect(result, '\$ 1,234.56');
    });

    test('default position without space', () async {
      await ServiceConfig.sharedPreferences!
          .setInt(PreferencesKeys.currencySymbolPosition, 0);
      await ServiceConfig.sharedPreferences!
          .setInt(PreferencesKeys.currencySymbolSpacing, 1);

      final result = insertCurrencySymbol('1,234.56', '\$');
      expect(result, '\$1,234.56');
    });

    test('left position with space', () async {
      await ServiceConfig.sharedPreferences!
          .setInt(PreferencesKeys.currencySymbolPosition, 1);
      await ServiceConfig.sharedPreferences!
          .setInt(PreferencesKeys.currencySymbolSpacing, 0);

      final result = insertCurrencySymbol('1,234.56', '€');
      expect(result, '€ 1,234.56');
    });

    test('left position without space', () async {
      await ServiceConfig.sharedPreferences!
          .setInt(PreferencesKeys.currencySymbolPosition, 1);
      await ServiceConfig.sharedPreferences!
          .setInt(PreferencesKeys.currencySymbolSpacing, 1);

      final result = insertCurrencySymbol('1,234.56', '€');
      expect(result, '€1,234.56');
    });

    test('right position with space', () async {
      await ServiceConfig.sharedPreferences!
          .setInt(PreferencesKeys.currencySymbolPosition, 2);
      await ServiceConfig.sharedPreferences!
          .setInt(PreferencesKeys.currencySymbolSpacing, 0);

      final result = insertCurrencySymbol('1,234.56', '£');
      expect(result, '1,234.56 £');
    });

    test('right position without space', () async {
      await ServiceConfig.sharedPreferences!
          .setInt(PreferencesKeys.currencySymbolPosition, 2);
      await ServiceConfig.sharedPreferences!
          .setInt(PreferencesKeys.currencySymbolSpacing, 1);

      final result = insertCurrencySymbol('1,234.56', '£');
      expect(result, '1,234.56£');
    });

    test('left position with negative amount', () async {
      await ServiceConfig.sharedPreferences!
          .setInt(PreferencesKeys.currencySymbolPosition, 1);
      await ServiceConfig.sharedPreferences!
          .setInt(PreferencesKeys.currencySymbolSpacing, 0);

      final result = insertCurrencySymbol('-1,234.56', '\$');
      expect(result, '\$ -1,234.56');
    });

    test('right position with negative amount', () async {
      await ServiceConfig.sharedPreferences!
          .setInt(PreferencesKeys.currencySymbolPosition, 2);
      await ServiceConfig.sharedPreferences!
          .setInt(PreferencesKeys.currencySymbolSpacing, 0);

      final result = insertCurrencySymbol('-1,234.56', '€');
      expect(result, '-1,234.56 €');
    });
  });

  group('LocaleService.reloadCurrencyLocale tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      ServiceConfig.sharedPreferences = await SharedPreferences.getInstance();
      ServiceConfig.currencyLocale = const Locale('en', 'US');
    });

    test('reloads currency locale and formats', () async {
      await ServiceConfig.sharedPreferences!
          .setString(PreferencesKeys.decimalSeparator, ',');
      await ServiceConfig.sharedPreferences!
          .setString(PreferencesKeys.groupSeparator, '.');

      LocaleService.reloadCurrencyLocale();

      final result = getCurrencyValueString(1234.56);
      expect(result, contains(','));
    });

    test('respects decimal separator from preferences', () async {
      await ServiceConfig.sharedPreferences!
          .setString(PreferencesKeys.decimalSeparator, ',');
      await ServiceConfig.sharedPreferences!
          .setString(PreferencesKeys.groupSeparator, '.');

      LocaleService.reloadCurrencyLocale();

      final result = getCurrencyValueString(12.34);
      expect(result, contains('12,34'));
    });
  });
}
