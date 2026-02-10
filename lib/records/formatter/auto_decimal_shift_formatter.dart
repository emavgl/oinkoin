import 'package:flutter/services.dart';

class AutoDecimalShiftFormatter extends TextInputFormatter {
  AutoDecimalShiftFormatter({
    required this.decimalDigits,
    required this.decimalSep,
    required this.groupSep,
  });

  final int decimalDigits;
  final String decimalSep;
  final String groupSep;

  bool _isOp(String c) => c == '+' || c == '-' || c == '*' || c == '/' || c == '%';

  String _onlyDigits(String s) {
    return s
        .replaceAll(groupSep, '')
        .replaceAll(decimalSep, '')
        .replaceAll(RegExp(r'[^0-9]'), '');
  }

  String _formatDigits(String digits) {
    if (digits.isEmpty) return '';

    String left;
    String right;

    if (digits.length <= decimalDigits) {
      left = '0';
      right = digits.padLeft(decimalDigits, '0');
    } else {
      final cut = digits.length - decimalDigits;
      left = digits.substring(0, cut);
      right = digits.substring(cut);
    }

    left = left.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    if (left.isEmpty) left = '0';

    return '$left$decimalSep$right';
  }

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
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (decimalDigits <= 0) return newValue;

    final input = newValue.text;
    if (input.isEmpty) return newValue;

    final s = input.trimLeft();

    final globalSign = (s.startsWith('-') || s.startsWith('+')) ? s[0] : '';
    final body = globalSign.isEmpty ? s : s.substring(1);

    final tokens = <String>[];
    var cur = '';

    for (var i = 0; i < body.length; i++) {
      final c = body[i];

      if (_isOp(c)) {
        final prevIsOp = tokens.isNotEmpty && _isOp(tokens.last) && tokens.last.length == 1;
        final unary = (c == '-' || c == '+') && cur.isEmpty && (tokens.isEmpty || prevIsOp);

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

    return TextEditingValue(
      text: outStr,
      selection: TextSelection.collapsed(offset: outStr.length),
    );
  }
}

class LeadingZeroIntegerTrimmerFormatter extends TextInputFormatter {
  LeadingZeroIntegerTrimmerFormatter({
    required this.decimalSep,
    required this.groupSep,
  });

  final String decimalSep;
  final String groupSep;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final t = newValue.text;
    if (t.isEmpty) return newValue;

    final bodyForOps = (t.startsWith('-') || t.startsWith('+')) ? t.substring(1) : t;
    if (RegExp(r'[+\-*/%]').hasMatch(bodyForOps)) return newValue;

    final sign = (t.startsWith('-') || t.startsWith('+')) ? t[0] : '';
    final body = sign.isEmpty ? t : t.substring(1);

    final decIdx = body.indexOf(decimalSep);
    final intPartRaw = decIdx >= 0 ? body.substring(0, decIdx) : body;
    final fracPart = decIdx >= 0 ? body.substring(decIdx) : '';

    var intDigits = intPartRaw.replaceAll(groupSep, '');

    if (intDigits.isEmpty) return newValue;

    intDigits = intDigits.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    if (intDigits.isEmpty) intDigits = '0';

    final out = '$sign$intDigits$fracPart';

    if (out == t) return newValue;

    return TextEditingValue(
      text: out,
      selection: TextSelection.collapsed(offset: out.length),
    );
  }
}