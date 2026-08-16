import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/style.dart';

void main() {
  group('getFontFamilyFallbackForLocale', () {
    test('returns Noto Sans JP for Japanese locale', () {
      expect(getFontFamilyFallbackForLocale(const Locale('ja')),
          ['Noto Sans JP']);
    });

    test('returns Noto Sans SC for Simplified Chinese locale', () {
      expect(getFontFamilyFallbackForLocale(const Locale('zh', 'CN')),
          ['Noto Sans SC']);
    });

    test('returns null for locales that need no CJK fallback', () {
      expect(getFontFamilyFallbackForLocale(const Locale('en', 'US')), isNull);
      expect(getFontFamilyFallbackForLocale(const Locale('it')), isNull);
      expect(getFontFamilyFallbackForLocale(const Locale('de')), isNull);
    });
  });
}