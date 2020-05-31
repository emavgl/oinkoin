import 'package:i18n_extension/i18n_extension.dart';

// this extension is for localizing and translating strings for the
// 'movements-page.dart' widget. Essentially, for each string in the
// widget, you report here the translation and related locale.
// Then, in the 'movements-page.dart' widget, you just append '.i18n' to
// the strings you want to translate (and of course import this dart file)
// e.g., "This is my message." => "This is my message.".i18n
extension Localization on String {
  static var _translations = Translations("en_us") +
      {
        "en_us": "This is my message.",
        "it_it": "Questo è il mio messaggio.",
        "es_es": "TODO",
        "fr_fr": "TODO",
        "de_de": "TODO",
      } +
      {
        "en_us": "My title",
        "it_it": "Il mio titolo",
        "es_es": "TODO",
        "fr_fr": "TODO",
        "de_de": "TODO",
      } +
      {
        "en_us": "April",
        "it_it": "Aprile",
        "es_es": "Avril",
        "fr_fr": "Abril",
        "de_de": "TODO",
      };

  String get i18n => localize(this, _translations);
}
