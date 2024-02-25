import 'package:flutter/material.dart';
import 'package:piggybank/i18n.dart';

class AlertDialogBuilder {
  /// Utility class that simplify the creation of an alert dialog that return a boolean value.
  /// There are two buttons, trueButton and falseButton that return either true or false.

  late String title;
  String? subtitle;
  late String trueButtonName;
  late String falseButtonName;

  AlertDialogBuilder(String title) {
    this.title = title;
    this.trueButtonName = "OK";
    this.falseButtonName = "Cancel".i18n;
    this.subtitle = null;
  }

  AlertDialogBuilder addTitle(String title) {
    this.title = title;
    return this;
  }

  AlertDialogBuilder addSubtitle(String subtitle) {
    this.subtitle = subtitle;
    return this;
  }

  AlertDialogBuilder addTrueButtonName(String trueButtonName) {
    this.trueButtonName = trueButtonName;
    return this;
  }

  AlertDialogBuilder addFalseButtonName(String falseButtonName) {
    this.falseButtonName = falseButtonName;
    return this;
  }

  AlertDialog build(BuildContext context) {
    // set up the button
    Widget trueButton = TextButton(
      child: Text(trueButtonName),
      onPressed: () => Navigator.of(context, rootNavigator: true).pop(true),
    );

    // set up the button
    Widget falseButton = TextButton(
      child: Text(falseButtonName),
      onPressed: () => Navigator.of(context, rootNavigator: true).pop(false),
    );

    return AlertDialog(
      title: Text(title),
      content: (subtitle != null) ? Text(subtitle!) : null,
      actions: [
        trueButton,
        falseButton,
      ],
    );
  }
}
