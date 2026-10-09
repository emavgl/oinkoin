import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:i18n_extension/i18n_extension.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:piggybank/helpers/datetime-utility-functions.dart';
import 'package:piggybank/helpers/intl-locale-utils.dart';
import 'package:piggybank/helpers/records-utility-functions.dart';
import 'package:piggybank/services/locale-service.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/settings/constants/preferences-keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Loads date symbols for every locale intl knows about. Tibetan ("bo") is
    // not one of them, which is exactly the case under test.
    await initializeDateFormatting();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ServiceConfig.sharedPreferences = await SharedPreferences.getInstance();
    ServiceConfig.currencyLocale = null;
  });

  group('intl locale resolution', () {
    test('unknown locales resolve to the fallback tag', () {
      expect(findNumberFormatLocaleTag('bo'), isNull);
      expect(findDateFormatLocaleTag('bo'), isNull);
      expect(resolveNumberFormatLocaleTag('bo'), kIntlFallbackLocale);
      expect(resolveDateFormatLocaleTag('bo'), kIntlFallbackLocale);
    });

    test('supported locales keep their own tag', () {
      expect(findNumberFormatLocaleTag('en_US'), 'en_US');
      expect(findDateFormatLocaleTag('en_US'), 'en_US');
      expect(findDateFormatLocaleTag('it'), 'it');
      expect(resolveDateFormatLocaleTag('it'), 'it');
    });

    test('candidates cover tag, canonical and language-only forms', () {
      expect(intlLocaleCandidates('en-US'), ['en-US', 'en_US', 'en']);
      expect(intlLocaleCandidates('bo'), ['bo']);
      expect(intlLocaleCandidates('pt_BR'), ['pt_BR', 'pt']);
    });

    test('empty tags are treated as unknown', () {
      expect(findNumberFormatLocaleTag(null), isNull);
      expect(findNumberFormatLocaleTag(''), isNull);
      expect(findDateFormatLocaleTag(null), isNull);
      expect(resolveDateFormatLocaleTag(''), kIntlFallbackLocale);
    });
  });

  group('usesWesternArabicNumerals', () {
    test('does not throw for a locale intl has no data for', () {
      expect(usesWesternArabicNumerals(const Locale('bo')), isFalse);
    });

    test('still detects western arabic numerals for known locales', () {
      expect(usesWesternArabicNumerals(const Locale('en', 'US')), isTrue);
    });
  });

  group('setCurrencyLocale with an unsupported locale', () {
    test('falls back to the default locale instead of throwing', () {
      expect(() => LocaleService.setCurrencyLocale(const Locale('bo')),
          returnsNormally);
      expect(ServiceConfig.currencyLocale, LocaleService.DEFAULT_LOCALE);
      expect(ServiceConfig.currencyNumberFormat, isNotNull);
      expect(getCurrencyValueString(1234.5), matches(RegExp(r'1,?234')));
    });

    test('survives the full startup sequence for a Tibetan user', () async {
      await ServiceConfig.sharedPreferences!
          .setString(PreferencesKeys.languageLocale, 'bo');

      final currencyLocale = LocaleService.resolveCurrencyLocale();
      expect(currencyLocale, const Locale('bo'));

      expect(() => LocaleService.setCurrencyLocale(currencyLocale),
          returnsNormally);
      expect(ServiceConfig.currencyLocale, LocaleService.DEFAULT_LOCALE);
    });

    test('getNumberFormatWithCustomizations does not throw', () {
      expect(
          () => getNumberFormatWithCustomizations(locale: const Locale('bo')),
          returnsNormally);
    });
  });

  group('date formatting with an unsupported locale', () {
    test('renders without throwing when the UI language is Tibetan', () {
      I18n.define(const Locale('bo'));

      expect(getMonthStr(DateTime(2026, 10, 1)), isNotEmpty);
      expect(getDateStr(DateTime(2026, 10, 1)), isNotEmpty);
      expect(getDateRangeStr(DateTime(2026, 10, 1), DateTime(2026, 10, 31)),
          isNotEmpty);
      expect(extractMonthString(DateTime(2026, 10, 1)), isNotEmpty);
      expect(extractYearString(DateTime(2026, 10, 1)), isNotEmpty);
      expect(extractWeekdayString(DateTime(2026, 10, 1)), isNotEmpty);
    });

    test('falls back to the default locale for month and year names', () {
      I18n.define(const Locale('bo'));

      expect(getMonthStr(DateTime(2026, 10, 1)), 'October 2026');
      expect(extractMonthString(DateTime(2026, 10, 1)), 'October');
      expect(extractYearString(DateTime(2026, 10, 1)), '2026');
    });

    test('known locales keep their own formatting', () {
      I18n.define(const Locale('it'));

      expect(getMonthStr(DateTime(2026, 10, 1)), startsWith('Ottobre'));
      expect(extractMonthString(DateTime(2026, 10, 1)), 'ottobre');
    });
  });
}
