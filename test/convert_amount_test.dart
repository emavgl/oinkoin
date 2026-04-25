import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/helpers/records-utility-functions.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/settings/constants/preferences-keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ServiceConfig.sharedPreferences = await SharedPreferences.getInstance();
  });

  group('convertAmount', () {
    test('returns same amount when currencies are equal', () {
      expect(convertAmount(100.0, 'USD', 'USD'), 100.0);
    });

    test('converts using direct rate', () {
      ServiceConfig.sharedPreferences!.setString(
        PreferencesKeys.currencyConversionRates,
        jsonEncode({'USD_EUR': 0.92}),
      );
      expect(convertAmount(100.0, 'USD', 'EUR'), closeTo(92.0, 0.001));
    });

    test('converts using inverse rate', () {
      ServiceConfig.sharedPreferences!.setString(
        PreferencesKeys.currencyConversionRates,
        jsonEncode({'EUR_USD': 1.087}),
      );
      // USD -> EUR: invert EUR_USD rate
      final result = convertAmount(100.0, 'USD', 'EUR');
      expect(result, closeTo(100.0 / 1.087, 0.01));
    });

    test('converts via default currency', () {
      ServiceConfig.sharedPreferences!.setString(
        PreferencesKeys.defaultCurrency,
        'USD',
      );
      ServiceConfig.sharedPreferences!.setString(
        PreferencesKeys.currencyConversionRates,
        jsonEncode({
          'EUR_USD': 1.087,
          'GBP_USD': 1.27,
        }),
      );
      // EUR -> GBP via USD: EUR * EUR_USD / GBP_USD
      final result = convertAmount(100.0, 'EUR', 'GBP');
      expect(result, closeTo(100.0 * 1.087 / 1.27, 0.01));
    });

    test('returns null when no rate available', () {
      ServiceConfig.sharedPreferences!.setString(
        PreferencesKeys.currencyConversionRates,
        jsonEncode({'USD_EUR': 0.92}),
      );
      expect(convertAmount(100.0, 'JPY', 'GBP'), isNull);
    });

    test('returns null when no rates configured at all', () {
      expect(convertAmount(100.0, 'USD', 'EUR'), isNull);
    });
  });

  group('getConversionRateString', () {
    test('returns null for same currency', () {
      expect(getConversionRateString('USD', 'USD'), isNull);
    });

    test('formats direct rate', () {
      ServiceConfig.sharedPreferences!.setString(
        PreferencesKeys.currencyConversionRates,
        jsonEncode({'USD_EUR': 0.92}),
      );
      expect(getConversionRateString('USD', 'EUR'), '1 USD = 0.9200 EUR');
    });

    test('formats inverse rate', () {
      ServiceConfig.sharedPreferences!.setString(
        PreferencesKeys.currencyConversionRates,
        jsonEncode({'EUR_USD': 1.1234}),
      );
      final result = getConversionRateString('USD', 'EUR');
      expect(result, '1 USD = 0.8902 EUR');
    });

    test('returns null when no rate available', () {
      expect(getConversionRateString('JPY', 'GBP'), isNull);
    });
  });
}
