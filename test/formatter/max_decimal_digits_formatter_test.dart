import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/records/formatter/max_decimal_digits_formatter.dart';

void main() {
  group('MaxDecimalDigitsFormatter', () {
    group('with 2 decimal digits (default)', () {
      late MaxDecimalDigitsFormatter formatter;

      setUp(() {
        formatter = const MaxDecimalDigitsFormatter(
          decimalDigits: 2,
          decimalSep: '.',
        );
      });

      test('allows value with exactly 2 decimal digits', () {
        final oldValue = TextEditingValue(text: '0.25');
        final newValue = TextEditingValue(text: '50.25');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '50.25');
      });

      test('allows value with exactly 1 decimal digit', () {
        final oldValue = TextEditingValue(text: '0.2');
        final newValue = TextEditingValue(text: '0.2');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '0.2');
      });

      test('rejects value exceeding 2 decimal digits', () {
        final oldValue = TextEditingValue(text: '0.25');
        final newValue = TextEditingValue(text: '0.255');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '0.25');
      });

      test('rejects value with 3 decimal digits', () {
        final oldValue = TextEditingValue(text: '0.2');
        final newValue = TextEditingValue(text: '0.255');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '0.2');
      });

      test('allows integer value', () {
        final oldValue = TextEditingValue.empty;
        final newValue = TextEditingValue(text: '500');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '500');
      });

      test('allows empty input', () {
        final oldValue = TextEditingValue.empty;
        final newValue = TextEditingValue.empty;

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '');
      });

      test('rejects decimal separator when decimalDigits is 0', () {
        final formatterZero = const MaxDecimalDigitsFormatter(
          decimalDigits: 0,
          decimalSep: '.',
        );

        final oldValue = TextEditingValue.empty;
        final newValue = TextEditingValue(text: '5.');

        final result = formatterZero.formatEditUpdate(oldValue, newValue);

        expect(result.text, '');
      });
    });

    group('with 6 decimal digits (conversion ratio)', () {
      late MaxDecimalDigitsFormatter formatter;

      setUp(() {
        formatter = const MaxDecimalDigitsFormatter(
          decimalDigits: 6,
          decimalSep: '.',
        );
      });

      test('allows value with 5 decimal digits like 0.26315', () {
        final oldValue = TextEditingValue(text: '0.2631');
        final newValue = TextEditingValue(text: '0.26315');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '0.26315');
      });

      test('allows value with exactly 6 decimal digits', () {
        final oldValue = TextEditingValue(text: '0.12345');
        final newValue = TextEditingValue(text: '0.123456');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '0.123456');
      });

      test('rejects value exceeding 6 decimal digits', () {
        final oldValue = TextEditingValue(text: '0.123456');
        final newValue = TextEditingValue(text: '0.1234567');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '0.123456');
      });

      test('allows integer value with 6-digit formatter', () {
        final oldValue = TextEditingValue.empty;
        final newValue = TextEditingValue(text: '100');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '100');
      });

      test('allows value with 1 decimal digit', () {
        final oldValue = TextEditingValue(text: '0.1');
        final newValue = TextEditingValue(text: '0.1');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '0.1');
      });
    });

    group('math expressions', () {
      test('rejects operand exceeding max decimal digits in expression', () {
        final formatter = const MaxDecimalDigitsFormatter(
          decimalDigits: 2,
          decimalSep: '.',
        );

        final oldValue = TextEditingValue(text: '0.25+0.2');
        final newValue = TextEditingValue(text: '0.25+0.255');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '0.25+0.2');
      });

      test('allows expression within decimal limit', () {
        final formatter = const MaxDecimalDigitsFormatter(
          decimalDigits: 2,
          decimalSep: '.',
        );

        final oldValue = TextEditingValue(text: '0.25+0.2');
        final newValue = TextEditingValue(text: '0.25+0.25');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '0.25+0.25');
      });

      test('allows expression with 6 decimal digits per operand', () {
        final formatter = const MaxDecimalDigitsFormatter(
          decimalDigits: 6,
          decimalSep: '.',
        );

        final oldValue = TextEditingValue(text: '0.26315+0.1');
        final newValue = TextEditingValue(text: '0.26315+0.123456');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '0.26315+0.123456');
      });
    });

    group('comma as decimal separator', () {
      test('works with comma decimal separator', () {
        final formatter = const MaxDecimalDigitsFormatter(
          decimalDigits: 6,
          decimalSep: ',',
        );

        final oldValue = TextEditingValue(text: '0,2631');
        final newValue = TextEditingValue(text: '0,26315');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '0,26315');
      });
    });
  });
}
