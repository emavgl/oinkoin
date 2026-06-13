import 'package:flutter/material.dart';
import 'package:piggybank/helpers/amount-input-utils.dart';
import 'package:piggybank/helpers/records-utility-functions.dart';
import 'package:piggybank/i18n.dart';
import 'package:piggybank/components/inapp-keyboard.dart';

/// A unified amount input widget that transparently switches between keyboard
/// modes based on the user's preference (read once at construction):
///
/// - [AmountKeyboardMode.phoneKeyboard] / [AmountKeyboardMode.numberKeyboard]:
///   a [TextFormField] with math-aware formatters.
/// - [AmountKeyboardMode.inAppKeyboard]: a tappable [TextFormField] that
///   slides up [InAppKeyboard] as a non-modal overlay when tapped.
///
/// Callers interact only with this widget and never need to know which mode
/// is active.
class AmountInputField extends StatefulWidget {
  const AmountInputField({
    super.key,
    required this.controller,
    this.labelText,
    this.suffixText,
    this.enabled = true,
    this.allowNegative = false,
    this.validator,
    this.onChanged,
    this.autofocus = false,
    this.autovalidateMode = AutovalidateMode.disabled,
  });

  final TextEditingController controller;
  final String? labelText;
  final String? suffixText;
  final bool enabled;

  /// Allow negative values. Enables the sign-toggle in [InAppKeyboard] and
  /// accepts a leading minus in text-field mode.
  final bool allowNegative;

  /// Override the default validator. The default rejects empty input and
  /// values that cannot be parsed as locale-aware currency strings.
  final FormFieldValidator<String>? validator;

  final ValueChanged<String>? onChanged;
  final bool autofocus;
  final AutovalidateMode autovalidateMode;

  @override
  State<AmountInputField> createState() => _AmountInputFieldState();
}

class _AmountInputFieldState extends State<AmountInputField> {
  String? _defaultValidator(String? value) {
    if (value == null || value.isEmpty) return "Please enter a value".i18n;
    final parsed = widget.allowNegative
        ? tryParseSignedCurrencyString(value)
        : tryParseCurrencyString(value);
    if (parsed == null) return amountFormatErrorMessage();
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final mode = getAmountKeyboardMode();
    final validator = widget.validator ?? _defaultValidator;

    if (mode == AmountKeyboardMode.inAppKeyboard) {
      return _InAppKeyboardField(
        controller: widget.controller,
        labelText: widget.labelText,
        suffixText: widget.suffixText,
        enabled: widget.enabled,
        allowNegative: widget.allowNegative,
        validator: validator,
        onChanged: widget.onChanged,
        autovalidateMode: widget.autovalidateMode,
        autofocus: widget.autofocus,
      );
    }

    return TextFormField(
      controller: widget.controller,
      enabled: widget.enabled,
      autofocus: widget.autofocus,
      autovalidateMode: widget.autovalidateMode,
      inputFormatters: buildAmountInputFormatters(
        decimalSep: getDecimalSeparator(),
        groupSep: getGroupingSeparator(),
        autoDec: getAmountInputAutoDecimalShift(),
        decDigits: getNumberDecimalDigits(),
      ),
      validator: validator,
      onChanged: widget.onChanged,
      textAlign: TextAlign.end,
      style: TextStyle(
        fontSize: 32.0,
        color: widget.enabled
            ? Theme.of(context).colorScheme.onSurface
            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
      ),
      keyboardType: getAmountInputKeyboardType(mode, signed: widget.allowNegative),
      decoration: InputDecoration(
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelText: widget.labelText,
        hintText: buildZeroAmountText(),
        suffixText: widget.suffixText,
      ),
    );
  }
}

