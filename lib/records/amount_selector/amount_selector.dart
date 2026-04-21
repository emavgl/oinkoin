import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:piggybank/helpers/records-utility-functions.dart';
import 'package:piggybank/records/amount_selector/logic/evaluate_expression.dart';
import 'package:piggybank/records/amount_selector/utils/bool.extension.dart';
import 'package:piggybank/records/amount_selector/utils/numbers.extensions.dart';
import 'package:piggybank/records/amount_selector/widgets/animated_expanded.dart';
import 'package:piggybank/records/amount_selector/widgets/modal_container.dart';

import '../formatter/auto_decimal_shift_formatter.dart';
import 'formatting/number_formatter.dart';

class AmountSelector extends StatefulWidget {
  const AmountSelector({
    super.key,
    required this.initialAmount,
    // this.currency,
    this.onSubmit,
    this.enableSignToggleButton = true,
    required this.title,
    required this.categorySign,
  });

  final String title;

  final String categorySign;

  final double initialAmount;

  /// Display a button to change the sign of the current value (when the calculator is not enabled)
  final bool enableSignToggleButton;

  final void Function(double amount)? onSubmit;

  @override
  State<AmountSelector> createState() => _AmountSelectorState();
}

class _AmountSelectorState extends State<AmountSelector> {
  late String amountString;
  final autoDec = getAmountInputAutoDecimalShift();

  double get valueToNumber {
    if (amountString.trim() == '') {
      return 0;
    } else if (amountString.trim() == '-' || amountString.trim() == '-0') {
      return -0;
    }

    return evaluateExpression(amountString).roundWithDecimals(2);
  }

  final FocusNode _focusNode = FocusNode();
  late FocusAttachment _focusAttachment;

  bool calculatorMode = false;

