import 'package:i18n_extension/i18n_extension.dart';

// check doc in movements-page.i18n.dart
extension Localization on String {
  static var _translations = Translations("en_us") +
      {
        "en_us": "Change Icon",
        "it_it": "Cambia Icona",
        "es_es": "TODO",
        "fr_fr": "TODO",
        "de_de": "TODO",
      } +
      {
        "en_us": "AppBar Demo",
        "it_it": "AppBar Demo (it)",
        "es_es": "TODO",
        "fr_fr": "TODO",
        "de_de": "TODO",
      };

  String get i18n => localize(this, _translations);
}
