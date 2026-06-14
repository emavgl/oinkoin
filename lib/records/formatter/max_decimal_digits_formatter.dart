import 'package:flutter/services.dart';

/// Rejects any keystroke that would produce more than [decimalDigits] digits
/// after the decimal separator in any operand of a math expression.
///
/// When [decimalDigits] is 0 the decimal separator itself is also blocked.
/// Works for both the system keyboard and the in-app keyboard since both
/// run through [buildAmountInputFormatters].
class MaxDecimalDigitsFormatter extends TextInputFormatter {
  final int decimalDigits;
  final String decimalSep;

  const MaxDecimalDigitsFormatter({
    required this.decimalDigits,
    required this.decimalSep,
  });

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;

    // Reject if the decimal separator appears and no decimals are allowed.
    if (decimalDigits <= 0 && newValue.text.contains(decimalSep)) {
      return oldValue;
    }

    // Split the expression by operators and check each numeric segment.
    final segments = newValue.text.split(RegExp(r'[+\-*/%]'));
    for (final seg in segments) {
      final parts = seg.split(decimalSep);
      if (parts.length > 1 && parts[1].length > decimalDigits) {
        return oldValue;
      }
    }

    return newValue;
  }
}
