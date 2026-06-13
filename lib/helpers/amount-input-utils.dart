import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:function_tree/function_tree.dart';
import 'package:piggybank/i18n.dart';
import 'package:piggybank/records/formatter/auto_decimal_shift_formatter.dart';
import 'package:piggybank/records/formatter/calculator-normalizer.dart';
import 'package:piggybank/records/formatter/group-separator-formatter.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/settings/constants/preferences-keys.dart';
import 'package:piggybank/settings/preferences-utils.dart';

import 'records-utility-functions.dart';

/// Keyboard mode stored as the `amountInputKeyboardType` preference.
enum AmountKeyboardMode {
  phoneKeyboard(0),
  numberKeyboard(1),
  inAppKeyboard(2);

  const AmountKeyboardMode(this.prefValue);
  final int prefValue;

  static AmountKeyboardMode fromPrefValue(int value) {
    return AmountKeyboardMode.values.firstWhere(
      (m) => m.prefValue == value,
      orElse: () => AmountKeyboardMode.phoneKeyboard,
    );
  }
}

bool isMathExpression(String text) {
  return RegExp(r'[+\-*/%]').hasMatch(text);
}

/// Strips grouping/decimal separators and returns the expression ready to be
/// evaluated by [function_tree], or null if [text] is not a math expression.
String? tryParseMathExpr(String text) {
  if (!isMathExpression(text)) return null;
  try {
    text = text.replaceAll(getGroupingSeparator(), "");
    text = text.replaceAll(getDecimalSeparator(), ".");
    return text;
  } catch (_) {
    return null;
  }
}

/// Evaluates a math expression in [controller] and replaces the text with the
/// formatted result. Calls [onSolved] with the new text if provided.
void solveMathExpressionAndUpdateController(
  TextEditingController controller, {
  void Function(String)? onSolved,
}) {
  final text = controller.text.toLowerCase();
  final mathExpr = tryParseMathExpr(text);
  if (mathExpr == null) return;
  try {
    final result = mathExpr.interpret();
    final formatted =
        getCurrencyValueString(result.toDouble(), turnOffGrouping: false);
    controller.value = controller.value.copyWith(
      text: formatted,
      selection:
          TextSelection(baseOffset: formatted.length, extentOffset: formatted.length),
      composing: TextRange.empty,
    );
    onSolved?.call(controller.text.toLowerCase());
  } catch (e) {
    stderr.writeln("Can't parse the expression: $text");
  }
}

/// Returns the system [TextInputType] for text-mode amount input.
/// [AmountKeyboardMode.inAppKeyboard] is not a system keyboard — [AmountInputField]
/// handles it by opening [InAppKeyboard] instead.
TextInputType getAmountInputKeyboardType(AmountKeyboardMode mode, {bool signed = false}) {
  if (mode == AmountKeyboardMode.numberKeyboard) {
    return TextInputType.numberWithOptions(decimal: true, signed: signed);
  }
  return TextInputType.phone;
}

/// Global notifier: true while the InApp keyboard overlay is visible.
/// Consumed by [Shell] to hide the bottom navigation bar.
final ValueNotifier<bool> inAppKeyboardOpen = ValueNotifier(false);

/// Height of the InApp keyboard overlay in logical pixels.
/// Set to the measured height when the keyboard opens, reset to 0 on close.
/// Consumed by pages that need to add scroll padding so content stays reachable.
final ValueNotifier<double> inAppKeyboardHeight = ValueNotifier(0.0);

/// Reads the amountInputKeyboardType preference as an [AmountKeyboardMode].
AmountKeyboardMode getAmountKeyboardMode() {
  return AmountKeyboardMode.fromPrefValue(getAmountInputKeyboardTypeIndex());
}

/// Reads the raw preference index (used by the settings dropdown).
int getAmountInputKeyboardTypeIndex() {
  return PreferencesUtils.getOrDefault<int>(
      ServiceConfig.sharedPreferences!, PreferencesKeys.amountInputKeyboardType)!;
}

/// Returns the zero placeholder text for amount fields.
/// Returns `"0.00"` (locale-appropriate) when auto-decimal is on, `"0"` otherwise.
String buildZeroAmountText() {
  if (!getAmountInputAutoDecimalShift()) return '0';
  final decDigits = getNumberDecimalDigits();
  if (decDigits <= 0) return '0';
  final decSep = getDecimalSeparator();
  return '0$decSep${List.filled(decDigits, '0').join()}';
}

/// Shared validation error message for unparseable amount strings.
String amountFormatErrorMessage() {
  return "Not a valid format (use for example: %s)"
      .i18n
      .fill([getCurrencyValueString(1234.20, turnOffGrouping: true)]);
}

/// Returns the [RegExp] used to deny characters not valid in an amount field.
RegExp buildAmountAllowedRegex() {
  return RegExp(
      '[^0-9\\+\\-\\*/%${RegExp.escape(getDecimalSeparator())}${RegExp.escape(getGroupingSeparator())}]');
}

/// Builds the list of [TextInputFormatter]s used by amount input fields.
List<TextInputFormatter> buildAmountInputFormatters({
  required String decimalSep,
  required String groupSep,
  required bool autoDec,
  required int decDigits,
}) {
  return [
    CalculatorNormalizer(
      overwriteDot: getOverwriteDotValue(),
      overwriteComma: getOverwriteCommaValue(),
      decimalSep: decimalSep,
      groupSep: groupSep,
    ),
    FilteringTextInputFormatter.deny(buildAmountAllowedRegex()),
    LeadingZeroIntegerTrimmerFormatter(
      decimalSep: decimalSep,
      groupSep: groupSep,
    ),
    if (autoDec)
      AutoDecimalShiftFormatter(
        decimalDigits: decDigits,
        decimalSep: decimalSep,
        groupSep: groupSep,
      ),
    if (!autoDec)
      GroupSeparatorFormatter(
        groupSep: groupSep,
        decimalSep: decimalSep,
      ),
  ];
}
