import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/settings/constants/preferences-defaults-values.dart';
import 'package:piggybank/settings/constants/preferences-keys.dart';
import 'package:piggybank/settings/preferences-utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Show Future Records Preference Tests', () {
    setUp(() async {
      // Clear all preferences before each test
      SharedPreferences.setMockInitialValues({});
    });

    test('Default value for showFutureRecords should be true', () {
      final defaultValue = PreferencesDefaultValues
          .defaultValues[PreferencesKeys.showFutureRecords];
      expect(defaultValue, true);
    });

    test('Preference key should exist', () {
      expect(PreferencesKeys.showFutureRecords, 'showFutureRecords');
    });

    test('PreferencesUtils should return default value when not set', () async {
      final prefs = await SharedPreferences.getInstance();
      final value = PreferencesUtils.getOrDefault<bool>(
          prefs, PreferencesKeys.showFutureRecords);
      expect(value, true);
    });

    test('PreferencesUtils should return stored value when set to false',
        () async {
      SharedPreferences.setMockInitialValues({
        PreferencesKeys.showFutureRecords: false,
      });

      final prefs = await SharedPreferences.getInstance();
      final value = PreferencesUtils.getOrDefault<bool>(
          prefs, PreferencesKeys.showFutureRecords);
      expect(value, false);
    });

    test('PreferencesUtils should return stored value when set to true',
        () async {
      SharedPreferences.setMockInitialValues({
        PreferencesKeys.showFutureRecords: true,
      });

      final prefs = await SharedPreferences.getInstance();
      final value = PreferencesUtils.getOrDefault<bool>(
          prefs, PreferencesKeys.showFutureRecords);
      expect(value, true);
    });

    test('Setting can be toggled', () async {
      final prefs = await SharedPreferences.getInstance();

      // Set to false
      await prefs.setBool(PreferencesKeys.showFutureRecords, false);
      var value = PreferencesUtils.getOrDefault<bool>(
          prefs, PreferencesKeys.showFutureRecords);
      expect(value, false);

      // Set to true
      await prefs.setBool(PreferencesKeys.showFutureRecords, true);
      value = PreferencesUtils.getOrDefault<bool>(
          prefs, PreferencesKeys.showFutureRecords);
      expect(value, true);
    });
  });
}
