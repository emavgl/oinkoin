import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:piggybank/helpers/amount-input-utils.dart';
import 'package:piggybank/helpers/records-utility-functions.dart';
import 'package:piggybank/records/amount_selector/logic/evaluate_expression.dart';
import 'package:piggybank/records/amount_selector/utils/numbers.extensions.dart';
import 'package:piggybank/records/amount_selector/widgets/modal_container.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/settings/constants/preferences-keys.dart';
import 'package:piggybank/settings/preferences-utils.dart';
import 'package:piggybank/components/keyboard-settings-page.dart';

// Fixed background color palette.
// null entries are theme-resolved in _resolvedBgColor (see switch there).
const List<Color?> kKeyboardBgColors = [
  null, // 0 Default  → colorScheme.secondaryContainer
  Color(0xFF1C1C1E), // 1 Black
  Color(0xFFFFFFFF), // 2 White
  Color(0xFF1A237E), // 3 Navy
  Color(0xFF1B5E20), // 4 Forest
  Color(0xFF37474F), // 5 Slate
  Color(0xFF9E9E9E), // 6 Grey
  null, // 7 Page background → scaffoldBackgroundColor
  Color(0xFFEEEEEE), // 8 Light grey
];

// Fixed button color palette. Index 0 (null) = use the app theme color.
const List<Color?> kKeyboardButtonColors = [
  null,
  Color(0xFF212121), // Black
  Color(0xFFFFFFFF), // White
  Color(0xFFEEEEEE), // Light grey
  Color(0xFF424242), // Dark grey
];

class InAppKeyboard extends StatefulWidget {
  const InAppKeyboard({
    super.key,
    required this.controller,
    this.onSubmit,
    this.enableSignToggleButton = true,
    this.title,
    this.decDigits,
  });

  final TextEditingController controller;
  final String? title;
  final bool enableSignToggleButton;
  final void Function(double amount)? onSubmit;

  /// Overrides the global [getNumberDecimalDigits] when non-null.
  final int? decDigits;

  @override
  State<InAppKeyboard> createState() => _InAppKeyboardState();
}

class _InAppKeyboardState extends State<InAppKeyboard> {
  late final List<TextInputFormatter> _formatters;

  final FocusNode _focusNode = FocusNode();
  late FocusAttachment _focusAttachment;

  String get _text => widget.controller.text;

  double get _scale {
    final index = PreferencesUtils.getOrDefault<int>(
        ServiceConfig.sharedPreferences!, PreferencesKeys.inAppKeyboardScale)!;
    const scales = [0.6, 0.75, 0.9];
    return scales[index.clamp(0, 2)];
  }

  int get _bgColorIndex => PreferencesUtils.getOrDefault<int>(
      ServiceConfig.sharedPreferences!,
      PreferencesKeys.inAppKeyboardBackgroundColorIndex)!;

  int get _buttonColorIndex => PreferencesUtils.getOrDefault<int>(
      ServiceConfig.sharedPreferences!,
      PreferencesKeys.inAppKeyboardButtonColorIndex)!;

  int get _textColorIndex => PreferencesUtils.getOrDefault<int>(
      ServiceConfig.sharedPreferences!,
      PreferencesKeys.inAppKeyboardTextColorIndex)!;

  /// Fixed palette entries are used directly.
  /// null entries are resolved against the active theme by index.
  Color _resolvedBgColor(BuildContext context) {
    final paletteColor =
        _bgColorIndex >= 0 && _bgColorIndex < kKeyboardBgColors.length
            ? kKeyboardBgColors[_bgColorIndex]
            : null;
    if (paletteColor != null) return paletteColor;
    switch (_bgColorIndex) {
      case 7:
        return Theme.of(context).scaffoldBackgroundColor;
      default:
        return Theme.of(context).colorScheme.secondaryContainer;
    }
  }

  /// Index 0 → theme's surface (adapts to light/dark).
  /// Any other index → fixed color from the palette.
  Color _resolvedButtonBgColor(BuildContext context) {
    final fixed = _buttonColorIndex > 0 &&
            _buttonColorIndex < kKeyboardButtonColors.length
        ? kKeyboardButtonColors[_buttonColorIndex]
        : null;
    return fixed ?? Theme.of(context).colorScheme.surface;
  }

  /// Explicit text color setting (1=white, 2=black) takes priority.
  /// Auto (0): derived from button background luminance.
  Color _resolvedButtonTextColor(BuildContext context) {
    switch (_textColorIndex) {
      case 1: return Colors.white;
      case 2: return Colors.black87;
      default: break;
    }
    final fixed = _buttonColorIndex > 0 &&
            _buttonColorIndex < kKeyboardButtonColors.length
        ? kKeyboardButtonColors[_buttonColorIndex]
        : null;
    if (fixed == null) return Theme.of(context).colorScheme.onSurface;
    return fixed.computeLuminance() > 0.4 ? Colors.black87 : Colors.white;
  }

