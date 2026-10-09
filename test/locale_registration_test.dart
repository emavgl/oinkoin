import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/services/locale-service.dart';
import 'package:piggybank/settings/constants/preferences-options.dart';

/// Guards every place a language has to be registered in (see CLAUDE.md):
/// the locale JSON, [LocaleService.supportedLocales], the language picker and
/// Android's locales_config.xml. Miss any of them and the language is either
/// unreachable or silently falls back to another one.
void main() {
  final bundledLocales = Directory('assets/locales')
      .listSync()
      .whereType<File>()
      .map((file) => file.uri.pathSegments.last)
      .where((name) => name.endsWith('.json'))
      .map((name) => name.substring(0, name.length - '.json'.length))
      .toList()
    ..sort();

  final supportedTags =
      LocaleService.supportedLocales.map((locale) => locale.toLanguageTag());
  final pickerValues = PreferencesOptions.languageLocaleValues;

  group('language registration', () {
    test('bundled locale files are supported locales', () {
      expect(bundledLocales, isNotEmpty);
      for (final tag in bundledLocales) {
        expect(
          supportedTags,
          contains(tag),
          reason: 'assets/locales/$tag.json is bundled but is missing from '
              'LocaleService.supportedLocales',
        );
      }
    });

    test('bundled locale files are selectable in the language picker', () {
      for (final tag in bundledLocales) {
        // The picker may offer the language under a region tag (ar.json is
        // offered as ar-SA), so a shared language code counts as selectable.
        final selectable = pickerValues.contains(tag) ||
            pickerValues.any((value) =>
                value != 'system' && value.split('-').first == tag);
        expect(
          selectable,
          isTrue,
          reason: 'assets/locales/$tag.json is bundled but has no entry in '
              'PreferencesOptions.languageDropdown',
        );
      }
    });

    test('every picker language resolves to a supported locale', () {
      for (final value in pickerValues.where((value) => value != 'system')) {
        final resolves = supportedTags.contains(value) ||
            supportedTags.contains(value.split('-').first);
        expect(
          resolves,
          isTrue,
          reason: 'the language picker offers "$value" but no supported '
              'locale can ever resolve to it',
        );
      }
    });

    test('bundled locale files are declared for Android', () {
      final androidConfig = File(
              'android/app/src/main/res/xml/locales_config.xml')
          .readAsStringSync();
      for (final tag in bundledLocales) {
        expect(
          androidConfig,
          contains('<locale android:name="$tag"/>'),
          reason: 'assets/locales/$tag.json is bundled but $tag is missing '
              'from locales_config.xml',
        );
      }
    });
  });
}
