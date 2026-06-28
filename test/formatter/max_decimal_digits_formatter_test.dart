import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/records/formatter/max_decimal_digits_formatter.dart';

void main() {
  group('MaxDecimalDigitsFormatter', () {
    late MaxDecimalDigitsFormatter formatter;

    group('2 decimal digits (default)', () {
      setUp(() {
        formatter = MaxDecimalDigitsFormatter(
          decimalDigits: 2,
          decimalSep: '.',
        );
      });

      test('should allow exactly 2 decimal digits', () {
        final oldValue = TextEditingValue(text: '50');
        final newValue = TextEditingValue(text: '50.99');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '50.99');
      });

      test('should reject more than 2 decimal digits', () {
        final oldValue = TextEditingValue(text: '50.9');
        final newValue = TextEditingValue(text: '50.999');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '50.9');
      });

      test('should allow integer input', () {
        final oldValue = TextEditingValue(text: '50');
        final newValue = TextEditingValue(text: '500');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '500');
      });
    });

    group('8 decimal digits (Bitcoin-style)', () {
      setUp(() {
        formatter = MaxDecimalDigitsFormatter(
          decimalDigits: 8,
          decimalSep: '.',
        );
      });

      test('should allow exactly 8 decimal digits', () {
        final oldValue = TextEditingValue(text: '0.1234567');
        final newValue = TextEditingValue(text: '0.12345678');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '0.12345678');
      });

      test('should reject more than 8 decimal digits', () {
        final oldValue = TextEditingValue(text: '0.12345678');
        final newValue = TextEditingValue(text: '0.123456789');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '0.12345678');
      });

      test('should allow integer input with 8-digit formatter', () {
        final oldValue = TextEditingValue(text: '1234567');
        final newValue = TextEditingValue(text: '12345678');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '12345678');
      });
    });

    group('0 decimal digits (no decimals)', () {
      setUp(() {
        formatter = MaxDecimalDigitsFormatter(
          decimalDigits: 0,
          decimalSep: '.',
        );
      });

      test('should block decimal separator when 0 digits', () {
        final oldValue = TextEditingValue(text: '50');
        final newValue = TextEditingValue(text: '50.');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '50');
      });

      test('should allow normal integer input', () {
        final oldValue = TextEditingValue(text: '50');
        final newValue = TextEditingValue(text: '500');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '500');
      });
    });

    group('Comma decimal separator', () {
      setUp(() {
        formatter = MaxDecimalDigitsFormatter(
          decimalDigits: 8,
          decimalSep: ',',
        );
      });

      test('should work with comma as decimal separator', () {
        final oldValue = TextEditingValue(text: '0,1234567');
        final newValue = TextEditingValue(text: '0,12345678');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '0,12345678');
      });

      test('should reject more than 8 decimal digits with comma', () {
        final oldValue = TextEditingValue(text: '0,12345678');
        final newValue = TextEditingValue(text: '0,123456789');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '0,12345678');
      });
    });

    group('Mathematical expressions', () {
      setUp(() {
        formatter = MaxDecimalDigitsFormatter(
          decimalDigits: 8,
          decimalSep: '.',
        );
      });

      test('should allow expression with 8 decimal digits', () {
        final oldValue = TextEditingValue(text: '0.12345678+0.8765432');
        final newValue = TextEditingValue(text: '0.12345678+0.87654321');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '0.12345678+0.87654321');
      });

      test('should reject expression with too many decimal digits', () {
        final oldValue = TextEditingValue(text: '0.12345678+0.87654321');
        final newValue = TextEditingValue(text: '0.123456789+0.87654321');

        // First operand has 9 digits -> should reject back to oldValue
        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '0.12345678+0.87654321');
      });
    });
  });
}
