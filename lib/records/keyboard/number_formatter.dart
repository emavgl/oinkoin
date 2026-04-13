import 'package:flutter/material.dart';
import 'package:piggybank/helpers/records-utility-functions.dart';

import '../formatter/group-separator-formatter.dart'
    show GroupSeparatorFormatter;

class OinKoinNumberFormatter {
  static Widget formatForDisplay(
    BuildContext context,
    String amountStr, {
    required TextStyle integerStyle,
    required TextStyle decimalsStyle,
  }) {
    final decimalSep = getDecimalSeparator();
    final groupSep = getGroupingSeparator();

    // 1. Use your GroupSeparatorFormatter logic to inject separators
    // We create a dummy value to process
    final formatter =
        GroupSeparatorFormatter(groupSep: groupSep, decimalSep: decimalSep);
    final visualValue = formatter
        .formatEditUpdate(
            TextEditingValue.empty, TextEditingValue(text: amountStr))
        .text;

    // 2. Split for styling (Large Int / Small Decimals)
    // We split by the decimal separator, but we are careful with expressions (10+5.50)
    // For the UI display, we usually only style the last number's decimals
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
