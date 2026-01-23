import 'package:flutter/services.dart';

/// A post-processor and decorator responsible for visual presentation
/// and numeric segment logic.
class GroupSeparatorFormatter extends TextInputFormatter {
  final String groupSep;
  final String decimalSep;

  /// This formatter handles:
  /// 1. **Expression Awareness:** Splits input strings by operators
  ///    (e.g., '1000+500' → `['1000', '500']`) to group numbers independently.
  /// 2. **Double-Decimal Prevention:** Validates numeric segments to prevent
  ///    invalid math formats like '10.5.5'.
  /// 3. **Visual Grouping:** Injects thousands-separators into integer portions
  ///    using a lookahead [RegExp].
  /// 4. **Cursor Management:** Implements custom `_calculateOffset` logic to
  ///    maintain cursor stability when separators are dynamically added or removed.
  const GroupSeparatorFormatter(
      {required this.groupSep, required this.decimalSep});

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;

    String raw = newValue.text.replaceAll(groupSep, "");

    final segments = raw.split(RegExp(r'([+\-*/%])'));
    final operators =
        RegExp(r'[+\-*/%]').allMatches(raw).map((m) => m.group(0)).toList();

    List<String> formatted = [];
    for (var seg in segments) {
      if (seg.isEmpty) {
        formatted.add("");
        continue;
      }

      if (decimalSep.allMatches(seg).length > 1) {
        return oldValue;
      }

      // Split into Integer and Decimal
      List<String> parts = seg.split(decimalSep);
      String intPart = parts[0];

      // Apply grouping to integer part
      RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
      intPart = intPart.replaceAllMapped(reg, (m) => '${m[1]}$groupSep');

      formatted
          .add(parts.length > 1 ? "$intPart$decimalSep${parts[1]}" : intPart);
    }

    String result = "";
    for (int i = 0; i < formatted.length; i++) {
      result += formatted[i];
      if (i < operators.length) result += operators[i]!;
    }

    int offset = _calculateOffset(newValue, result);

    return TextEditingValue(
      text: result,
      selection: TextSelection.collapsed(offset: offset),
    );
  }

  int _calculateOffset(TextEditingValue newValue, String formatted) {
    // If selection is invalid, keep cursor at end of formatted text.
    final int rawCursorPos = newValue.selection.baseOffset;
    if (rawCursorPos < 0) return formatted.length;

    final int cursorPos = rawCursorPos.clamp(0, newValue.text.length);

    // Count how many non-separator characters are before the cursor in the
    // *current* text, treating groupSep as possibly multi-character.
    int cleanCursorUnits = 0;
    int i = 0;
    while (i < cursorPos) {
      if (groupSep.isNotEmpty &&
          i + groupSep.length <= cursorPos &&
          newValue.text.startsWith(groupSep, i)) {
        i += groupSep.length;
        continue;
      }
      cleanCursorUnits++;
      i++;
    }

    // Map that clean count onto the formatted string.
    int formattedPos = 0;
    int cleanSeen = 0;
    while (formattedPos < formatted.length && cleanSeen < cleanCursorUnits) {
      if (groupSep.isNotEmpty &&
          formattedPos + groupSep.length <= formatted.length &&
          formatted.startsWith(groupSep, formattedPos)) {
        formattedPos += groupSep.length;
        continue;
      }
      cleanSeen++;
      formattedPos++;
    }

    return formattedPos.clamp(0, formatted.length);
  }
}
