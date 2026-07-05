import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/helpers/amount-input-utils.dart';
import 'package:piggybank/helpers/records-utility-functions.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/settings/constants/preferences-keys.dart';
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
