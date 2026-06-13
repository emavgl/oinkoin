import 'package:flutter/material.dart';
import 'package:piggybank/i18n.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/settings/components/setting-separator.dart';
import 'package:piggybank/settings/constants/preferences-keys.dart';
import 'package:piggybank/settings/constants/preferences-options.dart';
import 'package:piggybank/settings/dropdown-customization-item.dart';
import 'package:piggybank/settings/preferences-utils.dart';
import 'package:piggybank/components/inapp-keyboard.dart';

class KeyboardSettingsPage extends StatefulWidget {
  const KeyboardSettingsPage({super.key});

  @override
  State<KeyboardSettingsPage> createState() => _KeyboardSettingsPageState();
}

class _KeyboardSettingsPageState extends State<KeyboardSettingsPage> {
  late String keyboardTypeKey;
  late String keyboardScaleKey;
  late String bgColorKey;
  late String buttonColorKey;
  late String textColorKey;

  static String _keyFromMap<T>(Map<String, T> map, T value) {
    return map.entries
        .firstWhere((e) => e.value == value,
            orElse: () => MapEntry(map.keys.first, value))
        .key;
  }

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  bool get _isInAppKeyboardSelected =>
      PreferencesOptions.amountInputKeyboardType[keyboardTypeKey] == 2;

  void _loadPreferences() {
    final prefs = ServiceConfig.sharedPreferences!;
    keyboardTypeKey = _keyFromMap(
      PreferencesOptions.amountInputKeyboardType,
      PreferencesUtils.getOrDefault<int>(prefs, PreferencesKeys.amountInputKeyboardType)!,
    );
    keyboardScaleKey = _keyFromMap(
      PreferencesOptions.inAppKeyboardScaleOptions,
      PreferencesUtils.getOrDefault<int>(prefs, PreferencesKeys.inAppKeyboardScale)!,
    );
    bgColorKey = _keyFromMap(
      PreferencesOptions.inAppKeyboardBackgroundColorOptions,
      PreferencesUtils.getOrDefault<int>(prefs, PreferencesKeys.inAppKeyboardBackgroundColorIndex)!,
    );
    buttonColorKey = _keyFromMap(
      PreferencesOptions.inAppKeyboardButtonColorOptions,
      PreferencesUtils.getOrDefault<int>(prefs, PreferencesKeys.inAppKeyboardButtonColorIndex)!,
    );
    textColorKey = _keyFromMap(
      PreferencesOptions.inAppKeyboardTextColorOptions,
      PreferencesUtils.getOrDefault<int>(prefs, PreferencesKeys.inAppKeyboardTextColorIndex)!,
    );
  }

  /// Builds a small filled circle for the given [color].
  /// Light colors get a grey border so they're visible against a white dialog.
  Widget _colorDot(Color color) {
    final needsBorder = color.computeLuminance() > 0.85;
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: needsBorder
            ? Border.all(color: Colors.grey.shade400, width: 1)
            : null,
      ),
    );
  }

  Map<String, Widget> _bgColorSwatches(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Color resolveForSwatch(int index) {
      final fixed = index >= 0 && index < kKeyboardBgColors.length
          ? kKeyboardBgColors[index]
          : null;
      if (fixed != null) return fixed;
      if (index == 7) return Theme.of(context).scaffoldBackgroundColor;
      return cs.secondaryContainer;
    }

    return {
      for (final entry in PreferencesOptions.inAppKeyboardBackgroundColorOptions.entries)
        entry.key: _colorDot(resolveForSwatch(entry.value)),
    };
  }

  Map<String, Widget> _buttonColorSwatches(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return {
      for (final entry in PreferencesOptions.inAppKeyboardButtonColorOptions.entries)
        entry.key: _colorDot(
          entry.value == 0
              ? cs.surface
              : kKeyboardButtonColors[entry.value] ?? cs.surface,
        ),
    };
  }

  void _showPreview() {
    final controller = TextEditingController();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (ctx) => Scaffold(
        appBar: AppBar(title: Text('Preview'.i18n)),
        body: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Expanded(
              child: Center(
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (ctx, value, _) => Text(
                    value.text.isEmpty ? '0' : value.text,
                    style: Theme.of(ctx).textTheme.displayLarge,
                  ),
                ),
              ),
            ),
            InAppKeyboard(
              controller: controller,
              onSubmit: (_) => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Keyboard Settings'.i18n)),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SettingSeparator(title: 'Keyboard Type'.i18n),
            DropdownCustomizationItem(
              title: 'Amount input keyboard type'.i18n,
              subtitle: 'Select the keyboard layout for amount input'.i18n,
              dropdownValues: PreferencesOptions.amountInputKeyboardType,
              selectedDropdownKey: keyboardTypeKey,
              sharedConfigKey: PreferencesKeys.amountInputKeyboardType,
              onChanged: () => setState(() => _loadPreferences()),
            ),
            Visibility(
              visible: _isInAppKeyboardSelected,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SettingSeparator(title: 'Appearance'.i18n),
                  DropdownCustomizationItem(
                    title: 'Keyboard size'.i18n,
                    subtitle: 'Adjust the overall keyboard scale'.i18n,
                    dropdownValues: PreferencesOptions.inAppKeyboardScaleOptions,
                    selectedDropdownKey: keyboardScaleKey,
                    sharedConfigKey: PreferencesKeys.inAppKeyboardScale,
                    onChanged: () => setState(() => _loadPreferences()),
                  ),
                  DropdownCustomizationItem(
                    title: 'Background color'.i18n,
                    subtitle: 'Select the keyboard background color'.i18n,
                    dropdownValues: PreferencesOptions.inAppKeyboardBackgroundColorOptions,
                    selectedDropdownKey: bgColorKey,
                    sharedConfigKey: PreferencesKeys.inAppKeyboardBackgroundColorIndex,
                    onChanged: () => setState(() => _loadPreferences()),
                    optionTrailingWidgets: _bgColorSwatches(context),
                  ),
                  DropdownCustomizationItem(
                    title: 'Button color'.i18n,
                    subtitle: 'Select the keyboard button color'.i18n,
                    dropdownValues: PreferencesOptions.inAppKeyboardButtonColorOptions,
                    selectedDropdownKey: buttonColorKey,
                    sharedConfigKey: PreferencesKeys.inAppKeyboardButtonColorIndex,
                    onChanged: () => setState(() => _loadPreferences()),
                    optionTrailingWidgets: _buttonColorSwatches(context),
                  ),
                  DropdownCustomizationItem(
                    title: 'Button text color'.i18n,
                    subtitle: 'Select the keyboard button text color'.i18n,
                    dropdownValues: PreferencesOptions.inAppKeyboardTextColorOptions,
                    selectedDropdownKey: textColorKey,
                    sharedConfigKey: PreferencesKeys.inAppKeyboardTextColorIndex,
                    onChanged: () => setState(() => _loadPreferences()),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _showPreview,
                  icon: const Icon(Icons.preview_outlined),
                  label: Text('Preview keyboard'.i18n),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