  @override
  void initState() {
    super.initState();

    amountString = _parseInitialAmount(widget.initialAmount);

    _focusAttachment = _focusNode.attach(
      context,
      onKeyEvent: (node, event) {
        bool keyIsPressed = event.runtimeType == KeyDownEvent ||
            event.runtimeType == KeyRepeatEvent;

        if (!keyIsPressed) {
          return KeyEventResult.handled;
        }

        if ((event.logicalKey == LogicalKeyboardKey.browserBack ||
            event.logicalKey == LogicalKeyboardKey.goBack ||
            event.logicalKey == LogicalKeyboardKey.escape)) {}

        for (int i = 0; i <= 9; i++) {
          // 0x30 is the standard ASCII/HID offset for the number '0'
          if (event.logicalKey.keyId == 0x30 + i ||
              event.logicalKey.keyId == 0x1100000030 + i) {
            // Numpad offset
            addToAmount(i.toString());
            break;
          }
        }

        for (int i = 0; i <= 9; i++) {
          // 0x1100000030 is the base ID for Numpad 0 in Flutter's LogicalKeyboardKey
          if (event.logicalKey.keyId == 0x1100000030 + i) {
            addToAmount(i.toString());
            break;
          }
        }

        if (event.logicalKey == LogicalKeyboardKey.period) {
          addToAmount('.');
        } else if (event.logicalKey == LogicalKeyboardKey.numpadDecimal) {
          addToAmount('.');
        } else if (event.logicalKey == LogicalKeyboardKey.comma) {
          addToAmount('.');
        } else if (event.logicalKey == LogicalKeyboardKey.backspace) {
          removeLastCharFromAmount();
        } else if (event.logicalKey == LogicalKeyboardKey.delete) {
          removeLastCharFromAmount();
        } else if (event.logicalKey == LogicalKeyboardKey.enter) {
          submitAmount();
        }

        return KeyEventResult.handled;
      },
    );

    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  String _parseInitialAmount(double amount) {
    if (amount == 0) {
      return amount.isNegative ? '-' : '';
    }

    String stringAmount = amount.toStringAsFixed(2);
    if (!stringAmount.contains('.')) {
      return stringAmount;
    }

    int index = stringAmount.length - 1;
    while (stringAmount[index] == '0') {
      index--;
    }
    if (stringAmount[index] == '.') {
      index--;
    }

    return stringAmount.substring(0, index + 1);
  }

  bool _currentNumberHasDecimal() {
    final exprSplit = splitExprByNumbersAndOperator(amountString);

    if (exprSplit.isEmpty) {
      return false;
    }

    return exprSplit.last.contains('.');
  }

  toggleSign() {
    if (amountString.startsWith('-')) {
      amountString = amountString.substring(1, amountString.length);
    } else {
      amountString = '-$amountString';
    }

    HapticFeedback.mediumImpact();

    setState(() {});
  }

  void addToAmount(String newText) {
    final decimalSep = getDecimalSeparator();
    final groupSep = getGroupingSeparator();
    final decDigits = getNumberDecimalDigits();

    // Create the 'old' and 'new' values for the formatters to compare
    final TextEditingValue oldV = TextEditingValue(text: amountString);
    final TextEditingValue newV = TextEditingValue(
      text: amountString + newText,
      selection:
          TextSelection.collapsed(offset: (amountString + newText).length),
    );

    // Always run LeadingZeroIntegerTrimmerFormatter first
    var result = LeadingZeroIntegerTrimmerFormatter(
      decimalSep: decimalSep,
      groupSep: groupSep,
    ).formatEditUpdate(oldV, newV);

    if (autoDec) {
      // If autoDec is ON, we shift decimals
      result = AutoDecimalShiftFormatter(
        decimalDigits: decDigits,
        decimalSep: decimalSep,
        groupSep: groupSep,
      ).formatEditUpdate(oldV, result);
    }

    setState(() {
      // This variable now contains the fully formatted string (e.g., "1,250.00")
      amountString = result.text;
    });
  }

  submitAmount() {
    HapticFeedback.lightImpact();

    if (widget.onSubmit != null) {
      widget.onSubmit!(valueToNumber);
    }
  }

  void clearAmount() {
    setState(() {
      amountString = '0';
      HapticFeedback.lightImpact();
    });
  }

  void removeLastCharFromAmount() {
    if (amountString.isEmpty ||
        amountString == CalculatorOperator.subtract.symbol) {
      return;
    }

    setState(() {
      amountString = amountString.substring(0, amountString.length - 1);
      HapticFeedback.lightImpact();
    });
  }

  toggleCalculatorMode() {
    calculatorMode = !calculatorMode;

    if (calculatorMode == false) {
      amountString = _parseInitialAmount(valueToNumber);
    }

    HapticFeedback.mediumImpact();

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    _focusAttachment.reparent();

    Color tint = Colors.transparent;
    if (widget.categorySign == "-") {
      tint = Colors.red.withOpacity(0.1);
    } else {
      tint = Colors.green.withOpacity(0.1);
    }

    return Container(
      decoration: BoxDecoration(
        color: tint,
      ),
      child: ModalContainer(
        title: widget.title,
        bodyPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // -----
                  // ----> CALCULATOR OPERATION (only displayed if any operation is active):
                  AnimatedExpanded(
                    expand: CalculatorOperator.exprHasOperator(amountString),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [Text(amountString)],
                    ),
                  ),
                  // -----
                  // -----> CURRENT AMOUNT IN THE SELECTED CURRENCY:
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Builder(
                          builder: (context) {
                            final double fontSize = valueToNumber >= 100000000
                                ? valueToNumber >= 100000000000000
                                    ? 24
                                    : 28
                                : 32;

                            return AnimatedDefaultTextStyle(
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineLarge!
                                  .copyWith(fontSize: fontSize),
                              duration: const Duration(milliseconds: 200),
                              child: Builder(
                                builder: (context) {
                                  return OinKoinNumberFormatter
                                      .formatForDisplay(
                                    context,
                                    amountString,
                                    // The raw string being manipulated by addToAmount
                                    integerStyle: Theme.of(context)
                                        .textTheme
                                        .headlineLarge!
                                        .copyWith(
                                          fontSize: 32,
                                        ),
                                    decimalsStyle: TextStyle(
                                      fontSize: 32,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Divider(),
            Flexible(
              child: Container(
                // height: min(MediaQuery.of(context).size.width * 0.8, 300),
                margin: const EdgeInsets.only(top: 16),
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CalculatorButton(
                            onClick: () =>
                                addToAmount(CalculatorOperator.multiply.symbol),
                            text: '×',
                            style: CalculatorButtonStyle.secondary,
                            flex: calculatorMode.toInt(),
                          ),
                          CalculatorButton(
                            onClick: () => addToAmount('1'),
                            text: '1',
                          ),
                          CalculatorButton(
                            onClick: () => addToAmount('4'),
                            text: '4',
                          ),
                          CalculatorButton(
                            onClick: () => addToAmount('7'),
                            text: '7',
                          ),
                          CalculatorButton(
                            onClick: () => addToAmount('0'),
                            text: '0',
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CalculatorButton(
                            onClick: () =>
                                addToAmount(CalculatorOperator.divide.symbol),
                            text: '÷',
                            style: CalculatorButtonStyle.secondary,
                            flex: calculatorMode.toInt(),
                          ),
                          CalculatorButton(
                            onClick: () => addToAmount('2'),
                            text: '2',
                          ),
                          CalculatorButton(
                            onClick: () => addToAmount('5'),
                            text: '5',
                          ),
                          CalculatorButton(
                            onClick: () => addToAmount('8'),
                            text: '8',
                          ),
                          CalculatorButton(
                            disabled: _currentNumberHasDecimal(),
                            onClick: () => addToAmount('.'),
                            text: '.',
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CalculatorButton(
                            onClick: () =>
                                addToAmount(CalculatorOperator.subtract.symbol),
                            text: '-',
                            style: CalculatorButtonStyle.secondary,
                            flex: calculatorMode.toInt(),
                          ),
                          CalculatorButton(
                            onClick: () => addToAmount('3'),
                            text: '3',
                          ),
                          CalculatorButton(
                            onClick: () => addToAmount('6'),
                            text: '6',
                          ),
                          CalculatorButton(
                            onClick: () => addToAmount('9'),
                            text: '9',
                          ),
                          CalculatorButton(
                            onClick: toggleCalculatorMode,
                            style: CalculatorButtonStyle.secondary,
                            icon: calculatorMode
                                ? Icons.fullscreen_exit_rounded
                                : Icons.calculate_rounded,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CalculatorButton(
                            onClick: () =>
                                addToAmount(CalculatorOperator.add.symbol),
                            text: '+',
                            style: CalculatorButtonStyle.secondary,
                            flex: calculatorMode.toInt(),
                          ),
                          CalculatorButton(
                            onClick: removeLastCharFromAmount,
                            onLongPress: clearAmount,
                            style: CalculatorButtonStyle.secondary,
                            icon: Icons.backspace_outlined,
                          ),
                          CalculatorButton(
                            onClick: toggleSign,
                            style: CalculatorButtonStyle.secondary,
                            icon: Icons.exposure_rounded,
                            flex:
                                calculatorMode || !widget.enableSignToggleButton
                                    ? 0
                                    : 1,
                          ),
                          CalculatorButton(
                            disabled: valueToNumber == 0 ||
                                valueToNumber.isInfinite ||
                                valueToNumber.isNaN,
                            onClick: submitAmount,
                            icon: Icons.check_rounded,
                            style: CalculatorButtonStyle.submit,
                            flex:
                                calculatorMode || !widget.enableSignToggleButton
                                    ? 3
                                    : 2,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum CalculatorButtonStyle { submit, main, secondary }

class CalculatorButton extends StatelessWidget {
  final String? text;
  final IconData? icon;
  final int flex;
  final VoidCallback? onClick;
  final VoidCallback? onLongPress;

  final bool disabled;

  final CalculatorButtonStyle style;

  const CalculatorButton({
    super.key,
    this.text,
    this.icon,
    required this.onClick,
    this.onLongPress,
    this.flex = 1,
    this.disabled = false,
    this.style = CalculatorButtonStyle.main,
  }) : assert(
          (text != null && icon == null) || (text == null && icon != null),
          'You must specify either text or icon, not both.',
        );

  @override
  Widget build(BuildContext context) {
    EdgeInsets padding = const EdgeInsets.symmetric(
      vertical: 2.5,
      horizontal: 2.5,
    );
    if (MediaQuery.of(context).size.width >= 600) {
      padding = const EdgeInsets.symmetric(vertical: 4, horizontal: 5);
    } else if (MediaQuery.of(context).size.width >= 1024) {
      padding = const EdgeInsets.symmetric(vertical: 4, horizontal: 32);
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.fastEaseInToSlowEaseOut,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        switchInCurve: Curves.fastEaseInToSlowEaseOut,
        switchOutCurve: Curves.fastOutSlowIn,
        transitionBuilder: (Widget child, Animation<double> animation) {
          return ScaleTransition(scale: animation, child: child);
        },
        child: Container(
          key: ValueKey((text ?? icon.toString()) + flex.toString()),
          height: 65.0 * flex,
          width: double.infinity,
          clipBehavior: Clip.hardEdge,
          decoration: const BoxDecoration(),
          padding: padding,
          child: elevatedButton(context),
        ),
      ),
    );
  }

  ElevatedButton elevatedButton(BuildContext context) {
    Color effectiveTextColor = Theme.of(context).colorScheme.onSurface;
    Color effectiveBgColor = Theme.of(context).colorScheme.surface;

    if (style == CalculatorButtonStyle.submit) {
      effectiveTextColor = Theme.of(context).colorScheme.onPrimary;
      effectiveBgColor = Theme.of(context).colorScheme.primary;
    } else if (style == CalculatorButtonStyle.secondary) {
      effectiveTextColor = Theme.of(
        context,
      ).colorScheme.onSurface.withOpacity(0.9);
      effectiveBgColor = Theme.of(context).colorScheme.surfaceContainerHigh;
    }

    if (icon == Icons.backspace_outlined) {
      effectiveTextColor = Theme.of(context).colorScheme.error;
    }

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).brightness == Brightness.light
            ? effectiveBgColor.withOpacity(0.975)
            : effectiveBgColor.withOpacity(0.85),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        iconColor: effectiveTextColor,
        shadowColor: effectiveBgColor.withOpacity(0.85),
        surfaceTintColor: effectiveBgColor.withOpacity(0.85),
        foregroundColor: effectiveTextColor,
        disabledForegroundColor: effectiveTextColor.withOpacity(0.3),
        disabledIconColor: effectiveTextColor.withOpacity(0.3),
        disabledBackgroundColor: effectiveBgColor.withOpacity(0.3),
        elevation: 0,
        padding: const EdgeInsets.all(0),
      ),
      onPressed: disabled ? null : onClick,
      onLongPress: disabled ? null : onLongPress,
      child: icon != null
          ? Icon(icon, size: 26)
          : Text(
              text!,
              softWrap: false,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
    );
  }
}
