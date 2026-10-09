import 'package:intl/intl.dart';

/// Locale tag used for formatting when `package:intl` has no data for the
/// requested locale.
///
/// intl only ships data for a subset of the locales this app supports —
/// Tibetan ("bo"), for one, has neither number nor date symbols — and throws
/// an [ArgumentError] instead of falling back to a default.
const String kIntlFallbackLocale = 'en_US';

/// Tags worth trying for [localeTag], most specific first: the tag as given,
/// its underscore form, and its bare language code. Mirrors the fallback chain
/// intl uses internally when resolving a locale.
List<String> intlLocaleCandidates(String localeTag) {
  final underscored = localeTag.replaceAll('-', '_');
  final languageOnly = underscored.split('_').first;
  return <String>{localeTag, underscored, languageOnly}.toList();
}

/// A tag intl can format numbers with for [localeTag], or `null` when it has
/// no data for it or for any of its variants.
String? findNumberFormatLocaleTag(String? localeTag) {
  if (localeTag == null || localeTag.isEmpty) return null;
  try {
    for (final candidate in intlLocaleCandidates(localeTag)) {
      if (NumberFormat.localeExists(candidate)) return candidate;
    }
  } on Exception catch (_) {
    // Number symbols are unavailable in this isolate: treat as unknown.
  }
  return null;
}

/// A tag intl can format dates with for [localeTag], or `null` when it has no
/// data for it.
///
/// Returns `null` as well when intl's date symbols have not been loaded in
/// this isolate yet. That is a different failure from an unknown locale, and
/// [DateFormat] reports it itself, so it is not worth masking here.
String? findDateFormatLocaleTag(String? localeTag) {
  if (localeTag == null || localeTag.isEmpty) return null;
  try {
    for (final candidate in intlLocaleCandidates(localeTag)) {
      if (DateFormat.localeExists(candidate)) return candidate;
    }
  } on Exception catch (_) {
    // Date symbols not initialized yet: fall through to the fallback tag.
  }
  return null;
}

/// Like [findDateFormatLocaleTag], but always yields a usable tag.
String resolveDateFormatLocaleTag(String? localeTag) =>
    findDateFormatLocaleTag(localeTag) ?? kIntlFallbackLocale;

/// Like [findNumberFormatLocaleTag], but always yields a usable tag.
String resolveNumberFormatLocaleTag(String? localeTag) =>
    findNumberFormatLocaleTag(localeTag) ?? kIntlFallbackLocale;
