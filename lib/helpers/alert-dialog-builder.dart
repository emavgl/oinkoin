import 'package:flutter/material.dart';
import 'package:piggybank/i18n.dart';

class AlertDialogBuilder {
  /// Utility class that simplify the creation of an alert dialog that return a boolean value.
  /// There are two buttons, trueButton and falseButton that return either true or false.

  late String title;
  String? subtitle;
  late bool trueButtonShow;
  late bool falseButtonShow;
  late String trueButtonName;
  late String falseButtonName;

  AlertDialogBuilder(String title) {
    this.title = title;
    this.trueButtonShow = true;
    this.falseButtonShow = true;
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

  AlertDialogBuilder renameTrueButtonName(String trueButtonName) {
    this.trueButtonName = trueButtonName;
    return this;
  }

  AlertDialogBuilder renameFalseButtonName(String falseButtonName) {
    this.falseButtonName = falseButtonName;
    return this;
  }

  AlertDialogBuilder hideTrueButton() {
    this.trueButtonShow = false;
    return this;
  }

  AlertDialogBuilder hideFalseButton() {
    this.falseButtonShow = false;
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
        if (trueButtonShow) trueButton,
        if (falseButtonShow) falseButton,
      ],
    );
  }
}
