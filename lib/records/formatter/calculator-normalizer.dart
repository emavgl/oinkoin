import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

class CalculatorNormalizer extends TextInputFormatter {
  final bool overwriteDot;
  final bool overwriteComma;
  final String groupSep;
  final String decimalSep;

  CalculatorNormalizer(
      {required this.overwriteDot,
      required this.overwriteComma,
      required this.decimalSep,
      required this.groupSep});

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    debugPrint("formatEditUpdate overwriteDot $overwriteDot");
    debugPrint("formatEditUpdate overwriteComma $overwriteComma");
    debugPrint("formatEditUpdate groupSep $groupSep");
    debugPrint("formatEditUpdate decimalSep $decimalSep");
    // 1. Convert 'x' to '*' immediately
    String newText = newValue.text.toLowerCase().replaceAll("x", "*");

    // 2. Detect what was JUST typed
    // We compare the length to ensure the user is adding text, not deleting
    if (newText.length > oldValue.text.length) {
      int selectionIndex = newValue.selection.baseOffset;
      if (selectionIndex > 0) {
        // Look at the character exactly where the cursor is
        String charTyped = newText.substring(selectionIndex - 1, selectionIndex);

        // 3. Force-normalize the specifically typed character
        if (overwriteDot && charTyped == ".") {
          newText = newText.replaceRange(selectionIndex - 1, selectionIndex, decimalSep);
        } else if (overwriteComma && charTyped == ",") {
          newText = newText.replaceRange(selectionIndex - 1, selectionIndex, decimalSep);
        }
      }
    }

    return newValue.copyWith(
      text: newText,
      selection: newValue.selection,
    );
  }
}
