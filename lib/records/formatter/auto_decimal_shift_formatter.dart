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
/// Note: the cursor is preserved across formatting: it is mapped by counting
/// the digits that sit to the right of the caret in the typed token, so the
/// caret stays where the user put it even though decimal separators and
/// leading zeros are inserted or removed. It should be used before
/// GroupSeparatorFormatter in the inputFormatters list to ensure proper group
/// separator insertion.
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

  bool _isDigit(int codeUnit) => codeUnit >= 0x30 && codeUnit <= 0x39;

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

    // Tokenize the input, respecting operators and unary signs. Raw start
    // offsets are kept so the caret can be mapped onto the formatted output.
    final tokens = <_AmountToken>[];
    var cur = '';
    var curStart = 0;

    for (var i = 0; i < body.length; i++) {
      final c = body[i];

      if (_isOp(c)) {
        // Check if this is a unary operator (+- after another operator or at start)
        final prevIsOp = tokens.isNotEmpty && tokens.last.isOperator;
        final unary = (c == '-' || c == '+') &&
            cur.isEmpty &&
            (tokens.isEmpty || prevIsOp);

        if (unary) {
          if (cur.isEmpty) curStart = i;
          cur += c;
          continue;
        }

        if (cur.isNotEmpty) {
          tokens.add(_AmountToken(cur, curStart, isOperator: false));
          cur = '';
        }
        tokens.add(_AmountToken(c, i, isOperator: true));
      } else {
        if (cur.isEmpty) curStart = i;
        cur += c;
      }
    }
    if (cur.isNotEmpty) {
      tokens.add(_AmountToken(cur, curStart, isOperator: false));
    }

    // Build the output string
    final out = StringBuffer();
    if (globalSign.isNotEmpty) out.write(globalSign);

    for (final t in tokens) {
      t.outStart = out.length;
      if (t.isOperator) {
        out.write(t.text);
      } else {
        out.write(_formatNumberToken(t.text));
      }
      t.outEnd = out.length;
    }

    final outStr = out.toString();

    return TextEditingValue(
      text: outStr,
      selection: TextSelection.collapsed(
        offset: _calculateOffset(newValue, tokens, outStr, globalSign.length),
      ),
    );
  }

  /// Maps the caret of [newValue] onto the formatted [output].
  ///
  /// The caret is located inside a token of the raw text; the number of digits
  /// that follow it inside that token is then used to find the equivalent spot
  /// in the formatted token. This keeps the caret stable when the decimal
  /// separator or leading zeros are inserted elsewhere in the token.
  int _calculateOffset(TextEditingValue newValue, List<_AmountToken> tokens,
      String output, int signLength) {
    if (tokens.isEmpty) return output.length;

    final selection = newValue.selection;
    final rawCaret =
        selection.isValid ? selection.baseOffset : newValue.text.length;
    // Token offsets are relative to the body, i.e. without the global sign.
    final caret = (rawCaret - signLength).clamp(0, newValue.text.length);

    _AmountToken? target;
    for (final token in tokens) {
      if (caret <= token.rawEnd) {
        target = token;
        break;
      }
    }
    target ??= tokens.last;

    // Operators are single characters: keep the caret right after them.
    if (target.isOperator) return target.outEnd;

    final caretInToken =
        (caret - target.rawStart).clamp(0, target.text.length);
    var digitsRight = 0;
    for (var i = caretInToken; i < target.text.length; i++) {
      if (_isDigit(target.text.codeUnitAt(i))) digitsRight++;
    }

    final formattedToken = output.substring(target.outStart, target.outEnd);
    var pos = formattedToken.length;
    var remaining = digitsRight;
    while (pos > 0 && remaining > 0) {
      pos--;
      if (_isDigit(formattedToken.codeUnitAt(pos))) remaining--;
    }
    return target.outStart + pos;
  }
}

/// A numeric or operator token produced while formatting, together with its
/// position in the raw input and in the formatted output.
class _AmountToken {
  _AmountToken(this.text, this.rawStart, {required this.isOperator})
      : rawEnd = rawStart + text.length;

  final String text;
  final int rawStart;
  final int rawEnd;
  final bool isOperator;
  int outStart = 0;
  int outEnd = 0;
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
    final intDigits = intPartRaw.replaceAll(groupSep, '');

    if (intDigits.isEmpty) return newValue;

    // Remove leading zeros, but keep at least one digit
    final trimmedDigits =
        intDigits.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    if (trimmedDigits.isEmpty) return newValue;

    // Nothing to trim: keep the value untouched (including group separators
    // and the current caret). GroupSeparatorFormatter, which runs next when
    // auto-decimal-shift is off, handles the regrouping.
    if (trimmedDigits.length == intDigits.length) return newValue;

    final removedZeros = intDigits.length - trimmedDigits.length;
    final out = '$sign$trimmedDigits$fracPart';

    // Map the caret: count the characters that are not group separators
    // before it, then account for the removed leading zeros. This keeps the
    // caret stable instead of jumping to the end of the field.
    final selection = newValue.selection;
    if (!selection.isValid) {
      return TextEditingValue(
        text: out,
        selection: TextSelection.collapsed(offset: out.length),
      );
    }
    final rawCaret = selection.baseOffset.clamp(0, t.length);
    var cleanBefore = 0;
    var i = 0;
    while (i < rawCaret) {
      if (groupSep.isNotEmpty &&
          t.startsWith(groupSep, i) &&
          i + groupSep.length <= rawCaret) {
        i += groupSep.length;
        continue;
      }
      cleanBefore++;
      i++;
    }
    final caret = (cleanBefore - removedZeros).clamp(0, out.length);

    return TextEditingValue(
      text: out,
      selection: TextSelection.collapsed(offset: caret),
    );
  }
}
