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

    // Strip existing groups so we can re-calculate (prevents 1,,000 error)
    String raw = newValue.text.replaceAll(groupSep, "");

    // Split by operators to handle expressions
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
        // If the user tried to add a second dot, REJECT the change
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

    // Rebuild string
    String result = "";
    for (int i = 0; i < formatted.length; i++) {
      result += formatted[i];
      if (i < operators.length) result += operators[i]!;
    }

    // Cursor Math (Crucial so it doesn't jump)
    int offset = _calculateOffset(newValue.text, result);

    return TextEditingValue(
      text: result,
      selection: TextSelection.collapsed(offset: offset),
    );
  }

  int _calculateOffset(String raw, String formatted) {
    // Logic: The cursor should stay after the digit just typed,
    // even if a grouping separator was inserted behind it.
    int diff = formatted.length - raw.length;
    return (raw.length + diff).clamp(0, formatted.length);
  }
}