  double get valueToNumber {
    try {
      final trimmed = _text.trim();
      if (trimmed.isEmpty) return 0;
      if (trimmed == '-' || trimmed == '-0') return 0;
      return evaluateExpression(trimmed).roundWithDecimals(2);
    } catch (_) {
      return 0;
    }
  }

  bool _currentNumberHasDecimal() {
    final parts = splitExprByNumbersAndOperator(_text);
    return parts.isNotEmpty && parts.last.contains(getDecimalSeparator());
  }

  @override
  void initState() {
    super.initState();
    _formatters = buildAmountInputFormatters(
      decimalSep: getDecimalSeparator(),
      groupSep: getGroupingSeparator(),
      autoDec: getAmountInputAutoDecimalShift(),
      decDigits: widget.decDigits ?? getNumberDecimalDigits(),
    );
    widget.controller.addListener(_onControllerChanged);
    _focusAttachment = _focusNode.attach(context, onKeyEvent: _handleKeyEvent);
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    final keyIsPressed = event.runtimeType == KeyDownEvent ||
        event.runtimeType == KeyRepeatEvent;
    if (!keyIsPressed) return KeyEventResult.ignored;

    for (int i = 0; i <= 9; i++) {
      if (event.logicalKey.keyId == 0x30 + i ||
          event.logicalKey.keyId == 0x1100000030 + i) {
        _pressKey(i.toString());
        return KeyEventResult.handled;
      }
    }
    if (event.logicalKey == LogicalKeyboardKey.period ||
        event.logicalKey == LogicalKeyboardKey.numpadDecimal ||
        event.logicalKey == LogicalKeyboardKey.comma) {
      _pressKey(getDecimalSeparator());
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.backspace ||
        event.logicalKey == LogicalKeyboardKey.delete) {
      _backspace();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      _submit();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  TextEditingValue _applyFormatters(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return _formatters.fold(
        newValue, (v, f) => f.formatEditUpdate(oldValue, v));
  }

  void _pressKey(String char) {
    final old = widget.controller.value;
    String base = old.text;
    if (CalculatorOperator.isOperator(char) &&
        CalculatorOperator.exprEndsWithOperator(base)) {
      base = base.substring(0, base.length - 1);
    }
    final appended = base + char;
    final baseValue = TextEditingValue(
      text: base,
      selection: TextSelection.collapsed(offset: base.length),
    );
    final next = TextEditingValue(
      text: appended,
      selection: TextSelection.collapsed(offset: appended.length),
    );
    widget.controller.value = _applyFormatters(baseValue, next);
    HapticFeedback.lightImpact();
  }

  void _backspace() {
    final old = widget.controller.value;
    if (old.text.isEmpty) return;
    final newText = old.text.substring(0, old.text.length - 1);
    final next = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
    widget.controller.value = _applyFormatters(old, next);
    HapticFeedback.lightImpact();
  }

  void _clear() {
    widget.controller.value = TextEditingValue.empty;
    HapticFeedback.lightImpact();
  }

  void _toggleSign() {
    final text = _text;
    final newText = text.startsWith('-') ? text.substring(1) : '-$text';
    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
    HapticFeedback.mediumImpact();
  }

  void _submit() {
    HapticFeedback.lightImpact();
    widget.onSubmit?.call(valueToNumber);
  }

  Future<void> _openSettings() async {
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => const KeyboardSettingsPage()),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    _focusAttachment.reparent();
    final scale = _scale;
    final containerBg = _resolvedBgColor(context);
    final btnBg = _resolvedButtonBgColor(context);
    final btnFg = _resolvedButtonTextColor(context);

    // Local helper — captures scale and resolved colors so call sites stay terse.
    CalculatorButton btn({
      String? text,
      IconData? icon,
      required VoidCallback? onClick,
      VoidCallback? onLongPress,
      int flex = 1,
      bool disabled = false,
      CalculatorButtonStyle style = CalculatorButtonStyle.main,
    }) {
      final isSubmit = style == CalculatorButtonStyle.submit;
      return CalculatorButton(
        text: text,
        icon: icon,
        onClick: onClick,
        onLongPress: onLongPress,
        flex: flex,
        disabled: disabled,
        style: style,
        scale: scale,
        bgColorOverride: isSubmit ? null : btnBg,
        textColorOverride: isSubmit ? null : btnFg,
      );
    }

    return Container(
      decoration: BoxDecoration(color: containerBg),
      child: ModalContainer(
        title: widget.title,
        bodyPadding: EdgeInsets.fromLTRB(
          16 * scale,
          widget.title == null ? 12 * scale : 0,
          16 * scale,
          12 * scale,
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Container(
                    margin: EdgeInsets.only(top: 16 * scale),
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
                              btn(
                                  onClick: () => _pressKey('*'),
                                  text: '×',
                                  style: CalculatorButtonStyle.secondary),
                              btn(onClick: () => _pressKey('1'), text: '1'),
                              btn(onClick: () => _pressKey('4'), text: '4'),
                              btn(onClick: () => _pressKey('7'), text: '7'),
                              btn(
                                  onClick: _openSettings,
                                  icon: Icons.settings_outlined,
                                  style: CalculatorButtonStyle.secondary),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              btn(
                                  onClick: () => _pressKey('/'),
                                  text: '÷',
                                  style: CalculatorButtonStyle.secondary),
                              btn(onClick: () => _pressKey('2'), text: '2'),
                              btn(onClick: () => _pressKey('5'), text: '5'),
                              btn(onClick: () => _pressKey('8'), text: '8'),
                              btn(onClick: () => _pressKey('0'), text: '0'),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              btn(
                                  onClick: () => _pressKey('-'),
                                  text: '-',
                                  style: CalculatorButtonStyle.secondary),
                              btn(onClick: () => _pressKey('3'), text: '3'),
                              btn(onClick: () => _pressKey('6'), text: '6'),
                              btn(onClick: () => _pressKey('9'), text: '9'),
                              btn(
                                onClick: () => _pressKey(getDecimalSeparator()),
                                text: getDecimalSeparator(),
                                disabled: _currentNumberHasDecimal(),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              btn(
                                  onClick: () => _pressKey('+'),
                                  text: '+',
                                  style: CalculatorButtonStyle.secondary),
                              btn(
                                onClick: _backspace,
                                onLongPress: _clear,
                                style: CalculatorButtonStyle.secondary,
                                icon: Icons.backspace_outlined,
                              ),
                              btn(
                                onClick: _toggleSign,
                                style: CalculatorButtonStyle.secondary,
                                icon: Icons.exposure_rounded,
                                flex: widget.enableSignToggleButton ? 1 : 0,
                              ),
                              btn(
                                disabled: valueToNumber.isInfinite ||
                                    valueToNumber.isNaN,
                                onClick: _submit,
                                icon: Icons.check_rounded,
                                style: CalculatorButtonStyle.submit,
                                flex: widget.enableSignToggleButton ? 2 : 3,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum CalculatorButtonStyle { main, submit, secondary }

class CalculatorButton extends StatelessWidget {
  final String? text;
  final IconData? icon;
  final int flex;
  final double scale;
  final VoidCallback? onClick;
  final VoidCallback? onLongPress;
  final bool disabled;
  final CalculatorButtonStyle style;
  final Color? bgColorOverride;
  final Color? textColorOverride;

  const CalculatorButton({
    super.key,
    this.text,
    this.icon,
    required this.onClick,
    this.scale = 0.75,
    this.onLongPress,
    this.flex = 1,
    this.disabled = false,
    this.style = CalculatorButtonStyle.secondary,
    this.bgColorOverride,
    this.textColorOverride,
  }) : assert(
          (text != null && icon == null) || (text == null && icon != null),
          'Specify either text or icon, not both.',
        );

  @override
  Widget build(BuildContext context) {
    final padding = EdgeInsets.symmetric(
      vertical: 2.5 * scale,
      horizontal: 2.5 * scale,
    );

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.fastEaseInToSlowEaseOut,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        switchInCurve: Curves.fastEaseInToSlowEaseOut,
        switchOutCurve: Curves.fastOutSlowIn,
        transitionBuilder: (child, animation) =>
            ScaleTransition(scale: animation, child: child),
        child: Container(
          key: ValueKey((text ?? icon.toString()) + flex.toString()),
          height: 65.0 * scale * flex,
          width: double.infinity,
          clipBehavior: Clip.hardEdge,
          decoration: const BoxDecoration(),
          padding: padding,
          child: _elevatedButton(context),
        ),
      ),
    );
  }

  ElevatedButton _elevatedButton(BuildContext context) {
    Color textColor =
        textColorOverride ?? Theme.of(context).colorScheme.onSurface;
    Color bgColor = bgColorOverride ?? Theme.of(context).colorScheme.surface;

    // Submit and special icons always override the resolved colors.
    if (style == CalculatorButtonStyle.submit) {
      textColor = Theme.of(context).colorScheme.onPrimary;
      bgColor = Theme.of(context).colorScheme.primary;
    }
    if (icon == Icons.backspace_outlined) {
      textColor = Theme.of(context).colorScheme.error;
    }

    final isLight = Theme.of(context).brightness == Brightness.light;
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: bgColor.withValues(alpha: isLight ? 0.975 : 0.85),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        iconColor: textColor,
        shadowColor: bgColor.withValues(alpha: 0.85),
        surfaceTintColor: bgColor.withValues(alpha: 0.85),
        foregroundColor: textColor,
        disabledForegroundColor: textColor.withValues(alpha: 0.3),
        disabledIconColor: textColor.withValues(alpha: 0.3),
        disabledBackgroundColor: bgColor.withValues(alpha: 0.3),
        elevation: 0,
        padding: const EdgeInsets.all(0),
      ),
      onPressed: disabled ? null : onClick,
      onLongPress: disabled ? null : onLongPress,
      child: icon != null
          ? Icon(icon, size: 26 * scale)
          : Text(
              text!,
              softWrap: false,
              style: TextStyle(
                fontSize: 24 * scale,
                fontWeight: FontWeight.bold,
              ),
            ),
    );
  }
}
