import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/records/formatter/auto_decimal_shift_formatter.dart';

void main() {
  group('AutoDecimalShiftFormatter', () {
    late AutoDecimalShiftFormatter formatter;

    setUp(() {
      formatter = AutoDecimalShiftFormatter(
        decimalDigits: 2,
        decimalSep: '.',
        groupSep: ',',
      );
    });

    group('Basic decimal shift functionality', () {
      test('typing single digit should become 0.0X format', () {
        final oldValue = TextEditingValue.empty;
        final newValue = TextEditingValue(text: '5');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '0.05');
      });

      test('typing two digits should become 0.XX format', () {
        final oldValue = TextEditingValue(text: '5');
        final newValue = TextEditingValue(text: '50');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '0.50');
      });

      test('typing three digits should shift decimal correctly', () {
        final oldValue = TextEditingValue(text: '50');
        final newValue = TextEditingValue(text: '500');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '5.00');
      });

      test('typing four digits should shift decimal correctly', () {
        final oldValue = TextEditingValue(text: '500');
        final newValue = TextEditingValue(text: '5000');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '50.00');
      });

      test('typing 5099 should become 50.99', () {
        final oldValue = TextEditingValue(text: '509');
        final newValue = TextEditingValue(text: '5099');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '50.99');
      });
    });

    group('Edge cases', () {
      test('empty input should return empty', () {
        final oldValue = TextEditingValue.empty;
        final newValue = TextEditingValue.empty;

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '');
      });

      test('zero decimal digits should pass through unchanged', () {
        final formatterZero = AutoDecimalShiftFormatter(
          decimalDigits: 0,
          decimalSep: '.',
          groupSep: ',',
        );

        final oldValue = TextEditingValue.empty;
        final newValue = TextEditingValue(text: '500');

        final result = formatterZero.formatEditUpdate(oldValue, newValue);

        expect(result.text, '500');
      });

      test('input with only zeros should work correctly', () {
        final oldValue = TextEditingValue(text: '0');
        final newValue = TextEditingValue(text: '00');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '0.00');
      });

      test('typing 100 should become 1.00 not 100.00', () {
        final oldValue = TextEditingValue(text: '10');
        final newValue = TextEditingValue(text: '100');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '1.00');
      });

      test('typing 1000 should become 10.00', () {
        final oldValue = TextEditingValue(text: '100');
        final newValue = TextEditingValue(text: '1000');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '10.00');
      });
    });

    group('Different decimal separators', () {
      test('should use comma as decimal separator', () {
        final formatterComma = AutoDecimalShiftFormatter(
          decimalDigits: 2,
          decimalSep: ',',
          groupSep: '.',
        );

        final oldValue = TextEditingValue(text: '509');
        final newValue = TextEditingValue(text: '5099');

        final result = formatterComma.formatEditUpdate(oldValue, newValue);

        expect(result.text, '50,99');
      });
    });

    group('Mathematical expressions', () {
      test('simple addition should format both numbers', () {
        final oldValue = TextEditingValue(text: '50+2');
        final newValue = TextEditingValue(text: '50+25');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '0.50+0.25');
      });

      test('expression with multiple operators', () {
        final oldValue = TextEditingValue(text: '10+20');
        final newValue = TextEditingValue(text: '100+200');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '1.00+2.00');
      });

      test('subtraction should work correctly', () {
        final oldValue = TextEditingValue(text: '10-5');
        final newValue = TextEditingValue(text: '100-50');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '1.00-0.50');
      });

      test('multiplication should work correctly', () {
        final oldValue = TextEditingValue(text: '2*3');
        final newValue = TextEditingValue(text: '20*30');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '0.20*0.30');
      });

      test('division should work correctly', () {
        final oldValue = TextEditingValue(text: '10/2');
        final newValue = TextEditingValue(text: '100/20');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '1.00/0.20');
      });

      test('modulo should work correctly', () {
        final oldValue = TextEditingValue(text: '10%3');
        final newValue = TextEditingValue(text: '100%30');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '1.00%0.30');
      });
    });

    group('Sign handling', () {
      test('positive sign at start should be preserved', () {
        final oldValue = TextEditingValue(text: '+');
        final newValue = TextEditingValue(text: '+50');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '+0.50');
      });

      test('negative sign at start should be preserved', () {
        final oldValue = TextEditingValue(text: '-');
        final newValue = TextEditingValue(text: '-50');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '-0.50');
      });

      test('unary minus in expression should work', () {
        final oldValue = TextEditingValue(text: '5+-');
        final newValue = TextEditingValue(text: '5+-3');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '0.05+-0.03');
      });

      test('unary plus in expression should work', () {
        final oldValue = TextEditingValue(text: '5++');
        final newValue = TextEditingValue(text: '5++3');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '0.05++0.03');
      });
    });

    group('Group separator handling', () {
      test('should strip existing group separators before processing', () {
        // Simulate user typing 1,000 (with group separator)
        final oldValue = TextEditingValue(text: '1,00');
        final newValue = TextEditingValue(text: '1,000');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        // 1000 with 2 decimal digits -> 10.00
        expect(result.text, '10.00');
      });
    });

    group('3 decimal digits', () {
      late AutoDecimalShiftFormatter formatter3;

      setUp(() {
        formatter3 = AutoDecimalShiftFormatter(
          decimalDigits: 3,
          decimalSep: '.',
          groupSep: ',',
        );
      });

      test('single digit with 3 decimal places', () {
        final oldValue = TextEditingValue.empty;
        final newValue = TextEditingValue(text: '5');

        final result = formatter3.formatEditUpdate(oldValue, newValue);

        expect(result.text, '0.005');
      });

      test('four digits with 3 decimal places', () {
        final oldValue = TextEditingValue(text: '123');
        final newValue = TextEditingValue(text: '1234');

        final result = formatter3.formatEditUpdate(oldValue, newValue);

        expect(result.text, '1.234');
      });
    });
  });

  group('LeadingZeroIntegerTrimmerFormatter', () {
    late LeadingZeroIntegerTrimmerFormatter formatter;

    setUp(() {
      formatter = LeadingZeroIntegerTrimmerFormatter(
        decimalSep: '.',
        groupSep: ',',
      );
    });

    group('Basic trimming', () {
      test('should remove leading zeros from integer part', () {
        final oldValue = TextEditingValue.empty;
        final newValue = TextEditingValue(text: '005');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '5');
      });

      test('should handle multiple leading zeros', () {
        final oldValue = TextEditingValue.empty;
        final newValue = TextEditingValue(text: '00050');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '50');
      });

      test('should keep single zero', () {
        final oldValue = TextEditingValue.empty;
        final newValue = TextEditingValue(text: '0');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '0');
      });

      test('should keep single zero before decimal', () {
        final oldValue = TextEditingValue.empty;
        final newValue = TextEditingValue(text: '0.50');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '0.50');
      });
    });

    group('With decimal separator', () {
      test('should trim zeros before decimal point', () {
        final oldValue = TextEditingValue.empty;
        final newValue = TextEditingValue(text: '005.50');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '5.50');
      });

      test('should not trim zeros after decimal point', () {
        final oldValue = TextEditingValue.empty;
        final newValue = TextEditingValue(text: '5.005');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '5.005');
      });

      test('all zeros before decimal should become single zero', () {
        final oldValue = TextEditingValue.empty;
        final newValue = TextEditingValue(text: '000.50');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '0.50');
      });
    });

    group('With group separator', () {
      test('should handle group separators correctly', () {
        final oldValue = TextEditingValue.empty;
        final newValue = TextEditingValue(text: '0,050');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        // Strips group separators and leading zeros (GroupSeparatorFormatter will re-add on next keystroke)
        expect(result.text, '50');
      });

      test('should trim zeros before group separator', () {
        final oldValue = TextEditingValue.empty;
        final newValue = TextEditingValue(text: '001,000');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        // Group separators are stripped during zero trimming, GroupSeparatorFormatter will re-add them
        expect(result.text, '1000');
      });
    });

    group('Sign handling', () {
      test('should preserve negative sign', () {
        final oldValue = TextEditingValue.empty;
        final newValue = TextEditingValue(text: '-005');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '-5');
      });

      test('should preserve positive sign', () {
        final oldValue = TextEditingValue.empty;
        final newValue = TextEditingValue(text: '+005');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '+5');
      });

      test('should handle sign with decimal', () {
        final oldValue = TextEditingValue.empty;
        final newValue = TextEditingValue(text: '-005.50');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '-5.50');
      });
    });

    group('Mathematical expressions', () {
      test('should skip processing for expressions with operators', () {
        final oldValue = TextEditingValue.empty;
        final newValue = TextEditingValue(text: '005+003');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        // Should not change since it contains operators
        expect(result.text, '005+003');
      });

      test('should skip processing for subtraction', () {
        final oldValue = TextEditingValue.empty;
        final newValue = TextEditingValue(text: '005-003');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '005-003');
      });

      test('should skip processing for multiplication', () {
        final oldValue = TextEditingValue.empty;
        final newValue = TextEditingValue(text: '005*003');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '005*003');
      });

      test('should skip processing for division', () {
        final oldValue = TextEditingValue.empty;
        final newValue = TextEditingValue(text: '005/003');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '005/003');
      });
    });

    group('Edge cases', () {
      test('empty string should return empty', () {
        final oldValue = TextEditingValue.empty;
        final newValue = TextEditingValue.empty;

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '');
      });

      test('only zeros should become single zero', () {
        final oldValue = TextEditingValue.empty;
        final newValue = TextEditingValue(text: '000');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '0');
      });

      test('no leading zeros should return unchanged', () {
        final oldValue = TextEditingValue.empty;
        final newValue = TextEditingValue(text: '123');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '123');
      });

      test('zero with decimal only should stay as 0.xxx', () {
        final oldValue = TextEditingValue.empty;
        final newValue = TextEditingValue(text: '000.123');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '0.123');
      });
    });

    group('Different separators', () {
      test('should work with comma decimal separator', () {
        final formatterComma = LeadingZeroIntegerTrimmerFormatter(
          decimalSep: ',',
          groupSep: '.',
        );

        final oldValue = TextEditingValue.empty;
        final newValue = TextEditingValue(text: '005,50');

        final result = formatterComma.formatEditUpdate(oldValue, newValue);

        expect(result.text, '5,50');
      });
    });
  });
}
