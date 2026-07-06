import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/helpers/amount-input-utils.dart';
import 'package:piggybank/helpers/records-utility-functions.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/settings/constants/preferences-keys.dart';
import 'package:piggybank/settings/currencies-page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('resolveDecimalDigits', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      ServiceConfig.sharedPreferences = await SharedPreferences.getInstance();
    });

    test('falls back to the global numberDecimalDigits preference when null',
        () async {
      await ServiceConfig.sharedPreferences!
          .setInt(PreferencesKeys.numberDecimalDigits, 4);

      expect(resolveDecimalDigits(null), 4);
    });

    test('uses the field override instead of the global preference', () async {
      await ServiceConfig.sharedPreferences!
          .setInt(PreferencesKeys.numberDecimalDigits, 2);

      expect(resolveDecimalDigits(6), 6);
    });

    test('falls back to the global preference when currencyCode has no override',
        () async {
      await ServiceConfig.sharedPreferences!
          .setInt(PreferencesKeys.numberDecimalDigits, 2);
      await saveUserCurrencyConfig(UserCurrencyConfig(
        mainCurrency: 'EUR',
        currencies: [UserCurrency(isoCode: 'EUR', ratioToMain: 1.0)],
      ));

      expect(resolveDecimalDigits(null, currencyCode: 'EUR'), 2);
    });

    test('uses the per-currency override when configured', () async {
      await ServiceConfig.sharedPreferences!
          .setInt(PreferencesKeys.numberDecimalDigits, 2);
      await saveUserCurrencyConfig(UserCurrencyConfig(
        mainCurrency: 'EUR',
        currencies: [
          UserCurrency(isoCode: 'EUR', ratioToMain: 1.0),
          UserCurrency(isoCode: 'BTC', ratioToMain: 45000, decimalDigits: 8),
        ],
      ));

      expect(resolveDecimalDigits(null, currencyCode: 'BTC'), 8);
    });

    test('the explicit field override wins over the per-currency override',
        () async {
      await ServiceConfig.sharedPreferences!
          .setInt(PreferencesKeys.numberDecimalDigits, 2);
      await saveUserCurrencyConfig(UserCurrencyConfig(
        mainCurrency: 'EUR',
        currencies: [
          UserCurrency(isoCode: 'BTC', ratioToMain: 45000, decimalDigits: 8),
        ],
      ));

      expect(resolveDecimalDigits(3, currencyCode: 'BTC'), 3);
    });

    test('an unset currencyCode falls back to the global preference',
        () async {
      await ServiceConfig.sharedPreferences!
          .setInt(PreferencesKeys.numberDecimalDigits, 4);

      expect(resolveDecimalDigits(null, currencyCode: null), 4);
      expect(resolveDecimalDigits(null, currencyCode: ''), 4);
    });
  });

  group('getCurrencyDecimalDigitsOverride', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      ServiceConfig.sharedPreferences = await SharedPreferences.getInstance();
    });

    test('returns null when no currencies are configured', () {
      expect(getCurrencyDecimalDigitsOverride('BTC'), isNull);
    });

    test('returns null for a currency without a configured override',
        () async {
      await saveUserCurrencyConfig(UserCurrencyConfig(
        mainCurrency: 'EUR',
        currencies: [UserCurrency(isoCode: 'EUR', ratioToMain: 1.0)],
      ));

      expect(getCurrencyDecimalDigitsOverride('EUR'), isNull);
    });

    test('returns the configured override for a currency', () async {
      await saveUserCurrencyConfig(UserCurrencyConfig(
        mainCurrency: 'EUR',
        currencies: [
          UserCurrency(isoCode: 'BTC', ratioToMain: 45000, decimalDigits: 8),
        ],
      ));

      expect(getCurrencyDecimalDigitsOverride('BTC'), 8);
    });

    test('returns null for null or empty currencyCode', () {
      expect(getCurrencyDecimalDigitsOverride(null), isNull);
      expect(getCurrencyDecimalDigitsOverride(''), isNull);
    });
  });

  group('amountFormatErrorMessage', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      ServiceConfig.sharedPreferences = await SharedPreferences.getInstance();
      ServiceConfig.currencyLocale = const Locale('en', 'US');
      await ServiceConfig.sharedPreferences!
          .setString(PreferencesKeys.decimalSeparator, '.');
      await ServiceConfig.sharedPreferences!
          .setString(PreferencesKeys.groupSeparator, ',');
    });

    test(
        'example reflects the global decimal-digit preference, not a hardcoded 2',
        () async {
      await ServiceConfig.sharedPreferences!
          .setInt(PreferencesKeys.numberDecimalDigits, 4);

      final message = amountFormatErrorMessage();

      expect(message, contains('1234.2000'));
      expect(message, isNot(contains('1234.20)')));
    });

    test('example uses exactly 2 decimals when the global preference is 2',
        () async {
      await ServiceConfig.sharedPreferences!
          .setInt(PreferencesKeys.numberDecimalDigits, 2);

      final message = amountFormatErrorMessage();

      expect(message, contains('1234.20'));
    });

    test('a field-level decimalDigits override wins over the global setting',
        () async {
      await ServiceConfig.sharedPreferences!
          .setInt(PreferencesKeys.numberDecimalDigits, 2);

      final message = amountFormatErrorMessage(decimalDigits: 6);

      expect(message, contains('1234.200000'));
    });
  });

  group('getNumberFormatWithCustomizations decimalDigits override', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      ServiceConfig.sharedPreferences = await SharedPreferences.getInstance();
      ServiceConfig.currencyLocale = const Locale('en', 'US');
      await ServiceConfig.sharedPreferences!
          .setString(PreferencesKeys.decimalSeparator, '.');
      await ServiceConfig.sharedPreferences!
          .setString(PreferencesKeys.groupSeparator, ',');
    });

    test('uses the global preference when no override is given', () async {
      await ServiceConfig.sharedPreferences!
          .setInt(PreferencesKeys.numberDecimalDigits, 3);

      final format = getNumberFormatWithCustomizations(turnOffGrouping: true);

      expect(format.format(1.5), '1.500');
    });

    test('an explicit override is independent of the global preference',
        () async {
      await ServiceConfig.sharedPreferences!
          .setInt(PreferencesKeys.numberDecimalDigits, 2);

      final format = getNumberFormatWithCustomizations(
        turnOffGrouping: true,
        decimalDigits: 6,
      );

      expect(format.format(1.5), '1.500000');
    });
  });
}
