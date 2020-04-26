import 'package:i18n_extension/i18n_extension.dart';

// check doc in movements-page.i18n.dart
extension Localization on String {
  static var _translations = Translations("en_us") +

      {
        "en_us": "Car",
        "it_it": "Macchina",
        "es_es": "TODO",
        "fr_fr": "TODO",
        "de_de": "TODO",
      } +
      {
        "en_us": "Burritos",
        "it_it": "Burrito",
        "es_es": "TODO",
        "fr_fr": "TODO",
        "de_de": "TODO",
      } +
      {
        "en_us": "Book",
        "it_it": "Libri",
        "es_es": "TODO",
        "fr_fr": "TODO",
        "de_de": "TODO",
      } +
      {
      "en_us": "Groceries",
      "it_it": "Spesa",
      "es_es": "TODO",
      "fr_fr": "TODO",
      "de_de": "TODO",
      } +
      {
      "en_us": "Coffee",
      "it_it": "Caffè",
      "es_es": "TODO",
      "fr_fr": "TODO",
      "de_de": "TODO",
      } +
      {
      "en_us": "Dinner",
      "it_it": "Cena",
      "es_es": "TODO",
      "fr_fr": "TODO",
      "de_de": "TODO",
      };

  String get i18n => localize(this, _translations);
}
