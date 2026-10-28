import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/helpers/amount-input-utils.dart';
import 'package:piggybank/records/formatter/auto_decimal_shift_formatter.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Runs the formatter chain the way a TextField does: [oldValue] is the value
/// shown before the edit, [newValue] the platform's edit (text already
/// changed, caret placed where the user typed).
TextEditingValue _apply(
  List<TextInputFormatter> formatters,
  TextEditingValue oldValue,
  TextEditingValue newValue,
) {
  var value = newValue;
  for (final formatter in formatters) {
    value = formatter.formatEditUpdate(oldValue, value);
  }
  return value;
}

void main() {
  group('AutoDecimalShiftFormatter caret preservation', () {
    late AutoDecimalShiftFormatter formatter;

    setUp(() {
      formatter = AutoDecimalShiftFormatter(
        decimalDigits: 2,
        decimalSep: '.',
        groupSep: ',',
      );
    });

    test('inserting a digit in the middle keeps the caret after it', () {
      // "12.34" with the caret after the "1", typing "5" -> "152.34".
      final oldValue = const TextEditingValue(
        text: '12.34',
        selection: TextSelection.collapsed(offset: 1),
      );
      final newValue = const TextEditingValue(
        text: '152.34',
        selection: TextSelection.collapsed(offset: 2),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);

      expect(result.text, '152.34');
      expect(result.selection.baseOffset, 2,
          reason: 'the caret must stay after the typed digit');
    });

    test('inserting at the start keeps the caret at the start', () {
      final oldValue = const TextEditingValue(
        text: '12.34',
        selection: TextSelection.collapsed(offset: 0),
      );
      final newValue = const TextEditingValue(
        text: '512.34',
        selection: TextSelection.collapsed(offset: 1),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);

      expect(result.text, '512.34');
      expect(result.selection.baseOffset, 1);
    });

    test('typing at the end still leaves the caret at the end', () {
      final oldValue = const TextEditingValue(
        text: '12.34',
        selection: TextSelection.collapsed(offset: 5),
      );
      final newValue = const TextEditingValue(
        text: '12.345',
        selection: TextSelection.collapsed(offset: 6),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);

      expect(result.text, '123.45');
      expect(result.selection.baseOffset, result.text.length);
    });

    test('backspace in the middle keeps the caret in place', () {
      final oldValue = const TextEditingValue(
        text: '152.34',
        selection: TextSelection.collapsed(offset: 2),
      );
      // Caret at offset 2, backspace removes the "5" -> "12.34", caret at 1.
      final newValue = const TextEditingValue(
        text: '12.34',
        selection: TextSelection.collapsed(offset: 1),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);

      expect(result.text, '12.34');
      expect(result.selection.baseOffset, 1);
    });

    test('keeps the caret inside the second operand of an expression', () {
      // Caret after the "2" in the second operand, typing a "5".
      final oldValue = const TextEditingValue(
        text: '1.00+2.500',
        selection: TextSelection.collapsed(offset: 7),
      );
      final newValue = const TextEditingValue(
        text: '1.00+2.5005',
        selection: TextSelection.collapsed(offset: 8),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);

      expect(result.text, '1.00+250.05');
      expect(result.selection.baseOffset, 7);
    });
  });

  group('full formatter chain keeps the caret where the user typed', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      ServiceConfig.sharedPreferences = await SharedPreferences.getInstance();
    });

    test('grouping mode: inserting in the middle does not append', () {
      final formatters = buildAmountInputFormatters(
        decimalSep: '.',
        groupSep: ',',
        autoDec: false,
        decDigits: 2,
      );

      final oldValue = const TextEditingValue(
        text: '1,234',
        selection: TextSelection.collapsed(offset: 1),
      );
      final newValue = const TextEditingValue(
        text: '15,234',
        selection: TextSelection.collapsed(offset: 2),
      );

      final result = _apply(formatters, oldValue, newValue);

      expect(result.text, '15,234');
      expect(result.selection.baseOffset, 2);
    });

    test('grouping mode: backspace in the middle deletes at the caret', () {
      final formatters = buildAmountInputFormatters(
        decimalSep: '.',
        groupSep: ',',
        autoDec: false,
        decDigits: 2,
      );

      final oldValue = const TextEditingValue(
        text: '15,234',
        selection: TextSelection.collapsed(offset: 2),
      );
      final newValue = const TextEditingValue(
        text: '1,234',
        selection: TextSelection.collapsed(offset: 1),
      );

      final result = _apply(formatters, oldValue, newValue);

      expect(result.text, '1,234');
      expect(result.selection.baseOffset, 1);
    });

    test('auto-decimal mode: inserting in the middle keeps the caret', () {
      final formatters = buildAmountInputFormatters(
        decimalSep: '.',
        groupSep: ',',
        autoDec: true,
        decDigits: 2,
      );

      final oldValue = const TextEditingValue(
        text: '12.34',
        selection: TextSelection.collapsed(offset: 1),
      );
      final newValue = const TextEditingValue(
        text: '152.34',
        selection: TextSelection.collapsed(offset: 2),
      );

      final result = _apply(formatters, oldValue, newValue);

      expect(result.text, '152.34');
      expect(result.selection.baseOffset, 2);
    });
  });
}
