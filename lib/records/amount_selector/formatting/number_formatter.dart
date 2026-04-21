import 'package:flutter/material.dart';
import 'package:piggybank/helpers/records-utility-functions.dart';

import '../../formatter/group-separator-formatter.dart'
    show GroupSeparatorFormatter;

/// A utility class responsible for transforming raw amount strings into
/// rich, localized UI components.
///
/// This class handles the "Display Layer" of the OinKoin amount input flow.
/// It ensures that regardless of how data is stored internally, it is presented
/// to the user with consistent styling, correct locale separators, and
/// emphasis on the integer part of the currency.
class OinKoinNumberFormatter {

  /// Formats an input string into a [RichText] widget with specialized styling
  /// for integer and decimal segments.
  ///
  /// ### Logic Flow:
  /// 1. **Separators Retrieval**: Fetches the active decimal and group
  ///    separators from global app settings.
  /// 2. **Auto-Decimal Logic**: Checks if the user has enabled the "Auto
  ///    Decimal Shift" feature.
  ///    - If **Disabled**: It applies [GroupSeparatorFormatter] to inject
  ///      thousands-separators (e.g., "1000" becomes "1,000").
  ///    - If **Enabled**: It skips grouping to avoid visual clutter during
  ///      rapid shifts (matching the behavior of the legacy TextFormField).
  /// 3. **Visual Splitting**: Splits the resulting string by the decimal
  ///    separator to create two distinct styling zones.
  /// 4. **Rich Construction**: Returns a [RichText] widget where the integer
  ///    portion uses [integerStyle] and the fractional portion uses [decimalsStyle].
  ///
  /// ### Parameters:
  /// - [context]: The BuildContext required for theme-aware rendering.
  /// - [amountStr]: The raw string to be formatted (may contain math operators or clean digits).
  /// - [integerStyle]: The [TextStyle] applied to the currency sign and integer part.
  /// - [decimalsStyle]: The [TextStyle] applied to the decimal separator and fractional part.
  ///
  /// ### Example:
  /// ```dart
  /// OinKoinNumberFormatter.formatForDisplay(
  ///   context,
  ///   "1250.50",
  ///   integerStyle: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
  ///   decimalsStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w300),
  /// )
  /// ```
  /// Output: **1,250**.50 (if grouping is active)
  static Widget formatForDisplay(
    BuildContext context,
    String amountStr, {
    required TextStyle integerStyle,
    required TextStyle decimalsStyle,
  }) {
    final decimalSep = getDecimalSeparator();
    final groupSep = getGroupingSeparator();
    final autoDec = getAmountInputAutoDecimalShift();

    String visualValue = amountStr;

    if (!autoDec) {
      final formatter = GroupSeparatorFormatter(
        groupSep: groupSep,
        decimalSep: decimalSep,
      );
      visualValue = formatter.formatEditUpdate(
          TextEditingValue.empty,
          TextEditingValue(text: amountStr)
      ).text;
    }

    List<String> parts = visualValue.split(decimalSep);

    if (parts.length < 2) {
      return Text(visualValue, style: integerStyle);
    }

    // Example: "1,250" and ".50"
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(text: parts[0], style: integerStyle),
          TextSpan(text: '$decimalSep${parts[1]}', style: decimalsStyle),
        ],
      ),
    );
  }
}