/// InApp-keyboard variant. Shows a [TextFormField] that slides up
/// [InAppKeyboard] as a non-modal overlay when tapped.
class _InAppKeyboardField extends StatefulWidget {
  const _InAppKeyboardField({
    required this.controller,
    required this.enabled,
    required this.allowNegative,
    required this.validator,
    required this.autovalidateMode,
    this.labelText,
    this.suffixText,
    this.onChanged,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool allowNegative;
  final FormFieldValidator<String> validator;
  final AutovalidateMode autovalidateMode;
  final String? labelText;
  final String? suffixText;
  final ValueChanged<String>? onChanged;
  final bool autofocus;

  @override
  State<_InAppKeyboardField> createState() => _InAppKeyboardFieldState();
}

class _InAppKeyboardFieldState extends State<_InAppKeyboardField>
    with WidgetsBindingObserver {
  OverlayEntry? _overlayEntry;
  final GlobalKey<_KeyboardOverlayState> _overlayKey = GlobalKey();
  final GlobalKey _keyboardSizeKey = GlobalKey();
  final FocusNode _focusNode = FocusNode();
  bool _isClosing = false;
  ModalRoute<dynamic>? _observedRoute;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Propagate any controller change (from InApp keyboard or hardware keyboard)
    // to the form via onChanged, since TextFormField.onChanged does not fire on
    // programmatic controller updates.
    widget.controller.addListener(_onControllerChanged);
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openKeyboard();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Watch the host route's animation so we can tear down the overlay the
    // instant a programmatic or AppBar-back navigation begins — before the
    // page transition plays — rather than waiting for dispose().
    final route = ModalRoute.of(context);
    if (route != _observedRoute) {
      _observedRoute?.animation?.removeStatusListener(_onRouteAnimationStatus);
      _observedRoute = route;
      _observedRoute?.animation?.addStatusListener(_onRouteAnimationStatus);
    }
  }

  void _onRouteAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.reverse && _overlayEntry != null) {
      _removeOverlay();
      inAppKeyboardOpen.value = false;
      inAppKeyboardHeight.value = 0.0;
    }
  }

  @override
  void dispose() {
    _observedRoute?.animation?.removeStatusListener(_onRouteAnimationStatus);
    widget.controller.removeListener(_onControllerChanged);
    WidgetsBinding.instance.removeObserver(this);
    _focusNode.dispose();
    _removeOverlay();
    if (inAppKeyboardOpen.value) {
      inAppKeyboardOpen.value = false;
    }
    super.dispose();
  }

  void _onControllerChanged() {
    widget.onChanged?.call(widget.controller.text);
  }

  // Intercepts the Android back button without pushing any route, so the page
  // behind stays fully interactive and focus is never stolen from the field.
  @override
  Future<bool> didPopRoute() async {
    if (_overlayEntry != null) {
      await _doClose();
      return true;
    }
    return false;
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Future<void> _doClose() async {
    if (_isClosing || _overlayEntry == null) return;
    _isClosing = true;
    await _overlayKey.currentState?.animateClose();
    inAppKeyboardOpen.value = false;
    inAppKeyboardHeight.value = 0.0;
    _removeOverlay();
    if (mounted) setState(() => _isClosing = false);
  }

  void _openKeyboard() {
    if (!widget.enabled || _overlayEntry != null) return;

    _overlayEntry = OverlayEntry(
      builder: (_) => Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        child: _KeyboardOverlay(
          key: _overlayKey,
          child: InAppKeyboard(
            key: _keyboardSizeKey,
            controller: widget.controller,
            enableSignToggleButton: widget.allowNegative,
            onSubmit: (_) => _doClose(),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
    inAppKeyboardOpen.value = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Measure the rendered keyboard height so pages can add matching scroll padding.
      final box = _keyboardSizeKey.currentContext?.findRenderObject() as RenderBox?;
      if (box != null) inAppKeyboardHeight.value = box.size.height;
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      focusNode: _focusNode,
      keyboardType: TextInputType.none,
      enabled: widget.enabled,
      autofocus: widget.autofocus,
      autovalidateMode: widget.autovalidateMode,
      inputFormatters: buildAmountInputFormatters(
        decimalSep: getDecimalSeparator(),
        groupSep: getGroupingSeparator(),
        autoDec: getAmountInputAutoDecimalShift(),
        decDigits: getNumberDecimalDigits(),
      ),
      validator: widget.validator,
      // onChanged omitted: _onControllerChanged (registered in initState) covers
      // both InApp-keyboard updates and hardware-keyboard input uniformly.
      onTap: _openKeyboard,
      textAlign: TextAlign.end,
      style: TextStyle(
        fontSize: 32.0,
        color: widget.enabled
            ? Theme.of(context).colorScheme.onSurface
            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
      ),
      decoration: InputDecoration(
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelText: widget.labelText,
        hintText: buildZeroAmountText(),
        suffixText: widget.suffixText,
      ),
    );
  }
}

/// Wraps the keyboard widget with a slide-up entrance / slide-down exit animation.
class _KeyboardOverlay extends StatefulWidget {
  const _KeyboardOverlay({super.key, required this.child});
  final Widget child;

  @override
  _KeyboardOverlayState createState() => _KeyboardOverlayState();
}

class _KeyboardOverlayState extends State<_KeyboardOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  Future<void> animateClose() => _controller.reverse();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(position: _slide, child: widget.child);
  }
}
