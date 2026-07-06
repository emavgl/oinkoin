import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/helpers/amount-input-utils.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/settings/constants/preferences-keys.dart';
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
  group('buildAmountInputFormatters with unlimitedDecimals', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      ServiceConfig.sharedPreferences = await SharedPreferences.getInstance();
    });

    test('allows more decimal digits than decDigits when auto-decimal-shift is off', () {
      final formatters = buildAmountInputFormatters(
        decimalSep: '.',
        groupSep: ',',
        autoDec: false,
        decDigits: 6,
        unlimitedDecimals: true,
      );

      final result = _typeAll(formatters, '0.123456789');

      expect(result.text, '0.123456789');
    });

    test('does not apply the decimal cap that a limited field with the same decDigits would', () {
      final limited = buildAmountInputFormatters(
        decimalSep: '.',
        groupSep: ',',
        autoDec: false,
        decDigits: 6,
      );
      final unlimited = buildAmountInputFormatters(
        decimalSep: '.',
        groupSep: ',',
        autoDec: false,
        decDigits: 6,
        unlimitedDecimals: true,
      );

      final limitedResult = _typeAll(limited, '0.1234567');
      final unlimitedResult = _typeAll(unlimited, '0.1234567');

      expect(limitedResult.text, '0.123456');
      expect(unlimitedResult.text, '0.1234567');
    });

    test('forces manual decimal entry even when global auto-decimal-shift is on', () async {
      await ServiceConfig.sharedPreferences!
          .setInt(PreferencesKeys.numberDecimalDigits, 2);
      await ServiceConfig.sharedPreferences!
          .setBool(PreferencesKeys.amountInputAutoDecimalShift, true);

      final formatters = buildAmountInputFormatters(
        decimalSep: '.',
        groupSep: ',',
        autoDec: true,
        decDigits: 2,
        unlimitedDecimals: true,
      );

      // With auto-decimal-shift, typing "263150" would normally become
      // "0.263150" (digits shifted from the right). With unlimitedDecimals,
      // shifting is disabled, so digits are taken at face value and the
      // user types the decimal separator explicitly.
      final result = _typeAll(formatters, '0.263150');

      expect(result.text, '0.263150');
    });
  });
}
