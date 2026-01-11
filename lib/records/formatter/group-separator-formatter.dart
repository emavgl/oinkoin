import 'package:flutter/services.dart';

class GroupSeparatorFormatter extends TextInputFormatter {
  final String groupSep;
  final String decimalSep;

  const GroupSeparatorFormatter(
      {required this.groupSep, required this.decimalSep});

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;

    // 1. Strip existing groups so we can re-calculate (prevents 1,,000 error)
    String raw = newValue.text.replaceAll(groupSep, "");

    // 2. Split by operators to handle expressions
    final segments = raw.split(RegExp(r'([+\-*/%])'));
    final operators = RegExp(r'[+\-*/%]').allMatches(raw).map((m) => m.group(0)).toList();

    List<String> formatted = [];
    for (var seg in segments) {
      if (seg.isEmpty) { formatted.add(""); continue; }

      if (decimalSep.allMatches(seg).length > 1) {
        // If the user tried to add a second dot, REJECT the change
        return oldValue;
      }

      // Split into Integer and Decimal
      List<String> parts = seg.split(decimalSep);
      String intPart = parts[0];

      // Apply grouping to integer part
      RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
      intPart = intPart.replaceAllMapped(reg, (m) => '${m[1]}$groupSep');

      formatted.add(parts.length > 1 ? "$intPart$decimalSep${parts[1]}" : intPart);
    }

    // 3. Rebuild string
    String result = "";
    for (int i = 0; i < formatted.length; i++) {
      result += formatted[i];
      if (i < operators.length) result += operators[i]!;
    }

    // 4. Cursor Math (Crucial so it doesn't jump)
    int offset = _calculateOffset(newValue.text, result);

    return TextEditingValue(
      text: result,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
  int _calculateOffset(String raw, String formatted) {
    // Logic: The cursor should stay after the digit you just typed,
    // even if a grouping separator was inserted behind it.
    int diff = formatted.length - raw.length;
    return (raw.length + diff).clamp(0, formatted.length);
  }

  String _preventDoubleDecimals(String text) {
    final segments = text.split(RegExp(r'[+\-*/%]'));
    String result = text;

    for (var segment in segments) {
      if (decimalSep.allMatches(segment).length > 1) {
        // If this segment has two decimals, revert the last one
        int lastIndex = text.lastIndexOf(decimalSep);
        result = text.substring(0, lastIndex) + text.substring(lastIndex + 1);
      }
    }
    return result;
  }

  String _applyGrouping(String text) {
    if (text.isEmpty) return "";

    final segments = text.split(RegExp(r'([+\-*/%])'));
    final operators =
        RegExp(r'[+\-*/%]').allMatches(text).map((m) => m.group(0)).toList();

    List<String> results = [];

    for (var segment in segments) {
      if (segment.isEmpty) {
        results.add("");
        continue;
      }

      List<String> parts = segment.split(decimalSep);
      // Remove existing group separators before re-applying
      String integerPart = parts[0].replaceAll(groupSep, "");

      // Regex for grouping: adds separator every 3 digits
      RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
      integerPart =
          integerPart.replaceAllMapped(reg, (m) => '${m[1]}$groupSep');

      if (parts.length > 1) {
        results.add("$integerPart$decimalSep${parts[1]}");
      } else if (segment.endsWith(decimalSep)) {
        results.add("$integerPart$decimalSep");
      } else {
        results.add(integerPart);
      }
    }

    // Reconstruct string with operators
    String finalStr = "";
    for (int i = 0; i < results.length; i++) {
      finalStr += results[i];
      if (i < operators.length) finalStr += operators[i]!;
    }
    return finalStr;
  }

  int _calculateCursorOffset(
      String oldText, String formattedText, int newSelectionOffset) {
    // This logic ensures that if a comma is added/removed, the cursor stays
    // relative to the digits the user just typed.
    int digitCountBeforeCursor = 0;
    // Count non-separator characters in the raw input before cursor
    for (int i = 0; i < newSelectionOffset; i++) {
      // If you have a dynamic input, we ignore the groupSep
      // but keep operators and decimals as 'anchor' points
      digitCountBeforeCursor++;
    }
    //var groupSep = ",";
    // We find the position in formattedText that contains the same number of 'non-grouping' chars
    int formattedOffset = 0;
    int nonGroupCount = 0;
    while (formattedOffset < formattedText.length &&
        nonGroupCount < newSelectionOffset) {
      if (formattedText[formattedOffset] != groupSep) {
        nonGroupCount++;
      }
      formattedOffset++;
    }
    return formattedOffset;
  }
}
