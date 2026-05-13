import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:function_tree/function_tree.dart';
import 'package:piggybank/records/formatter/auto_decimal_shift_formatter.dart';
import 'package:piggybank/records/formatter/calculator-normalizer.dart';
import 'package:piggybank/records/formatter/group-separator-formatter.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/settings/constants/preferences-keys.dart';
import 'package:piggybank/settings/preferences-utils.dart';

import 'records-utility-functions.dart';

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

/// Returns the keyboard type for amount input based on the user preference index.
/// 0 = Phone keyboard (with math symbols, default)
/// 1 = Number keyboard
TextInputType getAmountInputKeyboardType(int index, {bool signed = false}) {
  switch (index) {
    case 1:
      return TextInputType.numberWithOptions(decimal: true, signed: signed);
    case 0:
    default:
      return TextInputType.phone;
  }
}

/// Reads the amountInputKeyboardType preference index.
int getAmountInputKeyboardTypeIndex() {
  return PreferencesUtils.getOrDefault<int>(
      ServiceConfig.sharedPreferences!, PreferencesKeys.amountInputKeyboardType)!;
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
