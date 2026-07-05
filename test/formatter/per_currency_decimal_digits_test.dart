import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/helpers/amount-input-utils.dart';
import 'package:piggybank/helpers/records-utility-functions.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/settings/constants/preferences-keys.dart';
import 'package:piggybank/settings/currencies-page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Runs [text] key-by-key through [formatters], simulating the user typing
/// one character at a time (matches how TextInputFormatters are driven in
/// the real text field / in-app keyboard).
TextEditingValue _typeAll(List<TextInputFormatter> formatters, String text) {
  var value = TextEditingValue.empty;
  for (final char in text.split('')) {
    final next = TextEditingValue(
      text: value.text + char,
      selection: TextSelection.collapsed(offset: value.text.length + 1),
    );
    value = formatters.fold(next, (v, f) => f.formatEditUpdate(value, v));
  }
  return value;
}

void main() {
  group('per-currency decimal digits end-to-end (resolve + format)', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      ServiceConfig.sharedPreferences = await SharedPreferences.getInstance();
      await ServiceConfig.sharedPreferences!
          .setInt(PreferencesKeys.numberDecimalDigits, 2);
    });

    test('a wallet in a currency with an 8-digit override allows 8 decimals',
        () async {
      await saveUserCurrencyConfig(UserCurrencyConfig(
        mainCurrency: 'EUR',
        currencies: [
          UserCurrency(isoCode: 'BTC', ratioToMain: 45000, decimalDigits: 8),
        ],
      ));

      final decDigits = resolveDecimalDigits(null, currencyCode: 'BTC');
      final formatters = buildAmountInputFormatters(
        decimalSep: '.',
        groupSep: ',',
        autoDec: false,
        decDigits: decDigits,
      );

      final result = _typeAll(formatters, '0.123456789');

      expect(decDigits, 8);
      expect(result.text, '0.12345678');
    });

    test('a wallet in a currency without an override is capped at the global default',
        () async {
      await saveUserCurrencyConfig(UserCurrencyConfig(
        mainCurrency: 'EUR',
        currencies: [UserCurrency(isoCode: 'EUR', ratioToMain: 1.0)],
      ));

      final decDigits = resolveDecimalDigits(null, currencyCode: 'EUR');
      final formatters = buildAmountInputFormatters(
        decimalSep: '.',
        groupSep: ',',
        autoDec: false,
        decDigits: decDigits,
      );

      final result = _typeAll(formatters, '0.12345');

      expect(decDigits, 2);
      expect(result.text, '0.12');
    });

    test('a wallet with no assigned currency uses the global default',
        () async {
      final decDigits = resolveDecimalDigits(null, currencyCode: null);
      final formatters = buildAmountInputFormatters(
        decimalSep: '.',
        groupSep: ',',
        autoDec: false,
        decDigits: decDigits,
      );

      final result = _typeAll(formatters, '0.12345');

      expect(decDigits, 2);
      expect(result.text, '0.12');
    });

    test(
        'changing the global default does not affect a currency with its own override',
        () async {
      await saveUserCurrencyConfig(UserCurrencyConfig(
        mainCurrency: 'EUR',
        currencies: [
          UserCurrency(isoCode: 'BTC', ratioToMain: 45000, decimalDigits: 4),
        ],
      ));
      await ServiceConfig.sharedPreferences!
          .setInt(PreferencesKeys.numberDecimalDigits, 6);

      expect(resolveDecimalDigits(null, currencyCode: 'BTC'), 4);
    });
  });
}
