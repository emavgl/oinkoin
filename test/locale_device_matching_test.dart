import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/services/locale-service.dart';

void main() {
  group('getLocaleFromDeviceSettings', () {
    test('keeps Traditional Chinese devices on the Traditional locale', () {
      expect(
        LocaleService.getLocaleFromDeviceSettings(deviceLocales: const [
          Locale.fromSubtags(
              languageCode: 'zh', scriptCode: 'Hant', countryCode: 'TW'),
        ]),
        const Locale('zh', 'TW'),
      );
      expect(
        LocaleService.getLocaleFromDeviceSettings(deviceLocales: const [
          Locale.fromSubtags(
              languageCode: 'zh', scriptCode: 'Hant', countryCode: 'HK'),
        ]),
        const Locale('zh', 'TW'),
      );
      expect(
        LocaleService.getLocaleFromDeviceSettings(
            deviceLocales: const [Locale('zh', 'TW')]),
        const Locale('zh', 'TW'),
      );
    });

    test('keeps Simplified Chinese devices on the Simplified locale', () {
      expect(
        LocaleService.getLocaleFromDeviceSettings(deviceLocales: const [
          Locale.fromSubtags(
              languageCode: 'zh', scriptCode: 'Hans', countryCode: 'CN'),
        ]),
        const Locale('zh', 'CN'),
      );
      expect(
        LocaleService.getLocaleFromDeviceSettings(
            deviceLocales: const [Locale('zh')]),
        const Locale('zh', 'CN'),
      );
    });

    test('still matches by language when no script split exists', () {
      expect(
        LocaleService.getLocaleFromDeviceSettings(
            deviceLocales: const [Locale('pt')]),
        const Locale('pt', 'BR'),
      );
      expect(
        LocaleService.getLocaleFromDeviceSettings(
            deviceLocales: const [Locale('ja', 'JP')]),
        const Locale('ja'),
      );
      expect(
        LocaleService.getLocaleFromDeviceSettings(
            deviceLocales: const [Locale('fr', 'CA')]),
        const Locale('fr'),
      );
    });

    test('returns null when the device speaks nothing supported', () {
      expect(
        LocaleService.getLocaleFromDeviceSettings(
            deviceLocales: const [Locale('sv')]),
        isNull,
      );
      expect(
        LocaleService.getLocaleFromDeviceSettings(deviceLocales: const []),
        isNull,
      );
    });
  });
}
