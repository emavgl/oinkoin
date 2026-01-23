import 'package:flutter/services.dart';

/// A pre-processor that standardizes user input into a math-ready format.
class CalculatorNormalizer extends TextInputFormatter {
  final bool overwriteDot;
  final bool overwriteComma;
  final String groupSep;
  final String decimalSep;

  /// This formatter handles:
  /// * **Character Swapping:** Converts user-friendly input (e.g., 'x') into
  ///   the standard mathematical operator ('*').
  /// * **Dynamic Normalization:** Swaps '.' or ',' into the active decimal
  ///   separator based on app settings as the user types.
  /// * **Non-Destructive Editing:** Targets the [selectionIndex] only,
  ///   ensuring thousands-separators are not interfered with during input.
  CalculatorNormalizer(
      {required this.overwriteDot,
      required this.overwriteComma,
      required this.decimalSep,
      required this.groupSep});

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    String newText = newValue.text.toLowerCase().replaceAll("x", "*");

    // We compare the length to ensure the user is adding text, not deleting
    if (newText.length > oldValue.text.length) {
      int selectionIndex = newValue.selection.baseOffset;
      if (selectionIndex > 0) {
        String charTyped =
            newText.substring(selectionIndex - 1, selectionIndex);
        if (overwriteDot && charTyped == ".") {
          newText = newText.replaceRange(
              selectionIndex - 1, selectionIndex, decimalSep);
        } else if (overwriteComma && charTyped == ",") {
          newText = newText.replaceRange(
              selectionIndex - 1, selectionIndex, decimalSep);
        }
      }
    }

    return newValue.copyWith(
      text: newText,
      selection: newValue.selection,
    );
  }
}
