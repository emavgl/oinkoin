import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/helpers/records-utility-functions.dart';
import 'package:piggybank/records/formatter/auto_decimal_shift_formatter.dart';
import 'package:piggybank/records/formatter/max_decimal_digits_formatter.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/settings/constants/preferences-keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// End-to-end coverage for the newly supported 8-decimal-digits option
/// (Settings > Customization > Decimal digits).
void main() {
  group('8 decimal digits end-to-end', () {
    test('AutoDecimalShiftFormatter shifts the decimal point 8 places', () {
      final formatter = AutoDecimalShiftFormatter(
        decimalDigits: 8,
        decimalSep: '.',
        groupSep: ',',
      );

      final oldValue = TextEditingValue(text: '123456789');
      final newValue = TextEditingValue(text: '1234567890');

      final result = formatter.formatEditUpdate(oldValue, newValue);

      expect(result.text, '12.34567890');
    });

    test('MaxDecimalDigitsFormatter allows exactly 8 decimal digits', () {
      final formatter = const MaxDecimalDigitsFormatter(
        decimalDigits: 8,
        decimalSep: '.',
      );

      final oldValue = TextEditingValue(text: '0.1234567');
      final newValue = TextEditingValue(text: '0.12345678');

      final result = formatter.formatEditUpdate(oldValue, newValue);

      expect(result.text, '0.12345678');
    });

    test('MaxDecimalDigitsFormatter rejects a 9th decimal digit', () {
      final formatter = const MaxDecimalDigitsFormatter(
        decimalDigits: 8,
        decimalSep: '.',
      );

      final oldValue = TextEditingValue(text: '0.12345678');
      final newValue = TextEditingValue(text: '0.123456789');

      final result = formatter.formatEditUpdate(oldValue, newValue);

      expect(result.text, '0.12345678');
    });

    test(
        'getNumberFormatWithCustomizations formats with 8 decimals when the '
        'global preference is set to 8', () async {
      SharedPreferences.setMockInitialValues({});
      ServiceConfig.sharedPreferences = await SharedPreferences.getInstance();
      ServiceConfig.currencyLocale = const Locale('en', 'US');
      await ServiceConfig.sharedPreferences!
          .setString(PreferencesKeys.decimalSeparator, '.');
      await ServiceConfig.sharedPreferences!
          .setString(PreferencesKeys.groupSeparator, ',');
      await ServiceConfig.sharedPreferences!
          .setInt(PreferencesKeys.numberDecimalDigits, 8);

      final format = getNumberFormatWithCustomizations(turnOffGrouping: true);

      expect(format.format(1.5), '1.50000000');
    });
  });
}
