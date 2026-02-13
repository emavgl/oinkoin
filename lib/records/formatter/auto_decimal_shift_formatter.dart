import 'package:flutter/services.dart';

/// Automatically shifts digits to create decimal numbers based on the configured
/// number of decimal places.
///
/// This formatter assumes the user is typing the entire number including decimal
/// places, and automatically inserts the decimal separator at the correct position.
///
/// Example with 2 decimal places:
/// - Typing "5" becomes "0.05"
/// - Typing "50" becomes "0.50"
/// - Typing "5099" becomes "50.99"
///
/// The formatter also supports mathematical expressions and preserves operators:
/// - "50+25" becomes "0.50+0.25"
///
/// Note: This formatter always places the cursor at the end of the text after
/// formatting. It should be used before GroupSeparatorFormatter in the inputFormatters
/// list to ensure proper group separator insertion.
class AutoDecimalShiftFormatter extends TextInputFormatter {
  /// The number of decimal digits to shift (e.g., 2 for cents)
  final int decimalDigits;

  /// The decimal separator character (e.g., "." or ",")
  final String decimalSep;

  /// The grouping separator character (e.g., "," or ".")
  final String groupSep;

  AutoDecimalShiftFormatter({
    required this.decimalDigits,
    required this.decimalSep,
    required this.groupSep,
  });

  bool _isOp(String c) =>
      c == '+' || c == '-' || c == '*' || c == '/' || c == '%';

  /// Strips all non-digit characters (including separators) to get clean digits
  String _onlyDigits(String s) {
    return s
        .replaceAll(groupSep, '')
        .replaceAll(decimalSep, '')
        .replaceAll(RegExp(r'[^0-9]'), '');
  }

  /// Formats a string of digits by inserting the decimal separator
  /// at the position determined by decimalDigits
  String _formatDigits(String digits) {
    if (digits.isEmpty) return '';

    String left;
    String right;

    if (digits.length <= decimalDigits) {
      // Not enough digits: pad with leading zeros
      left = '0';
      right = digits.padLeft(decimalDigits, '0');
    } else {
      // Split digits at the decimal position from the right
      final cut = digits.length - decimalDigits;
      left = digits.substring(0, cut);
      right = digits.substring(cut);
    }

    // Remove unnecessary leading zeros from integer part, but keep at least one
    left = left.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    if (left.isEmpty) left = '0';

    return '$left$decimalSep$right';
  }

  /// Formats a number token (potentially with unary sign)
  String _formatNumberToken(String token) {
    if (token.isEmpty) return '';

    final hasSign = token.startsWith('-') || token.startsWith('+');
    final sign = hasSign ? token[0] : '';
    final body = hasSign ? token.substring(1) : token;

    final digits = _onlyDigits(body);
    final formatted = _formatDigits(digits);

    if (formatted.isEmpty) return sign;

    return '$sign$formatted';
  }

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    // Skip formatting if no decimal places configured
    if (decimalDigits <= 0) return newValue;

    final input = newValue.text;
    if (input.isEmpty) return newValue;

    final s = input.trimLeft();

    // Handle global sign at the start
    final globalSign = (s.startsWith('-') || s.startsWith('+')) ? s[0] : '';
    final body = globalSign.isEmpty ? s : s.substring(1);

    // Tokenize the input, respecting operators and unary signs
    final tokens = <String>[];
    var cur = '';

    for (var i = 0; i < body.length; i++) {
      final c = body[i];

      if (_isOp(c)) {
        // Check if this is a unary operator (+- after another operator or at start)
        final prevIsOp =
            tokens.isNotEmpty && _isOp(tokens.last) && tokens.last.length == 1;
        final unary = (c == '-' || c == '+') &&
            cur.isEmpty &&
            (tokens.isEmpty || prevIsOp);

        if (unary) {
          cur += c;
          continue;
        }

        if (cur.isNotEmpty) {
          tokens.add(cur);
          cur = '';
        }
        tokens.add(c);
      } else {
        cur += c;
      }
    }
    if (cur.isNotEmpty) tokens.add(cur);

    // Build the output string
    final out = StringBuffer();
    if (globalSign.isNotEmpty) out.write(globalSign);

    for (final t in tokens) {
      if (t.length == 1 && _isOp(t)) {
        out.write(t);
      } else {
        out.write(_formatNumberToken(t));
      }
    }

    final outStr = out.toString();

    // Always place cursor at the end (user is typing sequentially)
    return TextEditingValue(
      text: outStr,
      selection: TextSelection.collapsed(offset: outStr.length),
    );
  }
}

/// Removes unnecessary leading zeros from the integer part of a number.
///
/// This formatter trims leading zeros from the integer portion while preserving
/// the decimal part and signs. It only processes simple numbers, not mathematical
/// expressions (those are passed through unchanged).
///
/// Examples:
/// - "005" becomes "5"
/// - "000" becomes "0"
/// - "005.50" becomes "5.50"
/// - "005+003" stays "005+003" (expressions not modified)
///
/// This formatter should run after GroupSeparatorFormatter in the inputFormatters
/// list to ensure group separators are handled correctly.
class LeadingZeroIntegerTrimmerFormatter extends TextInputFormatter {
  /// The decimal separator character (e.g., "." or ",")
  final String decimalSep;

  /// The grouping separator character (e.g., "," or ".")
  final String groupSep;

  LeadingZeroIntegerTrimmerFormatter({
    required this.decimalSep,
    required this.groupSep,
  });

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final t = newValue.text;
    if (t.isEmpty) return newValue;

    // Skip processing for mathematical expressions
    final bodyForOps =
        (t.startsWith('-') || t.startsWith('+')) ? t.substring(1) : t;
    if (RegExp(r'[+\-*/%]').hasMatch(bodyForOps)) return newValue;

    // Extract sign if present
    final sign = (t.startsWith('-') || t.startsWith('+')) ? t[0] : '';
    final body = sign.isEmpty ? t : t.substring(1);

    // Split into integer and fractional parts
    final decIdx = body.indexOf(decimalSep);
    final intPartRaw = decIdx >= 0 ? body.substring(0, decIdx) : body;
    final fracPart = decIdx >= 0 ? body.substring(decIdx) : '';

    // Strip group separators for processing
    var intDigits = intPartRaw.replaceAll(groupSep, '');

    if (intDigits.isEmpty) return newValue;

    // Remove leading zeros, but keep at least one digit
    intDigits = intDigits.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    if (intDigits.isEmpty) intDigits = '0';

    final out = '$sign$intDigits$fracPart';

    // Return unchanged if no modification needed
    if (out == t) return newValue;

    return TextEditingValue(
      text: out,
      selection: TextSelection.collapsed(offset: out.length),
    );
  }
}
