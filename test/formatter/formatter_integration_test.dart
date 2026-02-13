import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/records/formatter/auto_decimal_shift_formatter.dart';
import 'package:piggybank/records/formatter/group-separator-formatter.dart';

/// Integration tests to verify formatter interactions
/// These tests simulate the actual order of formatters in the TextField
void main() {
  group('Formatter Integration Tests', () {
    /// Simulates TextField formatter chain by applying formatters sequentially
    TextEditingValue applyFormatters(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      List<TextInputFormatter> formatters,
    ) {
      var currentOld = oldValue;
      var currentNew = newValue;

      for (final formatter in formatters) {
        final result = formatter.formatEditUpdate(currentOld, currentNew);
        currentOld = currentNew;
        currentNew = result;
      }

      return currentNew;
    }

    group('AutoDecimalShift + GroupSeparator (Standard Order)', () {
      late AutoDecimalShiftFormatter autoDecimalFormatter;
      late GroupSeparatorFormatter groupSeparatorFormatter;
      late List<TextInputFormatter> formatters;

      setUp(() {
        autoDecimalFormatter = AutoDecimalShiftFormatter(
          decimalDigits: 2,
          decimalSep: '.',
          groupSep: ',',
        );
        groupSeparatorFormatter = GroupSeparatorFormatter(
          decimalSep: '.',
          groupSep: ',',
        );
        // Note: In edit-record-page.dart, AutoDecimalShift runs before GroupSeparator
        formatters = [autoDecimalFormatter, groupSeparatorFormatter];
      });

      test('typing 5099 should result in 50.99 with both formatters', () {
        final oldValue = TextEditingValue(text: '509');
        final newValue = TextEditingValue(text: '5099');

        final result = applyFormatters(oldValue, newValue, formatters);

        // AutoDecimalShift: 5099 -> 50.99
        // GroupSeparator: 50.99 -> 50.99 (no grouping needed)
        expect(result.text, '50.99');
      });

      test('typing 100000 should result in 1,000.00', () {
        final oldValue = TextEditingValue(text: '10000');
        final newValue = TextEditingValue(text: '100000');

        final result = applyFormatters(oldValue, newValue, formatters);

        // AutoDecimalShift: 100000 -> 1000.00
        // GroupSeparator: 1000.00 -> 1,000.00
        expect(result.text, '1,000.00');
      });

      test('typing 5 should result in 0.05', () {
        final oldValue = TextEditingValue.empty;
        final newValue = TextEditingValue(text: '5');

        final result = applyFormatters(oldValue, newValue, formatters);

        expect(result.text, '0.05');
      });

      test('large number should be properly formatted', () {
        final oldValue = TextEditingValue(text: '1234567');
        final newValue = TextEditingValue(text: '12345678');

        final result = applyFormatters(oldValue, newValue, formatters);

        // AutoDecimalShift: 12345678 -> 123456.78
        // GroupSeparator: 123456.78 -> 123,456.78
        expect(result.text, '123,456.78');
      });
    });

    group('LeadingZeroTrimmer + GroupSeparator', () {
      late LeadingZeroIntegerTrimmerFormatter trimmerFormatter;
      late GroupSeparatorFormatter groupSeparatorFormatter;
      late List<TextInputFormatter> formatters;

      setUp(() {
        trimmerFormatter = LeadingZeroIntegerTrimmerFormatter(
          decimalSep: '.',
          groupSep: ',',
        );
        groupSeparatorFormatter = GroupSeparatorFormatter(
          decimalSep: '.',
          groupSep: ',',
        );
        // LeadingZeroTrimmer runs after GroupSeparator in actual implementation
        formatters = [groupSeparatorFormatter, trimmerFormatter];
      });

      test('trimmer should strip leading zeros', () {
        final oldValue = TextEditingValue(text: '0,05');
        final newValue = TextEditingValue(text: '0,050');

        final result = applyFormatters(oldValue, newValue, formatters);

        // GroupSeparator: 0,050 -> 0,050 (no change)
        // Trimmer: 0,050 -> 50 (strips leading zero and group separator)
        expect(result.text, '50');
      });

      test('expression should not be modified by trimmer', () {
        final oldValue = TextEditingValue(text: '0,050+0,03');
        final newValue = TextEditingValue(text: '0,050+0,030');

        final result = applyFormatters(oldValue, newValue, formatters);

        // Expression detected, trimmer returns unchanged
        expect(result.text, '0,050+0,030');
      });
    });

    group('Full Chain: AutoDecimal + LeadingZeroTrimmer + GroupSeparator', () {
      test('complex typing scenario with all formatters', () {
        final autoDecimal = AutoDecimalShiftFormatter(
          decimalDigits: 2,
          decimalSep: '.',
          groupSep: ',',
        );
        final groupSep = GroupSeparatorFormatter(
          decimalSep: '.',
          groupSep: ',',
        );
        final trimmer = LeadingZeroIntegerTrimmerFormatter(
          decimalSep: '.',
          groupSep: ',',
        );

        // Order as in edit-record-page.dart:
        // 1. AutoDecimalShiftFormatter (conditional on autoDec)
        // 2. LeadingZeroIntegerTrimmerFormatter (always)
        // 3. GroupSeparatorFormatter (always, runs after)
        final formatters = [autoDecimal, trimmer, groupSep];

        // Test: typing 0001000
        final oldValue = TextEditingValue(text: '000100');
        final newValue = TextEditingValue(text: '0001000');

        final result = applyFormatters(oldValue, newValue, formatters);

        // This is a complex interaction:
        // AutoDecimal: 0001000 -> 10.00
        // Trimmer: 10.00 -> 10.00 (no leading zeros to trim)
        // GroupSeparator: 10.00 -> 10.00
        expect(result.text, '10.00');
      });
    });

    group('Comma decimal separator locale', () {
      test('German-style formatting (comma as decimal)', () {
        final autoDecimal = AutoDecimalShiftFormatter(
          decimalDigits: 2,
          decimalSep: ',',
          groupSep: '.',
        );
        final groupSep = GroupSeparatorFormatter(
          decimalSep: ',',
          groupSep: '.',
        );

        final formatters = [autoDecimal, groupSep];

        final oldValue = TextEditingValue(text: '5099');
        final newValue = TextEditingValue(text: '50999');

        final result = applyFormatters(oldValue, newValue, formatters);

        // 50999 -> 509,99
        expect(result.text, '509,99');
      });
    });

    group('Edge cases in formatter chain', () {
      late List<TextInputFormatter> formatters;

      setUp(() {
        formatters = [
          AutoDecimalShiftFormatter(
            decimalDigits: 2,
            decimalSep: '.',
            groupSep: ',',
          ),
          GroupSeparatorFormatter(
            decimalSep: '.',
            groupSep: ',',
          ),
        ];
      });

      test('empty input chain', () {
        final result = applyFormatters(
          TextEditingValue.empty,
          TextEditingValue.empty,
          formatters,
        );
        expect(result.text, '');
      });

      test('single digit chain', () {
        final result = applyFormatters(
          TextEditingValue.empty,
          TextEditingValue(text: '5'),
          formatters,
        );
        expect(result.text, '0.05');
      });

      test('only zeros input', () {
        final result = applyFormatters(
          TextEditingValue(text: '00'),
          TextEditingValue(text: '000'),
          formatters,
        );
        // 000 -> 0.00
        expect(result.text, '0.00');
      });

      test('expression with operators', () {
        final result = applyFormatters(
          TextEditingValue(text: '50+25'),
          TextEditingValue(text: '50+250'),
          formatters,
        );
        // 50+250 -> 0.50+2.50
        expect(result.text, '0.50+2.50');
      });
    });
  });
}
